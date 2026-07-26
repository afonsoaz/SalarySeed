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
/// Positions come from `Country.tile`. They are approximate on purpose: the grid
/// is a memory aid for finding a country, not a claim about geography.
struct EuropeGrid: View {
    let readings: [EuroReading]
    @Binding var selected: Country?

    private var byCountry: [Country: EuroReading] {
        Dictionary(readings.map { ($0.country, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        GeometryReader { geo in
            let cols = CGFloat(Country.gridColumns)
            let rows = CGFloat(Country.gridRows)
            let gap: CGFloat = 4
            let side = min((geo.size.width - gap * (cols - 1)) / cols,
                           (geo.size.height - gap * (rows - 1)) / rows)
            let originX = (geo.size.width - (side * cols + gap * (cols - 1))) / 2
            ZStack(alignment: .topLeading) {
                ForEach(Country.allCases) { country in
                    tile(country, side: side, gap: gap, originX: originX)
                }
            }
        }
        .aspectRatio(gridAspect, contentMode: .fit)
    }

    /// Width over height of the whole grid, so the caller can hand it any width
    /// and get a shape that fits its tiles exactly.
    private var gridAspect: CGFloat {
        CGFloat(Country.gridColumns) / CGFloat(Country.gridRows)
    }

    private func tile(_ country: Country, side: CGFloat, gap: CGFloat, originX: CGFloat) -> some View {
        let reading = byCountry[country]
        let pos = country.tile
        let isSelected = selected == country
        return RoundedRectangle(cornerRadius: 6)
            .fill(fill(reading))
            .overlay(border(country: country, selected: isSelected))
            .overlay(
                Text(country.code)
                    .font(.system(size: min(13, side * 0.32), weight: country == .portugal ? .bold : .medium))
                    .foregroundStyle(label(reading))
            )
            .frame(width: side, height: side)
            .offset(x: originX + CGFloat(pos.col) * (side + gap),
                    y: CGFloat(pos.row) * (side + gap))
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.15)) {
                    selected = isSelected ? nil : country
                }
            }
    }

    private func fill(_ reading: EuroReading?) -> Color {
        guard let bucket = reading?.bucket else { return Color.white.opacity(0.04) }
        return Theme.mapColor(bucket: bucket)
    }

    /// Portugal is outlined rather than coloured differently, because it is the
    /// reference and always sits in the neutral bucket by construction. A country
    /// with no cell gets a dashed outline, which has to look different from
    /// "close to Portugal" rather than merely fainter.
    @ViewBuilder
    private func border(country: Country, selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        if selected {
            shape.stroke(Theme.textPrimary, lineWidth: 2)
        } else if country == .portugal {
            shape.stroke(Theme.textPrimary, lineWidth: 1.5)
        } else if byCountry[country]?.hasData != true {
            shape.stroke(Theme.textFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        } else {
            shape.stroke(.clear, lineWidth: 0)
        }
    }

    private func label(_ reading: EuroReading?) -> Color {
        reading?.hasData == true ? Color(hex: 0x06281C) : Theme.textFaint
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
            .font(.system(size: 9))
            .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Theme.textFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: 14, height: 10)
                Text(s.euroLegendNoData)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
