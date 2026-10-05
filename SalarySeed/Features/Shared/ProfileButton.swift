import SwiftUI

/// The way into Profile: the person at the top right of Home.
///
/// v1.2 took Profile out of the tab bar and left one way back in, on Home.
/// v1.2b put the button in all five tab headers, because a screen that holds
/// every answer the comparisons run on should not be findable from only one of
/// the five places you might be standing. The hub took the tabs away, and with
/// them the reason: every screen is now one step from Home, and Home is where
/// the reader goes from, so the button is on Home alone again.
///
/// THE GLYPH IS A PERSON AND NOT THE SPROUT, and that is not an aesthetic call.
/// The sprout was tried first, because it already grows from stage 1 to 5 with
/// the profile and so already means this. On screen it was wrong twice: Home's
/// wordmark is a sprout too, so the row had two of them eighteen points apart,
/// and at stage 1, which is where somebody who has just finished onboarding
/// actually is, the drawing is a hairline stalk that reads as a smudge rather
/// than a control. A button whose whole job is to be found cannot be drawn by a
/// glyph that is nearly blank exactly when it is new.
///
/// It carries no count. Compare used to show "3 de 10" in this slot and that has
/// gone: the number lives in `ProfileNudgeCard` on Home, where there is room to
/// say what it means.
struct ProfileButton: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    /// What tapping it does. On Home that is `store.path = [.profile]`, a push
    /// onto the one navigation stack, so Profile can be popped by anything that
    /// sends the reader home.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "person.crop.circle")
                .appFont(24)
                .foregroundStyle(Theme.accent)
                // Apple's 44 point minimum, and no smaller than the glyph itself
                // once the reader has asked for bigger text.
                .frame(width: max(44, Theme.scaled(28, typeSize)),
                       height: max(44, Theme.scaled(28, typeSize)))
                .contentShape(Rectangle())
        }
        .accessibilityLabel(store.s.profileButtonVoice)
    }
}

// `profileDestination(isPresented:)` lived here while each tab pushed Profile
// onto a stack of its own. There is one stack now, and Profile is a `HubRoute`
// like every other screen; see `HubDestinations`.
