import SwiftUI

/// futureSeed, the signature feature: the long-term cost of ajudas de custo /
/// off-the-books pay. SKELETON: rough illustrative model, to be replaced with a
/// proper pension-formula estimate.
struct FutureSeedView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var offBookMonthly: Double = 200

    private var s: Strings { store.s }
    private var b: SalaryBreakdown { store.breakdown }

    /// PLACEHOLDER pension model: pension loss of about 2% of the undeclared part
    /// per year of career. The real model must follow the Segurança Social formula.
    private var monthlyPensionLoss: Double { offBookMonthly * 0.02 * 40 }
    private var lostSSContributions: Double { offBookMonthly * (TaxEngine.employeeSSRate + TaxEngine.employerSSRate) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.futureQuestion)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(eur(offBookMonthly))
                                .font(.system(size: 38, weight: .medium))
                                .foregroundStyle(Theme.segIRS)
                            Text(s.perMonthShort)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Slider(value: $offBookMonthly, in: 0...1_500, step: 50)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(s.todaysGain)
                        DetailCard(label: s.extraPocketNow, value: eur(offBookMonthly))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(s.tomorrowsLoss)
                        DetailCard(label: s.ssNotPaid, value: eur(lostSSContributions))
                        DetailCard(label: s.pensionLost, value: eur(monthlyPensionLoss))
                        DetailCard(label: s.alsoReduced, value: s.alsoReducedValue)
                    }

                    tradeOffCard
                    disclaimer
                }
                .padding(24)
            }
        }
        // v0.5: if the user already told us their ajudas de custo, start there.
        .onAppear {
            if store.ajudasMonthly > 0 { offBookMonthly = min(1_500, store.ajudasMonthly) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("futureSeed")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text(s.futureTitle)
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
            Text(s.tradeOffTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.tradeOffBody(eur(offBookMonthly)))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    private var disclaimer: some View {
        Text(s.futureDisclaimer)
            .font(.system(size: 10))
            .foregroundStyle(Theme.textFaint)
    }
}
