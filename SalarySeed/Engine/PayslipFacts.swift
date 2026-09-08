import Foundation

/// How a figure came to be believed.
///
/// v1.1: this is not decoration. It is what decides, in `PayslipFinding.tier`,
/// whether a check is allowed to say an employer got something wrong. A figure
/// that only a label vouches for cannot carry an accusation on its own.
enum PayslipProvenance: String {
    /// The label says what it is and the arithmetic agrees. The strong case.
    case labelAndArithmetic
    /// The numbers identify it. Segurança Social found by being 11% of a base
    /// is this: no label was needed and none was trusted.
    case arithmetic
    /// Only the label says so. Every earnings line is usually this, because
    /// there is no arithmetic identity for "base salary".
    case label
    /// The label and the arithmetic disagree. Never resolved silently: the
    /// reader is asked.
    case disputed
}

enum PayslipConfidence: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (a: PayslipConfidence, b: PayslipConfidence) -> Bool {
        a.rawValue < b.rawValue
    }
}

/// One line of the payslip after we have decided what it is.
struct PayslipClassifiedLine {
    let lineIndex: Int
    /// The description as printed, for showing back to the reader. Never
    /// interpreted again after classification.
    let rawLabel: String
    let concept: PayslipConcept?
    /// The figure this line contributes. The value column, not the base or the
    /// quantity printed beside it.
    let cents: Int?
    let provenance: PayslipProvenance
    let confidence: PayslipConfidence
    /// What the other kind of evidence thought it was, when they disagreed.
    let alternative: PayslipConcept?
    /// A percentage printed on the line, hundredths of a percent.
    let statedRate: Int?
    /// The amount printed immediately before the value, where there was one.
    ///
    /// On "Seg. social empregado | 11,0% | 5 357,14 | 589,29" this is the
    /// 5 357,14: the base the rate was charged on. Having it lets the stated
    /// rate be checked against the line's own arithmetic rather than against a
    /// base guessed from elsewhere on the page.
    let baseCents: Int?
    let repaired: Bool
}

/// An aggregated figure the reconciler can check against.
struct PayslipFact {
    let cents: Int
    let provenance: PayslipProvenance
    let confidence: PayslipConfidence
    let lineIndexes: [Int]
}

/// Everything read and decided, ready to be checked.
///
/// Nothing here is defaulted. A figure that was not found is nil, and a check
/// that needed it is reported as not checked. There is no zero anywhere in this
/// file, because a zero flows into a sum and becomes a confident, wrong
/// accusation, which is the worst failure this feature has available to it.
struct PayslipFacts {
    let source: PayslipSource
    let lines: [PayslipClassifiedLine]
    /// The contribution base found by the 11% identity, independent of labels.
    let ssBase: PayslipFact?
    /// The contribution the 11% identity paired with that base.
    ///
    /// Held separately from `fact(.employeeSS)`, which SUMS every Social
    /// Security line. A payslip paying the holiday and Christmas subsidies as
    /// duodecimos carries three of them, each on its own base, and checking the
    /// sum of all three against 11% of one base is a false accusation waiting
    /// to happen: on a real payslip that would have compared 687,51 against
    /// 589,29 and called a correct payslip wrong.
    let ssContribution: PayslipFact?
    /// The three totals, held separately rather than as line concepts.
    ///
    /// On one of the two real payslips the earnings total and the deductions
    /// total are printed on the SAME line ("Total  3 187,40  1 264,05"), so a
    /// model that stores one concept per line can only keep one of them. These
    /// come from the net identity, which names all three at once.
    let totalEarnings: PayslipFact?
    let totalDeductions: PayslipFact?
    let netPay: PayslipFact?
    /// Which totals the net identity confirmed, when it fired.
    let confirmedByNetIdentity: Bool
    /// Line indexes that fed each printed total, from `PayslipClassifier`'s
    /// side sums. v1.1a: the comment used to say "the contiguous-run test",
    /// which `sideSum` replaced; a run no longer has to be contiguous, it has
    /// to be everything on that side above the total. Read by
    /// `tools/payslip_probe`, which is how a change here is checked against a
    /// real payslip.
    let earningsRun: [Int]
    let deductionsRun: [Int]
    /// Set when a column's run came close to its printed total but did not
    /// reach it. This is the shape a misread digit makes.
    let earningsGap: Int?
    let deductionsGap: Int?

    /// Every line carrying this concept, summed.
    ///
    /// Summed rather than picked, because a real payslip carries three IRS
    /// lines when the holiday and Christmas subsidies are paid as duodécimos,
    /// each withheld separately. The reconciler wants the month's IRS, not one
    /// of its three parts.
    func fact(_ concept: PayslipConcept) -> PayslipFact? {
        switch concept {
        case .totalEarnings: return totalEarnings
        case .totalDeductions: return totalDeductions
        case .netPay: return netPay
        default: break
        }
        let matching = lines.filter { $0.concept == concept && $0.cents != nil }
        guard !matching.isEmpty else { return nil }
        return PayslipFact(
            cents: matching.reduce(0) { $0 + ($1.cents ?? 0) },
            provenance: matching.contains { $0.provenance == .disputed } ? .disputed
                : matching.allSatisfy { $0.provenance == .labelAndArithmetic } ? .labelAndArithmetic
                : matching.contains { $0.provenance == .arithmetic } ? .arithmetic : .label,
            confidence: matching.map(\.confidence).min() ?? .low,
            lineIndexes: matching.map(\.lineIndex))
    }

    /// Lines whose label and arithmetic disagreed. These are pinned to the top
    /// of the review screen as a question, never resolved behind the reader.
    var disputed: [PayslipClassifiedLine] {
        lines.filter { $0.provenance == .disputed }
    }

    /// True when nothing on the page could be identified. A reading can pass
    /// the not-a-payslip gate and still land here if it is a payslip we cannot
    /// make sense of.
    var isEmpty: Bool {
        lines.allSatisfy { $0.concept == nil }
    }
}
