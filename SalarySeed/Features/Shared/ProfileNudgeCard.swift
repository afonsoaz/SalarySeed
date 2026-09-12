import SwiftUI

/// "Your comparison is running on 3 of 10 answers. Here is where to fix that."
///
/// v1.2b. Profile holds ten signals and every cohort on Compare is only as
/// sharp as how many of them are filled, and until now nothing outside Profile
/// said so. The count existed in two places, both of them passive: a status card
/// inside Profile, which you only see once you are already there, and a small
/// "3 de 10" in Compare's header that led nowhere. This is the version that
/// leads somewhere.
///
/// IT DISAPPEARS AT 10/10 AND CANNOT BE DISMISSED, which is deliberate and is
/// not the same thing as a nag. It never interrupts, it never counts launches,
/// it has no countdown and no second ask; it is a row on a screen you chose to
/// open, and it ends the moment there is nothing left to ask.
///
/// `store.signalTotal` rather than 10. The status card in Profile hard-coded a
/// total once, the profile grew from five signals to ten underneath it, and it
/// spent several releases reading "11 de 5".
struct ProfileNudgeCard: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    let action: () -> Void

    private var s: Strings { store.s }

    var body: some View {
        Button(action: action) {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            sprout
                            title
                        }
                        count
                        reason
                    }
                } else {
                    HStack(spacing: 12) {
                        sprout
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                title
                                count
                            }
                            reason
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .appFont(12)
                            .foregroundStyle(Theme.accent.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                }
            }
            // Text in a Button label is centred by SwiftUI unless it is told
            // otherwise, and the reason line wraps on most phones.
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder, lineWidth: 1))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)
    }

    /// The same mark Profile puts at the top of its own progress card, at the
    /// stage the answers have actually reached. Here it is decoration with a
    /// meaning rather than a control, so VoiceOver skips it and reads the row.
    /// Size 44 and not 30. At three of ten, which is where a reader who has
    /// just finished onboarding actually is and therefore the state this card
    /// spends most of its life in, the drawing is a thin seedling: at 30 points
    /// it read as a smudge in an empty column rather than as the mark the whole
    /// card is about. Profile's own progress card draws it at 64 for the same
    /// reason.
    private var sprout: some View {
        SproutView(stage: store.sproutStage, size: 44)
            .frame(width: Theme.scaled(48, typeSize))
            .accessibilityHidden(true)
    }

    private var title: some View {
        Text(s.profileNudgeTitle)
            .appFont(14, weight: .medium)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var count: some View {
        Text(s.profileProgressCount(store.profileFilledCount, store.signalTotal))
            .appFont(12, weight: .medium)
            .foregroundStyle(Theme.accent)
            .contentTransition(.numericText())
    }

    private var reason: some View {
        Text(s.profileProgressSub)
            .appFont(11.5)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
