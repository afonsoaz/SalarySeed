import SwiftUI

/// A glyph on a soft square of the accent colour, the way Settings and Health
/// mark a row: findable by shape before it is read.
///
/// Home's rows drew this first. Compare in Portugal's groups needed the same
/// mark, so it is one view before it is two copies (rule 33). Scaled on the
/// reader's text curve, so it grows with the words beside it and the glyph
/// never outgrows its own tile.
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
                Image(systemName: glyph)
                    .appFont(glyphSize, weight: .semibold)
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityHidden(true)
    }
}
