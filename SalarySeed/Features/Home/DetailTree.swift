import SwiftUI

/// v0.5 "in detail" building blocks.
///
/// A DetailTreeCard shows one total that visually branches into its parts,
/// like a small tree: the company's total cost splits into gross salary and
/// employer Social Security; the user's total discounts split into IRS and
/// employee Social Security, each with its effective rate on gross.

struct TreeChild: Identifiable {
    let id: String
    let label: String
    let value: String
    let caption: String?

    init(id: String, label: String, value: String, caption: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.caption = caption
    }
}

struct DetailTreeCard: View {
    let title: String
    let total: String
    var totalCaption: String? = nil
    let children: [TreeChild]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(total)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let totalCaption {
                    Text(totalCaption)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .padding(.top, 2)

            VStack(spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    branchRow(child, isLast: index == children.count - 1)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func branchRow(_ child: TreeChild, isLast: Bool) -> some View {
        HStack(spacing: 10) {
            BranchGlyph(isLast: isLast)
                .stroke(Theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 16)
            Text(child.label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(child.value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let caption = child.caption {
                    Text(caption)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .frame(minHeight: 40)
        .padding(.leading, 6)
    }
}

/// The little elbow that makes the branching visible: a line coming down from
/// the total, turning towards the row. Continues downward when more branches follow.
private struct BranchGlyph: Shape {
    let isLast: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let x = rect.minX + 3
        let midY = rect.midY
        p.move(to: CGPoint(x: x, y: rect.minY))
        p.addLine(to: CGPoint(x: x, y: midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: midY))
        if !isLast {
            p.move(to: CGPoint(x: x, y: midY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        return p
    }
}

/// The red ajudas de custo card: the amount that goes straight to net, and the
/// honest reminder that it is invisible to banks, pension, and social protection.
struct AjudasCard: View {
    let value: String
    var yearlyLine: String? = nil
    let body_: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.danger)
            }
            Text(value)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.danger)
            if let yearlyLine {
                Text(yearlyLine)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.danger.opacity(0.8))
            }
            Text(body_)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.dangerSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.dangerBorder))
    }
}
