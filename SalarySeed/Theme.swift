import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Resign the first responder so the keyboard drops. Called when the user taps
/// empty space in a screen that has a text field open.
func dismissKeyboard() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}

/// SalarySeed design tokens — matches the onboarding HTML mockup.
enum Theme {
    static let accent = Color(hex: 0x3DDC97)        // seed green
    static let background = Color(hex: 0x070B09)
    static let card = Color.white.opacity(0.05)
    static let cardBorder = Color.white.opacity(0.07)
    static let textPrimary = Color(hex: 0xEAF0EC)
    static let textSecondary = Color(hex: 0x7E938A)
    static let textFaint = Color(hex: 0x42554B)

    // Breakdown segment colors
    static let segNet = Color(hex: 0x3DDC97)
    static let segIRS = Color(hex: 0xE0795A)
    static let segEmployeeSS = Color(hex: 0xE6B450)
    static let segEmployerSS = Color(hex: 0x5E6F66)

    static let accentSoft = Color(hex: 0x3DDC97).opacity(0.08)
    static let accentBorder = Color(hex: 0x3DDC97).opacity(0.18)

    // v0.5: warning red for the ajudas de custo highlight
    static let danger = Color(hex: 0xE06A5E)
    static let dangerSoft = Color(hex: 0xE06A5E).opacity(0.08)
    static let dangerBorder = Color(hex: 0xE06A5E).opacity(0.22)

    /// v0.9.3: the fiscal rows share one height so a long picker value cannot
    /// make its row taller than its neighbours.
    static let fiscalRowHeight: CGFloat = 30

    /// v0.9.3: every chip grid in the app uses this, so a two-line label like
    /// "Comércio e reparação de veículos" and a one-line one like "Construção"
    /// occupy the same box and the grid stops looking ragged.
    static let chipHeight: CGFloat = 52

    // MARK: v0.9.2 mapSeed diverging ramp

    /// Seven steps: three red, a neutral midpoint, three green. Polarity, so a
    /// diverging ramp, which means two opposed hues and a NEUTRAL midpoint — a
    /// hue at the middle would stop it reading as "no difference".
    ///
    /// Built by holding the hue of `danger` and `accent` and giving both arms the
    /// SAME OKLCH lightness and chroma ladder (L 0.600 / 0.665 / 0.730,
    /// C 0.060 / 0.110 / 0.155). Interpolating straight to the brand colours was
    /// tried first and rejected: `accent` is much lighter than `danger`, so the
    /// green arm shouted about twice as loud as the red arm at equal magnitude,
    /// which would have made "20% more" look like a bigger deal than "20% less".
    ///
    /// All seven clear 3:1 against `background` (worst is the midpoint at 3.72:1),
    /// each arm's lightness rises monotonically away from the middle, and the
    /// midpoint's chroma is 0.025, low enough to read as grey.
    ///
    /// Red and green is the worst possible pair for colour blindness, so the
    /// percentage is written next to every district in the list and colour is
    /// never the only channel. Swapping the red arm for a blue one would make this
    /// CVD-safe and is a change to these three hex values and nothing else.
    static let mapBelowStrong = Color(hex: 0xFA7D70)
    static let mapBelowMid    = Color(hex: 0xCF786E)
    static let mapBelowSoft   = Color(hex: 0xA1736C)
    static let mapNeutral     = Color(hex: 0x5E6F66)
    static let mapAboveSoft   = Color(hex: 0x608C74)
    static let mapAboveMid    = Color(hex: 0x4EA87C)
    static let mapAboveStrong = Color(hex: 0x2BC585)

    /// The same seven steps with the colour drained out of them, for cells built
    /// on too few workers to trust. Blended 62% toward the midpoint rather than
    /// faded toward the background: fading on a near-black surface turns the fill
    /// almost black, which reads as "no data" instead of "uncertain data". These
    /// keep their brightness (worst contrast 3.72:1) and lose their chroma.
    static let mapBelowStrongThin = Color(hex: 0x9C786B)
    static let mapBelowMidThin    = Color(hex: 0x8B7469)
    static let mapBelowSoftThin   = Color(hex: 0x797168)
    static let mapAboveSoftThin   = Color(hex: 0x5F7A6B)
    static let mapAboveMidThin    = Color(hex: 0x5B846E)
    static let mapAboveStrongThin = Color(hex: 0x578F72)

    /// Bucket 0 is furthest below, 3 is neutral, 6 is furthest above.
    static func mapColor(bucket: Int, thin: Bool = false) -> Color {
        if thin { return mapColorThin(bucket: bucket) }
        return mapColorSolid(bucket: bucket)
    }

    private static func mapColorThin(bucket: Int) -> Color {
        switch max(0, min(6, bucket)) {
        case 0: return mapBelowStrongThin
        case 1: return mapBelowMidThin
        case 2: return mapBelowSoftThin
        case 3: return mapNeutral
        case 4: return mapAboveSoftThin
        case 5: return mapAboveMidThin
        default: return mapAboveStrongThin
        }
    }

    private static func mapColorSolid(bucket: Int) -> Color {
        switch max(0, min(6, bucket)) {
        case 0: return mapBelowStrong
        case 1: return mapBelowMid
        case 2: return mapBelowSoft
        case 3: return mapNeutral
        case 4: return mapAboveSoft
        case 5: return mapAboveMid
        default: return mapAboveStrong
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Euro formatting helper (pt_PT locale).
func eur(_ value: Double, decimals: Int = 0) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "EUR"
    f.locale = Locale(identifier: "pt_PT")
    f.maximumFractionDigits = decimals
    f.minimumFractionDigits = decimals
    return f.string(from: NSNumber(value: value)) ?? "€\(Int(value))"
}
