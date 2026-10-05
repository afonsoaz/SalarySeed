import SwiftUI

/// mapSeed: what your sector pays somewhere else.
///
/// v0.9.2 built the Portuguese half: GEP Quadro 110 (ganho médio by CAE ×
/// distrito) with Quadro 61 for the worker counts. See DistrictDataset for why
/// tenure is not in here, and why adding it would not change a single colour.
///
/// v0.11 adds the European half from Eurostat SES 2022. The two halves share a
/// screen, a sector and a colour ramp, and share NOTHING else: they are separate
/// surveys of separate populations in separate years, so no figure from one is
/// ever placed beside a figure from the other. What crosses is a ratio computed
/// inside Eurostat and applied to the user's own salary. See EuroComparison.
struct MapView: View {
    @EnvironmentObject private var store: SalaryStore

    @State private var scope: MapScope = .portugal
    @State private var showProfile = false

    private var s: Strings { store.s }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scopePicker
                    switch scope {
                    case .portugal: DistrictMapView()
                    case .europe: EuropeSection()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .profileDestination(isPresented: $showProfile)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("mapSeed")
                    .appFont(12)
                    .foregroundStyle(Theme.accent)
                Text(scope == .portugal ? s.mapTitle : s.euroTitle)
                    .appFont(22, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            ProfileButton { showProfile = true }
        }
        .padding(.top, 8)
    }

    /// Portugal or Europe. The sector picker sits below it because it applies to
    /// both, and moving it would make the two halves feel like two screens.
    private var scopePicker: some View {
        ScopeChips(options: MapScope.allCases, selection: $scope) { $0.label(s) }
    }
}
