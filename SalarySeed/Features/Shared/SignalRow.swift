import SwiftUI

/// The row Other tools and the job offer use: a glyph, a title, a line under
/// it, and something trailing. Profile and Compare in Portugal used it too,
/// until phase two made each of them cards of `GlyphLine`s.
///
/// v1.2a: EIGHT COPIES OF THIS EXISTED, and all eight had the same three bugs,
/// which is the argument for the file rather than the tidiness.
///
/// 1. The icon sat in a `frame(width: 28)` while the glyph itself scaled with
///    Dynamic Type, so at the larger settings it grew out of its own box and
///    overdrew the title beside it. The same bug had already been found and
///    fixed twice, in `PayslipSourceStep` and in `SupportSheet`, and neither fix
///    could reach here because there was nothing shared to fix.
/// 2. The trailing "+ Add" pill had no line limit, so at an accessibility size
///    it broke mid-word into "+ Adicion / ar".
/// 3. The row never reflowed. With a scaled icon, a pill and a title all in one
///    `HStack`, the title column came out around 90 points wide and every word
///    wrapped: "Pessoas / da tua / idade".
///
/// Past `isAccessibilitySize` it becomes three stacked rows instead, which is
/// what every other row in this app does when it stops fitting. Below that
/// threshold the layout is what it always was, to the pixel: `Theme.scaled`
/// returns the design size unchanged at the default setting, so nobody who has
/// not opened Settings sees anything move.
struct SignalRow<Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let icon: String
    var iconTint: Color = Theme.textSecondary
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        iconView
                        titleView
                    }
                    subtitleView
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        trailing()
                    }
                }
            } else {
                HStack(spacing: 12) {
                    iconView
                    VStack(alignment: .leading, spacing: 2) {
                        titleView
                        subtitleView
                    }
                    Spacer(minLength: 8)
                    trailing()
                }
            }
        }
        // Text inside a Button label is centred by SwiftUI unless it is told
        // otherwise, and every one of these rows is the label of a Button.
        .multilineTextAlignment(.leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var iconView: some View {
        Image(systemName: icon)
            .appFont(18)
            .foregroundStyle(iconTint)
            .frame(width: Theme.scaled(28, typeSize))
            .accessibilityHidden(true)
    }

    private var titleView: some View {
        Text(title)
            .appFont(14, weight: .medium)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var subtitleView: some View {
        Text(subtitle)
            .appFont(11)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The pencil on a row that already has an answer.
struct EditGlyph: View {
    var body: some View {
        Image(systemName: "pencil")
            .appFont(14)
            .foregroundStyle(Theme.accent)
            .accessibilityHidden(true)
    }
}
