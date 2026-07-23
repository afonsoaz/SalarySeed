import SwiftUI

/// raiseSeed: "a €X net raise costs your employer €Y".
struct RaiseSimulatorView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var netRaise: Double = 100

    private var s: Strings { store.s }
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
                    Text(s.ifYouWant)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("+\(eur(netRaise))")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        Text(s.netPerMonth)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Slider(value: $netRaise, in: 25...1_000, step: 25)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(s.costsEmployer)
                    DetailCard(label: s.extraPerMonth, value: eur(employerDeltaMonthly))
                    DetailCard(label: s.extraPerYear(Int(current.months)), value: eur(employerDeltaMonthly * current.months))
                    DetailCard(label: s.newGross, value: eur(raised.grossMonthly))
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
                Text(s.raiseTitle)
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
        Text(s.raiseInfo(String(format: "%.2f", netRaise > 0 ? employerDeltaMonthly / netRaise : 0)))
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    private var disclaimer: some View {
        Text(s.raiseDisclaimer)
            .font(.system(size: 10))
            .foregroundStyle(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
