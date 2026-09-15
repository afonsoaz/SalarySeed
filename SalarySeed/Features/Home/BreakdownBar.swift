import SwiftUI

/// "Where the money goes": the share of total employer cost that reaches the
/// pocket, said as a percentage, then drawn as four segments.
///
/// v1.4 MERGED THE PERCENTAGE CARD INTO THIS, and the argument is "no echoes"
/// rather than tidiness. Home carried an accent card printing `efficiency` as a
/// percent beside "reaches your pocket, out of what your company pays", forty
/// points above a bar whose `segNet` segment IS that percentage, captioned
/// "Share of total cost to your company". One number, one picture of the same
/// number, and two sentences saying the same thing. One of them had to go, and
/// what was left was a bar with no headline. Now it has one, and the caption it
/// no longer needs (`shareOfCost`) is deleted rather than left unreferenced.
///
/// The figure's own history, carried over from the card it came from:
///
/// v1.2 replaced two lines, "Of every €100 your company spends," above
/// "€63 reaches your pocket". `efficiency` is a ratio, so €100 was a device for
/// turning it into something a reader could picture, and a percentage is what
/// that device was standing in for.
///
/// Whole percent, where the rates in the detail trees below carry one decimal.
/// A headline is a number you glance at; the decimal belongs where somebody is
/// comparing two rows, not where they are reading one figure.
struct BreakdownBar: View {
    let breakdown: SalaryBreakdown
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    private var s: Strings { store.s }
    private var total: Double { max(breakdown.employerCostMonthly, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.whereMoneyGoes)

            efficiencyRow
                .padding(.bottom, 2)

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
        }
    }

    @ViewBuilder
    private var efficiencyRow: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) { efficiencyFigure; efficiencyLabel }
        } else {
            // `.center`, not `.firstTextBaseline`. The sentence beside the figure
            // runs to two lines on most phones, and a baseline alignment pins the
            // figure to the FIRST of them, so the second hangs below it and the
            // pair reads as misaligned. Centring is what makes one number and one
            // sentence look like one row.
            HStack(alignment: .center, spacing: 10) {
                efficiencyFigure
                efficiencyLabel
            }
        }
    }

    private var efficiencyFigure: some View {
        Text("\(Int((breakdown.efficiency * 100).rounded()))%")
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

    private func segment(_ value: Double, _ color: Color, _ width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(0, width * value / total))
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).appFont(10).foregroundStyle(Theme.textSecondary)
        }
    }
}
