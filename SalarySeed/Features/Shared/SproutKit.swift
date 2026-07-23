import SwiftUI

// v0.2 "living sprout" personality kit.
// One parametric sprout drawn in code (no assets), reused everywhere:
// welcome screen, Home brand mark, compareSeed header, picker sheets, profileSeed hero.
// Stage 0–5 = seed → small plant, driven by SalaryStore.sproutStage
// (salary plants the seed, each profile signal grows one stage).

// MARK: - SproutView

struct SproutView: View {
    let stage: Int
    var size: CGFloat = 24
    var animatesIn: Bool = false
    var sways: Bool = false

    @State private var appeared = false
    @State private var sway = false
    @State private var pulse = false

    private var clamped: Int { min(5, max(0, stage)) }
    private var stemHeight: CGFloat { [0, 24, 36, 48, 58, 66][clamped] }

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width / 120, canvasSize.height / 110)
            context.scaleBy(x: s, y: s)
            draw(in: &context)
        }
        .frame(width: size * (120.0 / 110.0), height: size)
        .scaleEffect(appeared ? 1 : 0.15, anchor: .bottom)
        .scaleEffect(pulse ? 1.12 : 1, anchor: .bottom)
        .opacity(appeared ? 1 : 0)
        .rotationEffect(.degrees(sways ? (sway ? 1.6 : -1.6) : 0), anchor: .bottom)
        .onAppear {
            if animatesIn {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.15)) { appeared = true }
            } else {
                appeared = true
            }
            if sways {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { sway = true }
            }
        }
        .onChange(of: stage) { _, _ in
            // little pop when the seed grows
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { pulse = false }
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext) {
        // soil
        let ground = Path(ellipseIn: CGRect(x: 36, y: 96.5, width: 48, height: 7))
        context.fill(ground, with: .color(Theme.segEmployerSS.opacity(0.45)))

        guard clamped > 0 else {
            // stage 0: just the seed, resting in the soil
            let seed = Path(ellipseIn: CGRect(x: 53.5, y: 85.5, width: 13, height: 17))
            context.fill(seed, with: .color(Theme.accent.opacity(0.22)))
            context.stroke(seed, with: .color(Theme.accent), lineWidth: 2)
            return
        }

        let top: CGFloat = 100 - stemHeight
        var stem = Path()
        stem.move(to: CGPoint(x: 60, y: 100))
        stem.addCurve(
            to: CGPoint(x: 60, y: top),
            control1: CGPoint(x: 58, y: 100 - stemHeight * 0.35),
            control2: CGPoint(x: 62, y: 100 - stemHeight * 0.7)
        )
        context.stroke(stem, with: .color(Theme.accent), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

        // leaf pairs: (fraction along stem, scale)
        var pairs: [(f: CGFloat, s: CGFloat)] = [(1.0, 0.55)]
        if clamped >= 2 { pairs.append((0.60, 0.78)) }
        if clamped >= 3 { pairs.append((0.36, 0.98)) }
        if clamped >= 4 { pairs.append((0.80, 0.88)) }
        let boost: CGFloat = clamped >= 4 ? 1.12 : 1

        for pair in pairs {
            let y = 100 - stemHeight * pair.f
            let scale = pair.s * boost
            let opacity = pair.f == 1 ? 0.95 : 0.65
            drawLeafPair(in: &context, at: CGPoint(x: 60, y: y), scale: scale, opacity: opacity)
        }

        if clamped >= 5 {
            // flourish: a small bud at the top
            let halo = Path(ellipseIn: CGRect(x: 52.5, y: top - 12.5, width: 15, height: 15))
            context.fill(halo, with: .color(Theme.accent.opacity(0.16)))
            let bud = Path(ellipseIn: CGRect(x: 56.8, y: top - 8.2, width: 6.4, height: 6.4))
            context.fill(bud, with: .color(Theme.accent))
        }
    }

    private func drawLeafPair(in context: inout GraphicsContext, at point: CGPoint, scale: CGFloat, opacity: Double) {
        let right = CGAffineTransform(translationX: point.x, y: point.y).scaledBy(x: scale, y: scale)
        let left = CGAffineTransform(translationX: point.x, y: point.y).scaledBy(x: -scale, y: scale)
        context.fill(Self.leafPath.applying(right), with: .color(Theme.accent.opacity(opacity)))
        context.fill(Self.leafPath.applying(left), with: .color(Theme.accent.opacity(opacity)))
    }

    /// One leaf, pointing up-and-out from the origin (design units).
    private static let leafPath: Path = {
        var p = Path()
        p.move(to: .zero)
        p.addCurve(to: CGPoint(x: 12, y: -19), control1: CGPoint(x: 7, y: -1), control2: CGPoint(x: 13, y: -8))
        p.addCurve(to: .zero, control1: CGPoint(x: 4, y: -16), control2: CGPoint(x: -1, y: -8))
        p.closeSubpath()
        return p
    }()
}

// MARK: - SeedDots (onboarding progress: completed steps sprout into tiny leaves)

struct SeedDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                if i < current {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 3.5,
                        bottomTrailingRadius: 3.5,
                        topTrailingRadius: 3.5
                    )
                    .fill(Theme.accent)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(-45))
                } else if i == current {
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: 1.5)
                        .frame(width: 7, height: 7)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.13))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

// MARK: - UnfurlingLeaf (unfurls next to the net hero on every count-up)

struct LeafGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        // design space 20 × 24
        let sx = rect.width / 20, sy = rect.height / 24
        var p = Path()
        p.move(to: CGPoint(x: 2 * sx, y: 22 * sy))
        p.addCurve(to: CGPoint(x: 18 * sx, y: 2 * sy),
                   control1: CGPoint(x: 3 * sx, y: 12 * sy),
                   control2: CGPoint(x: 8 * sx, y: 4 * sy))
        p.addCurve(to: CGPoint(x: 2 * sx, y: 22 * sy),
                   control1: CGPoint(x: 17 * sx, y: 12 * sy),
                   control2: CGPoint(x: 12 * sx, y: 20 * sy))
        p.closeSubpath()
        return p
    }
}

struct UnfurlingLeaf: View {
    /// Replay the unfurl whenever this value changes.
    var trigger: Double

    @State private var open = false

    var body: some View {
        LeafGlyph()
            .fill(Theme.accent)
            .frame(width: 13, height: 16)
            .scaleEffect(open ? 1 : 0.01, anchor: .bottomLeading)
            .rotationEffect(.degrees(open ? 0 : -50), anchor: .bottomLeading)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.4)) { open = true }
            }
            .onChange(of: trigger) { _, _ in
                open = false
                withAnimation(.spring(response: 0.7, dampingFraction: 0.55).delay(0.25)) { open = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - RollingEuro (count-up hero numbers)

struct RollingEuro: View {
    let value: Double
    var color: Color = Theme.textPrimary
    var fontSize: CGFloat = 30

    @State private var shown: Double = 0

    var body: some View {
        Text(eur(shown))
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(color)
            .contentTransition(.numericText(value: shown))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .onAppear {
                shown = 0
                withAnimation(.easeOut(duration: 0.8)) { shown = value }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: 0.8)) { shown = newValue }
            }
    }
}
