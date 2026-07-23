import SwiftUI

/// futureSeed — the signature feature: the long-term cost of ajudas de custo /
/// off-the-books pay. SKELETON: rough illustrative model, to be replaced with a
/// proper pension-formula estimate.
struct FutureSeedView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var offBookMonthly: Double = 200

    private var b: SalaryBreakdown { store.breakdown }

    /// PLACEHOLDER pension model: pension ≈ 2% of declared gross per year of career.
    /// Real model must follow the Segurança Social pension formula.
    private var monthlyPensionLoss: Double { offBookMonthly * 0.02 * 40 }
    private var lostSSContributions: Double { offBookMonthly * (TaxEngine.employeeSSRate + TaxEngine.employerSSRate) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How much of your pay arrives as ajudas de custo or off the books?")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(eur(offBookMonthly))
                                .font(.system(size: 38, weight: .medium))
                                .foregroundStyle(Theme.segIRS)
                            Text("/ month")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Slider(value: $offBookMonthly, in: 0...1_500, step: 50)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Today's gain")
                        DetailCard(label: "Extra in pocket now (untaxed)", value: eur(offBookMonthly))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Tomorrow's loss (rough estimate)")
                        DetailCard(label: "Monthly SS contributions not made", value: eur(lostSSContributions))
                        DetailCard(label: "Est. monthly pension lost (40-yr career)", value: eur(monthlyPensionLoss))
                        DetailCard(label: "Also reduced", value: "Sick leave · unemployment · parental pay")
                    }

                    tradeOffCard
                    disclaimer
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("futureSeed")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text("The invisible trade-off")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 20)
    }

    private var tradeOffCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The trade-off, visible")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text("You gain \(eur(offBookMonthly))/month today — but your declared base shrinks, so your future pension and safety net shrink with it. This is the number nobody shows you.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    private var disclaimer: some View {
        Text("Very rough educational estimate — placeholder pension model, not advice. Real Segurança Social formula to be implemented.")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textFaint)
    }
}
