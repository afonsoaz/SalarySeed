import Foundation

/// v1.1: deciding what each line is, numbers first.
///
/// The order matters and is the whole idea. Label evidence is computed but not
/// committed until the arithmetic has had its say, because on a photographed
/// payslip the labels are the part OCR reads well and the numbers are the part
/// it reads badly, while on the page it is the numbers that are constrained and
/// the labels that are arbitrary.
///
/// Three identities do the work, none of which needs to read a word:
///
///  - **Net.** Some earnings total minus some deductions total equals some net.
///    That single triple names three figures at once and tells us which column
///    is which. Measured: 2480,00 - 611,52 = 1868,48 on one payslip and
///    3187,40 - 1264,05 = 1923,35 on the other.
///  - **Eleven percent.** Employee Social Security is 11% of a base.
///    11 x 274186 = 3016046 against 100 x 30160 = 3016000, forty-six hundredths
///    of a cent apart, which finds both the contribution and its base on a
///    payslip that called the line "Segurança Social (11%)" and on one that
///    called it "Seg. social empregado".
///  - **Contiguous runs.** The lines immediately above a printed total sum to
///    it. When they do not, the gap is the size of the error and the run is
///    where to look.
///
/// That last one is the safety net under every OCR mistake. On a real
/// photographed payslip Vision read 187,90 as 187,60, and the deductions run
/// came to 1263,75 against a printed 1264,05: caught, thirty cents out,
/// without needing to know which of the lines was the misread one.
///
/// Be precise about the ordering, because it is the feature and it is easy to
/// overstate. Labels are read FIRST: the lexicon is what picks which lines
/// belong to a side, and `netIdentity` will not accept a triple unless a
/// named run adds up to one of its totals. What the arithmetic has is the
/// VETO. A name can put a line in the run; only the sum can confirm the run,
/// and a run that misses its printed total is reported as a gap rather than
/// quietly accepted. So the rule to protect is not "labels are never read", it
/// is "no label reaches a verdict that the arithmetic has not agreed with".
enum PayslipClassifier {

    /// 11% of a base, in hundredths of a cent. Rounding alone cannot exceed
    /// half a cent, so 50 is the exact-match window.
    static let ssExactWindow = 50
    /// A wider window that still means "this is the Social Security line", used
    /// only to identify, never to assert the figure is right.
    static let ssWeakWindow = 550

    /// How far an unconfirmed total may miss its own lines before we stop
    /// believing it is the total. Ten, so a gap of more than a tenth.
    static let unconfirmedShare = 10

    // MARK: Entry point

    static func classify(_ reading: PayslipReading) -> PayslipFacts {
        let amounts = reading.amounts
        let net = netIdentity(in: amounts, lines: reading.lines)
        let ss = ssIdentity(in: amounts, lines: reading.lines)

        var claimed = Set<Int>()
        if let net {
            for a in [net.earnings, net.deductions, net.net] { claimed.insert(key(a)) }
        }

        // A payslip totals itself and then stops. Everything at or after the
        // totals row is commentary: on one real payslip a Valores Acumulados
        // block with year-to-date figures that satisfy every identity a line
        // item would.
        let totalsLine = net.map { min($0.earnings.lineIndex, $0.deductions.lineIndex, $0.net.lineIndex) }
            ?? Int.max
        // No single line can be bigger than the total it feeds. This is what
        // keeps a header's accumulated figure (22 311,80 against a 3 187,40
        // month) from being read as a line item.
        let ceiling = net?.earnings.cents ?? Int.max

        let earningsColumn = net?.earnings.columnIndex
        let deductionsColumn = net?.deductions.columnIndex

        var classified: [PayslipClassifiedLine] = []

        for line in reading.lines {
            let candidates = line.amounts.filter { !claimed.contains(key($0)) }
            // The value is the last amount on the line. Every payslip layout
            // puts the figure that counts to the right of the quantity, the
            // rate and the base it was computed on.
            let value = candidates.last
            let base = candidates.count >= 2 ? candidates[candidates.count - 2] : nil
            let insideTable = line.index < totalsLine
                && (value.map { abs($0.cents) <= ceiling } ?? false)

            // v1.1a: the two totals have to be in DIFFERENT columns before a
            // column can say anything about a side.
            //
            // `netIdentity` accepts a triple whose earnings and deductions
            // totals share one money column, because a payslip that stacks the
            // two blocks vertically prints both totals under the same edge. On
            // that layout these two indexes are equal, the first test below
            // won every time, and every deduction on the page was reported as
            // an earning. The label fallback under `filtered` happened to undo
            // it, so the reading came out right for the wrong reason and either
            // fix on its own would have broken it.
            let columnsDistinguishSides = earningsColumn != nil
                && deductionsColumn != nil
                && earningsColumn != deductionsColumn
            let sideFromColumn: PayslipConcept.Side? = !columnsDistinguishSides ? nil
                : value.flatMap { amount in
                    guard let column = amount.columnIndex else { return nil }
                    if column == earningsColumn { return .earning }
                    if column == deductionsColumn { return .deduction }
                    return nil
                }

            // The column narrows the label's candidates and does not overrule
            // them. A name on the page is better evidence about what a line IS
            // than the edge its figure happens to be aligned to, and the
            // ordering this feature rests on is about which evidence decides a
            // VERDICT, not which decides a name: nothing here reaches a finding
            // until `netIdentity` and the side sums have agreed with it. When
            // the column and every candidate disagree, the name still wins and
            // the column survives as the line's `alternative`, so the review
            // screen can put the question to the reader instead of the app
            // resolving it behind them.
            let byLabel = insideTable ? PayslipLexicon.candidates(for: line.label) : []
            let filtered = sideFromColumn.map { side in
                byLabel.filter { $0.concept.side == side }
            } ?? byLabel
            let labelConcept = (filtered.first ?? byLabel.first)?.concept
            let columnDisagreed = sideFromColumn != nil
                && !byLabel.isEmpty
                && filtered.isEmpty

            var arithmeticConcept: PayslipConcept?
            if let ss, let value, key(value) == key(ss.contribution), insideTable {
                arithmeticConcept = .employeeSS
            }

            var (concept, provenance, alternative) = reconcile(
                label: labelConcept, arithmetic: arithmeticConcept)

            // A column that contradicts every name the lexicon offered is not
            // enough to rename the line, and it is too much to throw away. The
            // line keeps its name, stops being able to accuse anybody, and goes
            // to the reader as a question. This is the same treatment a
            // label/arithmetic disagreement gets, for the same reason.
            if columnDisagreed, provenance != .disputed {
                provenance = .disputed
            }

            classified.append(PayslipClassifiedLine(
                lineIndex: line.index,
                rawLabel: line.rawLabel,
                concept: concept,
                cents: insideTable ? value?.cents : nil,
                provenance: provenance,
                confidence: confidence(provenance: provenance,
                                       source: reading.source,
                                       repaired: value?.repaired ?? false,
                                       damaged: line.hasUnreadableToken),
                alternative: alternative,
                statedRate: line.statedRate,
                baseCents: insideTable ? base?.cents : nil,
                repaired: value?.repaired ?? false))
        }

        classified = inferSideOfUnnamedLines(classified, before: totalsLine)

        func total(_ amount: PayslipAmount?, _ concept: PayslipConcept) -> PayslipFact? {
            guard let amount else { return nil }
            let agreed = reading.lines.indices.contains(amount.lineIndex)
                && PayslipLexicon.best(for: reading.lines[amount.lineIndex].label) == concept
            return PayslipFact(
                cents: amount.cents,
                provenance: agreed ? .labelAndArithmetic : .arithmetic,
                confidence: amount.repaired ? .low : (reading.source.isExactText ? .high : .medium),
                lineIndexes: [amount.lineIndex])
        }
        let earningsTotal = total(net?.earnings, .totalEarnings)
        let deductionsTotal = total(net?.deductions, .totalDeductions)
        var earnings = sideSum(.earning, lines: classified, total: earningsTotal)
        var deductions = sideSum(.deduction, lines: classified, total: deductionsTotal)

        // A total we could not confirm, and which its own lines then miss by a
        // wide margin, is more likely to be the wrong number than a payslip
        // that is a fifth wrong.
        //
        // This matters because a payslip can carry several figures that satisfy
        // earnings minus deductions equals net. One real payslip's Valores
        // Acumulados block has a monthly column where the Social Security and
        // the IRS happen to add up to its own "descontos do funcionário", and
        // when the real net was misread that block was the only triple left
        // standing. The screen then reported the month's deductions as 187,90
        // out, which is not a finding, it is an artefact.
        //
        // The line is drawn by magnitude, and only for a side the labels never
        // confirmed. Missing a total by a tenth is not a payroll error anybody
        // makes; missing it by 0,30 is exactly what a misread digit looks like,
        // and that case still reaches the reader.
        var keptEarnings = earningsTotal
        var keptDeductions = deductionsTotal
        if let total = earningsTotal, let gap = earnings?.gap,
           net?.earningsSupported == false, abs(gap) * unconfirmedShare > abs(total.cents) {
            keptEarnings = nil
            earnings = nil
        }
        if let total = deductionsTotal, let gap = deductions?.gap,
           net?.deductionsSupported == false, abs(gap) * unconfirmedShare > abs(total.cents) {
            keptDeductions = nil
            deductions = nil
        }

        return PayslipFacts(
            source: reading.source,
            lines: classified,
            // v1.1a: this used to be a flat `.high`, which was the one figure
            // in the app that claimed certainty it had not earned. `ssBase` is
            // the gross every engine check and the minimum-wage comparison
            // rest on, so a photographed payslip reported its gross as high
            // confidence while every other figure on the same page was low.
            //
            // It now follows the same rule as the contribution beside it, plus
            // one more: a pair matched only inside the weak 11% window agreed
            // to within five euros rather than to the cent, and that is a
            // guess about which figure is the base. `SSPair.exact` existed for
            // this and was read by nothing.
            ssBase: ss.map {
                PayslipFact(cents: $0.base.cents, provenance: .arithmetic,
                            confidence: $0.base.repaired ? .low
                                : !$0.exact ? .medium
                                : (reading.source.isExactText ? .high : .medium),
                            lineIndexes: [$0.base.lineIndex])
            },
            ssContribution: ss.map {
                PayslipFact(cents: $0.contribution.cents, provenance: .arithmetic,
                            confidence: $0.contribution.repaired ? .low
                                : (reading.source.isExactText ? .high : .medium),
                            lineIndexes: [$0.contribution.lineIndex])
            },
            totalEarnings: keptEarnings,
            totalDeductions: keptDeductions,
            netPay: total(net?.net, .netPay),
            confirmedByNetIdentity: net != nil,
            earningsRun: earnings?.lineIndexes ?? [],
            deductionsRun: deductions?.lineIndexes ?? [],
            earningsGap: earnings?.gap,
            deductionsGap: deductions?.gap)
    }

    /// Gives a side to a line that carries a figure and no recognised name.
    ///
    /// A real payslip carried "Deduction - CIGNA July  24,00", an employer's
    /// health plan, in English, on an otherwise Portuguese document. Nothing
    /// will ever match it by name, and leaving it out made the deductions come
    /// up 24 euros short against their own printed total, which is a false
    /// accusation manufactured out of a vocabulary gap.
    ///
    /// Payslips group their sides, so an unnamed line between two deductions is
    /// a deduction.
    ///
    /// It fires in two cases: a classified line on the same side above AND
    /// below, or a classified line above and nothing classified below before
    /// the totals. The second is not a weaker version of the first, it is the
    /// last line of a block, and it is load-bearing: on one of the two real
    /// payslips a 24 euro line sits below the last named deduction and above
    /// the totals, and without this arm it goes unclassified, drops out of the
    /// deductions run, and the payslip is accused of being 24 euros short
    /// against its own printed total.
    ///
    /// A header row is left alone because it has nothing classified ABOVE it,
    /// which is what `above` being nil means. v1.1a: the guard used to end in
    /// `|| (below == nil && above != nil)`, where `above != nil` could never be
    /// false, since `above` had already been unwrapped to produce the side. The
    /// dead half made the condition look symmetric and hid which case was
    /// actually doing the work.
    static func inferSideOfUnnamedLines(_ lines: [PayslipClassifiedLine],
                                        before totalsLine: Int) -> [PayslipClassifiedLine] {
        var out = lines
        for (position, line) in lines.enumerated() {
            guard line.concept == nil, line.cents != nil, line.lineIndex < totalsLine else { continue }
            let above = lines[..<position].last { $0.concept?.side == .earning || $0.concept?.side == .deduction }
            let below = lines[(position + 1)...].first { $0.concept?.side == .earning || $0.concept?.side == .deduction }
            guard let side = above?.concept?.side,
                  side == below?.concept?.side || below == nil else { continue }
            out[position] = PayslipClassifiedLine(
                lineIndex: line.lineIndex, rawLabel: line.rawLabel,
                concept: side == .deduction ? .otherDeduction : .otherEarning,
                cents: line.cents, provenance: .arithmetic,
                confidence: min(line.confidence, .medium),
                alternative: nil, statedRate: line.statedRate,
                baseCents: line.baseCents, repaired: line.repaired)
        }
        return out
    }

    // MARK: The net identity

    struct NetTriple {
        let earnings: PayslipAmount
        let deductions: PayslipAmount
        let net: PayslipAmount
        /// Whether each total was confirmed by the named lines above it adding
        /// up to it. A side that was not confirmed is one we are reasoning
        /// about on position alone.
        let earningsSupported: Bool
        let deductionsSupported: Bool
    }

    /// Finds earnings - deductions = net among everything on the page.
    ///
    /// A real payslip contains more than one true instance of this. The
    /// Valores Acumulados block on one of them satisfies it exactly with
    /// year-to-date figures, and its earnings figure is the LARGER of the two,
    /// so magnitude picks the wrong triple. Label agreement does not save it
    /// either: that payslip labels its real totals row just "Total", which
    /// matches nothing, so both triples scored zero.
    ///
    /// Position helps: a payslip totals itself and then, if it says anything
    /// else, says it afterwards, so the earliest triple is the month's.
    ///
    /// Position is not enough on its own. When the real net is misread, the
    /// real triple cannot be formed at all, and the year-to-date one is then
    /// the only candidate left standing rather than merely the second-best.
    /// That happened on a device, and the screen confidently reported the
    /// month's pay as 544,38 out.
    ///
    /// So a total has to be a total OF something: the lines above it, on its
    /// own side, have to add up to it. That is what `support` scores, and a
    /// triple with no support at all is rejected outright. The checks that
    /// needed it are then reported as not run, which is the honest answer and
    /// far better than two large findings invented out of a year-to-date
    /// summary.
    static func netIdentity(in amounts: [PayslipAmount], lines: [PayslipLine]) -> NetTriple? {
        let positive = amounts.filter { $0.cents > 0 }
        guard positive.count >= 3 else { return nil }

        func concept(_ a: PayslipAmount) -> PayslipConcept? {
            guard lines.indices.contains(a.lineIndex) else { return nil }
            return PayslipLexicon.best(for: lines[a.lineIndex].label)
        }

        /// Whether the lines above this amount, on the given side, add up to
        /// it. Labels only: the columns are not known yet, and this is what
        /// decides them.
        func isSupported(_ total: PayslipAmount, _ side: PayslipConcept.Side) -> Bool {
            var sum = 0
            for line in lines where line.index < total.lineIndex {
                guard let value = line.amounts.last?.cents,
                      PayslipLexicon.best(for: line.label)?.side == side else { continue }
                sum += value
            }
            return sum > 0 && sum == total.cents
        }

        // `size` holds the triple's last line index: earlier is better.
        var best: (triple: NetTriple, score: Int, size: Int)?
        for e in positive {
            for d in positive where d.cents < e.cents && key(d) != key(e) {
                let target = e.cents - d.cents
                for n in positive where n.cents == target && key(n) != key(e) && key(n) != key(d) {
                    var score = 0
                    // A total that its own lines add up to is a real total.
                    // Weighted above every naming signal, because a label can
                    // be missing or generic ("Total") and arithmetic cannot.
                    let supported = (isSupported(e, .earning) ? 1 : 0)
                        + (isSupported(d, .deduction) ? 1 : 0)
                    guard supported > 0 else { continue }
                    score += 6 * supported
                    if concept(e) == .totalEarnings { score += 2 }
                    if concept(d) == .totalDeductions { score += 2 }
                    if concept(n) == .netPay { score += 2 }
                    if e.columnIndex != d.columnIndex { score += 1 }
                    let triple = NetTriple(earnings: e, deductions: d, net: n,
                                           earningsSupported: isSupported(e, .earning),
                                           deductionsSupported: isSupported(d, .deduction))
                    let last = max(e.lineIndex, d.lineIndex, n.lineIndex)
                    if best == nil || score > best!.score
                        || (score == best!.score && last < best!.size) {
                        best = (triple, score, last)
                    }
                }
            }
        }
        return best?.triple
    }

    // MARK: The eleven percent identity

    struct SSPair {
        let base: PayslipAmount
        let contribution: PayslipAmount
        let exact: Bool
    }

    /// Finds the employee Social Security line by what it is, not what it is
    /// called. The rate is read from `TaxEngine`, never retyped here.
    static func ssIdentity(in amounts: [PayslipAmount], lines: [PayslipLine]) -> SSPair? {
        let rate = Int((TaxEngine.employeeSSRate * 100).rounded())   // 11
        var best: (pair: SSPair, score: Int, size: Int)?
        for base in amounts where base.cents > 0 {
            for ss in amounts where ss.cents > 0 && key(ss) != key(base) && ss.cents < base.cents {
                let delta = abs(rate * base.cents - 100 * ss.cents)
                guard delta <= ssWeakWindow else { continue }
                var score = delta <= ssExactWindow ? 2 : 0
                if lines.indices.contains(ss.lineIndex),
                   PayslipLexicon.best(for: lines[ss.lineIndex].label) == .employeeSS {
                    score += 3
                }
                if best == nil || score > best!.score
                    || (score == best!.score && base.cents > best!.size) {
                    best = (SSPair(base: base, contribution: ss, exact: delta <= ssExactWindow),
                            score, base.cents)
                }
            }
        }
        return best?.pair
    }

    // MARK: Summing a side

    struct SideSum {
        let lineIndexes: [Int]
        /// Printed total minus what the lines add up to. Zero reconciles.
        let gap: Int
    }

    /// Adds up every line on one side and compares it with the printed total.
    ///
    /// This replaced a contiguous-run search, which only works when the two
    /// columns sit side by side. One of the two real payslips stacks them
    /// vertically instead, earnings block above deductions block, so the lines
    /// immediately above the earnings total are all deductions and no run from
    /// there could ever reach it.
    ///
    /// Summing by side works on both layouts and is what catches a misread
    /// digit: on the photographed payslip the deductions come to 1263,75
    /// against a printed 1264,05, thirty cents out, with the arithmetic never
    /// having read a single label.
    static func sideSum(_ side: PayslipConcept.Side, lines: [PayslipClassifiedLine],
                        total: PayslipFact?) -> SideSum? {
        guard let total else { return nil }
        let members = lines.filter { $0.concept?.side == side && $0.cents != nil }
        guard !members.isEmpty else { return nil }
        let sum = members.reduce(0) { $0 + ($1.cents ?? 0) }
        return SideSum(lineIndexes: members.map(\.lineIndex), gap: total.cents - sum)
    }

    // MARK: Reconciling the two kinds of evidence

    private static func reconcile(
        label: PayslipConcept?, arithmetic: PayslipConcept?
    ) -> (PayslipConcept?, PayslipProvenance, PayslipConcept?) {
        switch (label, arithmetic) {
        case let (l?, a?) where l == a:
            return (l, .labelAndArithmetic, nil)
        case let (l?, a?):
            // Both spoke and they disagree. The arithmetic is the better
            // witness, but the reader is told, and the confidence drop stops
            // this line accusing anybody.
            return (a, .disputed, l)
        case let (nil, a?):
            return (a, .arithmetic, nil)
        case let (l?, nil):
            return (l, .label, nil)
        case (nil, nil):
            // No name and no identity, so nothing is claimed here.
            //
            // There used to be a second rule at this point: a line inside the
            // table whose figure sat in the deductions column became an
            // unexplained deduction on the strength of the column alone. On a
            // real payslip that turned "N.º Dias Úteis 22.00", the count of
            // working days printed in the header, into a 22 euro deduction,
            // because a day count is written exactly like money and happened
            // to be right-aligned under the same edge.
            //
            // `inferSideOfUnnamedLines` does this job properly, by requiring
            // a classified line ABOVE before it will guess, and agreement from
            // the one below where there is one. A header row has nothing above
            // it and is left alone; a genuine unnamed deduction sitting among
            // named ones, or closing the block, is still picked up.
            return (nil, .label, nil)
        }
    }

    private static func confidence(provenance: PayslipProvenance, source: PayslipSource,
                                   repaired: Bool, damaged: Bool) -> PayslipConfidence {
        if provenance == .disputed || damaged || repaired { return .low }
        switch provenance {
        case .labelAndArithmetic, .arithmetic:
            return source.isExactText ? .high : .medium
        case .label:
            return source.isExactText ? .medium : .low
        case .disputed:
            return .low
        }
    }

    /// Identity of an amount by where it sat, so the same figure appearing
    /// twice on a payslip stays two different amounts.
    private static func key(_ a: PayslipAmount) -> Int {
        a.lineIndex &* 1000 &+ (a.columnIndex ?? 999)
    }
}
