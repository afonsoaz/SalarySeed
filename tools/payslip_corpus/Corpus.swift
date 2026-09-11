// The fixture catalogue.
//
// Each entry describes a payslip's LAYOUT and VOCABULARY. Every figure on it
// comes from `compute`, which calls `TaxEngine`, so adding a fixture never
// means typing a euro amount.

import Foundation

/// The fictional people and companies. One set, reused, so a diff across the
/// corpus is never noise about names.
let employerName = "PADARIA CENTRAL DE AVEIRO, LDA"
let employerAddr = "Rua das Pombas, 3800-120 Aveiro"
let employerNIPC = "501234567"
let employeeName = "Maria Joana Ferreira dos Santos"
let employeeNIF  = "234567890"

/// The line set almost every family shares: base salary, its total, Social
/// Security, IRS, their total, the net, and the two figures a payslip prints
/// underneath.
///
/// Labels marked `.lexicon` are verbatim in `PayslipLexicon.matchFixtures`
/// (accents aside). The ones marked `.attested` are off real payslips but are
/// not in that list, which is exactly the gap `Verify.swift` reports on.
func standardLines(_ c: Computed, style: MoneyStyle) -> [FixtureLine] {
    [
        FixtureLine(label: "Vencimento base", concept: .baseSalary, cents: c.grossCents,
                    block: .earnings, labelSource: .lexicon, quantity: "30"),
        FixtureLine(label: "Total Ilíquido", concept: .totalEarnings, cents: c.grossCents,
                    block: .earnings, labelSource: .lexicon),

        FixtureLine(label: "Segurança Social (11%)", concept: .employeeSS, cents: c.ssCents,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "IRS Retenção na fonte", concept: .irs, cents: c.irsCents,
                    block: .deductions, labelSource: .attested),
        FixtureLine(label: "Total Descontos", concept: .totalDeductions,
                    cents: c.deductionsCents, block: .deductions, labelSource: .lexicon),

        FixtureLine(label: "LÍQUIDO A RECEBER", concept: .netPay, cents: c.netCents,
                    block: .net, labelSource: .attested),

        FixtureLine(label: "Base de incidência Segurança Social", concept: .ssBase,
                    cents: c.grossCents, block: .extra, labelSource: .attested),
        FixtureLine(label: "Encargo da entidade empregadora", concept: .employerSS,
                    cents: c.employerSSCents, block: .extra, labelSource: .attested),
    ]
}

/// The knobs a fixture is described by. Everything else is derived.
struct Seed {
    var id: String
    var family: String
    var style: MoneyStyle = .dotComma
    var region: TaxEngine.TaxRegion = .continente
    var months: Double = 14
    var marital: MaritalSituation = .single
    var dependents: Int = 0
    var jovem: Double = 0
    var grossCents: Int = 240_000
    var period: String = "MARÇO 2026"
    var days: String = "30"
    var category: String = "Assistente administrativa"
    var expectedSkips: [String] = []
    var isPayslip: Bool = true
    var injection: Injection? = nil
    /// Replaces the shared line set when a family needs its own.
    var lines: ((Computed, MoneyStyle) -> [FixtureLine])? = nil
}

func build(_ seed: Seed) -> Fixture {
    let c = compute(grossCents: seed.grossCents, region: seed.region, months: seed.months,
                    marital: seed.marital, dependents: seed.dependents, jovem: seed.jovem)
    var lines = (seed.lines ?? standardLines)(c, seed.style)

    // Injection happens HERE, after truth is computed and after the page is
    // laid out, so exactly one printed figure moves and the totals do not. The
    // page is then internally inconsistent by exactly `deltaCents`, which is
    // the misread-digit and payroll-typo shape.
    if let injection = seed.injection, injection.kind == .line {
        var moved = false
        lines = lines.map { line in
            guard !moved, line.concept == injection.concept, let cents = line.cents,
                  line.concept?.side != .total else { return line }
            moved = true
            var copy = line
            copy.cents = cents + injection.deltaCents
            return copy
        }
    }

    return Fixture(
        id: seed.id, family: seed.family, style: seed.style, region: seed.region,
        months: seed.months, marital: seed.marital, dependents: seed.dependents,
        jovem: seed.jovem,
        monthlyGrossCents: seed.grossCents, ajudasMonthlyCents: 0,
        employer: employerName, employerAddress: employerAddr, nipc: employerNIPC,
        employee: employeeName, nif: employeeNIF, category: seed.category,
        period: seed.period, days: seed.days,
        lines: lines, expectedSkips: seed.expectedSkips, isPayslip: seed.isPayslip,
        injection: seed.injection)
}


// MARK: Line sets the families that need their own

/// Ajudas de custo and a meal allowance beside the salary.
///
/// The signature fixture. Both go straight to net and sit OUTSIDE the Social
/// Security base, so the earnings total is deliberately not the gross. Whether
/// a recovered "gross" is contaminated by them is the single most important
/// thing to know before a payslip is allowed to fill in somebody's salary.
func ajudasLines(_ c: Computed, style: MoneyStyle) -> [FixtureLine] {
    let ajudas = 15_000      // 150,00
    let meal = 12_540        // 125,40, a month of 5,70 x 22 days
    let earnings = c.grossCents + ajudas + meal
    let net = earnings - c.deductionsCents
    return [
        FixtureLine(label: "Vencimento base", concept: .baseSalary, cents: c.grossCents,
                    block: .earnings, labelSource: .lexicon, quantity: "30"),
        FixtureLine(label: "Ajudas de Custo", concept: .ajudas, cents: ajudas,
                    block: .earnings, labelSource: .lexicon),
        FixtureLine(label: "Subs. Alim. (isento)", concept: .mealAllowance, cents: meal,
                    block: .earnings, labelSource: .lexicon, quantity: "22"),
        FixtureLine(label: "Total Ilíquido", concept: .totalEarnings, cents: earnings,
                    block: .earnings, labelSource: .lexicon),

        FixtureLine(label: "Segurança Social (11%)", concept: .employeeSS, cents: c.ssCents,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "IRS - Tx. 18,18%", concept: .irs, cents: c.irsCents,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "Total Descontos", concept: .totalDeductions,
                    cents: c.deductionsCents, block: .deductions, labelSource: .lexicon),

        FixtureLine(label: "Total a Receber", concept: .netPay, cents: net,
                    block: .net, labelSource: .lexicon),

        FixtureLine(label: "Base de incidência Segurança Social", concept: .ssBase,
                    cents: c.grossCents, block: .extra, labelSource: .attested),
    ]
}

/// The holiday and Christmas subsidies paid as duodécimos, each with its own
/// Social Security and IRS line.
///
/// Three IRS lines and three SS lines, which is the only shape that exercises
/// `PayslipFacts.fact(.irs)` summing across lines. The engine models a month as
/// gross times a schedule, so the four engine checks should decline here with
/// `subsidiesPaidSeparately` rather than answer a different question.
func duodecimosLines(_ c: Computed, style: MoneyStyle) -> [FixtureLine] {
    let duo = Int((Double(c.grossCents) / 12).rounded())
    let earnings = c.grossCents + duo + duo

    let rate = Double(c.irsCents) / Double(c.grossCents)
    let ssDuo = Int((Double(duo) * TaxEngine.employeeSSRate).rounded())
    let irsDuo = Int((Double(duo) * rate).rounded())

    let deductions = c.ssCents + ssDuo + ssDuo + c.irsCents + irsDuo + irsDuo
    let net = earnings - deductions

    return [
        FixtureLine(label: "Vencimento base", concept: .baseSalary, cents: c.grossCents,
                    block: .earnings, labelSource: .lexicon, quantity: "30"),
        FixtureLine(label: "Sub. Férias - duodécimo", concept: .holidaySubsidy, cents: duo,
                    block: .earnings, labelSource: .lexicon),
        FixtureLine(label: "Subsídio de Natal", concept: .christmasSubsidy, cents: duo,
                    block: .earnings, labelSource: .lexicon),
        FixtureLine(label: "Total Ilíquido", concept: .totalEarnings, cents: earnings,
                    block: .earnings, labelSource: .lexicon),

        FixtureLine(label: "Segurança Social (11%)", concept: .employeeSS, cents: c.ssCents,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "Seg. Social Sub. Férias", concept: .employeeSS, cents: ssDuo,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "Seg. Social Sub. Natal", concept: .employeeSS, cents: ssDuo,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "IRS - Tx. 18,18%", concept: .irs, cents: c.irsCents,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "IRS Sub. Férias", concept: .irs, cents: irsDuo,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "IRS Sub. Natal", concept: .irs, cents: irsDuo,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "Total Descontos", concept: .totalDeductions, cents: deductions,
                    block: .deductions, labelSource: .lexicon),

        FixtureLine(label: "Total a Receber", concept: .netPay, cents: net,
                    block: .net, labelSource: .lexicon),

        FixtureLine(label: "Base de incidência Segurança Social", concept: .ssBase,
                    cents: earnings, block: .extra, labelSource: .attested),
    ]
}

/// The month's own totals labelled only "Total", plus a year-to-date block
/// whose three figures satisfy the net identity on their own.
///
/// The most important adversarial fixture in the corpus. The page carries TWO
/// valid earnings-minus-deductions-equals-net triples, the accumulated one is
/// LARGER so magnitude picks the wrong one, and the real totals row scores zero
/// on labels so neither triple wins on its name. Only "a total has to be a
/// total of something" can choose, and on a real payslip this exact shape sent
/// the reader into the annual block.
func accumulatedTrapLines(_ c: Computed, style: MoneyStyle) -> [FixtureLine] {
    let months = 3
    let ytdEarnings = c.grossCents * months
    let ytdDeductions = c.deductionsCents * months
    let ytdNet = ytdEarnings - ytdDeductions
    return [
        FixtureLine(label: "Vencimento base", concept: .baseSalary, cents: c.grossCents,
                    block: .earnings, labelSource: .lexicon, quantity: "30"),
        FixtureLine(label: "Segurança Social (11%)", concept: .employeeSS, cents: c.ssCents,
                    block: .deductions, labelSource: .lexicon),
        FixtureLine(label: "IRS - Tx. 18,18%", concept: .irs, cents: c.irsCents,
                    block: .deductions, labelSource: .lexicon),

        // Deliberately just "Total". No label evidence for either side.
        FixtureLine(label: "Total", concept: .totalEarnings, cents: c.grossCents,
                    block: .earnings, labelSource: .unknown),
        FixtureLine(label: "Total", concept: .totalDeductions, cents: c.deductionsCents,
                    block: .deductions, labelSource: .unknown),
        FixtureLine(label: "A Receber", concept: .netPay, cents: c.netCents,
                    block: .net, labelSource: .unknown),

        FixtureLine(label: "Acumulado Abonos", cents: ytdEarnings,
                    block: .accumulated, labelSource: .unknown),
        FixtureLine(label: "Acumulado Descontos", cents: ytdDeductions,
                    block: .accumulated, labelSource: .unknown),
        FixtureLine(label: "Acumulado Líquido", cents: ytdNet,
                    block: .accumulated, labelSource: .unknown),
    ]
}

/// An invoice, baited.
///
/// Not a payslip, and it must not be reconciled. It carries a "Total a pagar"
/// that the lexicon may well read as a net, an amount that is exactly 11% of
/// another so the Social Security identity has something to find, and enough
/// money tokens to clear the minimum. A reconciled invoice would be the second
/// worst thing this feature could do, after accusing a correct payslip.
func invoiceLines(_ c: Computed, style: MoneyStyle) -> [FixtureLine] {
    let services = 100_000          // 1 000,00
    let discount = 11_000           //   110,00, exactly 11% of the above
    let taxable = services - discount
    let vat = Int((Double(taxable) * 0.23).rounded())
    return [
        FixtureLine(label: "Serviços prestados em Março", cents: services,
                    block: .earnings, labelSource: .unknown),
        FixtureLine(label: "Desconto comercial", cents: discount,
                    block: .earnings, labelSource: .unknown),
        FixtureLine(label: "Valor tributável", cents: taxable,
                    block: .deductions, labelSource: .unknown),
        FixtureLine(label: "IVA 23%", cents: vat,
                    block: .deductions, labelSource: .unknown),
        FixtureLine(label: "Total a pagar", cents: taxable + vat,
                    block: .net, labelSource: .unknown),
    ]
}

// MARK: The catalogue

let seeds: [Seed] = [
    // The repo's original hand-written fixture, now derived from the engine.
    //
    // Its six skips are not a defect to optimise away. With one money column
    // there is nothing to separate the deductions run geometrically, and
    // `docs/fixtures/README.md` already argues that an honest reading of an
    // awkward page is worth more than a tuned reading of a convenient one.
    Seed(id: "onecol-cont14", family: "oneColumn",
         expectedSkips: ["deductionsSum", "irsWithholding", "jovemApplied",
                         "netMonthly", "regionTable", "statedRate"]),

    // The same figures and vocabulary in the shape most Portuguese payslips
    // actually use. The ONLY difference from the fixture above is that the two
    // sides print in two money columns, so this is the controlled comparison
    // that says what geometry is worth.
    Seed(id: "split-cont14", family: "twoColumnSplit"),
    Seed(id: "split-sidebyside-cont14", family: "twoColumnSideBySide"),
    Seed(id: "split-threecol-cont14", family: "threeColumn"),

    // Context sweep. Same layout, different tax tables and schedules, so a
    // region or month-count bug shows up as a row rather than as a hunch.
    Seed(id: "split-acores14", family: "twoColumnSplit", region: .acores),
    Seed(id: "split-madeira14", family: "twoColumnSplit", region: .madeira),
    Seed(id: "split-cont12", family: "twoColumnSplit", months: 12),
    Seed(id: "split-married2dep", family: "twoColumnSplit",
         marital: .marriedTwo, dependents: 2),
    Seed(id: "split-jovem", family: "twoColumnSplit", jovem: 0.5),
    Seed(id: "split-minwage", family: "twoColumnSplit", grossCents: 92_000),

    // Money styles, rotated rather than multiplied out. Every one of these is
    // in PayslipNumber.parsingFixtures marked as coming off a real document.
    Seed(id: "split-spacecomma", family: "twoColumnSplit", style: .spaceComma),
    Seed(id: "split-plaindot", family: "twoColumnSplit", style: .plainDot),
    Seed(id: "split-nbsp", family: "twoColumnSplit", style: .nbspComma),
    Seed(id: "split-eursuffix", family: "twoColumnSplit", style: .euroSuffix),

    // Ajudas de custo and the meal allowance, outside gross.
    Seed(id: "ajudas-cont14", family: "twoColumnSplit", lines: ajudasLines),
    Seed(id: "ajudas-onecol", family: "oneColumn", lines: ajudasLines),

    // Subsidies as duodécimos. The engine checks should decline.
    Seed(id: "duodecimos-cont14", family: "twoColumnSplit", lines: duodecimosLines),

    // The year-to-date trap.
    Seed(id: "ytdtrap-cont14", family: "oneColumn", lines: accumulatedTrapLines),
    Seed(id: "ytdtrap-split", family: "twoColumnSplit", lines: accumulatedTrapLines),

    // Injected errors, after truth was computed. A line moves and the printed
    // totals do not, so the page contradicts itself by exactly this much and
    // self-consistency alone should catch it.
    Seed(id: "inject-ss-3000", family: "twoColumnSplit",
         injection: Injection(kind: .line, concept: .employeeSS, deltaCents: 3000,
                              note: "SS 30,00 too high, totals untouched")),
    Seed(id: "inject-ss-30", family: "twoColumnSplit",
         injection: Injection(kind: .line, concept: .employeeSS, deltaCents: 30,
                              note: "SS 0,30 too high, the real Vision misread")),
    Seed(id: "inject-irs-50000", family: "twoColumnSplit",
         injection: Injection(kind: .line, concept: .irs, deltaCents: 50_000,
                              note: "IRS 500,00 too high, totals untouched")),
    Seed(id: "inject-base-2", family: "twoColumnSplit",
         injection: Injection(kind: .line, concept: .baseSalary, deltaCents: 2,
                              note: "two cents, must never reach wrong")),

    // Not payslips. None of these may produce a verdict.
    Seed(id: "negative-invoice", family: "notAPayslip", category: "FATURA-RECIBO",
         isPayslip: false, lines: invoiceLines),
]

func fixtures() -> [Fixture] { seeds.map(build) }
