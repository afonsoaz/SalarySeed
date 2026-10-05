import SwiftUI

/// Compare in Portugal: where you stand against other people, and what your
/// sector pays district by district.
///
/// Two views of one question, how your pay sits in this country, switched by
/// the chips Map used for Portugal and Europe. They were two tabs, Compare and
/// the Portuguese half of Map. The European half went to a screen of its own,
/// because it is a different survey of a different population in a different
/// year, and the two halves never shared a figure.
///
/// Both views are drawn by exactly the views the tabs drew, so nothing in
/// either changed on the way here.
struct ComparePortugalView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var scope: Scope = .people

    enum Scope: String, CaseIterable, Identifiable {
        case people, districts
        var id: String { rawValue }
    }

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                ScopeChips(options: Scope.allCases, selection: $scope) {
                    $0 == .people ? s.compareScopePeople : s.compareScopeDistricts
                }
                switch scope {
                case .people: CompareSections()
                case .districts: DistrictMapView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("compareSeed")
                .appFont(12)
                .foregroundStyle(Theme.accent)
            Text(scope == .people ? s.compareTitle : s.mapTitle)
                .appFont(22, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}
