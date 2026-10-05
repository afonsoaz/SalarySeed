import SwiftUI

// The section furniture every screen uses: the uppercased label, the label with a
// hint opposite it, the hint itself, and the small label-over-value card.
//
// These lived at the bottom of `HomeView.swift` because Home is where they were
// first written, and thirteen files use them now. Home is about to become a list
// of ways into the app with no sections of its own, so they live here rather
// than in the one file that no longer needs them.

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .appFont(11, weight: .medium)
            .kerning(0.5)
            .foregroundStyle(Theme.textFaint)
    }
}

/// A section label with a small hint opposite it: "DETALHE … por mês".
///
/// v1.0.3. At an accessibility text size the two halves stop fitting on one
/// line, and SwiftUI breaks the LABEL rather than the hint, mid-word, because an
/// uppercased single word is the thing it is willing to wrap: the distribution
/// header read "DISTRIBUIÇÃ / O NACIONAL". Past the threshold they become two
/// lines, label first, which is the order they are read in anyway.
struct SectionHeader<Hint: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    private let label: String
    private let hint: Hint

    init(_ label: String, @ViewBuilder hint: () -> Hint) {
        self.label = label
        self.hint = hint()
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(label)
                hint
            }
        } else {
            HStack {
                SectionLabel(label)
                Spacer()
                hint
            }
        }
    }
}

/// The house style for a section hint, so the four callers cannot drift apart.
struct SectionHint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .appFont(10)
            .foregroundStyle(Theme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct DetailCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .appFont(16, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
