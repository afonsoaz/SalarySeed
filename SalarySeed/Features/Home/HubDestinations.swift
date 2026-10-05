import SwiftUI

extension View {
    /// Every screen Home pushes, declared once, on Home's one stack.
    ///
    /// One `navigationDestination(for:)` rather than a flag per screen, so the
    /// stack's whole state is `SalaryStore.path` and nothing can be on screen
    /// that `path = []` would not take away.
    ///
    /// `period` is Home's own, handed to the screens that read the salary
    /// through it, so Tax and Home cannot show the same pay in two lenses.
    func hubDestinations(period: Binding<ResultPeriod>) -> some View {
        navigationDestination(for: HubRoute.self) { route in
            HubDestination(route: route, period: period)
        }
    }
}

private struct HubDestination: View {
    let route: HubRoute
    @Binding var period: ResultPeriod

    var body: some View {
        destination
            // Set ONCE, here, for every screen Home pushes. Each draws its own
            // eyebrow and title in its content, so the bar carries nothing but
            // the back chevron; without this, a screen that was a tab root and
            // never needed it gets an empty large-title band under the chevron.
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var destination: some View {
        switch route {
        case .tax: TaxView(period: $period)
        case .comparePortugal: ComparePortugalView()
        case .compareEurope: EuropeView()
        case .offer: OfferView()
        case .tools: ToolsView()
        case .profile: ProfileView()
        }
    }
}
