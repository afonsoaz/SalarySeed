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
/// v0.10.1 PUTS THE ANSWER FIRST. The screen used to open on the break-even
/// premium, which is the sharpest number here but not the one people arrive
/// with. They arrive with "what will I be earning". So the first card is now
/// today's salary next to the same salary at the end of the horizon, and, the
/// moment any lever is set, the same figure again with those changes applied.
/// Everything is gross: GEP publishes ganho, and putting a net line on the
/// projection stacked a second model on top of the first one.
///
/// GROW WRITES NOTHING. It is an exploring surface in the v0.9.4 sense: the
/// scenario lives in memory for the session and never reaches UserDefaults. The
/// single deliberate way to change the real salary is the year-0 card, which
/// routes through the same salaryChangeConfirmation every other entry point uses.
///
/// v1.0.1: THE WHOLE SCREEN IS BEHIND THE SUPPORT PAYMENT. Non-supporters see
/// this same screen through `SupportLock`: blurred, inert, with a small card over
/// it. Not a different screen, the same one out of focus, so what is behind the
/// payment is visible as a shape rather than described in a list. See
/// `SupportLock` for why that does not contradict v0.16's "ask once, where they
/// came looking".
struct GrowView: View {
    @EnvironmentObject private var store: SalaryStore
    @EnvironmentObject private var supporter: SupporterStore
    /// Drives the two rows that stack past the accessibility text sizes.
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var scrubYear = 0
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
            homeDistrict: store.district,
            taxRegion: store.taxRegion
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
            // v1.0.1a: the same content either way. A non-supporter gets it
            // blurred under `SupportLock` rather than a different screen, so what
            // they are looking at is Grow out of focus and not an advert for it.
            if supporter.isSupporter {
                growContent
            } else {
                SupportLock(title: s.lockGrowTitle, blurb: s.lockGrowBlurb) {
                    growContent
                }
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
                projectionCard(ctx: ctx, result: result)
                chartBlock(result: result)
                leversRow
                scrubCard(ctx: ctx, result: result)
                breakEvenCard(ctx: ctx, result: result)
                cumulativeCard(result: result)
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
                    .appFont(20, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(s.growSub(ctx.sector.label(pt: s.pt), years: Int(ctx.startTenure)))
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    // MARK: The answer, first

    /// Today's gross beside the same figure at the end of the horizon, and, when
    /// a lever is set, that figure again with the changes applied.
    ///
    /// "If you stay" comes from `result.baseline`, not `result.stay`. The stay
    /// path already carries the sector and district levers, so using it would
    /// have quietly folded a change into the number labelled "if nothing
    /// changes" and made the comparison beneath it meaningless.
    private func projectionCard(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        let horizon = store.growScenario.horizon
        let f = moneyScale(horizon)
        let today = ctx.grossToday
        let stayEnd = (result.baseline.last?.gross ?? today) * f
        let changed = GrowthEngine.changesPay(ctx: ctx, scenario: store.growScenario)
        let scenarioEnd = (result.headline.last?.gross ?? today) * f
        return VStack(alignment: .leading, spacing: 12) {
            // Bottom-aligned, not centred: the two labels are different lengths
            // ("Today" against "In 10 years, staying put"), so centring would
            // leave the two figures sitting at different heights.
            // v1.0.4: side by side normally, stacked past the accessibility
            // sizes. "Daqui a 10 anos, se ficares" needs four lines in half a
            // screen width at that point, and the label was capped at two, so it
            // truncated to "Daqui a 10 anos, se fi...". The arrow turns with the
            // stack so it still reads as today leading to later.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    projectionFigure(label: s.growToday, value: eur(today),
                                     tint: Theme.textPrimary, big: false)
                    Image(systemName: "arrow.down")
                        .appFont(13, weight: .medium)
                        .foregroundStyle(Theme.textFaint)
                    projectionFigure(label: s.growInYearsStaying(horizon), value: eur(stayEnd),
                                     tint: Theme.textPrimary, big: true)
                }
            } else {
                HStack(alignment: .bottom, spacing: 12) {
                    projectionFigure(label: s.growToday, value: eur(today),
                                     tint: Theme.textPrimary, big: false)
                    Image(systemName: "arrow.right")
                        .appFont(13, weight: .medium)
                        .foregroundStyle(Theme.textFaint)
                        .padding(.bottom, 8)
                    projectionFigure(label: s.growInYearsStaying(horizon), value: eur(stayEnd),
                                     tint: Theme.textPrimary, big: true)
                }
            }
            deltaLine(from: today, to: stayEnd, tint: Theme.textSecondary)
            if changed {
                Divider().overlay(Theme.cardBorder)
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.growWithYourChanges)
                        .appFont(11, weight: .medium)
                        .foregroundStyle(Theme.accent)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(eur(scenarioEnd))
                            .appFont(32, weight: .medium)
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text(s.growVsStaying(signedEur(scenarioEnd - stayEnd)))
                            .appFont(12)
                            .foregroundStyle(scenarioEnd >= stayEnd ? Theme.accent : Theme.danger)
                    }
                    deltaLine(from: today, to: scenarioEnd, tint: Theme.textFaint)
                }
            }
            Text(s.growProjectionUnit(store.growScenario.inTodaysMoney))
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accentBorder))
    }

    private func projectionFigure(label: String, value: String, tint: Color, big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .appFont(10)
                .foregroundStyle(Theme.textSecondary)
                // Two lines is right at the default size and a guillotine past the
                // accessibility ones, where the same label needs four.
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .appFont(big ? 34 : 22, weight: .medium)
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deltaLine(from: Double, to: Double, tint: Color) -> some View {
        let pct = from > 0 ? (to - from) / from * 100 : 0
        return Text(s.growVsToday(signedEur(to - from), percent(pct / 100, signed: true)))
            .appFont(11)
            .foregroundStyle(tint)
    }

    // MARK: Chart

    private func chartBlock(result: GrowthEngine.Result) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            unitRow
            GrowthChart(
                stay: result.stay.points,
                move: result.move?.points,
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

    /// v0.10.1: what was a three-way metric picker is now a label and one
    /// toggle. There is only one quantity on this chart, so the only choice left
    /// is which euros it is drawn in.
    /// The screen itself, pulled out so the locked and unlocked paths draw the
    /// SAME thing. If this split into two versions, the blur would eventually
    /// stop showing what is actually behind the payment.
    ///
    /// The locked path renders it with the session's scenario like anyone else's,
    /// which is fine: the levers cannot be reached through the lock, so it is
    /// always the default one.
    @ViewBuilder
    private var growContent: some View {
        if let ctx, let result = GrowthEngine.result(ctx: ctx, scenario: store.growScenario) {
            loaded(ctx: ctx, result: result)
        } else {
            emptyState
        }
    }

    private var unitRow: some View {
        HStack(spacing: 8) {
            SectionLabel(s.growChartTitle)
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.growScenario.inTodaysMoney.toggle()
                }
            } label: {
                Text(store.growScenario.inTodaysMoney ? s.growReal : s.growNominal)
                    .appFont(11, weight: .medium)
                    .foregroundStyle(store.growScenario.inTodaysMoney ? Theme.ink : Theme.textSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(store.growScenario.inTodaysMoney ? Theme.accent : Color.white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 10))
            }
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
        .appFont(10)
        .foregroundStyle(Theme.textFaint)
    }

    /// The scrubbed year. raiseSeed used to be a separate screen answering "what
    /// does a raise cost my employer"; that is this card, at whatever point on
    /// the path the user is holding. It is also the one place net appears on this
    /// screen, because inspecting a single point is exactly where the gross to
    /// net conversion earns its place.
    private func scrubCard(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        let stay = result.stay.point(year: scrubYear)
        let move = result.move?.point(year: scrubYear)
        let shown = move ?? stay
        let f = moneyScale(scrubYear)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(scrubYear == 0 ? s.growToday : s.growYears(scrubYear)) {
                if let p = shown, p.tenure >= 0 {
                    SectionHint(s.growTenureAt(Int(p.tenure)))
                }
            }
            // Three figures across a phone is already tight; past the
            // accessibility sizes "Custa à empresa" broke mid-word into
            // "Custa à empres / a". One per row from there, dividers dropped
            // because a vertical stack does not need them.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    figure(s.growScrubGross, eur((shown?.gross ?? 0) * f))
                    figure(s.growScrubNet, eur((shown?.net ?? 0) * f))
                    figure(s.growScrubEmployer, eur((shown?.employerCost ?? 0) * f))
                }
            } else {
                HStack(spacing: 10) {
                    figure(s.growScrubGross, eur((shown?.gross ?? 0) * f))
                    divider
                    figure(s.growScrubNet, eur((shown?.net ?? 0) * f))
                    divider
                    figure(s.growScrubEmployer, eur((shown?.employerCost ?? 0) * f))
                }
            }
            if let move, let stay, abs(move.gross - stay.gross) > 0.5 {
                Text(s.growScrubVsStay(signedEur((move.gross - stay.gross) * f)))
                    .appFont(11)
                    .foregroundStyle(move.gross >= stay.gross ? Theme.accent : Theme.danger)
            }
            if scrubYear == 0 {
                Button { askingSalaryChange = true } label: {
                    Text(s.growEditToday)
                        .appFont(12, weight: .medium)
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
                .appFont(10)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .appFont(15, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What staying is worth, per year.
    ///
    /// v0.11.1 reframed this. It used to read "a new job has to beat 14.4% if you
    /// leave after 6 years", which is a real number stated in a form nobody can
    /// act on: a percentage with no time attached is not comparable to a raise,
    /// to inflation, or to an offer. The headline is now the compounded annual
    /// rate, and the total it comes from is support underneath it.
    ///
    /// In the ten sectors whose bands fall, the rate is negative. That case gets
    /// its own sentence rather than a minus sign left to speak for itself.
    private func breakEvenCard(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        let years = Int(ctx.startTenure) + max(store.growScenario.switchEvery, 1)
        let positive = result.stayAnnual > 0.0005
        return VStack(alignment: .leading, spacing: 6) {
            Text(s.growBreakEvenTitle)
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(percent(result.stayAnnual, signed: true))
                    .appFont(32, weight: .medium)
                    .foregroundStyle(positive ? Theme.accent : Theme.danger)
                    .contentTransition(.numericText())
                Text(s.growPerYearOfTenure)
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(positive
                 ? s.growBreakEvenBody(percent(result.breakEven, signed: true), years: years)
                 : s.growBreakEvenFlat(ctx.sector.label(pt: s.pt)))
                .appFont(11.5)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.growBreakEvenNote)
                .appFont(10.5)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Monthly deltas look ignorable and are not. The cumulative figure is the
    /// one worth showing, so it gets its own card.
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
                        .appFont(26, weight: .medium)
                        .foregroundStyle(ahead ? Theme.accent : Theme.danger)
                        .contentTransition(.numericText())
                    Text(ahead ? s.growCumulativeAhead : s.growCumulativeBehind)
                        .appFont(12)
                        .foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 10) {
                    figure(s.growLegendStay, eur(result.stay.cumulativeGross * months))
                    divider
                    figure(s.growLegendMove, eur(move.cumulativeGross * months))
                }
                Text(result.crossoverYear.map { s.growCrossover($0) } ?? s.growNoCrossover(horizon))
                    .appFont(11)
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
                    .appFont(18)
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.growLeversButton)
                        .appFont(14, weight: .semibold)
                        .foregroundStyle(Theme.ink)
                    Text(activeLeversLine)
                        .appFont(11)
                        .foregroundStyle(Theme.ink.opacity(0.75))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .appFont(12, weight: .semibold)
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var activeLeversLine: String {
        let sc = store.growScenario
        var parts: [String] = []
        if sc.switchEvery > 0 {
            parts.append(sc.movePremium > 0
                         ? s.growCadenceEveryAt(sc.switchEvery, String(format: "%+.0f%%", sc.movePremium * 100))
                         : s.growCadenceEvery(sc.switchEvery))
        }
        if let sector = sc.sector, sector != store.sector { parts.append(sector.label(pt: s.pt)) }
        if let district = sc.district, district != store.district { parts.append(district.label) }
        if sc.payGrowth > 0 { parts.append("\(percent(sc.payGrowth, signed: true))/\(s.growPerYearShort)") }
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
                    .appFont(10.5)
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
                .appFont(12)
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
                .appFont(12, weight: .medium)
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
            line(s.growAssumptionGross)
            conditionalAssumptions(result: result)
            line(store.growScenario.bracketsIndexed ? s.growAssumptionBracketsOn : s.growAssumptionBracketsOff)
            line(s.growAssumptionNothingSaved)
            Text(s.cohortSourceLine)
                .appFont(9.5)
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
            // v0.11.1: the mover's ladder is frozen after the first move. That
            // is a modelling choice with a real effect on the answer, so it is
            // stated whenever a move is being modelled, not only when it happens
            // to flatter the result.
            if result.move != nil {
                line(s.growAssumptionMoverFrozen)
            }
            if store.growScenario.district != nil {
                line(s.growAssumptionRegion)
            }
            // v0.15: for an islander the district lever is inert, because the
            // district table is mainland. The tax on the path is theirs, though,
            // and both halves of that are worth saying together.
            if store.district == nil, store.taxRegion != .continente {
                line(s.growIslandNote)
            }
            if jovemBenefitYear != nil {
                line(s.growAssumptionJovem)
            }
        }
    }

    private func line(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .appFont(9)
                .foregroundStyle(Theme.textFaint)
                .frame(width: Theme.scaled(12, typeSize))
                .accessibilityHidden(true)
            Text(text)
                .appFont(10)
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
                .appFont(20, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(s.growEmptySub)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { showSectorTenure = true } label: {
                Text(s.growEmptyButton)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 36)
    }

    // MARK: Helpers

    /// Deflator for money, so the chart, the scrubbed figures and the headline
    /// projection all switch units together instead of drifting apart.
    private func moneyScale(_ year: Int) -> Double {
        guard store.growScenario.inTodaysMoney else { return 1 }
        return 1 / pow(1 + store.growScenario.inflation, Double(year))
    }

    private func signedEur(_ value: Double) -> String {
        (value >= 0 ? "+" : "-") + eur(abs(value))
    }
}
