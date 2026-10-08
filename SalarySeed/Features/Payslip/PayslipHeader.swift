import SwiftUI

/// The title row over every payslip screen: the checker, onboarding's cover,
/// and "Update my salary", which has to look like the checker it hands over to.
///
/// Its own view because the chooser and the flow draw the same header, and a
/// header drawn twice gets fixed in one of the copies (rule 33).
///
/// v1.1a: the header sits above all five steps, so anything it does badly it
/// does five times. It used to be one row with a 20pt title and a fixed 34 by
/// 34 circle. At an accessibility size the title wrapped to three or four lines
/// beside an unmoved button, eating the vertical room every step below it
/// needs, and the `xmark` grew straight out of its own background because the
/// glyph scaled and the circle did not. The row becomes two rows past the
/// threshold, and the circle scales with the glyph inside it.
struct PayslipHeader<Trailing: View>: View {
    // Held because the eyebrow draws with Theme.accent, which is a computed
    // static SwiftUI cannot observe. See SalarySeedApp.
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The accent "payslipSeed" over the title, where the screen is a place.
    var eyebrow: String? = nil
    let title: String
    var titleSize: CGFloat = 22
    var topPadding: CGFloat = 8
    /// Asked separately rather than by testing `trailing`, because a
    /// `some View` is never nil: an empty `@ViewBuilder` branch is a real view
    /// that draws nothing, and the accessibility-size layout needs to know
    /// whether to give it a row of its own.
    var hasTrailing: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    if hasTrailing {
                        HStack {
                            Spacer()
                            trailing()
                        }
                    }
                    titleView
                }
            } else {
                // v1.2b: `.bottom`, and it used to be `.firstTextBaseline`.
                //
                // A baseline alignment asks SwiftUI for the first text baseline
                // of each child, and an `Image` has no text in it, so it offers
                // its bottom edge instead. While the trailing slot was empty
                // that cost nothing; the moment it held a 44 point button, the
                // title was dragged down to meet the bottom of it (rule 31).
                HStack(alignment: .bottom) {
                    titleView
                    Spacer(minLength: 12)
                    trailing()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, 10)
    }

    private var titleView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let eyebrow {
                Text(eyebrow)
                    .appFont(12)
                    .foregroundStyle(Theme.accent)
            }
            Text(title)
                .appFont(titleSize, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension PayslipHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, titleSize: CGFloat = 22,
         topPadding: CGFloat = 8) {
        self.init(eyebrow: eyebrow, title: title, titleSize: titleSize,
                  topPadding: topPadding, hasTrailing: false) { EmptyView() }
    }
}
