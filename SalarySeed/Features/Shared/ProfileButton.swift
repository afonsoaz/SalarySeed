import SwiftUI

/// The way into Profile, in the same corner of every tab.
///
/// v1.2 took Profile out of the tab bar and left exactly one way back in: a grey
/// glyph on Home. v1.2b makes it accent green and puts it in all five headers,
/// because a screen that holds every answer the comparison runs on should not be
/// findable from only one of the five places you might be standing.
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
/// gone: the number now lives in `ProfileNudgeCard` on Home, where there is room
/// to say what it means, and Home's own top row has already given 188 points to
/// the period picker.
struct ProfileButton: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    @Binding var isPresented: Bool

    var body: some View {
        Button { isPresented = true } label: {
            Image(systemName: "person.crop.circle")
                .appFont(24)
                .foregroundStyle(Theme.accent)
                // Apple's 44 point minimum, and no smaller than the glyph itself
                // once the reader has asked for bigger text.
                .frame(width: max(44, Theme.scaled(28, typeSize)),
                       height: max(44, Theme.scaled(28, typeSize)))
                .contentShape(Rectangle())
        }
        .accessibilityLabel(store.s.tabProfile)
    }
}

extension View {
    /// Pushes Profile onto the tab's own navigation stack.
    ///
    /// A push and not a sheet, for the reason v1.2 gave when Profile stopped
    /// being a tab: it is a destination with ten sheets of its own hanging off
    /// it, and a sheet on a sheet is a stack of cards. Written once here rather
    /// than five times, so the five tabs cannot drift into presenting it five
    /// slightly different ways.
    ///
    /// The nav bar this creates is the only one in the app and carries nothing
    /// but a back chevron: `ProfileView` draws its own "profileSeed" header, so
    /// a title here would say the same thing twice.
    func profileDestination(isPresented: Binding<Bool>) -> some View {
        navigationDestination(isPresented: isPresented) {
            ProfileView()
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
