import SwiftUI

/// "Where the money goes": segmented share of total employer cost.
struct BreakdownBar: View {
    let breakdown: SalaryBreakdown
    @EnvironmentObject private var store: SalaryStore

    private var s: Strings { store.s }
    private var total: Double { max(breakdown.employerCostMonthly, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.whereMoneyGoes)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    segment(breakdown.netMonthly, Theme.segNet, geo.size.width)
                    segment(breakdown.irsMonthly, Theme.segIRS, geo.size.width)
                    segment(breakdown.employeeSSMonthly, Theme.segEmployeeSS, geo.size.width)
                    segment(breakdown.employerSSMonthly, Theme.segEmployerSS, geo.size.width)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .frame(height: 14)

            HStack(spacing: 12) {
                legend(s.legendNet, Theme.segNet)
                legend(s.legendIRS, Theme.segIRS)
                legend(s.legendYourSS, Theme.segEmployeeSS)
                legend(s.legendEmployerSS, Theme.segEmployerSS)
            }
            Text(s.shareOfCost)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textFaint)
        }
    }

    private func segment(_ value: Double, _ color: Color, _ width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(0, width * value / total))
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
        }
    }
}
