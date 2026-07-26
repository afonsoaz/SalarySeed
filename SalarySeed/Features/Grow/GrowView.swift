import SwiftUI

/// v0.10: Grow, the time axis of your own salary.
///
/// WHAT THIS SCREEN IS FOR. Home says what you earn now. Compare and the map say
/// how that sits against other people, now. Nothing in the app said anything
/// about later, and "later" is the question people actually carry around: is
/// staying here worth it, or should I move.
///
/// THE HONEST HEADLINE. Across the twenty-four sectors, the 20+ antiguidade band
/// sits a median 1.39 times the under-1 band. Over about twenty-two years that
/// is 1.5% a year before inflation. So the default shape of this screen is a
/// shallow staircase, not a hockey stick, and the screen is built around that
/// rather than around hiding it. What moves the line is changing something.
///
/// GROW WRITES NOTHING. It is an exploring surface in the v0.9.4 sense: the
/// scenario lives in memory for the session and never reaches UserDefaults. The
/// single deliberate way to change the real salary is the year-0 card, which
/// routes through the same salaryChangeConfirmation every other entry point uses.
struct GrowView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var scrubYear = 0
    @State private var metric: GrowMetric = .net
    @State private var showLevers = false
    @State private var showSectorTenure = false
    @State private var showEditor = false
    @State private var showExplorer = false
    @State private var askingSalaryChange = false

    private var s: Strings { store.s }

    private var ctx: GrowthEngine.Context? {
        guard let sector = store.sector, let tenure = store.tenureYears else { return nil }
        let b = store.breakdown
        guard b.grossMonthly > 0 else { return nil }
        return GrowthEngine.Context(
            sector: sector,
            startTenure: Double(tenure),
            grossToday: b.grossMonthly,
            months: b.months,
            marital: store.maritalSituation,
            dependents: store.dependents,
            jovemBenefitYear: jovemBenefitYear,
            homeDistrict: store.district
        )
    }

    /// The store keeps the exemption percentage, not which benefit year produced
    /// it, so the year is read back from the rate. A rate that spans three years
    /// resolves to the FIRST of them, which is the most generous reading, and the
    /// assumptions block says so rather than letting it pass as precision.
    private var jovemBenefitYear: Int? {
        let e = store.irsJovemExemption
        if e >= 0.99 { return 1 }
        if e >= 0.74 { return 2 }
        if e >= 0.49 { return 5 }
        if e >= 0.24 { return 8 }
        return nil
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let ctx, let result = GrowthEngine.result(ctx: ctx, scenario: store.growScenario) {
                loaded(ctx: ctx, result: result)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showSectorTenure) { SectorTenureSheet() }
        .sheet(isPresented: $showEditor) { SalaryEditorView() }
        .sheet(isPresented: $showExplorer) { SalaryExplorerSheet() }
        .sheet(isPresented: $showLevers) {
            if let ctx {
                GrowthLeversSheet(ctx: ctx, scenario: $store.growScenario)
            }
        }
        .salaryChangeConfirmation(
            isPresented: $askingSalaryChange,
            s: s,
            onChange: { showEditor = true },
            onExplore: { showExplorer = true }
        )
        .onChange(of: store.growScenario.horizon) { _, new in
            scrubYear = min(scrubYear, new)
        }
    }

    // MARK: Loaded

    private func loaded(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(ctx: ctx)
                breakEvenCard(ctx: ctx, result: result)
                chartBlock(result: result)
                scrubCard(ctx: ctx, result: result)
                cumulativeCard(result: result)
                leversRow
                waterfallCard(ctx: ctx)
                assumptions(ctx: ctx, result: result)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func header(ctx: GrowthEngine.Context) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                SproutView(stage: store.sproutStage, size: 16)
                Text(s.growTitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(s.growSub(ctx.sector.label(pt: s.pt), years: Int(ctx.startTenure)))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    /// The hero. Not a projection: the raise a new job has to beat before the
    /// move has bought anything at all. It is the one number here that is read
    /// straight off the published table with no modelling on top.
    private func breakEvenCard(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        let years = Int(ctx.startTenure) + max(store.growScenario.switchEvery, 1)
        return VStack(alignment: .leading, spacing: 6) {
            Text(s.growBreakEvenTitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f%%", result.breakEven * 100))
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                Text(s.growBreakEvenSuffix(years))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(s.growBreakEvenBody(ctx.sector.label(pt: s.pt)))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    private func chartBlock(result: GrowthEngine.Result) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            metricRow
            GrowthChart(
                stay: result.stay.points,
                move: result.move?.points,
                metric: metric,
                scale: moneyScale,
                scrubYear: $scrubYear
            )
            axisRow
            GrowthLegend(
                s: s,
                showMove: result.move != nil,
                moveAhead: (result.cumulativeDelta ?? 0) >= 0
            )
        }
    }

    private var metricRow: some View {
        HStack(spacing: 8) {
            SegmentedPicker(options: GrowMetric.allCases, selection: $metric) { $0.label(s) }
                .frame(maxWidth: .infinity)
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.growScenario.inTodaysMoney.toggle()
                }
            } label: {
                Text(store.growScenario.inTodaysMoney ? s.growReal : s.growNominal)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.growScenario.inTodaysMoney ? Color(hex: 0x06281C) : Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(store.growScenario.inTodaysMoney ? Theme.accent : Color.white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 11))
            }
            .disabled(metric == .percentile)
            .opacity(metric == .percentile ? 0.4 : 1)
        }
    }

    private var axisRow: some View {
        let horizon = store.growScenario.horizon
        return HStack {
            Text(s.growToday)
            Spacer()
            Text(s.growYears(horizon / 2))
            Spacer()
            Text(s.growYears(horizon))
        }
        .font(.system(size: 10))
        .foregroundStyle(Theme.textFaint)
    }

    /// The scrubbed year. raiseSeed used to be a separate screen answering "what
    /// does a raise cost my employer"; that is this card, at whatever point on
    /// the path the user is holding.
    private func scrubCard(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        let stay = result.stay.point(year: scrubYear)
        let move = result.move?.point(year: scrubYear)
        let shown = move ?? stay
        let f = moneyScale(scrubYear)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(scrubYear == 0 ? s.growToday : s.growYears(scrubYear))
                Spacer()
                if let p = shown, p.tenure >= 0 {
                    Text(s.growTenureAt(Int(p.tenure)))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            HStack(spacing: 10) {
                figure(s.growScrubNet, eur((shown?.net ?? 0) * f))
                divider
                figure(s.growScrubGross, eur((shown?.gross ?? 0) * f))
                divider
                figure(s.growScrubEmployer, eur((shown?.employerCost ?? 0) * f))
            }
            if let move, let stay, abs(move.net - stay.net) > 0.5 {
                Text(s.growScrubVsStay(eur((move.net - stay.net) * f)))
                    .font(.system(size: 11))
                    .foregroundStyle(move.net >= stay.net ? Theme.accent : Theme.danger)
            }
            if scrubYear == 0 {
                Button { askingSalaryChange = true } label: {
                    Text(s.growEditToday)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Monthly deltas look ignorable and are not. The cumulative figure is the
    /// one worth leading with, so it gets its own card.
    @ViewBuilder
    private func cumulativeCard(result: GrowthEngine.Result) -> some View {
        if let move = result.move, let delta = result.cumulativeDelta {
            let months = store.breakdown.months
            let horizon = store.growScenario.horizon
            let ahead = delta >= 0
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(s.growCumulativeTitle(horizon))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(signedEur(delta * months))
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(ahead ? Theme.accent : Theme.danger)
                        .contentTransition(.numericText())
                    Text(ahead ? s.growCumulativeAhead : s.growCumulativeBehind)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 10) {
                    figure(s.growLegendStay, eur(result.stay.cumulativeNet * months))
                    divider
                    figure(s.growLegendMove, eur(move.cumulativeNet * months))
                }
                Text(result.crossoverYear.map { s.growCrossover($0) } ?? s.growNoCrossover(horizon))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var leversRow: some View {
        Button { showLevers = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: 0x06281C))
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.growLeversButton)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x06281C))
                    Text(activeLeversLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: 0x06281C).opacity(0.75))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x06281C).opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var activeLeversLine: String {
        let sc = store.growScenario
        var parts: [String] = []
        if sc.switchEvery > 0 { parts.append(s.growCadenceEvery(sc.switchEvery)) }
        if let sector = sc.sector, sector != store.sector { parts.append(sector.label(pt: s.pt)) }
        if let district = sc.district, district != store.district { parts.append(district.label) }
        if sc.payGrowth > 0 { parts.append(String(format: "%+.1f%%/%@", sc.payGrowth * 100, s.growPerYearShort)) }
        if sc.bracketsIndexed { parts.append(s.growBracketsShort) }
        return parts.isEmpty ? s.growLeversNone : parts.joined(separator: " · ")
    }

    /// Where the difference between today and the far end came from. Gross-side
    /// levers are multipliers so their order cannot matter; tax and the change
    /// of unit are not, so they are always last and always in that sequence.
    @ViewBuilder
    private func waterfallCard(ctx: GrowthEngine.Context) -> some View {
        let bars = GrowthEngine.waterfall(ctx: ctx, scenario: store.growScenario)
        if bars.count > 1 {
            let peak = max(1, bars.map { abs($0.delta) }.max() ?? 1)
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(s.growWaterfallTitle(store.growScenario.horizon))
                waterfallRow(label: s.growWaterfallStart, value: eur(ctx.grossToday), delta: nil, peak: peak)
                ForEach(bars) { bar in
                    waterfallRow(label: s.growWaterfallLabel(bar.id), value: eur(bar.running),
                                 delta: bar.delta, peak: peak)
                }
                Text(s.growWaterfallNote)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func waterfallRow(label: String, value: String, delta: Double?, peak: Double) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 96, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            GeometryReader { geo in
                let d = delta ?? 0
                let width = max(2, CGFloat(abs(d) / peak) * geo.size.width * 0.9)
                RoundedRectangle(cornerRadius: 2)
                    .fill(delta == nil ? Theme.textFaint : (d >= 0 ? Theme.accent : Theme.danger))
                    .frame(width: delta == nil ? 2 : width, height: 10)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 16)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 62, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    /// Everything the picture takes for granted, stated unconditionally. Same
    /// rule as v0.9.4: an assumption that only appears in the branch where it
    /// happens to be flattering is not a stated assumption.
    private func assumptions(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(s.growAssumptionsTitle)
            line(s.growAssumptionCrossSection)
            line(s.growAssumptionAnchor)
            conditionalAssumptions(result: result)
            line(store.growScenario.bracketsIndexed ? s.growAssumptionBracketsOn : s.growAssumptionBracketsOff)
            line(s.growAssumptionNothingSaved)
            Text(CohortEngine.sourceLine)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 4)
        }
    }

    /// The assumptions that only apply to some scenarios, split into their own
    /// container so the block above cannot creep past ten ViewBuilder children
    /// as more of them are added.
    @ViewBuilder
    private func conditionalAssumptions(result: GrowthEngine.Result) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let entrant = result.entrantMean {
                line(s.growAssumptionEntrant(eur(entrant)))
            }
            if result.dipInSector {
                line(s.growAssumptionDip)
            }
            // Rendering the chart caught this one. In a sector whose pay does not
            // rise with tenure, a mover re-enters at the first-year level every
            // time and re-climbs the only rising part of the curve, while the
            // stayer decays. Over twenty years that compounds into a very large
            // gap. It follows from the assumption stated just above rather than
            // from anything GEP measured about movers, so it is said out loud.
            if result.dipInSector && result.move != nil {
                line(s.growAssumptionDipMoving)
            }
            if store.growScenario.district != nil {
                line(s.growAssumptionRegion)
            }
            if jovemBenefitYear != nil {
                line(s.growAssumptionJovem)
            }
        }
    }

    private func line(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 9))
                .foregroundStyle(Theme.textFaint)
                .frame(width: 12)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            SproutView(stage: max(1, store.sproutStage), size: 64)
            Text(s.growEmptyTitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(s.growEmptySub)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { showSectorTenure = true } label: {
                Text(s.growEmptyButton)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x06281C))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 36)
    }

    // MARK: Helpers

    /// Deflator for money, so the chart, the scrubbed figures and the cumulative
    /// total all switch units together instead of drifting apart.
    private func moneyScale(_ year: Int) -> Double {
        guard store.growScenario.inTodaysMoney else { return 1 }
        return 1 / pow(1 + store.growScenario.inflation, Double(year))
    }

    private func signedEur(_ value: Double) -> String {
        (value >= 0 ? "+" : "-") + eur(abs(value))
    }
}
