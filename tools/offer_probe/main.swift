// The offer comparison, swept.
//
// OfferComparison computes nothing new. Tax is TaxEngine, the percentiles are
// PercentileEngine and CohortEngine, and staying is GrowthEngine's baseline. So
// what can go wrong is the plumbing between them, and that is exactly what a
// screen cannot show you: a total added up on the wrong number of payments, a
// catch-up year off by one, a staying figure read off a different path from the
// one Grow draws. Every check below is an invariant that has to hold for any
// input, because there is no answer key for a job offer either.
//
//     tools/offer_probe/build.sh && .build/offer_probe     # sweep; exits 1 on any failure
//     .build/offer_probe show                              # a few worked examples, for reading

import Foundation

var checks = 0
var failures = 0

func check(_ ok: Bool, _ what: @autoclosure () -> String) {
    checks += 1
    guard !ok else { return }
    failures += 1
    if failures <= 40 { print("FAIL  \(what())") }
}

func close(_ a: Double, _ b: Double, _ tolerance: Double = 0.005) -> Bool {
    abs(a - b) <= tolerance
}

/// One NUTS II region per withholding table, so a Job can carry both.
let tables: [(tax: TaxEngine.TaxRegion, region: PTRegion)] = [
    (.continente, .norte), (.acores, .acores), (.madeira, .madeira),
]

struct Who {
    let person: OfferComparison.Person
    let jovemYear: Int?
}

let people: [Who] = [
    Who(person: .init(marital: .single, dependents: 0, jovemExemption: 0,
                      ageBand: .band25to34, education: .higher), jovemYear: nil),
    Who(person: .init(marital: .marriedOne, dependents: 2, jovemExemption: 0,
                      ageBand: .band45to54, education: .secondary), jovemYear: nil),
    // IRS Jovem, benefit year 2: the exemption steps down along the staying path.
    Who(person: .init(marital: .single, dependents: 0, jovemExemption: 0.75,
                      ageBand: .under25, education: nil), jovemYear: 2),
]

func job(_ gross: Double, months: Double, ajudas: Double = 0,
         table: (tax: TaxEngine.TaxRegion, region: PTRegion), sector: Sector?) -> OfferComparison.Job {
    OfferComparison.Job(grossMonthly: gross, months: months, ajudasMonthly: ajudas,
                        taxRegion: table.tax, region: table.region, sector: sector)
}

func context(_ sector: Sector, tenure: Int, gross: Double, months: Double,
             who: Who, tax: TaxEngine.TaxRegion) -> GrowthEngine.Context {
    GrowthEngine.Context(sector: sector, startTenure: Double(tenure), grossToday: gross,
                         months: months, marital: who.person.marital,
                         dependents: who.person.dependents, jovemBenefitYear: who.jovemYear,
                         homeDistrict: nil, taxRegion: tax)
}

func isFinite(_ r: OfferComparison.Result) -> Bool {
    let values = [r.now.netMonthly, r.offer.netMonthly, r.offer.annualIRSSettled,
                  r.offerYear.afterTax, r.national.now, r.national.offer, r.keepRate ?? 0]
    return values.allSatisfy { $0.isFinite }
}

// MARK: - Worked examples

if CommandLine.arguments.dropFirst().first == "show" {
    let lisboa: (tax: TaxEngine.TaxRegion, region: PTRegion) = (.continente, .grandeLisboa)
    let examples: [(String, Sector, Int, Double, Double, Double)] = [
        ("IT, 3 years in, 2000 x14 against 2400 x14", .it, 3, 2_000, 2_400, 14),
        ("IT, 1 year in, 2000 x14 against 2400 x14", .it, 1, 2_000, 2_400, 14),
        ("Retail, 12 years in, 1100 x14 against 1250 x14", .retail, 12, 1_100, 1_250, 14),
        ("Finance, 22 years in, 3000 x14 against 3300 x14", .finance, 22, 3_000, 3_300, 14),
        ("Arts, 2 years in, 1500 x14 against 1600 x12", .arts, 2, 1_500, 1_600, 12),
    ]
    for (title, sector, tenure, today, offer, offerMonths) in examples {
        let who = people[0]
        let ctx = context(sector, tenure: tenure, gross: today, months: 14, who: who, tax: lisboa.tax)
        let r = OfferComparison.compare(
            now: job(today, months: 14, table: lisboa, sector: sector),
            offer: job(offer, months: offerMonths, table: lisboa, sector: sector),
            person: who.person, staying: ctx)
        print("\n\(title)")
        print(String(format: "  net a month        now %8.2f   offer %8.2f", r.now.netMonthly, r.offer.netMonthly))
        print(String(format: "  year: gross        now %9.2f  offer %9.2f", r.nowYear.gross, r.offerYear.gross))
        print(String(format: "  year: SS + IRS     now %9.2f  offer %9.2f",
                     r.nowYear.socialSecurity + r.nowYear.irs, r.offerYear.socialSecurity + r.offerYear.irs))
        print(String(format: "  year: after tax    now %9.2f  offer %9.2f", r.nowYear.afterTax, r.offerYear.afterTax))
        print("  keep rate          \(r.keepRate.map { String(format: "%.3f", $0) } ?? "none")")
        print(String(format: "  national pctile    now %5.1f   offer %5.1f", r.national.now, r.national.offer))
        if let s = r.sector {
            print("  sector pctile      now \(s.now?.percentile ?? -1)   offer \(s.offer?.percentile ?? -1)")
        }
        if let st = r.staying {
            for row in st.rows {
                print(String(format: "  in %2d years        staying %8.2f   offer %8.2f   offer minus staying, total %+10.2f",
                             row.years, row.stayingGross, st.offerGross, row.totalDelta))
            }
            print("  catch-up year      \(st.catchUpYear.map(String.init) ?? "none")   flat from \(st.flatFrom.map(String.init) ?? "-")   falls \(st.falls)")
        }
    }
    exit(0)
}

// MARK: - 5. Five years crosses a band for every tenure under twenty

let horizons = OfferComparison.horizons
let shortest = horizons.min() ?? 0
let topBand = Int(GrowthEngine.bandStarts.last ?? 20)
check(shortest > 0, "no horizons")
for t in 0..<topBand {
    check(GrowthEngine.bandIndex(tenureYears: Double(t + shortest)) > GrowthEngine.bandIndex(tenureYears: Double(t)),
          "a \(shortest)-year horizon stays inside one band at tenure \(t): the bands got wider than \(shortest) years")
}

// MARK: - 1 to 4, and 8: the main sweep

let factors = stride(from: -0.30, through: 0.6001, by: 0.05).map { $0 }
var sweeps = 0

for sector in Sector.allCases {
    guard GrowthEngine.means(sector) != nil else {
        check(false, "\(sector) has no tenure row, so staying cannot be drawn for it")
        continue
    }
    for tenure in 0...25 {
        for table in tables {
            for today in [1_200.0, 2_400.0] {
                let who = people[0]
                let nowMonths = 14.0
                let ctx = context(sector, tenure: tenure, gross: today, months: nowMonths, who: who, tax: table.tax)
                let now = job(today, months: nowMonths, table: table, sector: sector)
                let baseline = GrowthEngine.baselineTrack(ctx: ctx, scenario: GrowthEngine.Scenario(horizon: 20))
                func stayingYear(_ y: Int) -> Double { (baseline.point(year: y)?.gross ?? .nan) * nowMonths }
                let label = "\(sector) t=\(tenure) \(table.tax) \(Int(today))"

                // 1. An offer identical to now.
                let same = OfferComparison.compare(now: now, offer: now, person: who.person, staying: ctx)
                check(same.keepRate == nil, "\(label): an identical offer has a keep rate")
                check(same.offer.netMonthly == same.now.netMonthly
                      && same.offer.annualIRSSettled == same.now.annualIRSSettled
                      && same.offerYear.gross == same.nowYear.gross,
                      "\(label): an identical offer is taxed differently")
                check(same.national.now == same.national.offer, "\(label): identical offer, different national percentile")
                check(same.sector?.now?.percentile == same.sector?.offer?.percentile,
                      "\(label): identical offer, different sector percentile")
                check(same.region?.now?.percentile == same.region?.offer?.percentile,
                      "\(label): identical offer, different regional percentile")
                check(same.age?.now?.percentile == same.age?.offer?.percentile
                      && same.education?.now?.percentile == same.education?.offer?.percentile,
                      "\(label): identical offer, different age or education percentile")
                check(same.staying?.offerAhead == false && same.staying?.catchUpYear == nil,
                      "\(label): an identical offer is ahead, or staying 'catches up' with itself")

                // 8. Twenty years or more at the company: nothing left to climb.
                if tenure >= topBand, let st = same.staying {
                    check(st.flatFrom == 0, "\(label): past the last band but not flat from day one")
                    for row in st.rows {
                        check(close(row.stayingGross, today), "\(label): staying moves after the last band")
                    }
                }
                if !GrowthEngine.hasDip(sector) {
                    check(same.staying?.falls == false, "\(label): a path falls in a sector with no dip")
                }

                for offerMonths in [12.0, 14.0] {
                    var previous: OfferComparison.Result?
                    for f in factors {
                        sweeps += 1
                        // Scaled on the year, so the offer's yearly pay rises with f
                        // whichever schedule it is on.
                        let offerGross = today * (1 + f) * nowMonths / offerMonths
                        let offerYear = offerGross * offerMonths
                        let r = OfferComparison.compare(
                            now: now, offer: job(offerGross, months: offerMonths, table: table, sector: sector),
                            person: who.person, staying: ctx)
                        let tag = "\(label) offer \(String(format: "%+.0f%%", f * 100)) x\(Int(offerMonths))"
                        check(isFinite(r), "\(tag): a figure is not finite")
                        if let k = r.keepRate {
                            check(k >= 0 && k <= 1, "\(tag): keep rate \(k) outside 0...1")
                        }
                        guard let st = r.staying else {
                            check(false, "\(tag): no staying block although sector and tenure are known")
                            continue
                        }

                        // 3. Each row is Grow's baseline at that year, computed on its
                        // own horizon rather than read off the 20-year track.
                        for row in st.rows {
                            let own = GrowthEngine.baselineTrack(
                                ctx: ctx, scenario: GrowthEngine.Scenario(horizon: row.years)
                            ).point(year: row.years)?.gross ?? .nan
                            check(close(row.stayingGross, own), "\(tag): staying at \(row.years) years is \(row.stayingGross), Grow says \(own)")
                        }

                        // 4. Totals and the catch-up year, recomputed from the path.
                        for row in st.rows {
                            let expected = (1...row.years).reduce(0.0) { $0 + offerYear - stayingYear($1) }
                            check(close(row.totalDelta, expected, 0.01),
                                  "\(tag): total over \(row.years) years is \(row.totalDelta), the path says \(expected)")
                        }
                        let ahead = offerYear - today * nowMonths > 1
                        check(st.offerAhead == ahead, "\(tag): offerAhead is \(st.offerAhead)")
                        if let n = st.catchUpYear {
                            check(ahead, "\(tag): a catch-up year for an offer that is not ahead")
                            check(stayingYear(n) >= offerYear, "\(tag): staying has not reached the offer in catch-up year \(n)")
                            for y in stride(from: 1, to: n, by: 1) {
                                check(stayingYear(y) < offerYear, "\(tag): staying reaches the offer in year \(y), before catch-up year \(n)")
                            }
                        } else if ahead {
                            for y in 1...20 {
                                check(stayingYear(y) < offerYear, "\(tag): no catch-up year, but staying reaches the offer in year \(y)")
                            }
                        }
                        if let from = st.flatFrom {
                            let after = st.rows.filter { $0.years >= from }
                            check(after.count >= 2, "\(tag): flat from \(from), but fewer than two rows repeat")
                            if let first = after.first {
                                for row in after {
                                    check(close(row.stayingGross, first.stayingGross),
                                          "\(tag): rows past the last band differ")
                                }
                            }
                        }

                        // 2. Monotonic in the offer.
                        if let p = previous, let pst = p.staying {
                            check(r.offer.netMonthly >= p.offer.netMonthly - 0.005, "\(tag): net fell as the offer rose")
                            check(r.offerYear.afterTax >= p.offerYear.afterTax - 0.005, "\(tag): the year after tax fell as the offer rose")
                            check(r.national.offer >= p.national.offer, "\(tag): national percentile fell as the offer rose")
                            if let a = r.sector?.offer?.percentile, let b = p.sector?.offer?.percentile {
                                check(a >= b, "\(tag): sector percentile fell as the offer rose")
                            }
                            for (a, b) in zip(st.rows, pst.rows) {
                                check(a.totalDelta >= b.totalDelta - 0.01, "\(tag): a row's total fell as the offer rose")
                            }
                        }
                        previous = r
                    }
                }
            }
        }
    }
}

// MARK: - Households: keep rate and tax on the other two people

for who in people.dropFirst() {
    for table in tables {
        for today in stride(from: 900.0, through: 5_000.0, by: 250.0) {
            let now = job(today, months: 14, table: table, sector: .it)
            for f in factors {
                let r = OfferComparison.compare(
                    now: now, offer: job(today * (1 + f), months: 14, table: table, sector: .it),
                    person: who.person, staying: nil)
                check(isFinite(r), "\(who.person.marital) \(table.tax) \(today) \(f): a figure is not finite")
                if let k = r.keepRate {
                    check(k >= 0 && k <= 1, "\(who.person.marital) \(table.tax) \(today) \(f): keep rate \(k)")
                }
                check(r.staying == nil, "a staying block with no context")
            }
        }
    }
}

// MARK: - 6. The same year's gross, paid in 12 and in 14

for who in people {
    for table in tables {
        for g14 in stride(from: 800.0, through: 6_000.0, by: 137.0) {
            let a = OfferComparison.Year(OfferComparison.breakdown(job(g14, months: 14, table: table, sector: nil), who.person))
            let b = OfferComparison.Year(OfferComparison.breakdown(job(g14 * 14 / 12, months: 12, table: table, sector: nil), who.person))
            check(close(a.gross, b.gross, 0.01) && close(a.irs, b.irs, 0.01) && close(a.socialSecurity, b.socialSecurity, 0.01),
                  "\(table.tax) \(g14): 12 and 14 payments of the same year settle differently (IRS \(a.irs) vs \(b.irs))")
        }
    }
}

// MARK: - 7. Each region's minimum wage withholds nothing on the offer side

for table in tables {
    let r = OfferComparison.compare(
        now: job(1_500, months: 14, table: table, sector: nil),
        offer: job(table.tax.minWage, months: 14, table: table, sector: nil),
        person: people[0].person, staying: nil)
    check(r.offer.irsMonthly == 0, "\(table.tax): the minimum wage withholds \(r.offer.irsMonthly) on the offer side")
}

// MARK: - 8. Degenerate inputs

// An island on both sides has no regional cohort at all, and says nothing.
let islands = OfferComparison.compare(
    now: job(1_500, months: 14, table: tables[1], sector: .retail),
    offer: job(1_700, months: 14, table: tables[2], sector: .retail),
    person: people[0].person, staying: nil)
check(islands.region == nil, "two islands produced a regional standing")
check(islands.keepRate == nil, "a keep rate across two different tax tables")

// An offer of nothing does not crash or produce NaN.
let nothing = OfferComparison.compare(
    now: job(1_500, months: 14, table: tables[0], sector: .it),
    offer: job(0, months: 14, table: tables[0], sector: .it),
    person: people[0].person, staying: nil)
check(isFinite(nothing), "an offer of zero produced a non-finite figure")

// A net offer goes to gross and back on every table and household.
for who in people {
    for table in tables {
        for g in stride(from: 950.0, through: 7_000.0, by: 311.0) {
            for months in [12.0, 14.0] {
                let net = OfferComparison.breakdown(job(g, months: months, table: table, sector: nil), who.person).netMonthly
                let back = TaxEngine.grossFromNet(net, marital: who.person.marital, dependents: who.person.dependents,
                                                  jovemExemption: who.person.jovemExemption, months: months, region: table.tax)
                check(close(back, g, 0.01), "\(table.tax) \(g) x\(Int(months)): net \(net) comes back as gross \(back)")
            }
        }
    }
}

print("\(checks) checks over \(sweeps) offers, \(failures) failed")
exit(failures == 0 ? 0 : 1)
