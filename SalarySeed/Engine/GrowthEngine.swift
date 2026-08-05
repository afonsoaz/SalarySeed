import Foundation

/// v0.10: the model behind the Grow screen.
///
/// WHAT THIS IS. Quadro 104 gives the mean ganho for every sector crossed with
/// antiguidade na empresa, in six bands. This turns that into a path through
/// time for one person, and compares staying at the same employer with changing
/// employer every few years.
///
/// WHAT IT IS NOT, and the screen says so. Quadro 104 is a cross-section taken
/// in October 2024, not a career followed over twenty years. The people in the
/// 20+ band are not the people in the <1 band two decades later: they are the
/// ones who stayed, in a different mix of jobs, hired in a different decade. So
/// every number here answers "what do people at that tenure earn today", never
/// "what will you earn then".
///
/// THE ONE MODELLING DECISION EVERYTHING RESTS ON. The user is not the band
/// mean, so the path is anchored by ratio: r = their gross ÷ the mean of the
/// band they are in now, and every later point is r × the mean of the band they
/// would then be in. Their path starts exactly on their real salary and keeps
/// their standing inside the cohort. It assumes the tenure SHAPE is the same for
/// everyone in a sector and only the level differs, which is an assumption, and
/// is stated on the screen.
///
/// WHY MOVING DOES NOT RESET TO THE <1 BAND. The obvious construction is to drop
/// a mover onto the <1 mean and let them climb back. It is wrong. The <1 band is
/// full of labour-market entrants (first jobs, no experience), so an experienced
/// person changing employer does not land there, and using it made moving look
/// far worse than it is. Instead the user states the raise they would negotiate
/// (v0.11.1: as a percentage, applied at every move), the path re-anchors on the
/// salary that produces, and the <1 mean appears on screen as a reference only.
enum GrowthEngine {

    // MARK: Bands

    /// Lower edge, in years, of each of Quadro 104's six antiguidade bands.
    /// Same cuts as `TenureBand`, in Double so the path can step through them.
    static let bandStarts: [Double] = [0, 1, 5, 10, 15, 20]

    /// Which of the six bands a tenure in years falls in.
    static func bandIndex(tenureYears: Double) -> Int {
        var i = 0
        while i + 1 < bandStarts.count && tenureYears >= bandStarts[i + 1] { i += 1 }
        return i
    }

    /// The six band means for a sector, or nil when the sector has no row.
    static func means(_ sector: Sector) -> [Double]? {
        guard let arr = SalaryDataset.sectorTenureMean[sector], arr.count == bandStarts.count else { return nil }
        return arr
    }

    /// The mean for one sector at one tenure.
    static func mean(_ sector: Sector, tenureYears: Double) -> Double? {
        means(sector).map { $0[bandIndex(tenureYears: tenureYears)] }
    }

    /// How far above the <1 band a tenure sits, as a share. The tenure step.
    static func tenureStep(_ sector: Sector, tenureYears: Double) -> Double {
        guard let m = means(sector), m[0] > 0 else { return 1 }
        return m[bandIndex(tenureYears: tenureYears)] / m[0]
    }

    /// What walking away after `tenureYears` gives up: the whole tenure step
    /// accumulated since year zero, because leaving resets tenure to zero and
    /// forfeits all of it, not just the last year's increment.
    static func breakEvenPremium(_ sector: Sector, tenureYears: Double) -> Double {
        tenureStep(sector, tenureYears: tenureYears) - 1
    }

    /// True when the sector's six bands are not monotonically rising. TEN of the
    /// twenty-four are not: extractive, energy, media, telecom, finance, real
    /// estate, consulting, public administration, health and arts. The chart
    /// draws the dip rather than smoothing it away, so the screen has to be able
    /// to say why. The count is counted from the table by the verification
    /// script, never asserted here; this comment records what it came to.
    static func hasDip(_ sector: Sector) -> Bool {
        guard let m = means(sector) else { return false }
        return (0..<(m.count - 1)).contains { m[$0 + 1] < m[$0] }
    }

    /// Ratio between two districts for one sector, used to shift a whole path
    /// sideways. Quadro 110 is not crossed with antiguidade, so a district can
    /// only scale the path, never bend it. The screen says exactly that.
    static func regionRatio(sector: Sector, from home: District?, to target: District?) -> Double {
        guard let target, target != home else { return 1 }
        guard let targetMean = DistrictDataset.mean(sector: sector, district: target) else { return 1 }
        let base: Double
        if let home, let homeMean = DistrictDataset.mean(sector: sector, district: home) {
            base = homeMean
        } else if let national = SalaryDataset.sectorTotalMean[sector] {
            base = national
        } else {
            return 1
        }
        guard base > 0 else { return 1 }
        return targetMean / base
    }

    // MARK: Inputs

    /// Everything the model takes from the user's real situation. Read once, at
    /// the top of the screen, so nothing downstream reaches into the store.
    struct Context {
        let sector: Sector
        let startTenure: Double
        let grossToday: Double
        let months: Double
        let marital: MaritalSituation
        let dependents: Int
        /// Which IRS Jovem benefit year the user is in now, or nil when the
        /// exemption does not apply to them.
        let jovemBenefitYear: Int?
        let homeDistrict: District?
        /// v0.15: the projection is taxed where the user actually lives. Without
        /// this, an islander's whole twenty-year net path would be mainland tax.
        let taxRegion: TaxEngine.TaxRegion

        /// The anchor. Their salary as a share of their own band's mean.
        var anchor: Double {
            guard let m = GrowthEngine.mean(sector, tenureYears: startTenure), m > 0 else { return 0 }
            return grossToday / m
        }

        var isUsable: Bool { anchor > 0 && grossToday > 0 }
    }

    /// Everything the user can change on the screen. Nothing here is persisted:
    /// Grow explores, it does not record.
    struct Scenario: Equatable {
        var horizon: Int = 10
        /// Working in a different sector. nil = the one they are in.
        var sector: Sector? = nil
        /// Working in a different district. nil = the one they live in.
        var district: District? = nil
        /// Years between employer changes. 0 = never change.
        var switchEvery: Int = 0
        /// The raise taken at EACH change of employer, as a share of the salary
        /// being earned right before that change.
        ///
        /// v0.11.1 replaced an absolute euro target with this. A euro figure
        /// only ever described the FIRST move, and the moment the horizon
        /// contained two or three moves it stopped being clear what it meant. A
        /// percentage applies identically to every move, and it annualises, so
        /// it can be set beside what staying is worth and compared directly.
        ///
        /// Zero is the deliberate default: a move with no raise shows exactly
        /// what leaving costs on its own, which is the thing worth seeing first.
        var movePremium: Double = 0
        /// Escalões and the IRS Jovem cap rising with prices instead of staying
        /// frozen at their 2026 values.
        var bracketsIndexed: Bool = false
        /// Used by the today's-money view and by bracket indexation.
        var inflation: Double = 0.02
        /// Pay rising across the whole economy, on top of the tenure effect.
        /// Zero by default: at zero every euro on the chart is in today's money
        /// and the curve shows the tenure effect and nothing else.
        var payGrowth: Double = 0
        /// Show euros deflated to today, rather than the nominal figure.
        var inTodaysMoney: Bool = false

        /// Cadences offered. Two years and under is left out on purpose: the
        /// model gives every mover the sector's tenure shape from zero, which
        /// gets generous fast if you let someone move every year.
        static let cadences = [0, 3, 4, 5, 7, 10]
        static let horizons = [5, 10, 20]
    }

    // MARK: Output

    struct YearPoint: Identifiable {
        let year: Int
        let tenure: Double
        let gross: Double
        let net: Double
        let employerCost: Double
        /// Against the national distribution, always in today's money, so the
        /// percentile moves only for real reasons.
        let percentile: Double
        let jovemExemption: Double
        /// A change of employer happened at the start of this year.
        let moved: Bool
        var id: Int { year }
    }

    struct Track {
        let points: [YearPoint]

        var first: YearPoint? { points.first }
        var last: YearPoint? { points.last }

        /// Net over the years ahead. Year 0 is today and is not counted.
        var cumulativeNet: Double {
            points.dropFirst().reduce(0) { $0 + $1.net }
        }

        var cumulativeGross: Double {
            points.dropFirst().reduce(0) { $0 + $1.gross }
        }

        func point(year: Int) -> YearPoint? {
            points.first { $0.year == year }
        }

        /// The compounded annual rate this path actually delivers, start to end.
        /// v0.11.1: everything the screen calls "per year" is computed this way,
        /// from the drawn path, so a rate can never disagree with the chart it
        /// sits under. An earlier draft derived the stayer's rate from the tenure
        /// step alone, which quoted 2.7% a year while the same screen drew a path
        /// growing at 1.2%.
        func annualRate(horizon: Int) -> Double {
            guard horizon > 0,
                  let start = first?.gross, start > 0,
                  let end = last?.gross, end > 0 else { return 0 }
            return pow(end / start, 1 / Double(horizon)) - 1
        }
    }

    /// Both paths plus the numbers the screen leads with.
    struct Result {
        /// Every lever off: the user's own sector and district, no moves, no
        /// economy-wide growth. This is what "if you stay" means, and it has to
        /// be its own track rather than `stay` because `stay` already carries the
        /// sector and district levers.
        let baseline: Track
        let stay: Track
        let move: Track?
        /// The raise a move has to beat, at the tenure the first move happens.
        let breakEven: Double
        /// The two headline rates, both read off the paths that get drawn:
        /// what staying compounds to per year with every lever off, and what the
        /// modelled scenario compounds to per year. nil when no move is set.
        let stayAnnual: Double
        let moveAnnual: Double?
        /// First year the move path is worth more cumulatively than staying.
        let crossoverYear: Int?
        /// The <1 band mean for the sector, shown as a reference and never used
        /// as the path.
        let entrantMean: Double?
        let dipInSector: Bool

        /// The line the screen's headline number comes from: the move path when
        /// the user is modelling a move, the stay path otherwise.
        var headline: Track { move ?? stay }

        /// v0.10.1: gross, not net, like everything else on the projection. GEP
        /// publishes a gross figure, so a cumulative built on net would be a
        /// second model stacked on the first one and compared against itself.
        var cumulativeDelta: Double? {
            move.map { $0.cumulativeGross - stay.cumulativeGross }
        }
    }

    // MARK: The paths

    /// Gross at one point, before tax. Every gross-side lever is a multiplier,
    /// so they commute and the order they are applied in cannot matter.
    private static func gross(anchor: Double,
                              sector: Sector,
                              tenure: Double,
                              regionRatio: Double,
                              growthFactor: Double) -> Double {
        guard let m = mean(sector, tenureYears: tenure) else { return 0 }
        return anchor * m * regionRatio * growthFactor
    }

    /// Turn a gross into the year's full picture.
    private static func point(year: Int,
                              tenure: Double,
                              grossMonthly: Double,
                              moved: Bool,
                              ctx: Context,
                              scenario: Scenario) -> YearPoint {
        let exemption = jovemExemption(year: year, ctx: ctx)
        // Indexed escalões in year y are the 2026 escalões grown by inflation, so
        // taxing a grown salary against grown brackets is the same as taxing the
        // deflated salary against the 2026 tables and growing the answer back.
        // The IRS Jovem cap rides along, which is right: it is set in IAS.
        let f = scenario.bracketsIndexed ? pow(1 + scenario.inflation, Double(year)) : 1
        let b = TaxEngine.breakdown(
            grossMonthly: grossMonthly / f,
            months: ctx.months,
            marital: ctx.marital,
            dependents: ctx.dependents,
            jovemExemption: exemption,
            region: ctx.taxRegion
        )
        let deflator = pow(1 + scenario.inflation, Double(year))
        return YearPoint(
            year: year,
            tenure: tenure,
            gross: grossMonthly,
            net: b.netMonthly * f,
            employerCost: b.employerCostMonthly * f,
            percentile: PercentileEngine.percentile(grossMonthly: grossMonthly / deflator),
            jovemExemption: exemption,
            moved: moved
        )
    }

    /// IRS Jovem steps down on its own schedule whether or not the salary moves,
    /// which is why a young user's net can fall in a year their gross rises.
    private static func jovemExemption(year: Int, ctx: Context) -> Double {
        guard let start = ctx.jovemBenefitYear else { return 0 }
        return TaxEngine.jovemRate(benefitYear: start + year)
    }

    /// Staying at the same employer: tenure just keeps counting up.
    static func stayTrack(ctx: Context, scenario: Scenario) -> Track {
        let sector = scenario.sector ?? ctx.sector
        let ratio = regionRatio(sector: sector, from: ctx.homeDistrict, to: scenario.district)
        let anchor = ctx.anchor
        let points = (0...scenario.horizon).map { y -> YearPoint in
            let tenure = ctx.startTenure + Double(y)
            let g = gross(anchor: anchor, sector: sector, tenure: tenure,
                          regionRatio: ratio,
                          growthFactor: pow(1 + scenario.payGrowth, Double(y)))
            return point(year: y, tenure: tenure, grossMonthly: g, moved: false,
                         ctx: ctx, scenario: scenario)
        }
        return Track(points: points)
    }

    /// Changing employer every `switchEvery` years.
    ///
    /// At a move the path is re-anchored, not reset: the stated raise is applied
    /// to the salary they were actually earning, and tenure goes back to zero.
    ///
    /// v0.11.1 THEN FREEZES THE MOVER'S LADDER, and this is the most important
    /// line in the file. Letting a mover re-climb the tenure curve from zero
    /// after every move produced a result that was arithmetically true and
    /// obviously false: in IT, changing employer every three years with a raise
    /// of EXACTLY ZERO came out €4,733 ahead over twelve years. The curve is
    /// concave, so its early steps are steep and its late ones flat, and a
    /// frequent mover simply harvested the steep part again and again.
    ///
    /// The mistake was treating Quadro 104 as a law of pay. It is a table about
    /// STAYING: every step in it is earned by not leaving, and it says nothing
    /// about what an experienced person is paid on arrival. So the conservative
    /// reading is the honest one. A mover's pay changes when they negotiate and
    /// at no other time, which makes a zero-raise move cost exactly the tenure
    /// step, and makes the two annual rates the screen shows an exact and
    /// honest comparison. The screen states this rather than burying it.
    static func moveTrack(ctx: Context, scenario: Scenario) -> Track? {
        let cadence = scenario.switchEvery
        guard cadence > 0, cadence <= scenario.horizon else { return nil }
        let sector = scenario.sector ?? ctx.sector
        let ratio = regionRatio(sector: sector, from: ctx.homeDistrict, to: scenario.district)
        guard let m = means(sector), m[0] > 0 else { return nil }

        let premium = scenario.movePremium
        var anchor = ctx.anchor
        var tenure = ctx.startTenure
        var hasMoved = false
        var previousGross = gross(anchor: anchor, sector: sector, tenure: tenure,
                                  regionRatio: ratio, growthFactor: 1)
        var points: [YearPoint] = []

        for y in 0...scenario.horizon {
            let growth = pow(1 + scenario.payGrowth, Double(y))
            var moved = false
            if y > 0 {
                if y % cadence == 0 {
                    // v0.11.1: the raise is measured against what they were
                    // ACTUALLY earning the year before, not against what staying
                    // one more year would have paid. "I move and get 20%" is a
                    // statement about the salary in their hand.
                    let target = previousGross * (1 + premium) * (1 + scenario.payGrowth)
                    tenure = 0
                    anchor = target / (m[0] * ratio * growth)
                    moved = true
                    hasMoved = true
                } else if !hasMoved {
                    // Still at the employer they started with, so still climbing.
                    tenure += 1
                }
                // AFTER the first move the ladder stops. See the note below.
            }
            let g = gross(anchor: anchor, sector: sector, tenure: tenure,
                          regionRatio: ratio, growthFactor: growth)
            previousGross = g
            points.append(point(year: y, tenure: tenure, grossMonthly: g, moved: moved,
                                ctx: ctx, scenario: scenario))
        }
        return Track(points: points)
    }

    /// One change of employer, read off the drawn path: what the salary was the
    /// year before, what it becomes, and the difference in euros a month.
    struct MoveStep: Identifiable {
        let year: Int
        let from: Double
        let to: Double
        var uplift: Double { to - from }
        var id: Int { year }
    }

    /// Every change of employer inside the horizon, in euros.
    ///
    /// v0.12: the levers sheet sets a percentage, because that is the only thing
    /// that can apply identically to a move in year 3 and a move in year 9, but
    /// nobody negotiates in percentages, and "+20%" does not tell you what you
    /// would be asking for. So the percentage stays as the input and the euro
    /// amount it produces at each change is what gets shown.
    ///
    /// The figures come from the path itself rather than from `premium × salary`,
    /// so that when economy-wide pay growth is also switched on, the number
    /// matches the step actually drawn on the chart instead of a component of it.
    static func moveSteps(ctx: Context, scenario: Scenario) -> [MoveStep] {
        guard let track = moveTrack(ctx: ctx, scenario: scenario) else { return [] }
        return track.points.compactMap { p in
            guard p.moved, let previous = track.point(year: p.year - 1) else { return nil }
            return MoveStep(year: p.year, from: previous.gross, to: p.gross)
        }
    }

    /// The two rates the levers sheet puts side by side, both measured over the
    /// whole horizon from the paths themselves rather than from the inputs, so
    /// the verdict underneath them always agrees with the chart.
    static func rates(ctx: Context, scenario: Scenario) -> (staying: Double, moving: Double?) {
        let horizon = scenario.horizon
        let staying = baselineTrack(ctx: ctx, scenario: scenario).annualRate(horizon: horizon)
        let moving = moveTrack(ctx: ctx, scenario: scenario)?.annualRate(horizon: horizon)
        return (staying, moving)
    }

    /// First year in which moving has paid more in total than staying.
    static func crossover(stay: Track, move: Track) -> Int? {
        var stayTotal = 0.0
        var moveTotal = 0.0
        for y in 1...max(1, stay.points.count - 1) {
            guard let sp = stay.point(year: y), let mp = move.point(year: y) else { break }
            stayTotal += sp.gross
            moveTotal += mp.gross
            if moveTotal > stayTotal { return y }
        }
        return nil
    }

    /// The path with every pay-side lever off. Same horizon and same tax
    /// treatment, so the only difference against `stay` is the levers themselves.
    static func baselineTrack(ctx: Context, scenario: Scenario) -> Track {
        var base = Scenario()
        base.horizon = scenario.horizon
        base.inflation = scenario.inflation
        base.bracketsIndexed = scenario.bracketsIndexed
        return stayTrack(ctx: ctx, scenario: base)
    }

    /// True when a lever that can move the pay line is set. The today's-money
    /// toggle and bracket indexation are deliberately excluded: they change the
    /// unit or the tax, not the salary, so they must not make the screen claim
    /// the user has changed something about their situation.
    static func changesPay(ctx: Context, scenario: Scenario) -> Bool {
        if scenario.switchEvery > 0 { return true }
        if let sector = scenario.sector, sector != ctx.sector { return true }
        if let district = scenario.district, district != ctx.homeDistrict { return true }
        if scenario.payGrowth != 0 { return true }
        return false
    }

    static func result(ctx: Context, scenario: Scenario) -> Result? {
        guard ctx.isUsable, means(scenario.sector ?? ctx.sector) != nil else { return nil }
        let stay = stayTrack(ctx: ctx, scenario: scenario)
        let move = moveTrack(ctx: ctx, scenario: scenario)
        let sector = scenario.sector ?? ctx.sector
        let firstMoveTenure = ctx.startTenure + Double(max(scenario.switchEvery, 1))
        return Result(
            baseline: baselineTrack(ctx: ctx, scenario: scenario),
            stay: stay,
            move: move,
            breakEven: breakEvenPremium(sector, tenureYears: firstMoveTenure),
            stayAnnual: stay.annualRate(horizon: scenario.horizon),
            moveAnnual: move?.annualRate(horizon: scenario.horizon),
            crossoverYear: move.flatMap { crossover(stay: stay, move: $0) },
            entrantMean: means(sector)?.first,
            dipInSector: hasDip(sector)
        )
    }

    // MARK: Waterfall

    /// One bar. `delta` is the change this lever causes on top of every lever
    /// before it in the fixed order below.
    struct WaterfallBar: Identifiable {
        let id: String
        let delta: Double
        let running: Double
    }

    /// What made up the difference between today and the far end of the chart.
    ///
    /// ORDER IS FIXED AND DELIBERATE. The gross-side levers are multipliers, so
    /// they commute and any order gives the same total; tax is not a multiplier
    /// and inflation is a change of unit, so those two always come last and
    /// always in that sequence. Keeping the order constant is what lets the bars
    /// be read as "this lever is worth that much".
    static func waterfall(ctx: Context, scenario: Scenario) -> [WaterfallBar] {
        guard ctx.isUsable else { return [] }
        let y = scenario.horizon
        var bars: [WaterfallBar] = []
        var running = ctx.grossToday

        func step(_ id: String, to value: Double) {
            let delta = value - running
            running = value
            bars.append(WaterfallBar(id: id, delta: delta, running: running))
        }

        var base = Scenario()
        base.horizon = y
        base.inflation = scenario.inflation

        // 1. tenure alone, in the user's own sector and district
        step("tenure", to: stayTrack(ctx: ctx, scenario: base).last?.gross ?? running)

        // 2. a different sector
        if let sector = scenario.sector, sector != ctx.sector {
            base.sector = sector
            step("sector", to: stayTrack(ctx: ctx, scenario: base).last?.gross ?? running)
        }

        // 3. a different district
        if let district = scenario.district, district != ctx.homeDistrict {
            base.district = district
            step("region", to: stayTrack(ctx: ctx, scenario: base).last?.gross ?? running)
        }

        // 4. changing employer
        if scenario.switchEvery > 0 {
            base.switchEvery = scenario.switchEvery
            base.movePremium = scenario.movePremium
            step("moving", to: moveTrack(ctx: ctx, scenario: base)?.last?.gross ?? running)
        }

        // 5. pay rising across the economy
        if scenario.payGrowth != 0 {
            base.payGrowth = scenario.payGrowth
            let track = base.switchEvery > 0 ? moveTrack(ctx: ctx, scenario: base) : stayTrack(ctx: ctx, scenario: base)
            step("growth", to: track?.last?.gross ?? running)
        }

        // 6. tax, which is not a multiplier and so cannot be reordered
        base.bracketsIndexed = scenario.bracketsIndexed
        let final = base.switchEvery > 0 ? moveTrack(ctx: ctx, scenario: base) : stayTrack(ctx: ctx, scenario: base)
        step("tax", to: final?.last?.net ?? running)

        // 7. and the change of unit, last of all
        if scenario.inTodaysMoney {
            step("inflation", to: running / pow(1 + scenario.inflation, Double(y)))
        }

        return bars
    }
}
