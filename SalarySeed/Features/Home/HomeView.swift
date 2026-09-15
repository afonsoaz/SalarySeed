import SwiftUI

/// netSeed, the dashboard. Hero numbers, breakdown, annual settlement, "what if".
/// v0.2: greeting, living-sprout brand mark, count-up + leaf unfurl.
/// v0.3: all copy comes from the string table (EN + PT).
/// v0.10.1: the percentile teaser and the pointer to Grow both came off. Home
/// answers one question, what your salary means right now, and hands the other
/// questions to the tabs that own them instead of previewing them badly.
/// Names for the one coordinate space and the one scroll anchor this screen
/// uses. Strings in two places that have to match are a typo waiting to happen.
private enum HomeScroll {
    static let space = "homeScroll"
    static let detailAnchor = "homeDetail"
}

/// How tall the VISIBLE region of the scroll view is, which is what `fold` is
/// sized to.
///
/// Read from a `.background` on the ScrollView and never from its content. A
/// background is sized by its host, and the host's frame comes from the
/// NavigationStack inside the TabView, so it is not a function of the content
/// and the measurement cannot feed back into itself.
///
/// `g.size.height` RAW, with nothing subtracted, and that was measured rather
/// than reasoned about. Subtracting `safeAreaInsets` looks obviously right and
/// is wrong twice over: SwiftUI has already sized the scroll view to the region
/// it may occupy, so the insets come off a number they have come off once
/// already. On an iPhone 17 the difference is 584 points against 756, and the
/// symptom is a fold that ends a third of the way up the screen with the next
/// section sitting in plain sight under the invitation to scroll to it.
private struct ViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Where the top of the content sits relative to the scroll view, so the
/// see-more prompt can retire once the reader has taken its advice.
private struct ScrollTopKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: SalaryStore
    /// Read for `leafSize`, and for the scaled glyph boxes further down. It
    /// drove the two-row top bar until v1.4 moved the picker out of it.
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var period: ResultPeriod = .m14
    @State private var pickedInitial = false
    @State private var showEditor = false
    @State private var showFutureSeed = false
    // v0.9.4
    @State private var showExplorer = false
    /// v1.2: Profile is no longer a tab, and this is how it is reached. A push
    /// rather than a sheet, because it is a destination with ten sheets of its
    /// own hanging off it and a sheet on a sheet is a stack of cards.
    @State private var showProfile = false
    @State private var askingSalaryChange = false
    /// v1.4: true once the reader has scrolled past the fold, which retires the
    /// see-more prompt. A Bool and not the offset: `body` holds `RollingEuro`'s
    /// content transition and the leaf's springs, and storing a CGFloat here
    /// would redraw all of it on every scroll frame.
    @State private var hasScrolled = false
    /// The visible height of the scroll view, measured. See `ViewportHeightKey`.
    @State private var viewport: CGFloat = 0

    /// v0.8: three ways to read the result. Two are monthly (the yearly pay spread
    /// over 12, or over the 14 real payments) and one is the yearly total.
    enum ResultPeriod: String, CaseIterable, Identifiable {
        case m12, m14, year
        var id: String { rawValue }
        /// 0 = monthly ÷12, 1 = monthly ÷14, 2 = annual. Drives the copy helpers.
        var modeIndex: Int { self == .m12 ? 0 : (self == .m14 ? 1 : 2) }
        var isAnnual: Bool { self == .year }
        func label(_ s: Strings) -> String {
            switch self {
            case .m12: return s.resultM12
            case .m14: return s.resultM14
            case .year: return s.resultYear
            }
        }
        /// Multiplier on a per-payment monthly value to reach this view.
        func factor(months: Double) -> Double {
            switch self {
            case .m12: return months / 12
            case .m14: return months / 14
            case .year: return months
            }
        }
    }

    private var s: Strings { store.s }
    private var b: SalaryBreakdown { store.breakdown }
    private var isAnnual: Bool { period.isAnnual }
    private var factor: Double { period.factor(months: b.months) }

    /// v1.4: HOME IS TWO SCREENS NOW, and the first one leads with one number.
    ///
    /// It held eleven blocks in one scroll, and the first screenful carried the
    /// pay figures, a percentage card, an edit button and a share-of-cost bar
    /// before anybody had read anything. `fold` is the top bar, a one-line
    /// greeting, the net figure, and then where the money goes; the detail
    /// trees and the annual settlement live below it, which is where somebody
    /// goes looking for them.
    ///
    /// v1.4a PUT "WHERE THE MONEY GOES" BACK IN THE FOLD. The first cut left
    /// the fold holding the figures alone, and it read as empty rather than as
    /// calm: most of a screen of nothing between the period picker and an
    /// invitation to scroll. The bar is one section label, one percentage and
    /// four segments, so it fills that space with the one thing a reader
    /// glancing at their pay actually wants next, and the invitation now has
    /// something to be at the bottom of.
    ///
    /// The default look moves, deliberately: 30pt side-by-side figures became a
    /// 44pt net figure over a 20pt gross annotation. That is a design decision,
    /// not a Dynamic Type one, and the locked Type rules say to name it as such.
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fold(proxy)
                    belowFold
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .coordinateSpace(.named(HomeScroll.space))
            .background {
                GeometryReader { g in
                    Color.clear.preference(key: ViewportHeightKey.self, value: g.size.height)
                }
            }
            .onPreferenceChange(ViewportHeightKey.self) { h in
                // `> 1` rather than `!=`: a sub-point difference re-entering
                // state is the shape that turns a measurement into a loop.
                if abs(h - viewport) > 1 { viewport = h }
            }
            .onPreferenceChange(ScrollTopKey.self) { y in
                // Two thresholds, 16 points apart, so a rubber-band settle at
                // exactly the boundary cannot flutter the prompt in and out.
                if !hasScrolled, y < -24 { hasScrolled = true }
                else if hasScrolled, y > -8 { hasScrolled = false }
            }
            .background(alignment: .top) {
                RadialGradient(
                    colors: [Theme.accent.opacity(0.06), .clear],
                    center: .top, startRadius: 0, endRadius: 420
                )
                .ignoresSafeArea()
            }
            .background(Theme.background)
            .sheet(isPresented: $showEditor) { SalaryEditorView() }
            .sheet(isPresented: $showFutureSeed) { FutureSeedView() }
            .sheet(isPresented: $showExplorer) { SalaryExplorerSheet() }
            .profileDestination(isPresented: $showProfile)
            .salaryChangeConfirmation(
                isPresented: $askingSalaryChange,
                s: s,
                onChange: { showEditor = true },
                onExplore: { showExplorer = true }
            )
            .onAppear {
                // Open on the lens that equals the user's real per-payment amount.
                guard !pickedInitial else { return }
                period = store.schedule == .twelve ? .m12 : .m14
                pickedInitial = true
            }
            }
        }
    }

    /// Everything the prompt scrolls to.
    ///
    /// One group rather than five siblings, so the scroll anchor has something
    /// to be on. The extra top padding is for that landing: `anchor: .top` puts
    /// this at the top of the scroll region, which runs under the clock, and
    /// `RootTabView.statusBarScrim` is 96 points tall there, so without it the
    /// section label arrives inside the scrim's fade and reads as half erased.
    /// Padding rather than a negative UnitPoint on `scrollTo`, because it also
    /// widens the gap between a full-screen fold and what follows it, which is
    /// wanted anyway.
    ///
    /// The inner spacing matches the outer stack's, so nothing moved by being
    /// grouped.
    private var belowFold: some View {
        VStack(alignment: .leading, spacing: 20) {
            detailsSection
            annualSettlementCard
            nudges
            disclaimer
        }
        .padding(.top, 28)
        .id(HomeScroll.detailAnchor)
    }

    // MARK: The fold

    /// The first screen: one number, and a way down to the rest.
    ///
    /// `minHeight: viewport` is what makes it a fold at all. The content here is
    /// about 314 points at the default text size against a screen of 600 to 730,
    /// so with fixed spacing there is no fold: three or four hundred points of
    /// the next section sit on screen and the invitation is pointless. The two
    /// Spacers absorb the difference, which lands the figure optically centred
    /// and the prompt at the bottom edge.
    ///
    /// Past an accessibility text size the natural content is taller than the
    /// screen, `minHeight` goes inert, both Spacers collapse to their minLength,
    /// and the prompt moves below the fold. That is correct: the content being
    /// cut off at the bottom is its own scroll affordance.
    private func fold(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                // The scroll sentinel rides in a BACKGROUND, not as a child of
                // this stack. A bare GeometryReader in a VStack claims all the
                // height it is offered, and even a zero-height Color.clear
                // child would still take a gap from the parent's spacing. In a
                // background it is sized by its host and contributes no layout.
                .background {
                    GeometryReader { g in
                        Color.clear.preference(
                            key: ScrollTopKey.self,
                            value: g.frame(in: .named(HomeScroll.space)).minY
                        )
                    }
                }

            greeting
                .padding(.top, 14)

            Spacer(minLength: 24)

            heroNet
            heroFootnotes

            // The picker changes the number, so it sits under the number rather
            // than in the top bar. See the note on `topBar`.
            periodPicker
                .padding(.top, 24)

            BreakdownBar(breakdown: b)
                .padding(.top, 26)

            // Still directly above the detail, so its own note about sitting
            // "at the boundary, the last moment the profile is still the
            // subject" stays literally true: everything below the fold is
            // arithmetic on the salary alone.
            profileNudge
                .padding(.top, 14)

            Spacer(minLength: 20)

            seeMorePrompt(proxy)
        }
        .frame(minHeight: max(0, viewport - Self.foldBottomSlack), alignment: .top)
    }

    /// Breathing room between the see-more prompt and the tab bar.
    ///
    /// The measured viewport ends exactly at the top of iOS 26's floating bar,
    /// which left the chevron about eight points off it: legible, but it read as
    /// jammed against the glass. One number, turned by looking at it.
    private static let foldBottomSlack: CGFloat = 12

    /// v1.0.3 made this two rows past an accessibility text size, and v1.4
    /// DELETED THAT BRANCH by moving the thing it existed for.
    ///
    /// Three things shared the row and the 188pt picker was the immovable one,
    /// so the wordmark was what got squeezed: it wrapped to "Salar / ySee / d"
    /// while the three segments overlapped each other. The picker now lives in
    /// the fold, under the figure it changes, so what is left is a wordmark and
    /// a 44pt button. Those fit on one row at every text size, including AX5,
    /// and a reflow branch for a row that no longer overflows is a branch
    /// nobody can check.
    private var topBar: some View {
        HStack {
            brandMark
            Spacer()
            ProfileButton(isPresented: $showProfile)
        }
        .padding(.top, 8)
    }

    private var brandMark: some View {
        HStack(spacing: 6) {
            // the brand mark is alive: it grows with the profile (sproutStage 1 to 5)
            SproutView(stage: store.sproutStage, size: 18)
            // One line always. It is a wordmark, and a wordmark that wraps is a
            // typo as far as the reader is concerned.
            Text("SalarySeed").appFont(13, weight: .medium).lineLimit(1)
        }
        .foregroundStyle(Theme.accent)
    }

    private var periodPicker: some View {
        SegmentedPicker(options: ResultPeriod.allCases, selection: $period) {
            $0.label(s)
        }
    }

    /// v1.2: PROFILE LIVES HERE NOW, and it cost nothing to put it here.
    ///
    /// This slot held a pencil that opened `askingSalaryChange`, which is what
    /// the row two below in the same scroll view already did. One action, twice,
    /// on one screen, which is the thing "no echoes" forbids. So the row did not
    /// have to grow to take a fourth item; it had to lose a third.
    ///
    /// v1.2b moved the button itself to `Features/Shared/ProfileButton.swift`,
    /// because it is now in all five tab headers and there is no version of
    /// that worth writing five times.
    ///
    /// v1.4 deleted that row and the pencil came back, but NOT to this slot: it
    /// sits on the net figure's own label, because the affordance only works
    /// while it is adjacent to the thing it edits. Three hundred points away
    /// from the number is how it became a floating pencil the first time.

    /// v1.4: one line. The subtitle said "here's what your salary really means",
    /// which is a sentence about the screen rather than about the reader's pay,
    /// and the whole point of the fold is that there is less to read on it.
    ///
    /// 18pt on the `.body` curve, deliberately not 20: 20 crosses into `.title3`
    /// and the greeting would then grow more slowly than the figure beneath it.
    /// No lineLimit, because "reflow, do not shrink" is locked and a long name
    /// wrapping to two lines is the correct outcome.
    private var greeting: some View {
        Text(s.hey(store.displayName))
            .appFont(18)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// v1.4: one figure, and it is the way into the editor.
    ///
    /// Net leads at 44pt with gross as a 20pt annotation under it, rather than
    /// the two side by side at 30. Two signals make the gross read as secondary
    /// before the sizes do: it is in `textSecondary` against the accent, and the
    /// word "Bruto" sits in front of it in `textFaint`.
    ///
    /// 44 is not too big, and it is measured rather than judged. `band(for: 44)`
    /// is `.largeTitle`, so it resolves to 67pt at accessibility-extra-large,
    /// where the widest figure anybody will see ("140 000 €", plus the leaf) is
    /// 334 points of the 335 available. `minimumScaleFactor` never engages. The
    /// old side-by-side pair was in fact the cramped one: each column had 153
    /// points and already shrank at that size.
    ///
    /// THE WHOLE BLOCK IS THE BUTTON, because the row that used to say "Update
    /// my salary" is gone. A bare figure is not discoverable as a control, so
    /// the 11pt pencil on the label is the affordance: the same glyph that row
    /// used, in a tenth of the space, and on the LABEL rather than the figure so
    /// the number stays undecorated and the pencil never shares a baseline with
    /// the unfurling leaf.
    private var heroNet: some View {
        Button { askingSalaryChange = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                // `.center`, not `.firstTextBaseline`. Rule 31: the pencil is an
                // Image, has no baseline of its own, and a baseline alignment
                // would drag its bottom edge down to meet the text's.
                HStack(alignment: .center, spacing: 5) {
                    Text("\(s.netWord) / \(s.periodSuffix(period.modeIndex))")
                        .appFont(12)
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "pencil")
                        .appFont(11)
                        .foregroundStyle(Theme.accent)
                }

                // `.firstTextBaseline` here is DELIBERATE and is not the rule 31
                // mistake it looks like. LeafGlyph is a Shape with no baseline,
                // so SwiftUI aligns its bottom edge, which is exactly where the
                // leaf's own `.bottomLeading` unfurl anchor wants to be: it
                // sprouts from the baseline of the number. Changing this to
                // `.bottom` detaches it.
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    RollingEuro(value: b.netMonthly * factor, color: Theme.accent, fontSize: 44)
                    UnfurlingLeaf(trigger: b.netMonthly * factor, size: leafSize)
                }
                .padding(.top, 2)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(s.grossWord)
                        .appFont(13)
                        .foregroundStyle(Theme.textFaint)
                    // No period suffix: the label above already named it, and
                    // the gross is the same period by construction.
                    Text(eur(b.grossMonthly * factor))
                        .appFont(20, weight: .medium)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 6)
            }
            // SwiftUI centres text inside a Button label unless told otherwise,
            // and this label is a left-aligned column of three. Rule 27.
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // So the 2pt and 6pt gaps between the rows are live too.
            .contentShape(Rectangle())
        }
        // Without this the default style press-dims a 335x90 area, and a flash
        // across a 44pt figure reads as a rendering glitch rather than a tap.
        .buttonStyle(.plain)
        // One element, with an explicit label rather than `.combine`: combined,
        // VoiceOver reads four fragments and speaks "(x14)" as punctuation.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            s.heroVoice(net: eur(b.netMonthly * factor),
                        gross: eur(b.grossMonthly * factor),
                        per: s.periodVoice(period.modeIndex))
        )
        .accessibilityHint(s.heroEditHint)
    }

    /// 18 points beside a 44 point figure keeps the ratio the 13pt leaf had
    /// beside the old 30pt one, and it is scaled on the FIGURE's curve rather
    /// than its own. See the note in `UnfurlingLeaf`.
    private var leafSize: CGFloat { 18 * Theme.scaled(44, typeSize) / 44 }

    /// What the figure above takes for granted. Outside the button on purpose:
    /// these are explanation rather than the figure, and the button's
    /// `children: .ignore` would otherwise swallow them.
    ///
    /// Both stay in the fold. The caption is the only thing that says what the
    /// 44pt number IS, and the ajudas line is a pay figure rather than detail:
    /// without it the net shown here understates what actually reaches the
    /// reader. The cost is honest and it is the least calm the fold gets, since
    /// at an accessibility size the Portuguese ajudas sentence runs to three or
    /// four lines right under the figures. A calm fold that understates
    /// somebody's pay would be the worse trade.
    @ViewBuilder
    private var heroFootnotes: some View {
        // A short note on what the 12x / 14x monthly view means. Nil for annual.
        if let cap = s.resultCaption(period.modeIndex) {
            Text(cap)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        // Net above is from the salary alone. Ajudas de custo show as their own
        // line, so it is always clear which net comes from gross and which comes
        // on top.
        if b.ajudasMonthly > 0 {
            let ajudasPart = isAnnual ? b.ajudasYearly : b.ajudasMonthly
            let pocket = b.netMonthly * factor + ajudasPart
            Text(s.heroAjudas(eur(ajudasPart), total: eur(pocket)))
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
    }

    /// The invitation down to everything that comes off the salary.
    ///
    /// INLINE, not pinned, and rule 24 is the reason rather than an oversight. A
    /// `safeAreaInset(edge: .bottom)` is the correct way to pin a control in a
    /// tab, but it reserves its height permanently, which would shrink the very
    /// viewport `fold` is sized to; and animating that inset away to hide the
    /// prompt IS the layout feedback loop. It would also sit on top of a
    /// floating glass tab bar already carrying five items. Scrolling away is
    /// itself the affordance: the prompt moving proves the screen moves.
    ///
    /// The arrow goes BELOW the text, not beside it, for two reasons. It points
    /// where it goes, and "Vê o que te descontam" is 331 points of the 335
    /// available at an accessibility size, so a chevron beside it would wrap.
    ///
    /// Hidden with opacity and never with `if`: removing it would shorten the
    /// content, which can move the scroll offset, which can flip the condition
    /// that hid it straight back.
    private func seeMorePrompt(_ proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.55)) {
                proxy.scrollTo(HomeScroll.detailAnchor, anchor: .top)
            }
        } label: {
            VStack(spacing: 4) {
                Text(s.homeSeeMore)
                    .appFont(13, weight: .medium)
                Image(systemName: "chevron.down")
                    .appFont(11, weight: .semibold)
            }
            .foregroundStyle(Theme.accent)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(s.homeSeeMoreHint)
        .opacity(hasScrolled ? 0 : 1)
        .animation(.easeOut(duration: 0.25), value: hasScrolled)
    }

    /// v1.2b: how complete the profile is, said on the screen people actually
    /// open, and above the detail rather than below it. Everything under
    /// "DETALHE" is arithmetic on the salary alone and needs no profile at all;
    /// everything the profile sharpens lives on other tabs. So this sits at the
    /// boundary, which is the last moment it is still the subject.
    @ViewBuilder
    private var profileNudge: some View {
        if store.profileFilledCount < store.signalTotal {
            ProfileNudgeCard { showProfile = true }
        }
    }

    // v1.4: `efficiencyCard` moved into `BreakdownBar`, comment and all. It
    // printed the same percentage the bar's net segment draws, forty points
    // above it, with a second sentence saying the same thing. See the note at
    // the top of BreakdownBar.swift for why that is a merge and not a move.

    /// v0.5 "in detail": two branching trees plus the red ajudas de custo highlight.
    /// Company side: total cost splits into gross salary and employer SS.
    /// Your side: total discounts split into IRS and employee SS, with effective rates.
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(s.theDetails) {
                SectionHint(s.perPeriod(yearly: isAnnual))
            }

            DetailTreeCard(
                title: s.treeCompanyTitle,
                total: eur(b.employerCostMonthly * factor),
                children: [
                    TreeChild(
                        id: "gross",
                        label: s.treeGross,
                        value: eur(b.grossMonthly * factor),
                        caption: s.ofCost(pct(b.employerCostMonthly > 0 ? b.grossMonthly / b.employerCostMonthly : 0))
                    ),
                    TreeChild(
                        id: "employerSS",
                        label: s.treeEmployerSS,
                        value: eur(b.employerSSMonthly * factor),
                        caption: s.ofCost(pct(b.employerCostMonthly > 0 ? b.employerSSMonthly / b.employerCostMonthly : 0))
                    ),
                ]
            )

            DetailTreeCard(
                title: s.treeDeductionsTitle,
                total: eur(b.deductionsMonthly * factor),
                totalCaption: s.ofGross(pct(b.deductionsRate)),
                children: [
                    TreeChild(
                        id: "irs",
                        label: s.cardIRS,
                        value: eur(b.irsMonthly * factor),
                        caption: s.ofGross(pct(b.irsRate))
                    ),
                    TreeChild(
                        id: "employeeSS",
                        label: s.cardYourSS,
                        value: eur(b.employeeSSMonthly * factor),
                        caption: s.ofGross(pct(b.employeeSSEffRate))
                    ),
                ]
            )

            if b.ajudasMonthly > 0 {
                AjudasCard(
                    value: eur(isAnnual ? b.ajudasYearly : b.ajudasMonthly),
                    yearlyLine: isAnnual ? nil : s.ajudasCardYearly(eur(b.ajudasYearly)),
                    body_: s.ajudasCardBody,
                    title: s.ajudasCardTitle
                )
            }
        }
    }

    private func pct(_ fraction: Double) -> String { percent(fraction) }

    /// v0.6: withholding vs the estimated real annual IRS. Month to month the
    /// employer withholds from the tables; the real tax settles the next year,
    /// so there is usually a small refund or amount left to pay. Always yearly.
    private var annualSettlementCard: some View {
        // No real IRS due for the year (salary below the taxable threshold).
        let noIRS = b.annualIRSSettled < 1
        let balance = b.annualBalance
        let evenish = abs(balance) < 20
        let refund = balance >= 0
        let accent = evenish ? Theme.textSecondary : (refund ? Theme.accent : Theme.danger)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(s.annualTitle) {
                SectionHint(s.perPeriod(yearly: true))
            }

            HStack(spacing: 10) {
                settlementFigure(label: s.annualWithheld, value: eur(b.annualIRSWithheld))
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 34)
                settlementFigure(label: s.annualSettled, value: eur(b.annualIRSSettled))
            }

            if noIRS {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.circle.fill")
                        .appFont(14)
                        .foregroundStyle(Theme.accent)
                    Text(s.annualNoIRS)
                        .appFont(13, weight: .medium)
                        .foregroundStyle(Theme.accent)
                }
                Text(b.annualIRSWithheld >= 1 ? s.annualNoIRSRefund(eur(b.annualIRSWithheld)) : s.annualNoIRSSub)
                    .appFont(11)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: evenish ? "equal.circle.fill" : (refund ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"))
                        .appFont(14)
                        .foregroundStyle(accent)
                    Text(evenish
                         ? s.annualEven
                         : (refund ? s.annualRefund(eur(abs(balance))) : s.annualToPay(eur(abs(balance)))))
                        .appFont(13, weight: .medium)
                        .foregroundStyle(accent)
                }

            }

            // v0.9.4: the assumptions are shown in BOTH branches. They used to sit
            // inside the else, so the moment real IRS came out at zero — which is
            // exactly when the €1,000 credit cannot be used — the app stopped
            // mentioning that it had assumed it at all.
            settlementAssumptions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    /// What the two numbers above take for granted, always spelled out.
    @ViewBuilder
    private var settlementAssumptions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(Theme.cardBorder).padding(.vertical, 2)

            if b.jovemExemption > 0 {
                assumptionLine(
                    icon: "sparkles",
                    text: s.annualJovemBoth(Int((b.jovemExemption * 100).rounded())),
                    tint: Theme.accent
                )
            }

            assumptionLine(icon: "receipt", text: creditText, tint: Theme.textFaint)
            // v0.15: which IRS tables produced these numbers. Stated in BOTH
            // branches, per the v0.9.4 rule: an islander needs to know their
            // figures are already regional, and a mainland-assumed user needs to
            // know the app guessed. Silence would look identical in both cases.
            if store.taxRegionAssumed {
                assumptionLine(icon: "mappin.slash", text: s.taxRegionAssumedNote,
                               tint: Theme.textFaint)
            } else if store.taxRegion != .continente {
                assumptionLine(icon: "map",
                               text: s.taxRegionNote(store.taxRegion.label(pt: s.pt)),
                               tint: Theme.accent)
            }
            assumptionLine(icon: "info.circle", text: s.annualNote, tint: Theme.textFaint)
        }
    }

    /// The €1,000 is capped at the IRS still owed, so it is often only partly used
    /// and, on a zero-IRS year, not used at all. Say which of the three it is.
    private var creditText: String {
        guard let d = b.settlement else { return s.annualNote }
        if d.generalCreditUnused { return s.annualCreditUnused(eur(d.generalCreditAssumed)) }
        if d.generalCreditFullyUsed { return s.annualCreditFull(eur(d.generalCreditAssumed)) }
        return s.annualCreditPartial(eur(d.generalCreditAssumed), eur(d.generalCreditApplied))
    }

    private func assumptionLine(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .appFont(9)
                .foregroundStyle(tint)
                .frame(width: Theme.scaled(12, typeSize))
                .accessibilityHidden(true)
            Text(text)
                .appFont(10)
                .foregroundStyle(tint == Theme.accent ? Theme.textSecondary : Theme.textFaint)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settlementFigure(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .appFont(18, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // v0.10.1: the national percentile card is gone from Home. It was a
    // one-line echo of a whole tab: compareSeed does this properly, with the
    // cohorts, the caveats and the distribution behind it. Two screens saying
    // the same thing meant one of them was always the worse version.

    /// v1.1: the payslip checker's entry point.
    ///
    /// Its own section rather than a card inside `nudges`, which is headed
    /// "what if" and holds hypotheticals. Checking a payslip is the opposite of
    /// a hypothetical: it is the one thing on this screen about something that
    /// already happened.
    ///
    /// Not accented. `explorerButton` is the one accent card on Home and two of
    /// them would fight for the same attention.
    private var nudges: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.whatIf)
            // v0.9.4: trying a number is the most common "what if" of all, so it
            // leads the section and is the only card that carries the accent.
            explorerButton
            // v0.10.1: no card pointing at Grow. The tab bar already points at
            // Grow, and it is tinted to say so, so a card doing the same job here
            // was a third thing on one screen asking to be tapped.
            NudgeCard(
                icon: "hourglass.circle.fill",
                title: s.ajudasNudgeTitle,
                subtitle: s.ajudasNudgeSub
            ) { showFutureSeed = true }
        }
    }

    private var explorerButton: some View {
        Button { showExplorer = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.below.square.filled.and.square")
                    .appFont(20)
                    .foregroundStyle(Theme.ink)
                    .frame(width: Theme.scaled(28, typeSize))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.explorerNudgeTitle)
                        .appFont(14, weight: .semibold)
                        .foregroundStyle(Theme.ink)
                    Text(s.explorerNudgeSub)
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

    private var disclaimer: some View {
        Text(s.homeDisclaimer(store.taxRegion))
            .appFont(10)
            .foregroundStyle(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}

// MARK: Components

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .appFont(11, weight: .medium)
            .kerning(0.5)
            .foregroundStyle(Theme.textFaint)
    }
}

/// A section label with a small hint opposite it: "DETALHE … por mês".
///
/// v1.0.3. At an accessibility text size the two halves stop fitting on one
/// line, and SwiftUI breaks the LABEL rather than the hint, mid-word, because an
/// uppercased single word is the thing it is willing to wrap: the distribution
/// header read "DISTRIBUIÇÃ / O NACIONAL". Past the threshold they become two
/// lines, label first, which is the order they are read in anyway.
struct SectionHeader<Hint: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    private let label: String
    private let hint: Hint

    init(_ label: String, @ViewBuilder hint: () -> Hint) {
        self.label = label
        self.hint = hint()
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(label)
                hint
            }
        } else {
            HStack {
                SectionLabel(label)
                Spacer()
                hint
            }
        }
    }
}

/// The house style for a section hint, so the four callers cannot drift apart.
struct SectionHint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .appFont(10)
            .foregroundStyle(Theme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct DetailCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .appFont(16, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct NudgeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .appFont(26)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appFont(14, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .appFont(12)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .appFont(12)
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
