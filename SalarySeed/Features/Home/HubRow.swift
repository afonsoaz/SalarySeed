import SwiftUI

/// One of Home's ways in: a tinted glyph tile, a title, and a chevron.
///
/// It replaced `SignalRow` on Home when Afonso found the rows read like a
/// descriptive list of features. That component is a question-and-answer row,
/// a title over a sentence, built for Profile and Compare, and seven of them
/// stacked made Home a page of text. A way in needs a name, not a paragraph:
/// this is the Health app's Browse list, a glyph you can find by shape and a
/// word you can read at a glance, with room around both.
///
/// The sentence did not go away. It is the VoiceOver hint, so a reader who
/// cannot see the glyph still hears what the row opens, without seven lines of
/// it on screen for everybody else.
///
/// No figures, as before: a row that names no number cannot disagree with the
/// screen it opens.
struct HubRow: View {
    // Held so the accent tile and glyph redraw when the colour changes.
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    let glyph: String
    let title: String
    /// Read by VoiceOver after the title, never drawn.
    let hint: String
    /// Only ever true in a paid build. See `HubFeature.tier`.
    var locked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                tile
                Text(title)
                    .appFont(17, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(HubRowStyle())
        .accessibilityHint(hint)
    }

    /// The glyph on a soft square of its own colour, the way Settings and
    /// Health mark a row: findable by shape before it is read. Scaled on the
    /// title's curve, so it grows with the reader's text and never outgrows
    /// its own tile.
    private var tile: some View {
        let side = Theme.scaled(38, typeSize)
        return RoundedRectangle(cornerRadius: side * 0.27)
            .fill(Theme.accentSoft)
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: glyph)
                    .appFont(17, weight: .semibold)
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHidden(true)
    }

    /// A lock on a row the support payment covers, which says something and is
    /// read out; otherwise a chevron, which says nothing past an accessibility
    /// size, where the title may need the room.
    @ViewBuilder
    private var trailing: some View {
        if locked {
            Image(systemName: "lock.fill")
                .appFont(13)
                .foregroundStyle(Theme.textFaint)
                .accessibilityLabel(store.s.hubLockedVoice)
        } else if !typeSize.isAccessibilitySize {
            Image(systemName: "chevron.right")
                .appFont(13, weight: .semibold)
                .foregroundStyle(Theme.textFaint)
                .accessibilityHidden(true)
        }
    }
}

/// A press that dims the row a little, the way a list row answers a touch,
/// rather than the default flash across the whole label.
private struct HubRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
