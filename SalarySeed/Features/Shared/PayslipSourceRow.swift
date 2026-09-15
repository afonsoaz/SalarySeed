import SwiftUI

/// One way to hand over a payslip: a glyph, a title, and optionally a line
/// saying what it costs you.
///
/// v1.4 LIFTED THIS out of `PayslipSourceStep`, and rule 29 is the argument
/// rather than tidiness. Onboarding's new first choice and the checker's own
/// source screen draw the same rows, and the row already carries a fix a pasted
/// copy could not have received: see the scaled glyph box below. Two copies
/// would mean the next fix reaches one of them.
///
/// It is NOT shared by sharing the screen. `PayslipSourceStep.body` is itself a
/// `ScrollView`, and onboarding's steps are wrapped in one already, so reusing
/// the screen would nest two scroll views and hit rule 17: the inner one gets
/// unbounded height, stops scrolling, and grows until the buttons under it
/// leave the bottom of the screen.
struct PayslipSourceRow: View {
    let icon: String
    let title: String
    /// What this route is good for, or what it costs. One line, optional.
    var subtitle: String?
    /// The primary route, drawn in the accent. Exactly one row should be.
    var accented: Bool = false

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // v1.1a: the icon's box scales with the icon. A fixed 26 point width
            // held an 18 point symbol, and `appFont` takes that 18 to roughly
            // three times the size at the largest settings, so the glyph was
            // clipped by its own frame or shoved the title off the row. The two
            // numbers describe the same thing and now move together.
            Image(systemName: icon)
                .appFont(18)
                .foregroundStyle(accented ? Theme.ink : Theme.accent)
                .frame(width: Theme.scaled(26, typeSize))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(accented ? Theme.ink : Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .appFont(11.5)
                        .foregroundStyle(accented ? Theme.ink.opacity(0.75) : Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        // SwiftUI centres the text inside a Button label unless told otherwise,
        // and adding a subtitle is exactly what makes that visible: the second
        // line would sit centred under a left-aligned first one. Rule 27, and
        // what `audit_layout.py` looks for.
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accented ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(accented ? Color.clear : Theme.cardBorder, lineWidth: 1))
    }
}
