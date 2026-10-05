import SwiftUI

/// Two or three equal chips that switch what one screen is showing.
///
/// This was MapView's Portugal / Europe picker. It moved here when that switch
/// was about to go and a different one, on the Compare screen, was about to
/// need exactly the same control: one shape for "which view of this screen",
/// written once.
///
/// Not `SegmentedPicker`, deliberately. That control picks a VALUE the figures
/// are read through (×12, ×14, a year) and sits under the number it changes;
/// these pick which part of the screen you are looking at, and each chip is a
/// full-height button of its own.
struct ScopeChips<Option: Identifiable & Equatable>: View {
    // Held so the selected chip redraws when the accent colour changes.
    @EnvironmentObject private var store: SalaryStore

    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                let isOn = selection == option
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option }
                } label: {
                    Text(label(option))
                        .appFont(13, weight: isOn ? .medium : .regular)
                        .foregroundStyle(isOn ? Theme.ink : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isOn ? Theme.accent : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .stroke(isOn ? Theme.accent : Theme.cardBorder, lineWidth: 1))
                }
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
