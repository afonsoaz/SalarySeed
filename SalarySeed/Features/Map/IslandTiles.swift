import SwiftUI

/// v0.15: Açores and Madeira, beside the mainland, with nothing in them.
///
/// WHY THEY ARE GREY, AND WHY THAT IS THE POINT. The Portugal map is a district
/// choropleth built on Quadro 110, and the islands are not districts: the Angra,
/// Horta, Ponta Delgada and Funchal districts were abolished in 1976, and the GEP
/// table has eighteen rows, all mainland. Nor is there a NUTS II fallback to
/// colour them from. Quadro 114 is headed "NUTS II DO CONTINENTE" and the whole
/// publication is scoped to Continente, so there is no Açores or Madeira figure
/// anywhere in the source this screen is drawn from.
///
/// The alternative sources do exist. INE measures the islands. But the app's
/// oldest rule is that survey levels are never mixed, and putting an INE mean in
/// a GEP choropleth would put two different populations, definitions and years in
/// the same colour ramp and let the user read the difference between them as
/// geography. So the tiles carry no colour.
///
/// Drawing them empty rather than leaving them out is the honest version of the
/// same fact. An absent island reads as an oversight; a dashed island beside a
/// coloured mainland reads as "nobody published this", which is what happened.
/// It is the same idiom the European grid already uses for the countries Eurostat
/// does not cover, so the app says "no data" one way rather than two.
struct IslandTiles: View {
    let s: Strings
    /// Highlighted when the user actually lives there, so an islander sees
    /// themselves on the map even though the tile has no figure.
    let home: PTRegion?

    var body: some View {
        VStack(spacing: 6) {
            tile(.acores)
            tile(.madeira)
        }
    }

    private func tile(_ region: PTRegion) -> some View {
        let isHome = home == region
        return VStack(alignment: .leading, spacing: 2) {
            Text(region.label)
                .font(.system(size: 10, weight: isHome ? .semibold : .medium))
                .foregroundStyle(isHome ? Theme.accent : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(s.mapIslandNoData)
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHome ? Theme.accentSoft : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHome ? Theme.accentBorder : Theme.textFaint.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1, dash: isHome ? [] : [3, 2]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(region.label), \(s.mapIslandNoData)")
    }
}
