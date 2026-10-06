import SwiftUI

// v0.5 drew the detail as two branching trees, and this file held them
// (`DetailTreeCard`, `TreeChild`, `BranchGlyph`). Phase two folded both trees
// into `MoneyWaterfall`, so all that is left here is the ajudas card.

/// The red ajudas de custo card: the amount that goes straight to net, and the
/// honest reminder that it is invisible to banks, pension, and social protection.
struct AjudasCard: View {
    let value: String
    var yearlyLine: String? = nil
    let body_: String
    let title: String
    /// What it costs later: the label, and what tapping it does. Both or
    /// neither, so the card cannot draw a link that goes nowhere.
    var seeCostTitle: String? = nil
    var onSeeCost: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .appFont(11)
                    .foregroundStyle(Theme.danger)
                Text(title)
                    .appFont(11, weight: .medium)
                    .foregroundStyle(Theme.danger)
            }
            Text(value)
                .appFont(24, weight: .medium)
                .foregroundStyle(Theme.danger)
            if let yearlyLine {
                Text(yearlyLine)
                    .appFont(11)
                    .foregroundStyle(Theme.danger.opacity(0.8))
            }
            Text(body_)
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
            if let onSeeCost, let seeCostTitle {
                // Phase two: the way to what this costs later, from the one
                // place a reader with ajudas is shown them. It opens the same
                // sheet as Other tools, so the two can never tell it apart.
                Button(action: onSeeCost) {
                    HStack(spacing: 6) {
                        Text(seeCostTitle)
                            .appFont(13, weight: .semibold)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "chevron.right")
                            .appFont(11, weight: .semibold)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.danger)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.dangerSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.dangerBorder))
    }
}
