import SwiftUI

/// v0.16 note on HOW THE ACCENT PROPAGATES, because the obvious answer is wrong.
///
/// `Theme.accent` and `Theme.ink` are computed statics reading `Theme.current`.
/// That keeps 52 call sites unchanged, and it costs one thing: SwiftUI cannot
/// observe a static, so changing the accent invalidates nothing by itself.
///
/// The first version of this fixed it with `.id(store.accent)` on the root, which
/// does work and is a trap. Changing the identity of the root tears down the whole
/// tree and resets every `@State` in it: Grow's in-memory scenario, every scroll
/// position, and, fatally, the sheet the user is standing in while tapping the
/// colour swatches. The one place the accent changes most often is the one place
/// that approach breaks.
///
/// So there is no `.id` here. Views redraw because they observe `SalaryStore`,
/// which nearly all of them already did. The eight that draw with the accent and
/// had no reason to hold the store now hold it anyway, with a comment saying why.
@main
struct SalarySeedApp: App {
    @StateObject private var store = SalaryStore()
    @StateObject private var supporter = SupporterStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.hasOnboarded {
                    RootTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(store)
            .environmentObject(supporter)
            .preferredColorScheme(.dark)
            // Read on every store change, so the system tint follows the accent.
            .tint(store.accent.accent)
            // v1.3: THIS NOW TOUCHES NOTHING. `AppConfig.monetisation` is
            // `.free`, so `start` returns before the first StoreKit call and the
            // app has no code path to the network at all, rather than one that
            // talks only to Apple. In a paid build this is the product price, the
            // purchase and the entitlement, and it was still the only one: nothing
            // about a salary is transmitted anywhere, by any code path, either way.
            .task { supporter.start(applyingTo: store) }
        }
    }
}
