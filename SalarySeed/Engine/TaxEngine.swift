import Foundation

/// The household situation that selects the IRS withholding table and shapes the
/// annual settlement. v0.6: real 2026 tables, so this is now a real tax input.
///
/// Raw values are stable IDs (persisted in UserDefaults).
enum MaritalSituation: String, CaseIterable, Identifiable {
    case single        // não casado
    case marriedTwo    // casado, dois titulares (both spouses earn)
    case marriedOne    // casado, único titular (one earner)

    var id: String { rawValue }

    func label(pt: Bool) -> String {
        switch self {
        case .single: pt ? "Não casado" : "Single"
        case .marriedTwo: pt ? "Casado, dois titulares" : "Married, both earn"
        case .marriedOne: pt ? "Casado, um titular" : "Married, one earner"
        }
    }

    /// v0.9.3: a compact form for inline rows. The full label wrapped to two lines
    /// in the profile's fiscal list, making that row taller than the ones around it.
    func shortLabel(pt: Bool) -> String {
        switch self {
        case .single: pt ? "Não casado" : "Single"
        case .marriedTwo: pt ? "Casado, 2 titulares" : "Married, both earn"
        case .marriedOne: pt ? "Casado, 1 titular" : "Married, one earner"
        }
    }

    func hint(pt: Bool) -> String {
        switch self {
        case .single: pt ? "Solteiro, divorciado ou viúvo" : "Not married"
        case .marriedTwo: pt ? "Os dois têm rendimentos" : "You and your partner both work"
        case .marriedOne: pt ? "Só um dos dois recebe salário" : "Only one of you earns a salary"
        }
    }
}

/// One computed salary picture. All monthly values are per paid month.
///
/// v0.5: ajudas de custo ride along, always kept separate from the salary.
/// They go straight to net (no IRS, no SS), are paid 12 times a year
/// regardless of the 12/14 schedule, and NEVER enter gross-based numbers
/// (percentiles, employer cost, efficiency). The UI must always show them
/// as their own thing.
///
/// v0.6: the IRS is now real 2026 withholding (Continente), sensitive to marital
/// situation, dependants and the IRS Jovem exemption. The breakdown also carries
/// an annual-settlement estimate (what actually settles the next year vs what was
/// withheld month to month), so the app can show the refund / amount-to-pay gap.
struct SalaryBreakdown {
    let grossMonthly: Double
    let netMonthly: Double
    let irsMonthly: Double
    let employeeSSMonthly: Double
    let employerSSMonthly: Double
    let months: Double
    /// Ajudas de custo (or similar) per month, straight to net. 12 payments a year.
    var ajudasMonthly: Double = 0

    // v0.6 annual settlement estimate (whole-year figures, employee/salary only).
    /// Real IRS due for the year (apuramento anual on the escalões).
    var annualIRSSettled: Double = 0
    /// IRS actually withheld across the year (monthly withholding × months).
    var annualIRSWithheld: Double = 0
    /// v0.9.4: the assumptions behind those two numbers, so the UI can state them
    /// instead of leaving the user to guess. Both figures above already include
    /// IRS Jovem: it lowers the monthly withholding AND the annual settlement.
    var settlement: TaxEngine.AnnualSettlement?
    /// The IRS Jovem exemption fraction used (0 = not on it).
    var jovemExemption: Double = 0

    var employerCostMonthly: Double { grossMonthly + employerSSMonthly }
    var grossYearly: Double { grossMonthly * months }
    var netYearly: Double { netMonthly * months }
    var employerCostYearly: Double { employerCostMonthly * months }

    var ajudasYearly: Double { ajudasMonthly * 12 }
    /// What actually lands in the pocket in a normal month: salary net plus ajudas.
    var pocketMonthly: Double { netMonthly + ajudasMonthly }
    var pocketYearly: Double { netYearly + ajudasYearly }

    var deductionsMonthly: Double { irsMonthly + employeeSSMonthly }
    /// Effective rates on the gross salary (0 when gross is 0).
    var irsRate: Double { grossMonthly > 0 ? irsMonthly / grossMonthly : 0 }
    var employeeSSEffRate: Double { grossMonthly > 0 ? employeeSSMonthly / grossMonthly : 0 }
    var deductionsRate: Double { grossMonthly > 0 ? deductionsMonthly / grossMonthly : 0 }

    /// Positive: money back at settlement. Negative: still to pay. Zero-ish: even.
    var annualBalance: Double { annualIRSWithheld - annualIRSSettled }

    /// Of every €1 the employer spends on the salary, how much reaches the pocket.
    /// Salary only: ajudas de custo stay out on both sides.
    var efficiency: Double {
        employerCostMonthly > 0 ? netMonthly / employerCostMonthly : 0
    }
}

/// Real Portuguese tax engine, fiscal year 2026, Continente, employees.
///
/// Sources (see the prepared data doc for the full extract):
/// - IRS monthly withholding: Despacho n.º 233-A/2026 (Diário da República),
///   the "taxa marginal máxima" formula model for trabalho dependente.
/// - Annual IRS escalões: OE2026 (thresholds +3.51% vs 2025).
/// - Social Security: 11% employee / 23.75% employer, on full gross, no ceiling.
/// - IRS Jovem: exemption steps 100/75/50/25%, cap 55 × IAS.
/// - IAS 2026 = €537,13; dedução específica cat. A = 8,54 × IAS.
///
/// Everything here is an estimate for insight, not official tax advice.
///
/// v0.15 ADDED THE AUTONOMOUS REGIONS. Every figure below that carries a region
/// is real: the withholding tables were generated from the AT workbooks rather
/// than transcribed, and round-tripped back against them.
enum TaxEngine {

    /// Where the user pays tax. Not a preference: it is derived from the concelho
    /// and nothing else, the same way the district and the NUTS II region are.
    ///
    /// WHY THIS EXISTS AT ALL. Social Security is national, IAS is national, and
    /// the per-dependant parcelas are national, so for twelve versions a single
    /// set of tables was defensible. IRS is not national. Both regions apply the
    /// maximum reduction the Lei das Finanças das Regiões Autónomas allows, and
    /// an islander computed on the Continente tables is told they pay more tax
    /// than they do, on every screen, for ever.
    enum TaxRegion: String, CaseIterable, Identifiable, Codable {
        case continente, acores, madeira
        var id: String { rawValue }

        func label(pt: Bool) -> String {
            switch self {
            case .continente: return pt ? "Continente" : "Mainland"
            case .acores: return "Açores"
            case .madeira: return "Madeira"
            }
        }

        /// The regional minimum wage, which is also the first row of each region's
        /// withholding table: the tables are built so that someone on the regional
        /// minimum withholds nothing.
        var minWage: Double {
            switch self {
            case .continente: return 920
            case .acores: return 966
            case .madeira: return 980
            }
        }

        /// What the region does to the NATIONAL annual rates.
        ///
        /// In 2026 both regions apply the full 30% differential the Lei das
        /// Finanças das Regiões Autónomas permits, to all nine brackets, with the
        /// thresholds left at the national values. One number instead of eighteen,
        /// and it is the rule the law states rather than a table to keep in sync.
        ///
        /// Verified two ways. The Açores withholding table is EXACTLY 0.70 of the
        /// Continente table on all twelve rates, which is arithmetic, not opinion.
        /// And AT Madeira's own January 2026 fiscal agenda says Madeira applies
        /// "o diferencial fiscal máximo de 30%" across all nine brackets. Note
        /// Madeira's withholding table is NOT 0.70 of Continente's, and that is
        /// not a contradiction: a withholding table is a derived instrument built
        /// around the regional minimum wage, so a different floor gives a
        /// different derivation of the same underlying rates.
        var annualRateFactor: Double {
            self == .continente ? 1 : 0.70
        }
    }

    // MARK: Social Security

    static let employeeSSRate = 0.11     // trabalhador
    static let employerSSRate = 0.2375   // entidade empregadora

    // MARK: 2026 constants (Continente)

    static let ias = 537.13
    /// Continente. Each region's own floor lives on `TaxRegion.minWage`.
    static let minWage = 920.0
    /// The fiscal year the engine models. Used by the IRS Jovem assessor to count
    /// benefit years and to check the age limit at the end of the income year.
    static let taxYear = 2026
    /// IRS Jovem yearly exemption cap: 55 × IAS = €29 542,15.
    static let jovemAnnualCap = 55 * ias
    /// Dedução específica, categoria A: 8,54 × IAS = €4 587,09.
    static let specificDeductionA = 8.54 * ias
    /// Dedução à coleta per dependant (base value; the app does not track ages).
    static let dependentCredit = 600.0
    /// Typical deduções à coleta most people collect over a year (health, education,
    /// housing, general family expenses, VAT on invoices). A flat, deliberately
    /// modest assumption so the annual settlement reflects the usual small refund.
    static let generalExpenseCredit = 1_000.0

    // MARK: Monthly withholding tables (retenção na fonte)

    /// One bracket row. `abate` (parcela a abater) is a function of the
    /// remuneration R because the two lowest taxed brackets use a formula.
    struct Row {
        let upTo: Double
        let rate: Double
        let abate: (Double) -> Double
    }

    /// Table I / II — não casado, or casado dois titulares. Rows are identical;
    /// only the per-dependant deduction differs (handled in `perDependent`).
    static let tableSingle: [Row] = [
        Row(upTo: 920,          rate: 0.0,    abate: { _ in 0 }),
        Row(upTo: 1_042,        rate: 0.125,  abate: { R in 0.125 * 2.60 * (1_273.85 - R) }),
        Row(upTo: 1_108,        rate: 0.157,  abate: { R in 0.157 * 1.35 * (1_554.83 - R) }),
        Row(upTo: 1_154,        rate: 0.157,  abate: { _ in 94.71 }),
        Row(upTo: 1_212,        rate: 0.212,  abate: { _ in 158.18 }),
        Row(upTo: 1_819,        rate: 0.241,  abate: { _ in 193.33 }),
        Row(upTo: 2_119,        rate: 0.311,  abate: { _ in 320.66 }),
        Row(upTo: 2_499,        rate: 0.349,  abate: { _ in 401.19 }),
        Row(upTo: 3_305,        rate: 0.3836, abate: { _ in 487.66 }),
        Row(upTo: 5_547,        rate: 0.3969, abate: { _ in 531.62 }),
        Row(upTo: 20_221,       rate: 0.4495, abate: { _ in 823.40 }),
        Row(upTo: .infinity,    rate: 0.4717, abate: { _ in 1_272.31 }),
    ]

    /// Table III — casado, único titular.
    static let tableMarriedOne: [Row] = [
        Row(upTo: 991,          rate: 0.0,    abate: { _ in 0 }),
        Row(upTo: 1_042,        rate: 0.125,  abate: { R in 0.125 * 2.60 * (1_372.15 - R) }),
        Row(upTo: 1_108,        rate: 0.125,  abate: { R in 0.125 * 1.35 * (1_677.85 - R) }),
        Row(upTo: 1_119,        rate: 0.125,  abate: { _ in 96.17 }),
        Row(upTo: 1_432,        rate: 0.1272, abate: { _ in 98.64 }),
        Row(upTo: 1_962,        rate: 0.157,  abate: { _ in 141.32 }),
        Row(upTo: 2_240,        rate: 0.1938, abate: { _ in 213.53 }),
        Row(upTo: 2_773,        rate: 0.2277, abate: { _ in 289.47 }),
        Row(upTo: 3_389,        rate: 0.257,  abate: { _ in 370.72 }),
        Row(upTo: 5_965,        rate: 0.2881, abate: { _ in 476.12 }),
        Row(upTo: 20_265,       rate: 0.3843, abate: { _ in 1_049.96 }),
        Row(upTo: .infinity,    rate: 0.4717, abate: { _ in 2_821.13 }),
    ]

    // MARK: Açores (Categoria A, from the AT workbook)

    /// Açores, Tabelas I and II. GENERATED from the AT workbook, never transcribed.
    static let tableSingleAcores: [Row] = [
        Row(upTo: 966,           rate: 0,        abate: { _ in 0 }),
        Row(upTo: 1_042,         rate: 0.0875,   abate: { R in 0.0875 * 2.6 * (1337.54 - R) }),
        Row(upTo: 1_108,         rate: 0.1099,   abate: { R in 0.1099 * 1.35 * (1652.49 - R) }),
        Row(upTo: 1_154,         rate: 0.1099,   abate: { _ in 80.79 }),
        Row(upTo: 1_212,         rate: 0.1484,   abate: { _ in 125.22 }),
        Row(upTo: 1_819,         rate: 0.1687,   abate: { _ in 149.83 }),
        Row(upTo: 2_119,         rate: 0.2177,   abate: { _ in 238.97 }),
        Row(upTo: 2_499,         rate: 0.2443,   abate: { _ in 295.34 }),
        Row(upTo: 3_305,         rate: 0.2685,   abate: { _ in 355.82 }),
        Row(upTo: 5_547,         rate: 0.2779,   abate: { _ in 386.89 }),
        Row(upTo: 20_221,        rate: 0.3146,   abate: { _ in 590.47 }),
        Row(upTo: .infinity,     rate: 0.3302,   abate: { _ in 905.92 }),
    ]

    /// Açores, Tabela III. 10 rows, not 12: each region sets its own bracket boundaries, so a row-for-row comparison with Continente is meaningless.
    static let tableMarriedOneAcores: [Row] = [
        Row(upTo: 1_226,         rate: 0,        abate: { _ in 0 }),
        Row(upTo: 1_267,         rate: 0.0728,   abate: { _ in 89.26 }),
        Row(upTo: 1_602,         rate: 0.0964,   abate: { _ in 119.17 }),
        Row(upTo: 1_962,         rate: 0.1099,   abate: { _ in 140.8 }),
        Row(upTo: 2_240,         rate: 0.1357,   abate: { _ in 191.42 }),
        Row(upTo: 2_900,         rate: 0.1594,   abate: { _ in 244.51 }),
        Row(upTo: 3_389,         rate: 0.1799,   abate: { _ in 303.96 }),
        Row(upTo: 5_965,         rate: 0.2017,   abate: { _ in 377.85 }),
        Row(upTo: 20_265,        rate: 0.271,    abate: { _ in 791.23 }),
        Row(upTo: .infinity,     rate: 0.3302,   abate: { _ in 1990.92 }),
    ]

    // MARK: Madeira (Categoria A, from the AT workbook)

    /// Madeira, Tabelas I and II. GENERATED from the AT workbook, never transcribed.
    static let tableSingleMadeira: [Row] = [
        Row(upTo: 980,           rate: 0,        abate: { _ in 0 }),
        Row(upTo: 1_028,         rate: 0.0872,   abate: { R in 0.0872 * 2.6 * (1356.92 - R) }),
        Row(upTo: 1_099,         rate: 0.1204,   abate: { R in 0.1204 * 1.35 * (1696.78 - R) }),
        Row(upTo: 1_201,         rate: 0.1204,   abate: { _ in 97.17 }),
        Row(upTo: 1_623,         rate: 0.1763,   abate: { _ in 164.31 }),
        Row(upTo: 2_332,         rate: 0.223,    abate: { _ in 240.11 }),
        Row(upTo: 3_203,         rate: 0.2242,   abate: { _ in 242.91 }),
        Row(upTo: 3_614,         rate: 0.2727,   abate: { _ in 398.26 }),
        Row(upTo: 6_585,         rate: 0.2778,   abate: { _ in 416.7 }),
        Row(upTo: 6_954,         rate: 0.2802,   abate: { _ in 432.51 }),
        Row(upTo: 21_411,        rate: 0.2924,   abate: { _ in 517.35 }),
        Row(upTo: .infinity,     rate: 0.3278,   abate: { _ in 1275.3 }),
    ]

    /// Madeira, Tabela III. 11 rows, not 12: each region sets its own bracket boundaries, so a row-for-row comparison with Continente is meaningless.
    static let tableMarriedOneMadeira: [Row] = [
        Row(upTo: 997,           rate: 0,        abate: { _ in 0 }),
        Row(upTo: 1_099,         rate: 0.0872,   abate: { R in 0.0872 * 1.35 * (1819.64 - R) }),
        Row(upTo: 1_141,         rate: 0.0872,   abate: { _ in 84.84 }),
        Row(upTo: 1_857,         rate: 0.1033,   abate: { _ in 103.22 }),
        Row(upTo: 2_485,         rate: 0.1091,   abate: { _ in 114 }),
        Row(upTo: 3_331,         rate: 0.1236,   abate: { _ in 150.04 }),
        Row(upTo: 3_895,         rate: 0.1404,   abate: { _ in 206.01 }),
        Row(upTo: 6_673,         rate: 0.1595,   abate: { _ in 280.41 }),
        Row(upTo: 6_878,         rate: 0.2213,   abate: { _ in 692.81 }),
        Row(upTo: 21_411,        rate: 0.2493,   abate: { _ in 885.4 }),
        Row(upTo: .infinity,     rate: 0.3278,   abate: { _ in 2566.17 }),
    ]

    /// The table for a situation and a region. Tabelas I and II share their rows
    /// in every region; only the per-dependant parcela separates them, and that
    /// is national.
    static func rows(for m: MaritalSituation, region: TaxRegion) -> [Row] {
        switch region {
        case .continente: return m == .marriedOne ? tableMarriedOne : tableSingle
        case .acores:     return m == .marriedOne ? tableMarriedOneAcores : tableSingleAcores
        case .madeira:    return m == .marriedOne ? tableMarriedOneMadeira : tableSingleMadeira
        }
    }

    /// Parcela adicional a abater por dependente.
    static func perDependent(_ m: MaritalSituation, dependents: Int) -> Double {
        switch m {
        case .marriedOne: return 42.86
        case .single:     return dependents > 0 ? 34.29 : 21.43
        case .marriedTwo: return 21.43
        }
    }

    /// Normal monthly IRS withholding (no IRS Jovem), for a gross remuneration R.
    static func withholding(grossMonthly R: Double, marital: MaritalSituation,
                            dependents: Int, region: TaxRegion) -> Double {
        let table = rows(for: marital, region: region)
        let perDep = perDependent(marital, dependents: dependents)
        for row in table where R <= row.upTo {
            return max(0, R * row.rate - row.abate(R) - Double(dependents) * perDep)
        }
        return 0
    }

    /// Monthly IRS withholding including the IRS Jovem exemption.
    ///
    /// Official method: find the rate that would be due on the whole remuneration,
    /// then apply it only to the non-exempt part. The exempt part is capped monthly
    /// at the yearly cap spread over the pay months.
    static func monthlyIRS(grossMonthly R: Double,
                           marital: MaritalSituation,
                           dependents: Int,
                           jovemExemption: Double,
                           months: Double,
                           region: TaxRegion) -> Double {
        let normal = withholding(grossMonthly: R, marital: marital,
                                 dependents: dependents, region: region)
        guard jovemExemption > 0, R > 0 else { return normal }
        let effRate = normal / R
        let monthlyCap = jovemAnnualCap / max(months, 12)
        let exemptPart = min(jovemExemption * R, monthlyCap)
        return max(0, effRate * (R - exemptPart))
    }

    // MARK: Annual IRS (escalões) and settlement estimate

    struct Escalao { let upTo: Double; let normal: Double; let media: Double }

    /// 2026 annual brackets. `media` is the average rate at the bracket's upper limit,
    /// used by the official split-bracket method.
    static let escaloes: [Escalao] = [
        Escalao(upTo: 8_342,     normal: 0.125,  media: 0.125),
        Escalao(upTo: 12_587,    normal: 0.157,  media: 0.13579),
        Escalao(upTo: 17_838,    normal: 0.212,  media: 0.15823),
        Escalao(upTo: 23_089,    normal: 0.241,  media: 0.17705),
        Escalao(upTo: 29_397,    normal: 0.311,  media: 0.20579),
        Escalao(upTo: 43_090,    normal: 0.349,  media: 0.25130),
        Escalao(upTo: 46_566,    normal: 0.431,  media: 0.26472),
        Escalao(upTo: 86_634,    normal: 0.446,  media: 0.34856),
        Escalao(upTo: .infinity, normal: 0.48,   media: 0.0),
    ]

    /// The nine brackets as they apply in a region: same thresholds, rates scaled
    /// by the regional factor.
    ///
    /// The média scales too, and that is not an approximation. Média is defined as
    /// the tax at the bracket's upper limit divided by that limit, so scaling every
    /// normal rate by k scales the tax by k and therefore the média by k exactly.
    /// Checked numerically at all eight finite bracket tops before relying on it.
    static func escaloes(for region: TaxRegion) -> [Escalao] {
        let k = region.annualRateFactor
        guard k != 1 else { return escaloes }
        return escaloes.map { Escalao(upTo: $0.upTo, normal: $0.normal * k, media: $0.media * k) }
    }

    /// Progressive annual IRS on a taxable income, split-bracket method:
    /// for income in bracket N, tax = lowerLimit × média(N−1) + (income − lowerLimit) × normal(N).
    static func progressiveAnnual(_ income: Double, region: TaxRegion) -> Double {
        guard income > 0 else { return 0 }
        let escaloes = escaloes(for: region)
        var lower = 0.0
        for (i, e) in escaloes.enumerated() {
            if income <= e.upTo {
                if i == 0 { return income * e.normal }
                let prev = escaloes[i - 1]
                return lower * prev.media + (income - lower) * e.normal
            }
            lower = e.upTo
        }
        return 0
    }

    /// Estimated real annual IRS (coleta líquida) for an employee.
    ///
    /// taxable = gross − dedução específica − IRS Jovem exempt part.
    /// The IRS Jovem exempt income still counts for setting the *rate* (englobamento
    /// para taxa): the average rate is taken on the full taxable base and applied to
    /// the non-exempt part. Married single-earner uses the quociente conjugal (÷2 ×2).
    /// Dependant credits (dedução à coleta) are then subtracted.
    static func annualSettled(grossMonthly: Double,
                              months: Double,
                              marital: MaritalSituation,
                              dependents: Int,
                              jovemExemption: Double,
                              region: TaxRegion) -> Double {
        annualDetail(grossMonthly: grossMonthly, months: months, marital: marital,
                     dependents: dependents, jovemExemption: jovemExemption,
                     region: region).due
    }

    /// v0.9.4: the same calculation, but returning its parts rather than only the
    /// answer. The €1,000 general-expense credit is an assumption the app makes on
    /// the user's behalf, and it is capped at whatever IRS is still owed, so it is
    /// often only partly used and sometimes not used at all. The UI has to be able
    /// to say which, and it could not while this function threw the detail away.
    struct AnnualSettlement {
        /// IRS on the non-exempt base, before any credits.
        let coleta: Double
        /// Dedução à coleta actually applied for dependants.
        let dependentCreditApplied: Double
        /// The €1,000 the app assumes.
        let generalCreditAssumed: Double
        /// How much of that €1,000 the IRS owed was big enough to absorb.
        let generalCreditApplied: Double
        /// Income exempted by IRS Jovem over the year.
        let jovemExemptYear: Double
        /// Real IRS for the year, after everything.
        let due: Double

        var generalCreditFullyUsed: Bool { generalCreditApplied >= generalCreditAssumed - 0.5 }
        var generalCreditUnused: Bool { generalCreditApplied < 0.5 }
    }

    static func annualDetail(grossMonthly: Double,
                             months: Double,
                             marital: MaritalSituation,
                             dependents: Int,
                             jovemExemption: Double,
                             region: TaxRegion) -> AnnualSettlement {
        let grossYear = grossMonthly * months
        let fullBase = max(0, grossYear - specificDeductionA)
        let exemptYear = min(max(0, jovemExemption) * grossYear, jovemAnnualCap)
        let nonExemptBase = max(0, fullBase - exemptYear)

        let quotient: Double = marital == .marriedOne ? 2 : 1
        let taxFull = progressiveAnnual(fullBase / quotient, region: region) * quotient
        let avgRate = fullBase > 0 ? taxFull / fullBase : 0

        let coleta = avgRate * nonExemptBase
        // Dedução à coleta per dependant comes off first, never below zero.
        let depApplied = min(coleta, Double(dependents) * dependentCredit)
        let afterDependents = max(0, coleta - depApplied)
        // The general-expense credit (health, education, invoices) only helps if there
        // is IRS left to reduce: you deduct the smaller of €1,000 and what you still owe,
        // never more. So it never turns into an extra refund on its own.
        let generalApplied = min(generalExpenseCredit, afterDependents)
        return AnnualSettlement(
            coleta: coleta,
            dependentCreditApplied: depApplied,
            generalCreditAssumed: generalExpenseCredit,
            generalCreditApplied: generalApplied,
            jovemExemptYear: exemptYear,
            due: afterDependents - generalApplied
        )
    }

    // MARK: Breakdown

    /// `region` is deliberately NOT defaulted. A default would let a call site
    /// forget it and silently hand an islander Continente tax, which is the exact
    /// failure this whole change exists to remove. Without a default the compiler
    /// asks the question at every site, which is where it should be asked.
    static func breakdown(grossMonthly: Double,
                          months: Double,
                          ajudasMonthly: Double = 0,
                          marital: MaritalSituation = .single,
                          dependents: Int = 0,
                          jovemExemption: Double = 0,
                          region: TaxRegion) -> SalaryBreakdown {
        let gross = max(0, grossMonthly)
        let deps = max(0, dependents)
        let ss = gross * employeeSSRate
        let irs = monthlyIRS(grossMonthly: gross, marital: marital, dependents: deps,
                             jovemExemption: jovemExemption, months: months, region: region)
        let net = gross - ss - irs

        let detail = annualDetail(grossMonthly: gross, months: months, marital: marital,
                                  dependents: deps, jovemExemption: jovemExemption,
                                  region: region)
        let withheld = irs * months

        return SalaryBreakdown(
            grossMonthly: gross,
            netMonthly: net,
            irsMonthly: irs,
            employeeSSMonthly: ss,
            employerSSMonthly: gross * employerSSRate,
            months: months,
            ajudasMonthly: max(0, ajudasMonthly),
            annualIRSSettled: detail.due,
            annualIRSWithheld: withheld,
            settlement: detail,
            jovemExemption: max(0, jovemExemption)
        )
    }

    /// Invert net → gross by bisection (net is monotonic in gross), carrying the
    /// same tax context so the inversion matches the forward calculation.
    static func grossFromNet(_ net: Double,
                             marital: MaritalSituation = .single,
                             dependents: Int = 0,
                             jovemExemption: Double = 0,
                             months: Double = 14,
                             region: TaxRegion) -> Double {
        guard net > 0 else { return 0 }
        var lo = net, hi = net * 3 + 1_000
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            let midNet = breakdown(grossMonthly: mid, months: months, marital: marital,
                                   dependents: dependents, jovemExemption: jovemExemption,
                                   region: region).netMonthly
            if midNet < net { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    // MARK: IRS Jovem eligibility assessment (v0.8)

    /// Why a person is (or is not) getting IRS Jovem this year.
    enum JovemReason {
        case eligible      // gets an exemption this year
        case tooOld        // over 35 at the end of the income year
        case isDependent   // still a tax dependant this year
        case otherRegime   // used RNH / IFICI / Regressar, which excludes IRS Jovem
        case notStarted    // first income year is in the future
        case exhausted     // already past the 10th benefit year
    }

    /// The outcome of the profileSeed self-assessment: whether IRS Jovem applies,
    /// which benefit year the person is in, and the exemption fraction to use.
    struct JovemAssessment {
        let eligible: Bool
        /// 0, 0.25, 0.5, 0.75 or 1.0.
        let exemption: Double
        /// The ordinal benefit year 1...10, when there is one.
        let benefitYear: Int?
        let reason: JovemReason

        /// Yearly exempt-income cap (55 × IAS), for display.
        var annualCap: Double { jovemAnnualCap }
    }

    /// The exemption for a given benefit year (1...10): 100% year 1, 75% years 2-4,
    /// 50% years 5-7, 25% years 8-10.
    static func jovemRate(benefitYear n: Int) -> Double {
        switch n {
        case 1: return 1.0
        case 2...4: return 0.75
        case 5...7: return 0.50
        case 8...10: return 0.25
        default: return 0
        }
    }

    /// Assess IRS Jovem from the plain inputs collected in profileSeed.
    ///
    /// Rules (OE2025/2026, confirmed 2026): age ≤ 35 at year end, up to 10 benefit
    /// years counted from the first year of Category A/B income while not a dependant,
    /// no overlap with RNH/IFICI/Regressar. We assume the person earned income each
    /// year since that first year (so benefit year = taxYear − firstIncomeYear + 1);
    /// gaps in real life pause the count, which only ever helps, so this is the
    /// conservative read. The exemption never applies while still a dependant.
    static func assessJovem(age: Int,
                            firstIncomeYear: Int,
                            isDependentThisYear: Bool,
                            usedOtherRegime: Bool,
                            year: Int = taxYear) -> JovemAssessment {
        if usedOtherRegime {
            return JovemAssessment(eligible: false, exemption: 0, benefitYear: nil, reason: .otherRegime)
        }
        if isDependentThisYear {
            return JovemAssessment(eligible: false, exemption: 0, benefitYear: nil, reason: .isDependent)
        }
        if age > 35 {
            return JovemAssessment(eligible: false, exemption: 0, benefitYear: nil, reason: .tooOld)
        }
        let n = year - firstIncomeYear + 1
        if n < 1 {
            return JovemAssessment(eligible: false, exemption: 0, benefitYear: nil, reason: .notStarted)
        }
        if n > 10 {
            return JovemAssessment(eligible: false, exemption: 0, benefitYear: nil, reason: .exhausted)
        }
        return JovemAssessment(eligible: true, exemption: jovemRate(benefitYear: n), benefitYear: n, reason: .eligible)
    }
}
