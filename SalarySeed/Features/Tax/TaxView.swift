import SwiftUI

/// taxSeed: everything that comes off the salary, and what it assumes.
///
/// The hub gave it its own screen, built from the half of Home that sat below
/// the fold. Phase two made it one story, top to bottom, in the order a reader
/// asks: how much of what my company pays reaches me (the bar), where the rest
/// goes on the way (the waterfall), what happens at the end of the year (the
/// settlement), and what all of that took for granted, editable right there
/// (the assumptions, which used to be in Profile and stated nowhere on here).
///
/// The period picker is BOUND to Home's, not a copy of it. Picking a year here
/// and going back shows a year on Home too, because both screens are reading
/// one salary through one lens and two lenses would let them disagree.
struct TaxView: View {
    @EnvironmentObject private var store: SalaryStore
    @Binding var period: ResultPeriod
    @State private var showHiddenCost = false

    private var s: Strings { store.s }
    private var b: SalaryBreakdown { store.breakdown }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                SegmentedPicker(options: ResultPeriod.allCases, selection: $period) {
                    $0.label(s)
                }
                BreakdownBar(breakdown: b)
                MoneyWaterfall(period: period)
                ajudas
                AnnualSettlementCard()
                TaxAssumptions()
                TaxDisclaimer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .sheet(isPresented: $showHiddenCost) { FutureSeedView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("taxSeed")
                .appFont(12)
                .foregroundStyle(Theme.accent)
            Text(s.taxTitle)
                .appFont(22, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    /// The red card, for a reader paid partly in ajudas de custo: what reaches
    /// them on top of the net, what it does not count towards, and the way to
    /// what that costs later, which is the app's whole reason for existing.
    @ViewBuilder
    private var ajudas: some View {
        if b.ajudasMonthly > 0 {
            AjudasCard(
                value: eur(b.allowance(in: period)),
                yearlyLine: period.isAnnual ? nil : s.ajudasCardYearly(eur(b.ajudasYearly)),
                body_: s.ajudasCardBody,
                title: s.ajudasCardTitle,
                seeCostTitle: s.ajudasSeeCost,
                onSeeCost: { showHiddenCost = true }
            )
        }
    }
}
