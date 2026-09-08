import Foundation

/// Everything the checker knows how to test.
///
/// The raw value is the key the copy is looked up by, so it is stable and must
/// not be renamed without renaming the strings beside it.
enum PayslipCheck: String, CaseIterable {
    /// The earnings lines add up to the earnings total.
    case earningsSum
    /// The deduction lines add up to the deductions total.
    case deductionsSum
    /// Earnings minus deductions equals net.
    case netIdentity
    /// Employee Social Security is 11% of the base it was charged on.
    case ssRate
    /// A percentage printed on a line reproduces that line's own figure.
    case statedRate
    /// IRS withheld against what the engine's tables say for this household.
    case irsWithholding
    /// Net pay against what the engine computes for this gross.
    case netMonthly
    /// Gross is at least the regional minimum wage.
    case minWage
    /// Whether IRS Jovem looks like it was applied.
    case jovemApplied
    /// Which region's tables the withholding actually matches.
    case regionTable

    /// True when the two figures are meant to be equal, so the gap between
    /// them is the story.
    ///
    /// False for the checks that test a threshold or a choice rather than an
    /// amount. `minWage` compares a gross against a floor: a gross far above
    /// it is the good case, and rendering "out by 4 437,14" against a healthy
    /// salary would read as an error. `regionTable` and `jovemApplied` name
    /// which of several engine answers the payslip matched, and their numbers
    /// are evidence rather than a target.
    ///
    /// v1.1a: there used to be a `comparesEquality` property here saying which
    /// three those are. Nothing read it, because the distinction is drawn where
    /// it is needed instead: those three checks are built inline in
    /// `PayslipReconciler` and can only ever be `.correct` or `.mention`, and
    /// `PayslipResultsView.sentence(for:)` writes a passing finding from its
    /// own copy rather than from a difference. A second copy of the rule that
    /// nothing consulted was one more thing to keep in step.
}

/// Why a check did not run. Always shown: a check that quietly did not happen
/// is worse than one that says it could not.
///
/// v1.1a: a `lowConfidence` case was removed. It read "the figures are there
/// but too uncertain to test against", it was never emitted by anything, and it
/// described a policy the feature does not have: an uncertain figure is still
/// checked, and `PayslipTiering.tier` caps what the result is allowed to say.
/// Not running a check we can run would tell the reader less, not more.
enum PayslipSkipReason: String, Hashable {
    /// A figure the check needs was not on the page, or could not be read.
    case missingFigure
    /// The payslip pays the holiday or Christmas subsidy separately, which the
    /// tax engine models as a months multiplier and not as its own taxed event.
    case subsidiesPaidSeparately
    /// The IRS base printed on the payslip is not the gross, so the engine
    /// would be answering a different question from the one the payslip asked.
    case taxBaseNotGross
    /// The reader has not told the app enough about themselves.
    case profileIncomplete
}

enum PayslipTier: String {
    case wrong
    case mention
    case correct
}

/// Anything extra a finding needs to say, beyond two numbers.
enum PayslipEvidence: Equatable {
    case none
    case region(TaxEngine.TaxRegion)
    case rate(hundredths: Int)
}

struct PayslipFinding: Identifiable {
    let id: PayslipCheck
    let tier: PayslipTier
    let confidence: PayslipConfidence
    let expectedCents: Int?
    let actualCents: Int?
    /// The amount the check was measured against, where there is one: the
    /// contribution base for a rate, the printed total for a sum. Carried so
    /// the copy can say "11,00% on 2 741,86" rather than "11,00%".
    let baseCents: Int?
    /// The figures this rests on, so the screen can point at them.
    let basis: [PayslipConcept]
    let evidence: PayslipEvidence

    var deltaCents: Int? {
        guard let expectedCents, let actualCents else { return nil }
        return actualCents - expectedCents
    }
}

struct PayslipSkipped: Identifiable {
    let check: PayslipCheck
    let reason: PayslipSkipReason
    var id: PayslipCheck { check }
}

struct PayslipVerdict {
    let findings: [PayslipFinding]
    let notChecked: [PayslipSkipped]
    let source: PayslipSource

    var wrong: [PayslipFinding] { findings.filter { $0.tier == .wrong } }
    var correct: [PayslipFinding] { findings.filter { $0.tier == .correct } }
    var mentions: [PayslipFinding] { findings.filter { $0.tier == .mention } }
}

/// v1.1: the one place a check is allowed to become an accusation.
///
/// This is deliberately a single function rather than a rule repeated inside
/// ten checks, because it is the feature's honesty and it has to be reviewable
/// in one screenful. Everything it does is a way of saying the same thing: the
/// app tells someone their employer got their pay wrong only when it is sure,
/// and says so in proportion to how sure it is.
enum PayslipTiering {

    /// One or two cents is rounding, not an error. Payroll software rounds each
    /// line and the sum of the roundings is not a mistake by anybody.
    static let roundingCents = 2
    /// Below a euro is worth mentioning and never worth an accusation.
    static let materialCents = 100
    /// And it has to be worth at least this share of the figure it is measured
    /// against, in parts per thousand. Half a percent.
    static let materialPerMille = 5

    static func tier(delta: Int, confidence: PayslipConfidence, against base: Int?) -> PayslipTier {
        if delta == 0 { return .correct }

        // The guard that matters most. A figure we had to guess at cannot
        // carry an accusation, however large the gap looks: the gap is at
        // least as likely to be our misreading as their mistake.
        if confidence == .low { return .mention }

        if abs(delta) <= roundingCents { return .mention }
        if abs(delta) < materialCents { return .mention }
        if let base, base > 0, abs(delta) * 1000 < materialPerMille * abs(base) { return .mention }
        return .wrong
    }
}
