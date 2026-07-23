import SwiftUI

/// netSeed, the dashboard. Hero numbers, breakdown, percentile teaser, "what if" nudges.
/// v0.2: greeting, living-sprout brand mark, count-up + leaf unfurl, growthSeed teaser.
/// v0.3: all copy comes from the string table (EN + PT).
struct HomeView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var period: Period = .monthly
    @State private var showEditor = false
    @State private var showRaiseSeed = false
    @State private var showFutureSeed = false

    enum Period: String, CaseIterable, Identifiable {
        case monthly, yearly
        var id: String { rawValue }
    }

    private var s: Strings { store.s }
    private var b: SalaryBreakdown { store.breakdown }
    private var isYearly: Bool { period == .yearly }
    private var factor: Double { isYearly ? b.months : 1 }

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
                    percentileCard
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
            .sheet(isPresented: $showRaiseSeed) { RaiseSimulatorView() }
            .sheet(isPresented: $showFutureSeed) { FutureSeedView() }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                // the brand mark is alive: it grows with the profile (sproutStage 1 to 5)
                SproutView(stage: store.sproutStage, size: 18)
                Text("SalarySeed").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.accent)
            Spacer()
            SegmentedPicker(options: Period.allCases, selection: $period) {
                $0 == .monthly ? s.monthly : s.yearly
            }
            .frame(width: 170)
            Button { showEditor = true } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(s.hey(store.displayName))
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.greetSub)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var heroNumbers: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.grossLabel(yearly: isYearly))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    RollingEuro(value: b.grossMonthly * factor, color: Theme.textPrimary, fontSize: 30)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(s.netLabel(yearly: isYearly))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        RollingEuro(value: b.netMonthly * factor, color: Theme.accent, fontSize: 30)
                        UnfurlingLeaf(trigger: b.netMonthly * factor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Net above is from the salary alone. Ajudas de custo show as their own line,
            // so it is always clear which net comes from gross and which comes on top.
            if b.ajudasMonthly > 0 {
                Text(s.heroAjudas(
                    eur(isYearly ? b.ajudasYearly : b.ajudasMonthly),
                    total: eur(isYearly ? b.pocketYearly : b.pocketMonthly)
                ))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 2)
    }

    private var updateSalaryButton: some View {
        Button { showEditor = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                Text(s.updateSalaryButton)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.accentBorder))
        }
    }

    private var efficiencyCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(s.effLine1)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(eur(b.efficiency * 100))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text(s.effLine2)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    /// v0.5 "in detail": two branching trees plus the red ajudas de custo highlight.
    /// Company side: total cost splits into gross salary and employer SS.
    /// Your side: total discounts split into IRS and employee SS, with effective rates.
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(s.theDetails)
                Spacer()
                Text(s.perPeriod(yearly: isYearly))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
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
                    value: eur(isYearly ? b.ajudasYearly : b.ajudasMonthly),
                    yearlyLine: isYearly ? nil : s.ajudasCardYearly(eur(b.ajudasYearly)),
                    body_: s.ajudasCardBody,
                    title: s.ajudasCardTitle
                )
            }
        }
    }

    private func pct(_ fraction: Double) -> String {
        String(format: "%.1f%%", fraction * 100)
    }

    private var percentileCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(s.standTitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(s.earnMorePre)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(String(format: "%.0f%%", store.percentile))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text(s.earnMorePost)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(s.ineNote)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
            if b.ajudasMonthly > 0 {
                Text(s.ajudasExcludedNote)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.danger.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var nudges: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.whatIf)
            NudgeCard(
                icon: "arrow.up.right.circle.fill",
                title: s.raiseNudgeTitle,
                subtitle: s.raiseNudgeSub
            ) { showRaiseSeed = true }
            NudgeCard(
                icon: "hourglass.circle.fill",
                title: s.ajudasNudgeTitle,
                subtitle: s.ajudasNudgeSub
            ) { showFutureSeed = true }
            growthTeaser
        }
    }

    /// growthSeed teaser. Groundwork only: an entry point, no advice logic or content.
    private var growthTeaser: some View {
        HStack(spacing: 12) {
            SproutView(stage: 2, size: 24)
                .saturation(0)
                .opacity(0.75)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.growthTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(s.growthSub)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Text(s.growthSoon)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
        .opacity(0.9)
    }

    private var disclaimer: some View {
        Text(s.homeDisclaimer)
            .font(.system(size: 10))
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
            .font(.system(size: 11, weight: .medium))
            .kerning(0.5)
            .foregroundStyle(Theme.textFaint)
    }
}

struct DetailCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .medium))
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
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
