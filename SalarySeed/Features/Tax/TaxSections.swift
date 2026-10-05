import SwiftUI

/// Everything that comes off the salary, in detail: the two trees and the
/// withheld-against-real settlement, with every assumption spelled out.
///
/// It was the half of Home below the fold. It is a view of its own so that one
/// drawing serves both Home, for as long as Home still shows it, and the Tax
/// screen, which is where it lives once Home becomes a list of ways in. Nothing
/// in it changed on the way out of HomeView: same breakdown, same period lens,
/// same rates.
struct TaxSections: View {
    @EnvironmentObject private var store: SalaryStore
    /// Read for the scaled glyph boxes in the assumption lines.
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The lens the figures are read through, which is the same one the net
    /// figure above them uses, so a period picked there carries over.
    let period: ResultPeriod

    private var s: Strings { store.s }
    private var b: SalaryBreakdown { store.breakdown }
    private var isAnnual: Bool { period.isAnnual }
    private var factor: Double { period.factor(months: b.months) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            detailsSection
            annualSettlementCard
        }
    }

    /// v0.5 "in detail": two branching trees plus the red ajudas de custo highlight.
    /// Company side: total cost splits into gross salary and employer SS.
    /// Your side: total discounts split into IRS and employee SS, with effective rates.
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(s.theDetails) {
                SectionHint(s.perPeriod(yearly: isAnnual))
            }

            DetailTreeCard(
                title: s.treeCompanyTitle,
                total: eur(b.employerCostMonthly * factor),
                children: [
                    TreeChild(
                        id: "gross",
                        label: s.treeGross,
                        value: eur(b.grossMonthly * factor),
                        caption: s.ofCost(pct(b.employerCostMonthly > 0 ? b.grossMonthly / b.employerCostMonthly : 0))
                    ),
                    TreeChild(
                        id: "employerSS",
                        label: s.treeEmployerSS,
                        value: eur(b.employerSSMonthly * factor),
                        caption: s.ofCost(pct(b.employerCostMonthly > 0 ? b.employerSSMonthly / b.employerCostMonthly : 0))
                    ),
                ]
            )

            DetailTreeCard(
                title: s.treeDeductionsTitle,
                total: eur(b.deductionsMonthly * factor),
                totalCaption: s.ofGross(pct(b.deductionsRate)),
                children: [
                    TreeChild(
                        id: "irs",
                        label: s.cardIRS,
                        value: eur(b.irsMonthly * factor),
                        caption: s.ofGross(pct(b.irsRate))
                    ),
                    TreeChild(
                        id: "employeeSS",
                        label: s.cardYourSS,
                        value: eur(b.employeeSSMonthly * factor),
                        caption: s.ofGross(pct(b.employeeSSEffRate))
                    ),
                ]
            )

            if b.ajudasMonthly > 0 {
                AjudasCard(
                    value: eur(b.allowance(in: period)),
                    yearlyLine: isAnnual ? nil : s.ajudasCardYearly(eur(b.ajudasYearly)),
                    body_: s.ajudasCardBody,
                    title: s.ajudasCardTitle
                )
            }
        }
    }

    private func pct(_ fraction: Double) -> String { percent(fraction) }

    /// v0.6: withholding vs the estimated real annual IRS. Month to month the
    /// employer withholds from the tables; the real tax settles the next year,
    /// so there is usually a small refund or amount left to pay. Always yearly.
    private var annualSettlementCard: some View {
        // No real IRS due for the year (salary below the taxable threshold).
        let noIRS = b.annualIRSSettled < 1
        let balance = b.annualBalance
        let evenish = abs(balance) < 20
        let refund = balance >= 0
        let accent = evenish ? Theme.textSecondary : (refund ? Theme.accent : Theme.danger)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(s.annualTitle) {
                SectionHint(s.perPeriod(yearly: true))
            }

            HStack(spacing: 10) {
                settlementFigure(label: s.annualWithheld, value: eur(b.annualIRSWithheld))
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 34)
                settlementFigure(label: s.annualSettled, value: eur(b.annualIRSSettled))
            }

            if noIRS {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.circle.fill")
                        .appFont(14)
                        .foregroundStyle(Theme.accent)
                    Text(s.annualNoIRS)
                        .appFont(13, weight: .medium)
                        .foregroundStyle(Theme.accent)
                }
                Text(b.annualIRSWithheld >= 1 ? s.annualNoIRSRefund(eur(b.annualIRSWithheld)) : s.annualNoIRSSub)
                    .appFont(11)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: evenish ? "equal.circle.fill" : (refund ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"))
                        .appFont(14)
                        .foregroundStyle(accent)
                    Text(evenish
                         ? s.annualEven
                         : (refund ? s.annualRefund(eur(abs(balance))) : s.annualToPay(eur(abs(balance)))))
                        .appFont(13, weight: .medium)
                        .foregroundStyle(accent)
                }

            }

            // v0.9.4: the assumptions are shown in BOTH branches. They used to sit
            // inside the else, so the moment real IRS came out at zero — which is
            // exactly when the €1,000 credit cannot be used — the app stopped
            // mentioning that it had assumed it at all.
            settlementAssumptions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    /// What the two numbers above take for granted, always spelled out.
    @ViewBuilder
    private var settlementAssumptions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(Theme.cardBorder).padding(.vertical, 2)

            if b.jovemExemption > 0 {
                assumptionLine(
                    icon: "sparkles",
                    text: s.annualJovemBoth(Int((b.jovemExemption * 100).rounded())),
                    tint: Theme.accent
                )
            }

            assumptionLine(icon: "receipt", text: creditText, tint: Theme.textFaint)
            // v0.15: which IRS tables produced these numbers. Stated in BOTH
            // branches, per the v0.9.4 rule: an islander needs to know their
            // figures are already regional, and a mainland-assumed user needs to
            // know the app guessed. Silence would look identical in both cases.
            if store.taxRegionAssumed {
                assumptionLine(icon: "mappin.slash", text: s.taxRegionAssumedNote,
                               tint: Theme.textFaint)
            } else if store.taxRegion != .continente {
                assumptionLine(icon: "map",
                               text: s.taxRegionNote(store.taxRegion.label(pt: s.pt)),
                               tint: Theme.accent)
            }
            assumptionLine(icon: "info.circle", text: s.annualNote, tint: Theme.textFaint)
        }
    }

    /// The €1,000 is capped at the IRS still owed, so it is often only partly used
    /// and, on a zero-IRS year, not used at all. Say which of the three it is.
    private var creditText: String {
        guard let d = b.settlement else { return s.annualNote }
        if d.generalCreditUnused { return s.annualCreditUnused(eur(d.generalCreditAssumed)) }
        if d.generalCreditFullyUsed { return s.annualCreditFull(eur(d.generalCreditAssumed)) }
        return s.annualCreditPartial(eur(d.generalCreditAssumed), eur(d.generalCreditApplied))
    }

    private func assumptionLine(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .appFont(9)
                .foregroundStyle(tint)
                .frame(width: Theme.scaled(12, typeSize))
                .accessibilityHidden(true)
            Text(text)
                .appFont(10)
                .foregroundStyle(tint == Theme.accent ? Theme.textSecondary : Theme.textFaint)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settlementFigure(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .appFont(18, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Which tables produced the figures on a screen, said under them.
///
/// The tax engine hardcodes 2026, and naming the year and the region it
/// computed with was the minimum bar for release, so every screen that shows a
/// computed tax figure carries this line: Home under its figure, and Tax under
/// the detail. One view, so the two cannot word it differently.
struct TaxDisclaimer: View {
    @EnvironmentObject private var store: SalaryStore

    var body: some View {
        Text(store.s.homeDisclaimer(store.taxRegion))
            .appFont(10)
            .foregroundStyle(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}
