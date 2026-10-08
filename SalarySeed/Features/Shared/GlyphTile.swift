import SwiftUI

/// A glyph on a soft square of the accent colour, the way Settings and Health
/// mark a row: findable by shape before it is read.
///
/// Home's rows drew this first. Compare in Portugal's groups needed the same
/// mark, so it is one view before it is two copies (rule 33). The tile scales
/// on the reader's text curve, so it grows with the words beside it, and the
/// glyph is drawn as a share of the tile, the way Profile's swatch tick is.
/// It used to scale on its own, faster, curve: a 17pt glyph is body and a 38pt
/// tile is largeTitle, so at AX5 wide symbols such as "person.2" reached the
/// edge of their square. At the default size the two are the design sizes, so
/// nothing moved there.
struct GlyphTile: View {
    // Held so the tile and glyph redraw when the accent colour changes.
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    let glyph: String
    var side: CGFloat = 38
    var glyphSize: CGFloat = 17

    var body: some View {
        let scaledSide = Theme.scaled(side, typeSize)
        RoundedRectangle(cornerRadius: scaledSide * 0.27)
            .fill(Theme.accentSoft)
            .frame(width: scaledSide, height: scaledSide)
            .overlay {
                // A computed size, on the tile's own curve; not `.appFont`,
                // which would put the glyph back on its own curve.
                Image(systemName: glyph)
                    .font(.system(size: glyphSize * scaledSide / side, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHidden(true)
    }
}
