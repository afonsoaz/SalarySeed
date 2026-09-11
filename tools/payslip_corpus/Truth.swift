// The corpus's truth model.
//
// Every figure on every generated payslip comes from `TaxEngine`, never from a
// number typed in here. That is the same discipline `docs/fixtures/README.md`
// already describes for the one hand-written fixture, and the reason is worth
// stating: a generator that computed its own withholding would be a second
// implementation of the 2026 tables, and when it disagreed with the app there
// would be no way to tell a reader bug from a generator bug. Calling the
// shipping engine removes that failure mode entirely.
//
// What this therefore CANNOT do is test whether the tables are right. Nothing
// here ever could; that is `tools/verify_tax_engine.py`'s job, against the AT
// workbooks. What it tests is whether the right cents come back off the page.

import Foundation

// MARK: Money as it is printed

/// How a payslip prints its money. Real payslips are not consistent about this
/// even within one page, and every one of these shapes is in
/// `PayslipNumber.parsingFixtures` marked as coming off a real document.
enum MoneyStyle: String, CaseIterable {
    case spaceComma      // 2 400,00
    case dotComma        // 2.400,00
    case plainDot        // 2400.00
    case nbspComma       // 2<nbsp>400,00
    case euroSuffix      // 2.400,00 EUR
}

func printedMoney(_ cents: Int, _ style: MoneyStyle) -> String {
    let negative = cents < 0
    let absolute = abs(cents)
    let units = absolute / 100
    let fraction = String(format: "%02d", absolute % 100)

    func grouped(_ separator: String) -> String {
        var digits = Array(String(units))
        var out: [String] = []
        while digits.count > 3 {
            out.insert(String(digits.suffix(3)), at: 0)
            digits.removeLast(3)
        }
        out.insert(String(digits), at: 0)
        return out.joined(separator: separator)
    }

    let body: String
    switch style {
    case .spaceComma: body = grouped(" ") + "," + fraction
    case .dotComma:   body = grouped(".") + "," + fraction
    case .plainDot:   body = String(units) + "." + fraction
    case .nbspComma:  body = grouped("\u{00A0}") + "," + fraction
    case .euroSuffix: body = grouped(".") + "," + fraction + " EUR"
    }
    return (negative ? "-" : "") + body
}

/// 14 rather than 14.0, because months is a Double nobody ever sees as one.
func monthsText(_ m: Double) -> String {
    m == m.rounded() ? String(Int(m)) : String(m)
}

/// A percentage as a payslip prints it: 1100 is "11,00%".
func printedRate(_ permyriad: Int) -> String {
    "\(permyriad / 100),\(String(format: "%02d", permyriad % 100))%"
}

extension PayslipConcept.Side {
    /// `Side` has no raw value in the shipping enum and does not need one; the
    /// corpus only wants a stable string for its truth files.
    var name: String {
        switch self {
        case .earning: return "earning"
        case .deduction: return "deduction"
        case .total: return "total"
        case .base: return "base"
        }
    }
}

// MARK: Lines

/// Where a line sits on the page. This is layout, deliberately separate from
/// `PayslipConcept.side`, which is meaning: the whole question the geometry
/// families ask is whether the reader can recover the second from the first.
enum Block: String {
    case header, earnings, deductions, net, extra, accumulated, note
}

/// Where a label came from, so the corpus can say out loud how much of its own
/// vocabulary it borrowed from the reader's.
///
/// A corpus built only from `PayslipLexicon`'s own words cannot discover a
/// label the lexicon has never seen, which is the reader's most likely real
/// failure. Recording this per line is what lets the report state that
/// limitation as a number rather than as a caveat.
enum LabelSource: String {
    /// Verbatim in `PayslipLexicon.matchFixtures`, accents aside.
    case lexicon
    /// Off a real payslip, but not in the lexicon's fixture list.
    case attested
    /// Deliberately outside the lexicon. The `unknownVocabulary` family.
    case unknown
}

struct FixtureLine {
    var code: String?
    var label: String
    var concept: PayslipConcept?
    var cents: Int?
    var block: Block
    var labelSource: LabelSource
    /// Printed in its own column by the `rateColumn` family.
    var ratePermyriad: Int?
    /// A base printed beside a rate, as "11,00% on 2 400,00".
    var baseCents: Int?
    /// Printed and deliberately not money: "30", "22,00", "8,00 h".
    var quantity: String?
    /// The month-to-date figure when the family prints two money columns per
    /// line. Breaks "the value is the last amount on the line" on purpose.
    var accumulatedCents: Int?

    init(code: String? = nil, label: String, concept: PayslipConcept? = nil,
         cents: Int? = nil, block: Block, labelSource: LabelSource = .attested,
         ratePermyriad: Int? = nil, baseCents: Int? = nil,
         quantity: String? = nil, accumulatedCents: Int? = nil) {
        self.code = code
        self.label = label
        self.concept = concept
        self.cents = cents
        self.block = block
        self.labelSource = labelSource
        self.ratePermyriad = ratePermyriad
        self.baseCents = baseCents
        self.quantity = quantity
        self.accumulatedCents = accumulatedCents
    }
}

// MARK: What the engine says a month looks like

func cents(_ euros: Double) -> Int { Int((euros * 100).rounded()) }

/// One month, entirely from `TaxEngine`.
struct Computed {
    let grossCents: Int
    let ssCents: Int
    let irsCents: Int
    let employerSSCents: Int

    var deductionsCents: Int { ssCents + irsCents }
    var netCents: Int { grossCents - deductionsCents }
}

func compute(grossCents: Int, region: TaxEngine.TaxRegion, months: Double,
             marital: MaritalSituation, dependents: Int, jovem: Double) -> Computed {
    let gross = Double(grossCents) / 100
    return Computed(
        grossCents: grossCents,
        ssCents: cents(gross * TaxEngine.employeeSSRate),
        irsCents: cents(TaxEngine.monthlyIRS(grossMonthly: gross, marital: marital,
                                             dependents: dependents, jovemExemption: jovem,
                                             months: months, region: region)),
        employerSSCents: cents(gross * TaxEngine.employerSSRate))
}

// MARK: A fixture

/// A figure moved by a known amount after truth was computed, so detection
/// sensitivity is measurable.
struct Injection {
    /// `line`: one line item moves and the printed totals do not, so the page
    /// contradicts itself by exactly `deltaCents` and self-consistency alone
    /// should catch it. `engine`: the page adds up perfectly and the IRS was
    /// computed wrongly, so only the engine checks can catch it.
    enum Kind: String { case line, engine }
    let kind: Kind
    let concept: PayslipConcept
    let deltaCents: Int
    let note: String
}

struct Fixture {
    let id: String
    let family: String
    let style: MoneyStyle
    let region: TaxEngine.TaxRegion
    let months: Double
    let marital: MaritalSituation
    let dependents: Int
    let jovem: Double

    /// The one number onboarding would need, stated separately from every
    /// concept on the page. On the ajudas families this is deliberately NOT the
    /// earnings total: ajudas de custo and the meal allowance go straight to
    /// net and sit outside gross, which is the whole point of the app.
    let monthlyGrossCents: Int
    let ajudasMonthlyCents: Int

    let employer: String
    let employerAddress: String
    let nipc: String
    let employee: String
    let nif: String
    let category: String
    let period: String
    let days: String

    let lines: [FixtureLine]
    /// Checks expected not to run, with the reason, so the scorer can tell an
    /// expected skip from a regression.
    let expectedSkips: [String]
    let isPayslip: Bool
    let injection: Injection?

    /// Every concept on the page and its cents, summed where a concept appears
    /// on more than one line (three IRS lines when subsidies are duodécimos).
    var truth: [PayslipConcept: Int] {
        var out: [PayslipConcept: Int] = [:]
        for line in lines {
            guard let concept = line.concept, let cents = line.cents else { continue }
            out[concept, default: 0] += cents
        }
        return out
    }

    func lines(in block: Block) -> [FixtureLine] { lines.filter { $0.block == block } }
}
