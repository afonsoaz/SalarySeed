import SwiftUI

/// v1.1: what is wrong, what checks out, and what is worth knowing.
///
/// The three sections are shown in that order and the middle one is not
/// optional. "What checks out" is what makes the first section credible: a
/// screen that only ever lists problems is a screen that has to find one.
///
/// The not-checked line at the bottom is the same idea pointed the other way.
/// On both of the real payslips this was built against, four or five of the ten
/// checks do not run, because the tax engine models a month as gross times a
/// schedule and neither payslip is shaped like that. A check that quietly did
/// not happen reads as a check that passed, so each one says why.
struct PayslipResultsView: View {
    // Held because this view draws with Theme.accent, which is a computed
    // static SwiftUI cannot observe. See SalarySeedApp.
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    let verdict: PayslipVerdict
    let workings: PayslipCheckModel.Workings

    private var s: Strings { store.s }

    /// v1.1a: this screen had no way out of its own.
    ///
    /// The only exit was the small circular button in the flow's header, which
    /// is at the top of a screen the reader has just scrolled to the bottom of,
    /// and which was under the minimum tap target until this release. Every
    /// other terminal step in this flow ends in a full width button. This one
    /// is the end of the whole thing and ended in a disclaimer.
    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if verdict.wrong.isEmpty {
                    reassurance
                } else {
                    section(s.payslipWrongLabel, verdict.wrong, tint: Theme.danger)
                }
                if !verdict.mentions.isEmpty {
                    section(s.payslipMentionLabel, verdict.mentions, tint: Theme.segEmployeeSS)
                }
                if !verdict.correct.isEmpty {
                    section(s.payslipCorrectLabel, verdict.correct, tint: Theme.accent)
                }
                if !verdict.notChecked.isEmpty { notChecked }
                footer
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        PrimaryButton(title: s.closeButton) { dismiss() }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Sections

    private var reassurance: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .appFont(18)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(s.payslipNothingWrong)
                .appFont(14, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder, lineWidth: 1))
    }

    private func section(_ title: String, _ findings: [PayslipFinding], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            ForEach(findings) { finding in card(finding, tint: tint) }
        }
    }

    private func card(_ finding: PayslipFinding, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // The dot rides the FIRST line's baseline, not the middle of the
            // block. At an accessibility text size these titles wrap to two
            // lines and a centred dot floats between them, pointing at
            // nothing.
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Circle().fill(tint)
                    .frame(width: Theme.scaled(6, typeSize), height: Theme.scaled(6, typeSize))
                    // The offset has to follow the title it sits beside. A
                    // literal 5 was right for a 12pt title and drifted with it.
                    .alignmentGuide(.firstTextBaseline) { _ in Theme.scaled(5, typeSize) }
                Text(s.payslipCheckName(finding.id))
                    .appFont(12, weight: .semibold)
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(sentence(for: finding))
                .appFont(14)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.payslipCheckWhy(finding.id))
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
            if finding.confidence == .low {
                Text(s.payslipLowConfidence)
                    .appFont(11)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
        // The check name, the sentence, the why and the confidence note are one
        // finding. Read separately they are four swipes that only make sense in
        // order, and the tinted dot that groups them visually is invisible.
        .accessibilityElement(children: .combine)
    }

    /// Grouped by reason rather than listed one per check.
    ///
    /// Four of the ten checks share a single cause on a real payslip, and
    /// printed one per line the screen said the same sentence four times in a
    /// row. One reason, with the checks it cost, reads as an explanation
    /// instead of a list of failures.
    private var notChecked: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(s.payslipNotCheckedLabel)
            ForEach(groupedSkips, id: \.reason) { group in
                Text("\(group.names): \(s.payslipSkipReason(group.reason))")
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private struct SkipGroup { let reason: PayslipSkipReason; let names: String }

    private var groupedSkips: [SkipGroup] {
        var order: [PayslipSkipReason] = []
        var byReason: [PayslipSkipReason: [String]] = [:]
        for skipped in verdict.notChecked {
            if byReason[skipped.reason] == nil { order.append(skipped.reason) }
            byReason[skipped.reason, default: []].append(s.payslipCheckName(skipped.check))
        }
        return order.map { SkipGroup(reason: $0, names: (byReason[$0] ?? []).joined(separator: ", ")) }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(s.payslipAssumptions(store.taxRegion,
                                      months: String(Int(store.schedule.months))))
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.payslipDisclaimer)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: Turning a finding into a sentence

    private func money(_ cents: Int?) -> String {
        cents.map { PayslipNumber.format(cents: $0) } ?? ""
    }

    private func sentence(for finding: PayslipFinding) -> String {
        // `other` is whatever the sentence needs beside the headline figure:
        // the base a rate was charged on, the total a column should have hit,
        // or the region whose tables actually matched.
        var other = money(finding.baseCents)
        if case .region(let region) = finding.evidence { other = s.payslipRegionName(region) }
        if finding.id == .minWage { other = money(finding.expectedCents) }

        if finding.tier == .correct {
            return s.payslipCheckPassed(finding.id, value: money(finding.actualCents), other: other)
        }
        if finding.id == .earningsSum || finding.id == .deductionsSum || finding.id == .netIdentity
            || finding.id == .statedRate || finding.id == .irsWithholding
            || finding.id == .netMonthly || finding.id == .minWage {
            other = money(finding.expectedCents)
        }
        let gap = finding.id == .ssRate
            ? money(finding.expectedCents)
            : s.payslipOutBy(money(finding.deltaCents.map(abs)))
        return s.payslipCheckFailed(finding.id, value: money(finding.actualCents),
                                    other: other, gap: gap)
    }
}
