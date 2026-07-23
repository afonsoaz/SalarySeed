import SwiftUI

/// netSeed — the dashboard. Hero numbers, breakdown, percentile teaser, "what if" nudges.
/// v0.2: personalized greeting, living-sprout brand mark, count-up + leaf unfurl,
/// growthSeed teaser (locked ≠ hidden — v0.3 groundwork).
struct HomeView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var period: Period = .monthly
    @State private var showEditor = false
    @State private var showRaiseSeed = false
    @State private var showFutureSeed = false

    enum Period: String, CaseIterable, Identifiable {
        case monthly = "Monthly", yearly = "Yearly"
        var id: String { rawValue }
    }

    private var b: SalaryBreakdown { store.breakdown }
    private var isYearly: Bool { period == .yearly }
    private var factor: Double { isYearly ? b.months : 1 }
    private var suffix: String { isYearly ? "/ year" : "/ month" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar
                    greeting
                    heroNumbers
                    efficiencyCard
                    BreakdownBar(breakdown: b)
                    detailsGrid
                    percentileCard
                    nudges
                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(alignment: .top) {
                // faint "sunlight" glow — v0.2 personality pass
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
                // the brand mark is alive: it grows with the profile (sproutStage 1–5)
                SproutView(stage: store.sproutStage, size: 18)
                Text("SalarySeed").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.accent)
            Spacer()
            SegmentedPicker(options: Period.allCases, selection: $period) { $0.rawValue }
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
            Text(store.displayName.map { "Hey \($0)" } ?? "Hey there")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text("here's what your salary really means.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var heroNumbers: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Gross \(suffix)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                RollingEuro(value: b.grossMonthly * factor, color: Theme.textPrimary, fontSize: 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("Net \(suffix)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    RollingEuro(value: b.netMonthly * factor, color: Theme.accent, fontSize: 30)
                    UnfurlingLeaf(trigger: b.netMonthly * factor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 2)
    }

    private var efficiencyCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Of every €100 your company spends,")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(eur(b.efficiency * 100))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text("reaches your pocket")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    private var detailsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("The details")
                Spacer()
                Text(isYearly ? "per year" : "per month")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                DetailCard(label: "Costs your company", value: eur(b.employerCostMonthly * factor))
                DetailCard(label: "Employer pays on top", value: eur(b.employerSSMonthly * factor))
                DetailCard(label: "Social Security (you)", value: eur(b.employeeSSMonthly * factor))
                DetailCard(label: "IRS withheld", value: eur(b.irsMonthly * factor))
                DetailCard(label: "Your deductions", value: eur((b.irsMonthly + b.employeeSSMonthly) * factor))
                DetailCard(label: "Tax + SS rate", value: String(format: "%.0f%%", (1 - b.netMonthly / max(b.grossMonthly, 1)) * 100))
            }
        }
    }

    private var percentileCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Where you stand in Portugal")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Your gross beats")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(String(format: "%.0f%%", store.percentile))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text("of workers")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text("Fonte: INE · 2025 · placeholder data — sharpen it in compareSeed →")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var nudges: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("What if…")
            NudgeCard(
                icon: "arrow.up.right.circle.fill",
                title: "Simulate a raise",
                subtitle: "What would a €100 net raise cost your employer?"
            ) { showRaiseSeed = true }
            NudgeCard(
                icon: "hourglass.circle.fill",
                title: "Paid partly in ajudas de custo?",
                subtitle: "See what it's costing your pension."
            ) { showFutureSeed = true }
            growthTeaser
        }
    }

    /// growthSeed teaser — v0.3 groundwork only. Locked ≠ hidden: the IA already
    /// anticipates the advice feature, but there is no advice logic or content here.
    private var growthTeaser: some View {
        HStack(spacing: 12) {
            SproutView(stage: 2, size: 24)
                .saturation(0)
                .opacity(0.75)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your next step, suggested")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text("One simple career move — grown from what you plant here.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Text("growthSeed · coming soon")
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
        Text("Estimates for guidance only — not official tax advice. Rates unverified (skeleton build).")
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
