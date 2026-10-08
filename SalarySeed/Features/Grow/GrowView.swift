import SwiftUI

/// v0.10: Grow, the time axis of your own salary.
///
/// WHAT THIS SCREEN IS FOR. Home says what you earn now. Compare says how that
/// sits against other people, now. Nothing in the app said anything about
/// later, and "later" is the question people actually carry around: is staying
/// here worth it, or should I move.
///
/// THE HONEST HEADLINE. Across the twenty-four sectors, the 20+ antiguidade band
/// sits a median 1.39 times the under-1 band. Over about twenty-two years that
/// is 1.5% a year before inflation. So the default shape of this screen is a
/// shallow staircase, not a hockey stick, and the screen is built around that
/// rather than around hiding it. What moves the line is changing something.
///
/// PHASE TWO (agreed with Afonso) made it read like Home and Compare. The answer
/// is one centred figure, what you would earn at the end of the horizon, with
/// the 5, 10 or 20 years as a quiet switch under it (it was inside the levers
/// sheet). Hold the chart at a year and the figure reads that year, with that
/// year's net and cost to the employer under the chart. Then a quiet line to try
/// a change, the one rate worth knowing, and everything else (where the years
/// came from, what the model takes for granted) folded behind "How this is
/// worked out". The caveat that changes how the whole chart reads, that it is a
/// photograph of 2024 and not a career, stays on screen.
///
/// Everything is gross: GEP publishes ganho, and putting a net line on the
/// projection stacked a second model on top of the first one. Net appears only
/// for the year being held, where it is worked out with the reader's own tax.
///
/// GROW WRITES NOTHING. It is an exploring surface in the v0.9.4 sense: the
/// scenario lives in memory for the session and never reaches UserDefaults. It
/// used to carry a way to change the real salary from its first year; phase two
/// took it off, as it did on Profile, in favour of Home's bubble.
///
/// v1.0.1: THE WHOLE PROJECTION IS BEHIND THE SUPPORT PAYMENT, DORMANT SINCE
/// v1.3. Non-supporters see this same screen through `SupportLock`: blurred,
/// inert, with a small card over it. The header stays outside the lock and
/// sharp, because a non-supporter is meant to be looking at Grow out of focus
/// rather than at an advert for it.
struct GrowView: View {
    @EnvironmentObject private var store: SalaryStore
    @EnvironmentObject private var supporter: SupporterStore
    /// Drives the rows that stack past the accessibility text sizes.
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The year held on the chart, or nil for the far end of the horizon, which
    /// is what the screen opens on: the answer people arrive with is "what will
    /// I be earning", not "what do I earn today".
    @State private var heldYear: Int?
    @State private var showLevers = false
    @State private var showSectorTenure = false
    @State private var showWorkings = false
    /// The height of the figure and the year switch, measured, so the paid
    /// lock can frame its blurred preview on the staircase rather than on a
    /// 56 point figure that stays legible through the blur. See `loaded`.
    @State private var lockCrop: CGFloat = 0

    private var s: Strings { store.s }
    private var horizon: Int { store.growScenario.horizon }

    /// Built on the store since v1.5, because the offer screen projects staying
    /// with the same model and must start from exactly the same place.
    private var ctx: GrowthEngine.Context? { store.growthContext }

    /// Pushed from Home's row, onto Home's one stack.
    var body: some View {
        Group {
            if let ctx, let result = GrowthEngine.result(ctx: ctx, scenario: store.growScenario) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(ctx: ctx)
                        if supporter.isSupporter {
                            loaded(ctx: ctx, result: result)
                        } else {
                            // Bounded, because it sits inside the scroll view:
                            // unbounded, the card would centre itself somewhere
                            // below the fold (see `SupportLock.contentHeight`).
                            //
                            // CROPPED PAST THE FIGURE. Blurred at radius 6, a 56
                            // point "2889 €" is still legible, which is the one
                            // sharp figure the gate was decided against. So the
                            // preview starts at the staircase, the shape that
                            // says what is behind the payment, and the figure
                            // and the switch are measured rather than guessed,
                            // because both grow with the reader's text. Found by
                            // rendering the paid build.
                            SupportLock(title: s.lockGrowTitle, blurb: s.lockGrowBlurb,
                                        contentHeight: 560, contentOffsetY: -(lockCrop + 12)) {
                                loaded(ctx: ctx, result: result)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            } else {
                // Rule 34: the header is furniture. This branch is a plain
                // column, so without the frame below it would shrink to fit
                // and be centred, header and all, a third of the way down.
                VStack(spacing: 0) {
                    header(ctx: nil)
                        .padding(.horizontal, 20)
                    if supporter.isSupporter {
                        emptyArea
                    } else {
                        SupportLock(title: s.lockGrowTitle, blurb: s.lockGrowBlurb) { emptyArea }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .background(Theme.background)
        .sheet(isPresented: $showSectorTenure) { SectorTenureSheet() }
        .sheet(isPresented: $showLevers) {
            if let ctx {
                GrowthLeversSheet(ctx: ctx, scenario: $store.growScenario)
            }
        }
        .onChange(of: store.growScenario.horizon) { _, new in
            // Picking a horizon means "show me its end", wherever the chart
            // was being held.
            heldYear = nil
            // Shortening the window can strand the cadence outside it, which
            // would leave a lit chip in the sheet doing nothing. This was the
            // sheet's job while the years lived there.
            if store.growScenario.switchEvery > new { store.growScenario.switchEvery = 0 }
        }
    }

    // MARK: The header

    /// The title, and what the projection is built on. Outside the lock, so it
    /// stays sharp for a reader who has not paid; it names their own sector,
    /// which is not the thing behind the payment.
    private func header(ctx: GrowthEngine.Context?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("growSeed")
                .appFont(12)
                .foregroundStyle(Theme.accent)
            Text(s.growTitle)
                .appFont(22, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let ctx {
                Text(s.growSub(ctx.sector.label(pt: s.pt), years: Int(ctx.startTenure)))
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: Loaded

    /// The screen itself, the same on both sides of the lock. If this split
    /// into two versions, the blur would eventually stop showing what is
    /// actually behind the payment.
    @ViewBuilder
    private func loaded(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        let year = min(heldYear ?? horizon, horizon)
        let changed = GrowthEngine.changesPay(ctx: ctx, scenario: store.growScenario)
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                hero(ctx: ctx, result: result, year: year, changed: changed)
                    .padding(.top, 28)
                // The years are a lens on the same path, so they are drawn the
                // way the other lenses are, and quietly: they re-read the
                // figure, they are not the figure.
                QuietSwitch(options: GrowthEngine.Scenario.horizons,
                            selection: $store.growScenario.horizon,
                            voiceLabel: s.growHorizonVoice) { s.growYears($0) }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
            // Measured for the paid lock's crop. It changes only with the
            // reader's text size or the copy, so this writes rarely.
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { lockCrop = $0 }
            chart(ctx: ctx, result: result, year: year, changed: changed)
                .padding(.top, 24)
            heldYearRow(result: result, year: year)
                .padding(.top, 16)
            // The one assumption that changes how every point on the chart
            // reads, so it is not folded away with the others.
            note(s.growAssumptionCrossSection)
                .padding(.top, 14)
            leversLine
                .padding(.top, 24)
            breakEvenCard(ctx: ctx, result: result)
                .padding(.top, 12)
            cumulativeCard(result: result)
            workings(ctx: ctx, result: result)
                .padding(.top, 12)
        }
    }

    // MARK: The answer

    /// What you would earn at the year being held, centred, like Home's figure.
    ///
    /// The figure is the highlighted line on the chart at that year: the
    /// changing-job path when a move is modelled, otherwise the staying path
    /// (which carries any sector, district or pay-growth lever, hence "with
    /// your changes"). Its comparison is ALWAYS with something the chart draws
    /// (rule 4): with a move, the grey staying line beside it, which is exactly
    /// the shaded gap; without one, the line's own start, today. The first
    /// build compared against the every-lever-off baseline, which the chart
    /// does not draw, and with pay growth and a move set it printed a green
    /// "ahead" over a red line sitting below the grey one. Found in review.
    private func hero(ctx: GrowthEngine.Context, result: GrowthEngine.Result,
                      year: Int, changed: Bool) -> some View {
        let f = moneyScale(year)
        let today = ctx.grossToday
        let figure = (result.headline.point(year: year)?.gross ?? today) * f
        let staying = (result.stay.point(year: year)?.gross ?? today) * f
        let label = figureLabel(year: year, changed: changed, figure: figure, today: today)
        return VStack(spacing: 0) {
            Text(label)
                .appFont(15)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // One line, always: a number cannot reflow, so at the largest text
            // sizes a wide one shrinks a little rather than wrapping, as Home's
            // figure does.
            Text(eur(figure))
                .appFont(56, weight: .medium)
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 2)
            // Laid out at year 0 too, invisible, so holding the chart's first
            // year does not take a line out from above the chart and move it
            // under the finger. Compare reserves its headline's height for the
            // same reason.
            Group {
                if result.move != nil {
                    Text(s.growVsStaying(signedEur(figure - staying)))
                        .foregroundStyle(figure >= staying ? Theme.accent : Theme.danger)
                } else {
                    Text(vsToday(from: today, to: figure))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .appFont(13)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
            .opacity(year > 0 ? 1 : 0)
            .accessibilityHidden(year == 0)
            Text(s.growProjectionUnit(store.growScenario.inTodaysMoney))
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func heroLabel(year: Int, changed: Bool) -> String {
        if year == 0 { return s.growToday }
        return changed ? s.growInYearsChanged(year) : s.growInYearsStaying(year)
    }

    /// The words over the figure, built once for the screen and for VoiceOver
    /// (rule 33). At year 0 a sector or district lever already moves the path,
    /// so the first point is not the salary Home shows, and the label says so.
    private func figureLabel(year: Int, changed: Bool, figure: Double, today: Double) -> String {
        year == 0 && abs(figure - today) > 0.5
            ? s.growTodayChanged
            : heroLabel(year: year, changed: changed)
    }

    private func vsToday(from: Double, to: Double) -> String {
        let fraction = from > 0 ? (to - from) / from : 0
        return s.growVsToday(signedEur(to - from), percent(fraction, signed: true))
    }

    // MARK: The chart

    private func chart(ctx: GrowthEngine.Context, result: GrowthEngine.Result,
                       year: Int, changed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GrowthChart(
                stay: result.stay.points,
                move: result.move?.points,
                scale: moneyScale,
                scrubYear: heldBinding
            )
            // The staircase is drawn, so to VoiceOver it is the figure above,
            // a year at a time: swipe up or down to move along it.
            .accessibilityElement()
            .accessibilityLabel(s.growChartVoice)
            .accessibilityValue(spokenYear(ctx: ctx, result: result, year: year, changed: changed))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: hold(year + 1)
                case .decrement: hold(year - 1)
                @unknown default: break
                }
            }
            axisRow
            // One row normally; past an accessibility size the legend and the
            // unit menu each get their own, or "Changing job" and "Today's
            // money" break mid-word fighting for one line.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    legend(result)
                    unitMenu
                }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    legend(result)
                    unitMenu
                }
            }
        }
    }

    private func legend(_ result: GrowthEngine.Result) -> some View {
        GrowthLegend(
            s: s,
            showMove: result.move != nil,
            // The same rule GrowthChart colours the line by: where the two
            // paths end. The cumulative card judges the total, and says so.
            moveAhead: (result.move?.last?.gross ?? 0) >= (result.stay.last?.gross ?? 0)
        )
    }

    /// The chart's held year, with the far end stored as nil so that it keeps
    /// following the horizon until somebody actually holds a year.
    private var heldBinding: Binding<Int> {
        Binding(
            get: { min(heldYear ?? horizon, horizon) },
            set: { hold($0) }
        )
    }

    private func hold(_ year: Int) {
        let y = min(horizon, max(0, year))
        heldYear = y >= horizon ? nil : y
    }

    private func spokenYear(ctx: GrowthEngine.Context, result: GrowthEngine.Result,
                            year: Int, changed: Bool) -> String {
        let gross = (result.headline.point(year: year)?.gross ?? ctx.grossToday) * moneyScale(year)
        let label = figureLabel(year: year, changed: changed, figure: gross, today: ctx.grossToday)
        return "\(label): \(eur(gross))"
    }

    private var axisRow: some View {
        HStack {
            Text(s.growToday)
            Spacer()
            Text(s.growYears(horizon / 2))
            Spacer()
            Text(s.growYears(horizon))
        }
        .appFont(10)
        .foregroundStyle(Theme.textFaint)
        .accessibilityHidden(true)
    }

    /// Which euros the whole screen is drawn in. A menu on the legend's line,
    /// the way a setting is picked on Profile: it was a filled pill above the
    /// chart, louder than the label it sat beside.
    private var unitMenu: some View {
        Menu {
            Picker(selection: $store.growScenario.inTodaysMoney) {
                Text(s.growNominal).tag(false)
                Text(s.growReal).tag(true)
            } label: {
                EmptyView()
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.growScenario.inTodaysMoney ? s.growReal : s.growNominal)
                    .appFont(12)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.up.chevron.down")
                    .appFont(9, weight: .semibold)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Theme.accent)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(s.growUnitLabel)
        .accessibilityValue(store.growScenario.inTodaysMoney ? s.growReal : s.growNominal)
    }

    /// The held year's net and what it costs the employer. Its gross is the
    /// figure at the top, so it is not said again here.
    ///
    /// raiseSeed used to be a separate screen answering "what does a raise cost
    /// my employer"; this row is that, at whatever point on the path is held.
    /// It is also where net appears on this screen, because inspecting a single
    /// point is exactly where the gross to net conversion earns its place.
    private func heldYearRow(result: GrowthEngine.Result, year: Int) -> some View {
        let p = result.headline.point(year: year)
        let f = moneyScale(year)
        return figurePair((s.growScrubNet, eur((p?.net ?? 0) * f)),
                          (s.growScrubEmployer, eur((p?.employerCost ?? 0) * f)))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Two figures side by side, or stacked past an accessibility size, where
    /// "Custa à empresa" broke mid-word and a total like "280 000 €" did not
    /// fit half a phone. One helper for both cards that show a pair, so the
    /// fix cannot reach one and miss the other (rule 33), which is how the
    /// first build had it.
    @ViewBuilder
    private func figurePair(_ a: (String, String), _ b: (String, String)) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                figure(a.0, a.1)
                figure(b.0, b.1)
            }
        } else {
            HStack(spacing: 12) {
                figure(a.0, a.1)
                divider
                figure(b.0, b.1)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 32)
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .appFont(17, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Trying a change

    /// The way into the levers, as one quiet line saying what is set. It was a
    /// full-width accent button, the loudest thing on the screen, for something
    /// most readers open once.
    private var leversLine: some View {
        LineCard {
            Button { showLevers = true } label: {
                GlyphLine(glyph: "slider.horizontal.3", accessory: "chevron.right") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.growLeversTitle)
                            .appFont(16, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(activeLeversLine)
                            .appFont(13)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(RowPressStyle())
        }
    }

    private var activeLeversLine: String {
        let sc = store.growScenario
        var parts: [String] = []
        if sc.switchEvery > 0 {
            parts.append(sc.movePremium > 0
                         ? s.growCadenceEveryAt(sc.switchEvery, percent(sc.movePremium, decimals: 0, signed: true))
                         : s.growCadenceEvery(sc.switchEvery))
        }
        if let sector = sc.sector, sector != store.sector { parts.append(sector.label(pt: s.pt)) }
        if let district = sc.district, district != store.district { parts.append(district.label) }
        if sc.payGrowth > 0 { parts.append("\(percent(sc.payGrowth, signed: true))/\(s.growPerYearShort)") }
        if sc.bracketsIndexed { parts.append(s.growBracketsShort) }
        return parts.isEmpty ? s.growLeversNone : parts.joined(separator: " · ")
    }

    // MARK: What staying is worth

    /// What staying is worth, per year.
    ///
    /// v0.11.1 reframed this. It used to read "a new job has to beat 14.4% if you
    /// leave after 6 years", which is a real number stated in a form nobody can
    /// act on: a percentage with no time attached is not comparable to a raise,
    /// to inflation, or to an offer. The headline is the compounded annual rate;
    /// phase two moved the total it comes from into "How this is worked out" and
    /// kept the one sentence a reader needs to use it.
    ///
    /// In the ten sectors whose bands fall, the rate is negative. That case gets
    /// its own sentence rather than a minus sign left to speak for itself.
    private func breakEvenCard(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        let positive = result.stayAnnual > 0.0005
        // Already in the survey's last band (20+ years): the rate is zero
        // because the table stops there, not because the sector's pay is flat,
        // so it gets its own sentence and no alarm colour.
        let topBand = ctx.startTenure >= (GrowthEngine.bandStarts.last ?? 20)
        // The sector the path is drawn for, which is the lever's when one is set.
        let pathSector = store.growScenario.sector ?? ctx.sector
        let note = positive ? s.growBreakEvenNote
            : topBand ? s.growBreakEvenTopBand(Int(GrowthEngine.bandStarts.last ?? 20))
            : s.growBreakEvenFlat(pathSector.label(pt: s.pt))
        return VStack(alignment: .leading, spacing: 6) {
            Text(s.growBreakEvenTitle)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(percent(result.stayAnnual, signed: true))
                    .appFont(32, weight: .medium)
                    .foregroundStyle(positive ? Theme.accent : topBand ? Theme.textPrimary : Theme.danger)
                    .contentTransition(.numericText())
                Text(s.growPerYearOfTenure)
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(note)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    /// Monthly deltas look ignorable and are not. The cumulative figure is the
    /// one worth showing, so it gets its own card, whenever a move is modelled.
    ///
    /// The totals are summed here, a year at a time in the euros the rest of
    /// the screen is drawn in. GrowthEngine's own totals are nominal, so with
    /// "Today's money" picked this card used to be the one thing on the screen
    /// in a different unit, and near break-even it could even disagree about
    /// which path was ahead. In nominal euros the two are identical.
    @ViewBuilder
    private func cumulativeCard(result: GrowthEngine.Result) -> some View {
        if let move = result.move {
            let months = store.breakdown.months
            let stayTotals = runningTotals(result.stay)
            let moveTotals = runningTotals(move)
            let stayTotal = stayTotals.last ?? 0
            let moveTotal = moveTotals.last ?? 0
            let delta = moveTotal - stayTotal
            let crossoverYear = zip(stayTotals, moveTotals).enumerated()
                .first { $0.element.1 > $0.element.0 }
                .map { $0.offset + 1 }
            let ahead = delta >= 0
            VStack(alignment: .leading, spacing: 8) {
                Text(s.growCumulativeTitle(horizon))
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
                // Past an accessibility size the sentence goes under the
                // figure, or it breaks "changing" mid-word beside it.
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) { cumulativeHeadline(delta * months, ahead: ahead) }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) { cumulativeHeadline(delta * months, ahead: ahead) }
                }
                figurePair((s.growLegendStay, eur(stayTotal * months)),
                           (s.growLegendMove, eur(moveTotal * months)))
                Text(crossoverYear.map { s.growCrossover($0) } ?? s.growNoCrossover(horizon))
                    .appFont(12)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .padding(.top, 12)
        }
    }

    /// A path's gross summed year by year from year 1, in the screen's euros.
    private func runningTotals(_ track: GrowthEngine.Track) -> [Double] {
        var total = 0.0
        return track.points.filter { $0.year >= 1 }.sorted { $0.year < $1.year }.map {
            total += $0.gross * moneyScale($0.year)
            return total
        }
    }

    @ViewBuilder
    private func cumulativeHeadline(_ amount: Double, ahead: Bool) -> some View {
        Text(signedEur(amount))
            .appFont(28, weight: .medium)
            .foregroundStyle(ahead ? Theme.accent : Theme.danger)
            .contentTransition(.numericText())
        Text(ahead ? s.growCumulativeAhead : s.growCumulativeBehind)
            .appFont(13)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: How this is worked out

    /// Everything the figures rest on, folded: the yearly rate's arithmetic,
    /// where the years came from, and what the model takes for granted.
    ///
    /// FOLDED, NEVER CONDITIONAL. "State every assumption, unconditionally" is
    /// about never showing an assumption only where it flatters, and none of
    /// these is shown or hidden by what the answer turned out to be: they are
    /// all one tap away, always, and the one that changes how the chart reads
    /// stays on screen beside it.
    private func workings(ctx: GrowthEngine.Context, result: GrowthEngine.Result) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if reduceMotion {
                    showWorkings.toggle()
                } else {
                    withAnimation(.snappy(duration: 0.3)) { showWorkings.toggle() }
                }
            } label: {
                HStack {
                    Text(s.growWorkingsTitle)
                        .appFont(15, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .appFont(12, weight: .semibold)
                        .foregroundStyle(Theme.textFaint)
                        .rotationEffect(.degrees(showWorkings ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressStyle())
            .accessibilityValue(showWorkings ? s.voiceExpanded : s.voiceCollapsed)

            if showWorkings {
                VStack(alignment: .leading, spacing: 20) {
                    if result.stayAnnual > 0.0005 {
                        let years = Int(ctx.startTenure) + max(store.growScenario.switchEvery, 1)
                        Text(s.growBreakEvenBody(percent(result.stayAnnual, signed: true),
                                                 total: percent(result.breakEven, signed: true),
                                                 years: years))
                            .appFont(13)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    waterfall(ctx: ctx)
                    assumptions(result: result)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    /// Where the difference between today and the far end came from. Gross-side
    /// levers are multipliers so their order cannot matter; tax and the change
    /// of unit are not, so they are always last and always in that sequence.
    @ViewBuilder
    private func waterfall(ctx: GrowthEngine.Context) -> some View {
        let bars = GrowthEngine.waterfall(ctx: ctx, scenario: store.growScenario)
        if bars.count > 1 {
            let peak = max(1, bars.map { abs($0.delta) }.max() ?? 1)
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(s.growWaterfallTitle(horizon))
                waterfallRow(label: s.growWaterfallStart, value: eur(ctx.grossToday), delta: nil, peak: peak)
                ForEach(bars) { bar in
                    waterfallRow(label: s.growWaterfallLabel(bar.id), value: eur(bar.running),
                                 delta: bar.delta, peak: peak)
                }
                Text(s.growWaterfallNote)
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Past the accessibility sizes the label gets a row of its own, with the
    /// bar and the figure under it. In fixed columns it was squeezed down and
    /// then cut off, which "reflow, do not shrink" forbids.
    @ViewBuilder
    private func waterfallRow(label: String, value: String, delta: Double?, peak: Double) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .appFont(12)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(value)
                        .appFont(12, weight: .medium)
                        .foregroundStyle(Theme.textSecondary)
                }
                waterfallBar(delta: delta, peak: peak)
            }
        } else {
            HStack(spacing: 10) {
                Text(label)
                    .appFont(12)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 96, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                waterfallBar(delta: delta, peak: peak)
                Text(value)
                    .appFont(12, weight: .medium)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 62, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private func waterfallBar(delta: Double?, peak: Double) -> some View {
        GeometryReader { geo in
            let d = delta ?? 0
            let width = max(2, CGFloat(abs(d) / peak) * geo.size.width * 0.9)
            RoundedRectangle(cornerRadius: 2)
                .fill(delta == nil ? Theme.textFaint : (d >= 0 ? Theme.accent : Theme.danger))
                .frame(width: delta == nil ? 2 : width, height: 10)
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    /// Everything the picture takes for granted, stated unconditionally. Same
    /// rule as v0.9.4: an assumption that only appears in the branch where it
    /// happens to be flattering is not a stated assumption. The photograph of
    /// 2024 is not repeated here; it is on the screen, under the chart.
    private func assumptions(result: GrowthEngine.Result) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.growAssumptionsTitle)
            note(s.growAssumptionAnchor)
            note(s.growAssumptionGross)
            conditionalAssumptions(result: result)
            note(store.growScenario.bracketsIndexed ? s.growAssumptionBracketsOn : s.growAssumptionBracketsOff)
            note(s.growAssumptionNothingSaved)
            Text(s.cohortSourceLine)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    /// The assumptions that only apply to some scenarios, split into their own
    /// container so the block above cannot creep past ten ViewBuilder children
    /// as more of them are added.
    @ViewBuilder
    private func conditionalAssumptions(result: GrowthEngine.Result) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let entrant = result.entrantMean {
                note(s.growAssumptionEntrant(eur(entrant)))
            }
            if result.dipInSector {
                note(s.growAssumptionDip)
            }
            // v0.11.1: the mover's ladder is frozen after the first move. That
            // is a modelling choice with a real effect on the answer, so it is
            // stated whenever a move is being modelled, not only when it happens
            // to flatter the result.
            if result.move != nil {
                note(s.growAssumptionMoverFrozen)
            }
            if store.growScenario.district != nil {
                note(s.growAssumptionRegion)
            }
            // v0.15: for an islander the district lever is inert, because the
            // district table is mainland. The tax on the path is theirs, though,
            // and both halves of that are worth saying together.
            if store.district == nil, store.taxRegion != .continente {
                note(s.growIslandNote)
            }
            if store.jovemBenefitYear != nil {
                note(s.growAssumptionJovem)
            }
        }
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .frame(width: Theme.scaled(13, typeSize))
                .accessibilityHidden(true)
            Text(text)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Empty

    /// The space under the header, with the empty state centred in it.
    ///
    /// The GeometryReader is greedy, so the header above stays put, and
    /// `minHeight` centres the empty state in the space that is left rather
    /// than parking it under the header. The ScrollView is the
    /// `OnboardingView.scrollingStep` shape and is here for the same reason:
    /// this column is a 64 point sprout, a title, three lines of body and a
    /// button, which stops fitting at a large text size, and without a scroll
    /// view SwiftUI takes the space back out of the text. Nothing inside it
    /// scrolls, so rule 17 is clear.
    private var emptyArea: some View {
        GeometryReader { geo in
            ScrollView {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
    }

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
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 36)
    }

    // MARK: Helpers

    /// Deflator for money, so the chart, the held year and the figure at the
    /// top all switch units together instead of drifting apart.
    private func moneyScale(_ year: Int) -> Double {
        guard store.growScenario.inTodaysMoney else { return 1 }
        return 1 / pow(1 + store.growScenario.inflation, Double(year))
    }
}
