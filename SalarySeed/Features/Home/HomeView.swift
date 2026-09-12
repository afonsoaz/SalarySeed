import SwiftUI

/// netSeed, the dashboard. Hero numbers, breakdown, annual settlement, "what if".
/// v0.2: greeting, living-sprout brand mark, count-up + leaf unfurl.
/// v0.3: all copy comes from the string table (EN + PT).
/// v0.10.1: the percentile teaser and the pointer to Grow both came off. Home
/// answers one question, what your salary means right now, and hands the other
/// questions to the tabs that own them instead of previewing them badly.
struct HomeView: View {
    @EnvironmentObject private var store: SalaryStore
    /// Drives the two-row top bar. See `topBar`.
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar
                    greeting
                    heroNumbers
                    updateSalaryButton
                    efficiencyCard
                    BreakdownBar(breakdown: b)
                    detailsSection
                    annualSettlementCard
                    nudges
                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
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
            .navigationDestination(isPresented: $showProfile) {
                // The only nav bar in the app, and it carries nothing but a
                // back chevron: `ProfileView` draws its own "profileSeed"
                // header, so a title here would say the same thing twice.
                ProfileView()
                    .navigationBarTitleDisplayMode(.inline)
            }
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

    /// v1.0.3: three things share this row, and at an accessibility text size
    /// they stop fitting. The 188pt picker is the immovable one, so the wordmark
    /// was the part that got squeezed: it wrapped to "Salar / ySee / d" while the
    /// three segments overlapped each other. Rather than shrink any of them, the
    /// row becomes two rows past the accessibility threshold, and the picker,
    /// which is the only thing here anybody taps repeatedly, gets a full width of
    /// its own. Below that threshold nothing changes at all.
    private var topBar: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    HStack {
                        brandMark
                        Spacer()
                        profileButton
                    }
                    periodPicker
                }
            } else {
                HStack {
                    brandMark
                    Spacer()
                    periodPicker.frame(width: 188)
                    profileButton
                }
            }
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
    /// `updateSalaryButton` two rows below in the same scroll view already
    /// does. One action, twice, on one screen, which is the thing "no echoes"
    /// forbids. So the row did not have to grow to take a fourth item; it had
    /// to lose a third.
    ///
    /// The glyph is a person and NOT the sprout, which is what it was first.
    ///
    /// The sprout was the tempting answer, because it already grows from stage
    /// 1 to 5 with the profile. Rendered, it was wrong twice over: `brandMark`
    /// is a sprout too, so the row had two of them eighteen points apart, and
    /// at stage 1, which is where somebody who has just finished onboarding
    /// actually is, the drawing is a hairline stalk that reads as a smudge
    /// rather than as a control. A button whose job is to be found cannot be
    /// drawn by a glyph that is nearly blank exactly when it is new.
    private var profileButton: some View {
        Button { showProfile = true } label: {
            Image(systemName: "person.crop.circle")
                .appFont(24)
                .foregroundStyle(Theme.textSecondary)
                // Apple's 44 point minimum, and no smaller than the glyph
                // itself once the reader has asked for bigger text.
                .frame(width: max(44, Theme.scaled(28, typeSize)),
                       height: max(44, Theme.scaled(28, typeSize)))
                .contentShape(Rectangle())
        }
        .accessibilityLabel(s.tabProfile)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(s.hey(store.displayName))
                .appFont(20, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            Text(s.greetSub)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var heroNumbers: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(s.grossWord) / \(s.periodSuffix(period.modeIndex))")
                        .appFont(12)
                        .foregroundStyle(Theme.textSecondary)
                    RollingEuro(value: b.grossMonthly * factor, color: Theme.textPrimary, fontSize: 30)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(s.netWord) / \(s.periodSuffix(period.modeIndex))")
                        .appFont(12)
                        .foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        RollingEuro(value: b.netMonthly * factor, color: Theme.accent, fontSize: 30)
                        UnfurlingLeaf(trigger: b.netMonthly * factor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // A short note on what the 12x / 14x monthly view means.
            if let cap = s.resultCaption(period.modeIndex) {
                Text(cap)
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
            }
            // Net above is from the salary alone. Ajudas de custo show as their own line,
            // so it is always clear which net comes from gross and which comes on top.
            if b.ajudasMonthly > 0 {
                let ajudasPart = isAnnual ? b.ajudasYearly : b.ajudasMonthly
                let pocket = b.netMonthly * factor + ajudasPart
                Text(s.heroAjudas(eur(ajudasPart), total: eur(pocket)))
                    .appFont(12)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 2)
    }

    private var updateSalaryButton: some View {
        Button { askingSalaryChange = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .appFont(13)
                Text(s.updateSalaryButton)
                    .appFont(14, weight: .medium)
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.accentBorder))
        }
    }

    /// v1.2: one figure and one sentence, where there were two lines and a
    /// division to do in your head.
    ///
    /// It used to read "Of every €100 your company spends," over "€63 reaches
    /// your pocket". `efficiency` is a ratio, so €100 was a device for turning
    /// it into something a reader could picture, and a percentage is what that
    /// device was standing in for.
    ///
    /// Whole percent, where the rates in the detail trees below carry one
    /// decimal. A headline is a number you glance at; the decimal belongs where
    /// somebody is comparing two rows, not where they are reading one figure.
    ///
    /// v1.2a: `pct` below is locale-correct now, so this no longer has to avoid
    /// it to avoid a POSIX decimal point. `percent(_:decimals:)` in `Theme` is
    /// the one path, and the 0 here is a design choice rather than a dodge.
    private var efficiencyCard: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 3) { efficiencyFigure; efficiencyLabel }
            } else {
                // `.center`, not `.firstTextBaseline`. The sentence beside the
                // figure runs to two lines on most phones, and a baseline
                // alignment pins the figure to the FIRST of them, so the second
                // hangs below it and the pair reads as misaligned. Centring is
                // what makes one number and one sentence look like one row.
                HStack(alignment: .center, spacing: 10) {
                    efficiencyFigure
                    efficiencyLabel
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    private var efficiencyFigure: some View {
        Text("\(Int((b.efficiency * 100).rounded()))%")
            .appFont(26, weight: .medium)
            .foregroundStyle(Theme.accent)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var efficiencyLabel: some View {
        Text(s.effPocket)
            .appFont(13)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

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
