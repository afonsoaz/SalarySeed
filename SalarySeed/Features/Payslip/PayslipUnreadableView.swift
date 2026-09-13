import SwiftUI

/// v1.1: a screen, not an alert.
///
/// An alert saying "could not read this file" is a dead end with an OK button.
/// This says what was looked for, what was found, and the two things that
/// actually fix it, because the reader is holding the payslip and is the only
/// one who can do anything about it.
struct PayslipUnreadableView: View {
    // Held because this view draws with Theme.accent, which is a computed
    // static SwiftUI cannot observe. See SalarySeedApp.
    @EnvironmentObject private var store: SalaryStore
    let why: PayslipUnreadable
    let onRetry: () -> Void
    /// Set during onboarding, where Try again is not enough of a way out: the
    /// reader still owes the app a salary and cannot leave the step without one.
    /// A screen whose only action is to attempt the thing that just failed is
    /// the dead end this file exists to avoid.
    var onGiveUp: (() -> Void)?

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "doc.questionmark")
                            .appFont(18)
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityHidden(true)
                        Text(s.payslipUnreadableTitle)
                            .appFont(16, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(s.payslipUnreadable(why))
                        .appFont(14)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(s.payslipUnreadableHelp)
                        .appFont(12)
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        // See `PayslipResultsView` for why this is an inset and not a sibling.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                PrimaryButton(title: s.payslipTryAgain, action: onRetry)
                    .padding(.horizontal, 20)
                if let onGiveUp {
                    Button(action: onGiveUp) {
                        Text(s.onbTypeItMyself)
                            .appFont(14, weight: .semibold)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 12)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Theme.background)
        }
    }
}
