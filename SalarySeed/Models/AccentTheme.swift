import SwiftUI

/// v0.16: the five accents a supporter can choose.
///
/// EACH ONE CARRIES ITS INK, and that is the whole reason this is a type rather
/// than a list of hues. The app draws dark text on top of the accent in 52
/// places, and until now that ink was a single hardcoded near-black GREEN. It
/// looks right on green because it is green. On amber it reads as a stain, and
/// on a light enough accent a single fixed ink is a contrast failure waiting for
/// the one hue somebody picks. So every accent brings the near-black of its own
/// family, and `Theme.ink` is the only thing any view ever asks for.
///
/// White is deliberately absent. It was in the original list, and it cannot work:
/// the app is dark-themed, so a white accent needs light-on-light or a second
/// ink system, and neither is worth one swatch.
enum AccentTheme: String, CaseIterable, Identifiable, Codable {
    case green, blue, purple, pink, amber

    var id: String { rawValue }

    /// The default, and the identity colour. Everyone has this before they ever
    /// see the support sheet, and everyone keeps it if they never open it.
    static let `default`: AccentTheme = .green

    var accent: Color {
        switch self {
        case .green:  return Color(hex: 0x3DDC97)
        case .blue:   return Color(hex: 0x5AC8FA)
        case .purple: return Color(hex: 0xC08BFF)
        case .pink:   return Color(hex: 0xFF8FB1)
        case .amber:  return Color(hex: 0xFFC857)
        }
    }

    /// What gets drawn ON the accent: a near-black of the same family, so the
    /// pairing reads as one colour rather than as two.
    var ink: Color {
        switch self {
        // NOT `Theme.ink`. That reads `current.ink`, which is this, so the
        // literal has to live here or the two recurse until the stack ends.
        case .green:  return Color(hex: 0x06281C)
        case .blue:   return Color(hex: 0x04222E)
        case .purple: return Color(hex: 0x1B0B2E)
        case .pink:   return Color(hex: 0x2E0B18)
        case .amber:  return Color(hex: 0x2E1F04)
        }
    }

    func label(pt: Bool) -> String {
        switch self {
        case .green:  return pt ? "Verde" : "Green"
        case .blue:   return pt ? "Azul" : "Blue"
        case .purple: return pt ? "Roxo" : "Purple"
        case .pink:   return pt ? "Rosa" : "Pink"
        case .amber:  return pt ? "Âmbar" : "Amber"
        }
    }

    /// The alternate app icon this accent maps to. nil for the default, which is
    /// what `setAlternateIconName(nil)` wants in order to go back to the primary.
    var alternateIconName: String? {
        self == .green ? nil : "AppIcon-\(rawValue.capitalized)"
    }
}
