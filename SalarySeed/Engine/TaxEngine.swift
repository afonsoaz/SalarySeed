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
/// Continente only for now (Açores/Madeira have their own reduced tables).
enum TaxEngine {

    // MARK: Social Security

    static let employeeSSRate = 0.11     // trabalhador
    static let employerSSRate = 0.2375   // entidade empregadora

    // MARK: 2026 constants (Continente)

    static let ias = 537.13
    static let minWage = 920.0
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

    static func rows(for m: MaritalSituation) -> [Row] {
        m == .marriedOne ? tableMarriedOne : tableSingle
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
    static func withholding(grossMonthly R: Double, marital: MaritalSituation, dependents: Int) -> Double {
        let table = rows(for: marital)
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
                           months: Double) -> Double {
        let normal = withholding(grossMonthly: R, marital: marital, dependents: dependents)
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

    /// Progressive annual IRS on a taxable income, split-bracket method:
    /// for income in bracket N, tax = lowerLimit × média(N−1) + (income − lowerLimit) × normal(N).
    static func progressiveAnnual(_ income: Double) -> Double {
        guard income > 0 else { return 0 }
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
                              jovemExemption: Double) -> Double {
        let grossYear = grossMonthly * months
        let fullBase = max(0, grossYear - specificDeductionA)
        let exemptYear = min(max(0, jovemExemption) * grossYear, jovemAnnualCap)
        let nonExemptBase = max(0, fullBase - exemptYear)

        let quotient: Double = marital == .marriedOne ? 2 : 1
        let taxFull = progressiveAnnual(fullBase / quotient) * quotient
        let avgRate = fullBase > 0 ? taxFull / fullBase : 0

        let coleta = avgRate * nonExemptBase
        let credits = Double(dependents) * dependentCredit + generalExpenseCredit
        return max(0, coleta - credits)
    }

    // MARK: Breakdown

    static func breakdown(grossMonthly: Double,
                          months: Double,
                          ajudasMonthly: Double = 0,
                          marital: MaritalSituation = .single,
                          dependents: Int = 0,
                          jovemExemption: Double = 0) -> SalaryBreakdown {
        let gross = max(0, grossMonthly)
        let deps = max(0, dependents)
        let ss = gross * employeeSSRate
        let irs = monthlyIRS(grossMonthly: gross, marital: marital, dependents: deps,
                             jovemExemption: jovemExemption, months: months)
        let net = gross - ss - irs

        let settled = annualSettled(grossMonthly: gross, months: months, marital: marital,
                                    dependents: deps, jovemExemption: jovemExemption)
        let withheld = irs * months

        return SalaryBreakdown(
            grossMonthly: gross,
            netMonthly: net,
            irsMonthly: irs,
            employeeSSMonthly: ss,
            employerSSMonthly: gross * employerSSRate,
            months: months,
            ajudasMonthly: max(0, ajudasMonthly),
            annualIRSSettled: settled,
            annualIRSWithheld: withheld
        )
    }

    /// Invert net → gross by bisection (net is monotonic in gross), carrying the
    /// same tax context so the inversion matches the forward calculation.
    static func grossFromNet(_ net: Double,
                             marital: MaritalSituation = .single,
                             dependents: Int = 0,
                             jovemExemption: Double = 0,
                             months: Double = 14) -> Double {
        guard net > 0 else { return 0 }
        var lo = net, hi = net * 3 + 1_000
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            let midNet = breakdown(grossMonthly: mid, months: months, marital: marital,
                                   dependents: dependents, jovemExemption: jovemExemption).netMonthly
            if midNet < net { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }
}
