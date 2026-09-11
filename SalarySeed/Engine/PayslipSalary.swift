import Foundation

/// v1.2: turning what was read off a payslip into a salary the app could keep.
///
/// This is the only place a figure crosses from the payslip reader into the rest
/// of the app, and it is deliberately one pure function with no view and no
/// storage behind it. Getting the mapping wrong would not produce a visible bug:
/// it would quietly poison every number the app draws, because gross monthly is
/// the single input net, yearly, cost to employer, the percentile and Grow's
/// projection are all pure functions of.
///
/// It lives in `Engine/` so `tools/payslip_probe` can compile it and print what
/// it decides about a real file, which is the only way to check a judgement. That
/// costs it `AmountKind` and `PaySchedule`, which live in `Models/SalaryStore.swift`
/// alongside SwiftUI and would drag the whole of `Models/` into a Foundation-only
/// tool. So this speaks integer cents and its own enums, and the two call sites
/// convert.
///
/// It REFUSES rather than guesses, and the refusals have names. A false refusal
/// costs one tap on "type it myself". A false proposal costs every figure in the
/// app, for as long as the reader keeps the app.
enum PayslipSalary {

    /// Everything this could not do, each with the actual reason.
    ///
    /// Four cases and not a `nil`, for the reason `PayslipSkipReason` has four:
    /// collapsing "the figures disagree" and "we never found one" into a single
    /// boolean once made the app accuse a payslip of withholding on the wrong
    /// base when it had simply failed to read the base.
    enum Refusal: String {
        /// The 11% identity never fired, so no arithmetic vouches for a gross.
        case noGrossFigure
        /// The gross rests on a repaired token or a weak match. A figure we had
        /// to guess at may not quietly become somebody's salary, which is the
        /// "cannot accuse anybody" rule applied to a write.
        case grossOnlyGuessed
        /// The holiday or Christmas subsidy is on its own line. See below.
        case subsidiesOnTheirOwnLine
        /// Something unaccounted for sits in the earnings total, and we cannot
        /// tell whether it belongs in gross or outside it.
        case earningsDisagree
    }

    /// Whether a second, independent reading of the page agreed.
    ///
    /// Three states rather than a Bool, again. "The totals agreed", "there was no
    /// total to check against" and "the totals disagreed" are different things to
    /// tell somebody, and the third is a refusal rather than a proposal.
    enum Corroboration: Equatable {
        case agreed(totalEarningsCents: Int)
        case notAvailable
    }

    /// Said on screen, unconditionally, rather than left for the reader to work
    /// out. A payslip is one month and it cannot answer questions about a year.
    enum Assumption: String {
        /// A payslip cannot tell you whether you are paid 12 or 14 times.
        case scheduleNotFromPayslip
        /// One month, which may not be a typical one.
        case oneMonthOnly
        /// The store keeps the meal allowance and ajudas de custo in one field.
        case mealAllowanceFoldedIntoAjudas
        /// Neither was found, which is not the same as there being none.
        case ajudasNotFound
    }

    /// A monthly GROSS, never a net.
    ///
    /// The name is load-bearing. A payslip's líquido is not the app's net salary:
    /// it already has ajudas de custo and the meal allowance added in and non-tax
    /// deductions like union dues taken out. Handing it to `grossFromNet` would
    /// send a number that is not a net into a 60-round bisection and poison the
    /// whole breakdown. If anything ever wants to propose a net, it needs a
    /// different type and a much better argument.
    struct GrossProposal {
        let monthlyGrossCents: Int
        /// The meal allowance plus ajudas de custo, where either was found. `nil`
        /// rather than 0, because a line we did not find is not a line that is
        /// not there.
        let ajudasMonthlyCents: Int?
        let corroboration: Corroboration
        let confidence: PayslipConfidence
        /// The lines this rests on, so a screen can point at them.
        let lineIndexes: [Int]
        let assumptions: [Assumption]
    }

    enum Outcome {
        case proposal(GrossProposal)
        case cannot(Refusal)
    }

    /// The concepts that are earnings on the page and are NOT part of gross.
    ///
    /// Ajudas de custo are the app's whole reason for existing: they arrive as
    /// pay, they are outside the Social Security base, and the long-term cost of
    /// being paid that way is what the app is for. Folding them into a gross
    /// would hide exactly the thing it is supposed to show.
    static let outsideGross: [PayslipConcept] = [.mealAllowance, .ajudas]

    static func propose(_ facts: PayslipFacts) -> Outcome {
        // Gross is `ssBase` and not `totalEarnings`, and not `fact(.baseSalary)`.
        //
        // It is the figure the employer actually charged 11% on, which is the
        // app's own notion of gross for tax. It is already what
        // `PayslipReconciler` uses as the gross for every engine check, so the
        // salary this proposes and the verdict on the same screen cannot rest on
        // two different numbers. And it is found by arithmetic, where
        // `fact(.baseSalary)` is found by a label: no name may decide the number
        // every other number in the app derives from.
        guard let gross = facts.ssBase else { return .cannot(.noGrossFigure) }
        guard gross.confidence > .low else { return .cannot(.grossOnlyGuessed) }

        // A month paying the subsidies as duodécimos has an incidence base of
        // roughly base x 14/12. Stored as a monthly salary on a 14 month
        // schedule, that is 16.7% too high, in the flattering direction,
        // silently, for ever. Telling a duodécimo month from a June or November
        // subsidy month needs a ratio test, and there are no real payslips here
        // to build one on. So this refuses, which is the same thing
        // `PayslipReconciler` does with `subsidiesPaidSeparately` and for the
        // same reason.
        let paysSubsidiesSeparately = facts.lines.contains {
            $0.concept == .holidaySubsidy || $0.concept == .christmasSubsidy
        }
        if paysSubsidiesSeparately { return .cannot(.subsidiesOnTheirOwnLine) }

        let meal = facts.fact(.mealAllowance)
        let ajudas = facts.fact(.ajudas)
        let outside = [meal, ajudas].compactMap { $0?.cents }.reduce(0, +)
        let ajudasCents = (meal == nil && ajudas == nil) ? nil : outside

        var corroboration = Corroboration.notAvailable
        var confidence = gross.confidence
        var lines = gross.lineIndexes

        if let total = facts.totalEarnings {
            // The corroboration, and the only thing here that is more than one
            // reading of the page. Earnings minus what sits outside gross should
            // BE the gross, and the two figures were found by different routes:
            // one by the 11% identity, the other by a printed total that its own
            // lines add up to. Two independent paths agreeing is a much stronger
            // claim than either alone, and it is "a total has to be a total of
            // something" pointed at the salary.
            let difference = total.cents - outside - gross.cents
            guard abs(difference) <= PayslipTiering.roundingCents else {
                return .cannot(.earningsDisagree)
            }
            corroboration = .agreed(totalEarningsCents: total.cents)
            confidence = min(confidence, total.confidence)
            lines += total.lineIndexes
        }

        var assumptions: [Assumption] = [.scheduleNotFromPayslip, .oneMonthOnly]
        if meal != nil { assumptions.append(.mealAllowanceFoldedIntoAjudas) }
        if ajudasCents == nil { assumptions.append(.ajudasNotFound) }

        return .proposal(GrossProposal(
            monthlyGrossCents: gross.cents,
            ajudasMonthlyCents: ajudasCents,
            corroboration: corroboration,
            confidence: confidence,
            lineIndexes: lines.sorted(),
            assumptions: assumptions))
    }
}
