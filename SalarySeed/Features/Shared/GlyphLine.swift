import SwiftUI

/// One line of a list led by a glyph tile: the tile, the words, and whatever
/// trails them (a figure, "no figure"), with an optional chevron or plus.
///
/// Compare in Portugal's group lines and its quick question are this shape. In
/// the first build of that screen they were four pasted copies of one `HStack`
/// and only one of them reflowed at an accessibility size, which is rule 29's
/// eight copies arriving again; a review found it before anyone saw a word
/// break in two. Past an accessibility size the trailing part goes under the
/// words and the chevron or plus goes, so the words get the width.
struct GlyphLine<Words: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let glyph: String
    /// What a tap does, as a glyph at the right edge: a chevron, a plus.
    /// Dropped past an accessibility size, where the words need the room and
    /// the button already says it is one.
    var accessory: String? = nil
    var accessoryTint: Color = Theme.textFaint
    /// A chevron turned down, for a line that is open.
    var accessoryTurned = false
    /// For a line with no answer yet.
    var dimmedTile = false
    @ViewBuilder let words: () -> Words
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            GlyphTile(glyph: glyph, side: 32, glyphSize: 14)
                .opacity(dimmedTile ? 0.5 : 1)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    words()
                    trailing()
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            } else {
                words()
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                trailing()
                if let accessory {
                    Image(systemName: accessory)
                        .appFont(12, weight: .semibold)
                        .foregroundStyle(accessoryTint)
                        .rotationEffect(.degrees(accessoryTurned ? 90 : 0))
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

extension GlyphLine where Trailing == EmptyView {
    /// A line with nothing trailing its words but, perhaps, its accessory.
    init(glyph: String, accessory: String? = nil, accessoryTint: Color = Theme.textFaint,
         dimmedTile: Bool = false, @ViewBuilder words: @escaping () -> Words) {
        self.init(glyph: glyph, accessory: accessory, accessoryTint: accessoryTint,
                  dimmedTile: dimmedTile, words: words, trailing: { EmptyView() })
    }
}
