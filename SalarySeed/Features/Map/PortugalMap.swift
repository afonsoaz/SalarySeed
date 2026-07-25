import SwiftUI

/// v0.9.2: one district as a SwiftUI Shape.
///
/// Every district is scaled with the SAME fit maths against the same rect, so
/// they line up into one country rather than eighteen independently-fitted blobs.
struct DistrictShape: Shape {
    let rings: [[CGPoint]]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width / DistrictShapes.width, rect.height / DistrictShapes.height)
        let dx = (rect.width - DistrictShapes.width * scale) / 2
        let dy = (rect.height - DistrictShapes.height * scale) / 2
        for ring in rings {
            guard let first = ring.first else { continue }
            path.move(to: CGPoint(x: dx + first.x * scale, y: dy + first.y * scale))
            for point in ring.dropFirst() {
                path.addLine(to: CGPoint(x: dx + point.x * scale, y: dy + point.y * scale))
            }
            path.closeSubpath()
        }
        return path
    }
}

/// The choropleth itself. Tapping a district selects it; the caller decides what
/// to do with that.
///
/// Hit testing uses `.contentShape(shape)` rather than the default frame, because
/// the districts' bounding boxes overlap heavily (Portugal is diagonal) and frame
/// hit testing would hand most taps to the wrong district.
struct PortugalMap: View {
    let readings: [DistrictReading]
    let home: District?
    @Binding var selected: District?

    private var byDistrict: [District: DistrictReading] {
        Dictionary(readings.map { ($0.district, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(District.allCases) { district in
                    districtLayer(district, size: geo.size)
                }
            }
        }
        .aspectRatio(DistrictShapes.aspect, contentMode: .fit)
    }

    @ViewBuilder
    private func districtLayer(_ district: District, size: CGSize) -> some View {
        if let rings = DistrictShapes.outlines[district] {
            let shape = DistrictShape(rings: rings)
            let reading = byDistrict[district]
            let isHome = district == home
            let isSelected = district == selected

            shape
                .fill(fill(for: reading))
                .overlay(shape.stroke(stroke(isHome: isHome, isSelected: isSelected),
                                      lineWidth: isHome || isSelected ? 1.8 : 0.6))
                .contentShape(shape)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selected = isSelected ? nil : district
                    }
                }
                .accessibilityLabel(Text(district.label))
        }
    }

    /// A thin cell is drawn washed out. It still gets its colour, because hiding
    /// it would be its own kind of lie, but it should not look as solid as a
    /// district built on a hundred thousand people. The washed-out step is a real
    /// colour rather than reduced opacity: opacity on this near-black surface
    /// turns the fill almost black, which reads as a hole in the map.
    private func fill(for reading: DistrictReading?) -> Color {
        guard let reading else { return Theme.card }
        return Theme.mapColor(bucket: reading.bucket, thin: reading.thin)
    }

    private func stroke(isHome: Bool, isSelected: Bool) -> Color {
        if isSelected { return Theme.textPrimary }
        if isHome { return Theme.textPrimary.opacity(0.85) }
        return Theme.background
    }
}

/// The colour key. Shown beside the map, in the space Portugal's shape leaves
/// empty, and labelled with real numbers rather than "low" and "high".
struct MapLegend: View {
    let s: Strings

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            row(6, s.mapLegendTop)
            row(5, "+15%")
            row(4, "+5%")
            row(3, s.mapLegendSame)
            row(2, "-5%")
            row(1, "-15%")
            row(0, s.mapLegendBottom)
        }
    }

    private func row(_ bucket: Int, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.mapColor(bucket: bucket))
                .frame(width: 14, height: 10)
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
