import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// v0.16: switching the home-screen icon to match the chosen accent.
///
/// Three things about `setAlternateIconName` that are worth knowing before
/// reading this, because each one shaped the code:
///
/// 1. **iOS shows its own alert every time the icon changes**, and there is no
///    way to suppress it. That is why `apply` bails out when the icon is already
///    the right one: without the guard, re-selecting the colour you already have
///    would pop a system dialog for no change at all.
/// 2. **It needs the icons declared in the bundle.** This project declares them
///    in the asset catalogue instead of hand-writing `CFBundleAlternateIcons`:
///    `AppIcon-Blue`, `-Purple`, `-Pink` and `-Amber` are real `.appiconset`s,
///    and two build settings in the pbxproj do the rest —
///    `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` lists them and
///    `ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS` makes the compiler emit
///    the plist entries. That matters here because the target sets
///    `GENERATE_INFOPLIST_FILE = YES` and so has no Info.plist to edit, and
///    because the alternative, loose PNGs at the bundle root, means maintaining
///    every size by hand. The names below must match those settings exactly.
/// 3. **It can fail**, most often because the app is not frontmost. The failure
///    is deliberately swallowed: the in-app accent has already changed and is the
///    thing the user actually asked for, so an error alert about a home-screen
///    icon would be noise about the least important half.
enum AppIcon {

    static func apply(_ theme: AccentTheme) {
        #if canImport(UIKit)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let wanted = theme.alternateIconName
        // Already correct. Without this, iOS shows its alert on every tap.
        guard UIApplication.shared.alternateIconName != wanted else { return }
        UIApplication.shared.setAlternateIconName(wanted) { _ in
            // Swallowed on purpose. See the note above.
        }
        #endif
    }

    /// Put the icon back to green. Called when the entitlement goes away, so a
    /// refunded user is not left with a purple icon they can no longer change.
    static func reset() { apply(.default) }
}
