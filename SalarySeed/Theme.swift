import SwiftUI

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
