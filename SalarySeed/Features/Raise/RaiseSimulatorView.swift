import SwiftUI

/// raiseSeed — "a €X net raise costs your employer €Y".
struct RaiseSimulatorView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var netRaise: Double = 100

    private var current: SalaryBreakdown { store.breakdown }

    private var raised: SalaryBreakdown {
        let targetNet = current.netMonthly + netRaise
        let newGross = TaxEngine.grossFromNet(targetNet)
        return TaxEngine.breakdown(grossMonthly: newGross, months: current.months)
    }

    private var employerDeltaMonthly: Double {
        raised.employerCostMonthly - current.employerCostMonthly
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 6) {
                    Text("If you want")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("+\(eur(netRaise))")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        Text("net / month")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Slider(value: $netRaise, in: 25...1_000, step: 25)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("It really costs your employer")
                    DetailCard(label: "Extra per month", value: eur(employerDeltaMonthly))
                    DetailCard(label: "Extra per year (\(Int(current.months)) months)", value: eur(employerDeltaMonthly * current.months))
                    DetailCard(label: "Your new gross / month", value: eur(raised.grossMonthly))
                }

                infoCard
                Spacer()
                disclaimer
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("raiseSeed")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text("Simulate a raise")
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

    private var infoCard: some View {
        Text("Every €1 extra in your pocket costs your employer roughly €\(String(format: "%.2f", netRaise > 0 ? employerDeltaMonthly / netRaise : 0)) — taxes and Social Security scale up on the way.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    private var disclaimer: some View {
        Text("Estimate with placeholder rates — verify before relying on it.")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
