import Foundation

/// What the app knows about the reader, as plain values.
///
/// v1.1: a struct rather than a reference to `SalaryStore`, for the same reason
/// `TaxEngine.breakdown` takes parameters: the reconciler has to be callable
/// with the reader's real answers, with an override they are trying out on the
/// review screen, and with whatever the verification script invents. `region`
/// is not defaulted, following the house rule that a region nobody chose is a
/// silently wrong answer.
struct PayslipContext {
    let region: TaxEngine.TaxRegion
    let months: Double
    let marital: MaritalSituation
    let dependents: Int
    let jovemExemption: Double
}

/// v1.1: turning read figures into what is wrong, what is right and what is
/// worth mentioning.
///
/// Two kinds of check live here and they are not equally strong.
///
/// The **self-consistency** checks need nothing but the payslip. They ask
/// whether it adds up, and they are as reliable as arithmetic. A payslip that
/// fails one of them is wrong on its own terms, whatever anybody's tax
/// situation is.
///
/// The **engine** checks compare the payslip against `TaxEngine`, and they are
/// only as good as the engine's model of the month. The engine treats the
/// holiday and Christmas subsidies as a months multiplier rather than as their
/// own taxed events, and it has no notion of a withholding base that differs
/// from gross. Both of the real payslips this was built against break one of
/// those assumptions. So these checks are gated hard, and where the gate closes
/// the reader is told the check did not run and why, which is the honest thing
/// and also the app's existing rule: say what the data cannot do, on the screen.
enum PayslipReconciler {

    /// `context` is optional, and deliberately has NO default value.
    ///
    /// Onboarding can read a payslip before it knows the region, the marital
    /// situation or the dependants, because those are later questions. Five of
    /// the ten checks do not need any of that: the three self-consistency ones,
    /// the Social Security rate, which reads a constant, and the printed rate
    /// against its own base. Running those and saying plainly that the other
    /// five cannot run yet tells the reader more than running none of them.
    ///
    /// Nil means "no profile yet", never "assume Continente". The house rule
    /// about not defaulting a parameter whose absence is a silent wrong answer
    /// is exactly why there is no default here: absence has to be spelled at
    /// every call site, and it produces a loud `profileIncomplete` skip rather
    /// than a quiet guess.
    static func check(_ facts: PayslipFacts, context: PayslipContext?) -> PayslipVerdict {
        var findings: [PayslipFinding] = []
        var skipped: [PayslipSkipped] = []

        func add(_ check: PayslipCheck, expected: Int?, actual: Int?,
                 confidence: PayslipConfidence, basis: [PayslipConcept],
                 base: Int? = nil, evidence: PayslipEvidence = .none) {
            guard let expected, let actual else {
                skipped.append(PayslipSkipped(check: check, reason: .missingFigure)); return
            }
            findings.append(PayslipFinding(
                id: check,
                tier: PayslipTiering.tier(delta: actual - expected,
                                          confidence: confidence,
                                          against: base ?? expected),
                confidence: confidence,
                expectedCents: expected, actualCents: actual,
                baseCents: base, basis: basis, evidence: evidence))
        }
        func skip(_ check: PayslipCheck, _ reason: PayslipSkipReason) {
            skipped.append(PayslipSkipped(check: check, reason: reason))
        }

        // MARK: Self-consistency

        // The columns add up to their own printed totals. This is the check
        // that earns the feature: on a photographed payslip it caught a digit
        // Vision misread, thirty cents out, without knowing which line was
        // wrong and without believing any line's name.
        //
        // v1.1a: this comment used to say "without reading a single label",
        // which was not true and mattered. The lines that get summed are
        // picked by the lexicon, so labels are read first. What arithmetic
        // does is decide, and it has the veto: a run the names picked out that
        // does not reach the printed total is reported as a gap rather than
        // accepted, and `netIdentity` throws out a triple no named run adds up
        // to. Labels propose and arithmetic disposes. Saying labels play no
        // part invited the next reader to build on a property this code does
        // not have.
        if let total = facts.totalEarnings, let gap = facts.earningsGap {
            add(.earningsSum, expected: total.cents, actual: total.cents - gap,
                confidence: min(total.confidence, lowestConfidence(facts, .earning)),
                basis: [.totalEarnings], base: total.cents)
        } else {
            skip(.earningsSum, .missingFigure)
        }

        if let total = facts.totalDeductions, let gap = facts.deductionsGap {
            add(.deductionsSum, expected: total.cents, actual: total.cents - gap,
                confidence: min(total.confidence, lowestConfidence(facts, .deduction)),
                basis: [.totalDeductions], base: total.cents)
        } else {
            skip(.deductionsSum, .missingFigure)
        }

        if facts.confirmedByNetIdentity,
           let e = facts.totalEarnings, let d = facts.totalDeductions, let n = facts.netPay {
            add(.netIdentity, expected: e.cents - d.cents, actual: n.cents,
                confidence: min(e.confidence, min(d.confidence, n.confidence)),
                basis: [.totalEarnings, .totalDeductions, .netPay], base: n.cents)
        } else {
            skip(.netIdentity, .missingFigure)
        }

        // Social Security against its own base, using the pair the 11% identity
        // found rather than the sum of every SS line on the page.
        if let base = facts.ssBase, let contribution = facts.ssContribution {
            let expected = round(cents: base.cents, byRate: TaxEngine.employeeSSRate)
            add(.ssRate, expected: expected, actual: contribution.cents,
                confidence: min(base.confidence, contribution.confidence),
                basis: [.employeeSS], base: base.cents,
                evidence: .rate(hundredths: 1100))
        } else {
            skip(.ssRate, .missingFigure)
        }

        // A printed rate reproducing its own line. Only where the payslip gave
        // us both the rate and the base it was charged on.
        if let line = facts.lines.first(where: {
            $0.statedRate != nil && $0.baseCents != nil && $0.cents != nil
        }), let rate = line.statedRate, let base = line.baseCents, let value = line.cents {
            add(.statedRate, expected: (base * rate + 5000) / 10000, actual: value,
                confidence: line.confidence, basis: line.concept.map { [$0] } ?? [],
                base: base, evidence: .rate(hundredths: rate))
        } else {
            skip(.statedRate, .missingFigure)
        }

        // MARK: Against the engine

        // The gate. `TaxEngine` models a month as gross times a schedule, with
        // withholding taken on that gross. A payslip that pays the subsidies as
        // duodecimos, or that withholds on a base which is not the gross, is
        // asking a question the engine does not answer, and running it anyway
        // would produce a confident wrong figure rather than an error.
        let paysSubsidiesSeparately = facts.lines.contains {
            $0.concept == .holidaySubsidy || $0.concept == .christmasSubsidy
        }
        let irsLine = facts.lines.first { $0.concept == .irs }

        // Three states, not two, and telling them apart is the whole point of
        // saying why a check did not run.
        //
        // v1.1a: this used to be a Bool, and both "the bases differ" and "we
        // never found one of them" came out as false, so the screen told a
        // reader their employer withholds on something other than gross when
        // the truth was that we could not read the base off the page. On the
        // photographed payslip this feature was built against, that is exactly
        // what happened: the IRS line carries no base column, so all four
        // engine checks accused the payslip of a shape it does not have.
        enum TaxBase { case isGross, isNotGross, notFound }
        let taxBase: TaxBase = {
            guard let base = facts.ssBase?.cents, let irsBase = irsLine?.baseCents
            else { return .notFound }
            return irsBase == base ? .isGross : .isNotGross
        }()

        let engineChecks: [PayslipCheck] = [.irsWithholding, .netMonthly, .jovemApplied, .regionTable]
        guard let context else {
            // No profile yet. Every check that needs the tax tables says so,
            // with the reason that already exists for it, and the five that
            // need nothing have already run above.
            engineChecks.forEach { skip($0, .profileIncomplete) }
            skip(.minWage, .profileIncomplete)
            return PayslipVerdict(findings: findings, notChecked: skipped, source: facts.source)
        }
        if paysSubsidiesSeparately {
            engineChecks.forEach { skip($0, .subsidiesPaidSeparately) }
        } else if taxBase == .isNotGross {
            engineChecks.forEach { skip($0, .taxBaseNotGross) }
        } else if taxBase == .notFound {
            engineChecks.forEach { skip($0, .missingFigure) }
        } else if let gross = facts.ssBase, let irs = facts.fact(.irs) {
            let grossEuros = Double(gross.cents) / 100
            let expected = TaxEngine.breakdown(
                grossMonthly: grossEuros, months: context.months, ajudasMonthly: 0,
                marital: context.marital, dependents: context.dependents,
                jovemExemption: context.jovemExemption, region: context.region)

            add(.irsWithholding, expected: euros(expected.irsMonthly), actual: irs.cents,
                confidence: min(gross.confidence, irs.confidence),
                basis: [.irs], base: gross.cents)

            if let net = facts.netPay {
                add(.netMonthly, expected: euros(expected.netMonthly), actual: net.cents,
                    confidence: min(gross.confidence, net.confidence),
                    basis: [.netPay], base: net.cents)
            } else {
                skip(.netMonthly, .missingFigure)
            }

            // Which region's tables the withholding actually matches. Three
            // engine calls, and a Madeira resident withheld on mainland tables
            // is worth the whole feature.
            let matched = TaxEngine.TaxRegion.allCases.min { a, b in
                abs(irsFor(grossEuros, context, a) - irs.cents)
                    < abs(irsFor(grossEuros, context, b) - irs.cents)
            }
            if let matched {
                findings.append(PayslipFinding(
                    id: .regionTable,
                    tier: matched == context.region ? .correct : .mention,
                    confidence: min(gross.confidence, irs.confidence),
                    expectedCents: irsFor(grossEuros, context, context.region),
                    actualCents: irs.cents,
                    baseCents: gross.cents, basis: [.irs], evidence: .region(matched)))
            } else {
                skip(.regionTable, .missingFigure)
            }

            // Whether the exemption looks applied, by seeing which of the two
            // engine answers the payslip actually matches.
            if context.jovemExemption > 0 {
                let withExemption = euros(expected.irsMonthly)
                let without = euros(TaxEngine.breakdown(
                    grossMonthly: grossEuros, months: context.months, ajudasMonthly: 0,
                    marital: context.marital, dependents: context.dependents,
                    jovemExemption: 0, region: context.region).irsMonthly)
                let looksApplied = abs(irs.cents - withExemption) <= abs(irs.cents - without)
                findings.append(PayslipFinding(
                    id: .jovemApplied,
                    tier: looksApplied ? .correct : .mention,
                    confidence: min(gross.confidence, irs.confidence),
                    expectedCents: withExemption, actualCents: irs.cents,
                    baseCents: gross.cents, basis: [.irs], evidence: .none))
            } else {
                skip(.jovemApplied, .profileIncomplete)
            }
        } else {
            engineChecks.forEach { skip($0, .missingFigure) }
        }

        // MARK: Minimum wage
        //
        // A mention and never an accusation. Part time, a partial month and
        // unpaid leave all put a legitimate gross below the minimum, and none
        // of them is reliably readable off the page.
        if let gross = facts.ssBase {
            let floor = euros(context.region.minWage)
            findings.append(PayslipFinding(
                id: .minWage,
                tier: gross.cents >= floor ? .correct : .mention,
                confidence: gross.confidence,
                expectedCents: floor, actualCents: gross.cents,
                baseCents: nil, basis: [.baseSalary], evidence: .none))
        } else {
            skip(.minWage, .missingFigure)
        }

        return PayslipVerdict(findings: findings, notChecked: skipped, source: facts.source)
    }

    // MARK: Helpers

    /// The weakest confidence among the lines feeding one side, so a single
    /// shaky line cannot let a whole column's sum accuse anybody.
    private static func lowestConfidence(_ facts: PayslipFacts,
                                         _ side: PayslipConcept.Side) -> PayslipConfidence {
        facts.lines
            .filter { $0.concept?.side == side && $0.cents != nil }
            .map(\.confidence)
            .min() ?? .low
    }

    /// Cents times a rate, rounded half up, in integer arithmetic.
    static func round(cents: Int, byRate rate: Double) -> Int {
        let perTenThousand = Int((rate * 10000).rounded())
        return (cents * perTenThousand + 5000) / 10000
    }

    /// Euros as `Double` from the engine, back to cents.
    static func euros(_ value: Double) -> Int { Int((value * 100).rounded()) }

    private static func irsFor(_ gross: Double, _ context: PayslipContext,
                               _ region: TaxEngine.TaxRegion) -> Int {
        euros(TaxEngine.breakdown(
            grossMonthly: gross, months: context.months, ajudasMonthly: 0,
            marital: context.marital, dependents: context.dependents,
            jovemExemption: context.jovemExemption, region: region).irsMonthly)
    }
}
