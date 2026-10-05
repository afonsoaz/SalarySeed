import SwiftUI

/// taxSeed: everything that comes off the salary, on a screen of its own.
///
/// This was the half of Home below the fold, behind a "See more". It is the same
/// content, drawn by the same views, now reached from its own row on Home:
/// where the money goes, the two detail trees, and the withheld-against-real
/// settlement with every assumption written out.
///
/// The period picker is BOUND to Home's, not a copy of it. Picking a year here
/// and going back shows a year on Home too, because both screens are reading
/// one salary through one lens and two lenses would let them disagree.
struct TaxView: View {
    @EnvironmentObject private var store: SalaryStore
    @Binding var period: ResultPeriod

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                SegmentedPicker(options: ResultPeriod.allCases, selection: $period) {
                    $0.label(s)
                }
                BreakdownBar(breakdown: store.breakdown)
                TaxSections(period: period)
                TaxDisclaimer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
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
}
