import Foundation

/// Every screen Home can open, as a value.
///
/// Home is the one way around the app, and everything it opens is a push onto
/// its single `NavigationStack`. The stack's path is `SalaryStore.path`, an
/// array of these, so any screen can send the reader back to Home with
/// `path = []` or onwards to another, with one source of truth for where they
/// are. A screen that pushed itself with a private `isPresented` flag could not
/// be popped by anybody else, which is how the old intro replay came to fade
/// onto Profile rather than onto Home.
///
/// Its own file, not `ProfileSignals.swift`, because `tools/offer_probe`
/// compiles three files in Models/ on their own and none of them may come to
/// depend on a screen.
enum HubRoute: Hashable {
    case tax
    case comparePortugal
    case compareEurope
    case offer
    case tools
    case profile
}
