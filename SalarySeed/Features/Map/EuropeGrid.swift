import SwiftUI

/// v0.11: the 27 EU countries as equal tiles in roughly geographic positions.
///
/// WHY NOT A REAL MAP. A true projection of Europe on a phone gives France and
/// Sweden most of the ink and turns Malta, Luxembourg and Cyprus into specks that
/// cannot be tapped, which is exactly backwards: every country here carries the
/// same amount of information, one number, so every country should carry the same
/// amount of screen. A tile cartogram also needs no boundary data, no projection,
/// and no decision about overseas territories.
///
/// v0.11.2 REBUILT THE LAYOUT, and the reason matters. The first version placed
/// every tile with `.offset()` inside a `ZStack` wrapped in a `GeometryReader`.
/// It LOOKED right and was almost entirely untappable: a ZStack sizes itself to
/// its largest child, so the stack was one tile big, every tile was then pushed
/// outside those bounds, and SwiftUI does not deliver taps to a view rendered
/// outside its container's frame. Only the tile nearest the origin responded.
///
/// Rows of `HStack`s have no such trap. Every tile occupies real layout space, so
/// hit testing is correct by construction rather than by care, and the empty
/// positions are `Color.clear` of the same size. It is also less code.
struct EuropeGrid: View {
    // v0.16: held, not read. This view draws with `Theme.accent`, which is a
    // computed static, and SwiftUI cannot see a static change. Observing the
    // store is what makes the view redraw when a supporter picks a new colour.
    // Every other view that uses the accent already holds the store for its own
    // reasons; these few did not, and without this line they keep the old colour
    // until something unrelated happens to invalidate them. See SalarySeedApp.
    @EnvironmentObject private var accentObserver: SalaryStore
    let readings: [EuroReading]
    /// Only needed so the voice-over label is in the user's language. A tile
    /// shows a two-letter code, which is not something to read aloud.
    let pt: Bool
    @Binding var selected: Country?

    private var byCountry: [Country: EuroReading] {
        Dictionary(readings.map { ($0.country, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Row index to the countries in it, keyed by column so gaps stay gaps.
    private var layout: [[Country?]] {
        var grid = Array(repeating: Array(repeating: Country?.none, count: Country.gridColumns),
                         count: Country.gridRows)
        for country in Country.allCases {
            let tile = country.tile
            guard tile.row < Country.gridRows, tile.col < Country.gridColumns else { continue }
            grid[tile.row][tile.col] = country
        }
        return grid
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(layout.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, country in
                        cell(country)
                    }
                }
            }
        }
    }

    /// Every cell is `Color.clear` made square by `aspectRatio`, with the content
    /// laid over it. That is the deterministic idiom: `Color` is fully flexible,
    /// so the HStack hands each of the six an equal share of the width, and the
    /// aspect ratio then fixes the height to match. Putting `aspectRatio` on the
    /// shape itself and a flexible frame around it leaves the size ambiguous in
    /// a way that depends on which modifier runs first.
    @ViewBuilder
    private func cell(_ country: Country?) -> some View {
        if let country {
            squareCell { tile(country) }
        } else {
            // Holds the column open so the grid keeps its shape. Explicitly not
            // hit-testable, so a tap on empty sea does nothing rather than
            // landing on whichever neighbour happens to be nearest.
            squareCell { Color.clear }
                .allowsHitTesting(false)
        }
    }

    private func squareCell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(content())
    }

    private func tile(_ country: Country) -> some View {
        let reading = byCountry[country]
        let isSelected = selected == country
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selected = isSelected ? nil : country
            }
        } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(fill(reading))
                .overlay(border(country: country, selected: isSelected))
                .overlay(
                    Text(country.code)
                        .appFont(12, weight: country == .portugal ? .bold : .medium)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(label(reading))
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(country.label(pt: pt))
    }

    private func fill(_ reading: EuroReading?) -> Color {
        guard let bucket = reading?.bucket else { return Color.white.opacity(0.04) }
        return Theme.mapColor(bucket: bucket)
    }

    /// Portugal is outlined rather than coloured differently, because it is the
    /// reference and always sits in the neutral bucket by construction. A country
    /// with no cell gets a dashed outline, which has to look different from
    /// "close to Portugal" rather than merely fainter. The selected tile takes a
    /// heavier ring, which wins over both.
    @ViewBuilder
    private func border(country: Country, selected isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        if isSelected {
            shape.stroke(Theme.textPrimary, lineWidth: 2.5)
        } else if country == .portugal {
            shape.stroke(Theme.textPrimary, lineWidth: 1.5)
        } else if byCountry[country]?.hasData != true {
            shape.stroke(Theme.textFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        } else {
            shape.stroke(.clear, lineWidth: 0)
        }
    }

    private func label(_ reading: EuroReading?) -> Color {
        reading?.hasData == true ? Theme.ink : Theme.textFaint
    }
}

/// The ramp explained in words as well as colour, because red and green is the
/// worst possible pair for colour blindness and the grid must not depend on it.
/// The percentages are the reciprocal-pair edges from `EuroComparison`.
struct EuroLegend: View {
    let s: Strings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { bucket in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.mapColor(bucket: bucket))
                        .frame(height: 9)
                }
            }
            HStack {
                Text(s.euroLegendBelow)
                Spacer()
                Text(s.euroLegendSame)
                Spacer()
                Text(s.euroLegendAbove)
            }
            .appFont(9)
            .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Theme.textFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: 14, height: 10)
                Text(s.euroLegendNoData)
                    .appFont(9)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
