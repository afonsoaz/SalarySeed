import SwiftUI

/// A choice of LENS, drawn quietly: a few small labels in a faint track, the
/// chosen one in a soft capsule that slides across.
///
/// `SegmentedPicker` draws the selected option as a full-width bar of solid
/// accent, which is right for a question in onboarding and too loud for this:
/// on Home it competed with the salary it only re-reads. Afonso asked for its
/// primacy to come down, so this is the Stocks-app shape instead. It hugs its
/// content, and its parent decides where it sits.
///
/// It was `PeriodSwitch` alone until Compare in Portugal needed the same thing
/// for "vs the country / vs where I am", which was a pair of bright green
/// buttons louder than the map they re-read. One shape for a lens, written
/// once, so a fix to one cannot miss the other (rule 33).
///
/// Every option is a 44 point target, Apple's minimum, while the soft capsule
/// marking the chosen one is drawn smaller inside it.
struct QuietSwitch<Option: Hashable & Identifiable>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    @Namespace private var capsule

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(.horizontal, 3)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        // Past an accessibility size the labels no longer fit hugging their
        // text, so the switch takes the full width and shares it, and each
        // label may take a second line rather than be cut to "Mo ×…". Found by
        // looking at it at accessibility-extra-large. Reflow, do not shrink.
        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
    }

    private func segment(_ option: Option) -> some View {
        let isOn = selection == option
        return Button {
            if reduceMotion {
                selection = option
            } else {
                withAnimation(.snappy(duration: 0.25)) { selection = option }
            }
        } label: {
            Text(label(option))
                .appFont(13, weight: isOn ? .semibold : .regular)
                .foregroundStyle(isOn ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, typeSize.isAccessibilitySize ? 8 : 14)
                .padding(.vertical, 7)
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
                .background {
                    if isOn {
                        Capsule()
                            .fill(Color.white.opacity(0.13))
                            .matchedGeometryEffect(id: "selected", in: capsule)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The ×12 / ×14 / Year lens.
///
/// Home, Tax and the job offer all use it, because they read pay through one
/// lens (Tax's is bound to Home's, and the offer reads "now" the way Home
/// does), and one control for one lens cannot drift.
struct PeriodSwitch: View {
    // Read for the copy.
    @EnvironmentObject private var store: SalaryStore
    @Binding var selection: ResultPeriod

    var body: some View {
        QuietSwitch(options: ResultPeriod.allCases, selection: $selection) { $0.label(store.s) }
    }
}
