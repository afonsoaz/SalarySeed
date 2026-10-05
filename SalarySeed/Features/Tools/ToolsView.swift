import SwiftUI

/// The things to try that are not a screen of their own.
///
/// It holds what Home's "What if…" section held, apart from the job offer,
/// which has a row on Home now: trying another salary without changing yours,
/// and what being paid in ajudas de custo costs later. Both open as the sheets
/// they always were. This is also where the next tool goes, so a new one costs
/// a row here rather than a row on Home.
///
/// Rows are `SignalRow`, for the reason rule 29 gives: one row, fixed once.
struct ToolsView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var showExplorer = false
    @State private var showFutureSeed = false

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(s.toolsTitle)
                    .appFont(22, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                Button { showExplorer = true } label: {
                    SignalRow(icon: "slider.horizontal.below.square.filled.and.square",
                              iconTint: Theme.accent,
                              title: s.explorerNudgeTitle,
                              subtitle: s.explorerNudgeSub) { chevron }
                }
                Button { showFutureSeed = true } label: {
                    SignalRow(icon: "hourglass",
                              iconTint: Theme.accent,
                              title: s.ajudasNudgeTitle,
                              subtitle: s.ajudasNudgeSub) { chevron }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .sheet(isPresented: $showExplorer) { SalaryExplorerSheet() }
        .sheet(isPresented: $showFutureSeed) { FutureSeedView() }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .appFont(12)
            .foregroundStyle(Theme.textFaint)
            .accessibilityHidden(true)
    }
}
