import SwiftUI

extension View {
    /// Every screen Home pushes, declared once, on Home's one stack.
    ///
    /// One `navigationDestination(for:)` rather than a flag per screen, so the
    /// stack's whole state is `SalaryStore.path` and nothing can be on screen
    /// that `path = []` would not take away.
    func hubDestinations() -> some View {
        navigationDestination(for: HubRoute.self) { route in
            HubDestination(route: route)
        }
    }
}

private struct HubDestination: View {
    let route: HubRoute

    var body: some View {
        switch route {
        case .profile:
            // The bar this creates carries nothing but a back chevron:
            // `ProfileView` draws its own "profileSeed" header, so a title here
            // would say the same thing twice.
            ProfileView()
                .navigationBarTitleDisplayMode(.inline)
        case .offer:
            OfferView()
        }
    }
}
