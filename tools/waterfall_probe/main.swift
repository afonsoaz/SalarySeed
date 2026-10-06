import Foundation

// Sweeps WaterfallRows and SettlementRows over the salaries, households,
// regions, schedules and lenses the Tax screen can show, and checks what they
// promise:
//
//   1. The rows add up: gross − SS − IRS = net, and cost = gross + employer SS.
//   2. Gross and net are the same whole euros Home prints for them.
//   3. Every figure is within a rounding of its exact value (strictly under 1 €).
//   4. The settlement card's "withheld" is the Year lens's IRS row, its real
//      IRS is a rounding of the exact one, and withheld − real is the balance.
//
// Gross is swept in cents as well as whole euros, because a salary typed as NET
// reaches the engine as a gross found by bisection, which is never whole.
// Exit status is the number of failures, so a script can gate on it.

func whole(_ x: Double) -> Double { x.rounded(.toNearestOrEven) }

let lenses: [(name: String, factor: (Double) -> Double)] = [
    ("x12", { $0 / 12 }), ("x14", { $0 / 14 }), ("year", { $0 }),
]
let households: [(MaritalSituation, Int)] = [
    (.single, 0), (.single, 2), (.marriedTwo, 1), (.marriedOne, 0), (.marriedOne, 3),
]

var failures = 0
var checked = 0
var printed = 0

func fail(_ what: String) {
    failures += 1
    if printed < 20 { print("FAIL " + what); printed += 1 }
}

func check(gross: Double, months: Double, marital: MaritalSituation, deps: Int,
           jovem: Double, region: TaxEngine.TaxRegion) {
    let b = TaxEngine.breakdown(grossMonthly: gross, months: months, marital: marital,
                                dependents: deps, jovemExemption: jovem, region: region)
    for lens in lenses {
        let f = lens.factor(months)
        let r = WaterfallRows(b, factor: f)
        checked += 1
        let tag = "gross=\(gross) months=\(months) \(marital) deps=\(deps) jovem=\(jovem) \(region) \(lens.name)"
        if r.gross - r.employeeSS - r.irs != r.net {
            fail("\(tag): \(r.gross) - \(r.employeeSS) - \(r.irs) != \(r.net)")
        }
        if r.cost != r.gross + r.employerSS {
            fail("\(tag): cost \(r.cost) != \(r.gross) + \(r.employerSS)")
        }
        if r.gross != whole(b.grossMonthly * f) || r.net != whole(b.netMonthly * f) {
            fail("\(tag): gross or net differs from Home's figure")
        }
        let exact: [(String, Double, Double)] = [
            ("employer SS", r.employerSS, b.employerSSMonthly * f),
            ("SS", r.employeeSS, b.employeeSSMonthly * f),
            ("IRS", r.irs, b.irsMonthly * f),
        ]
        for (name, shown, value) in exact where abs(shown - value) >= 1 {
            fail("\(tag): \(name) \(shown) is not a rounding of \(value)")
        }
    }

    let card = SettlementRows(b)
    let yearIRS = WaterfallRows(b, factor: months).irs
    let tag = "gross=\(gross) months=\(months) \(marital) deps=\(deps) jovem=\(jovem) \(region) card"
    if card.withheld != yearIRS {
        fail("\(tag): withheld \(card.withheld) != Year IRS row \(yearIRS)")
    }
    if card.withheld - card.settled != card.balance {
        fail("\(tag): \(card.withheld) - \(card.settled) != \(card.balance)")
    }
    if abs(card.withheld - b.annualIRSWithheld) >= 1 || abs(card.settled - b.annualIRSSettled) > 0.5 {
        fail("\(tag): a settlement figure is not a rounding of its exact value")
    }
}

// The degenerate cases first: nothing, a cent, below the first table row.
for gross in [0.0, 0.01, 0.5, 1, 500, 919.99] {
    for months in [12.0, 14.0] {
        check(gross: gross, months: months, marital: .single, deps: 0, jovem: 0, region: .continente)
    }
}

for region in TaxEngine.TaxRegion.allCases {
    for months in [12.0, 14.0] {
        for (marital, deps) in households {
            for jovem in [0.0, 0.5, 1.0] {
                // Whole euros, minimum wage to 6000.
                var g = 920.0
                while g <= 6000 { check(gross: g, months: months, marital: marital, deps: deps,
                                        jovem: jovem, region: region); g += 7 }
                // Odd cents, as a gross inverted from a typed net would be.
                g = 920.13
                while g <= 6000 { check(gross: g, months: months, marital: marital, deps: deps,
                                        jovem: jovem, region: region); g += 23.37 }
            }
        }
    }
}

// A typed net, inverted the way the app inverts it.
for net in stride(from: 800.0, through: 4000.0, by: 13.0) {
    let g = TaxEngine.grossFromNet(net, months: 14, region: .continente)
    check(gross: g, months: 14, marital: .single, deps: 0, jovem: 0, region: .continente)
}

print("\(checked) waterfalls checked, \(failures) failed")
exit(Int32(min(failures, 255)))
