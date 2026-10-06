import SwiftUI

/// From what your company pays down to what reaches you, in the order the money
/// moves.
///
/// PHASE TWO FOLDED THE TWO DETAIL TREES INTO THIS. The trees and the bar above
/// them showed the same four amounts twice, once as shares of a bar and once as
/// two separate totals, and neither said the employer's rate: the company tree
/// gave its Social Security as "19,2% of cost", which is a share of something
/// rather than the 23,75% the law charges. Here every deduction is quoted as the
/// rate on gross it actually is, and each row carries the colour of its segment
/// in the bar, so the rows are the bar's legend and the legend is gone.
///
/// The Social Security rates are the statutory ones from `TaxEngine`, which is
/// what the engine multiplies gross by, so the rate beside each amount and the
/// amount itself can never disagree (verification rule 4). IRS has no single
/// rate; it is the effective withholding on gross, worked out from the same
/// two numbers it sits between.
struct MoneyWaterfall: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The lens the figures are read through, Home's own, bound through Tax.
    let period: ResultPeriod

    private var s: Strings { store.s }
    private var b: SalaryBreakdown { store.breakdown }
    private var factor: Double { period.factor(months: b.months) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(s.waterfallTitle) {
                SectionHint(s.perPeriod(yearly: period.isAnnual))
            }

            VStack(alignment: .leading, spacing: 0) {
                total(s.treeCompanyTitle, b.employerCostMonthly * factor)
                step(s.treeEmployerSS, Theme.segEmployerSS,
                     amount: b.employerSSMonthly * factor,
                     rate: percent(TaxEngine.employerSSRate, decimals: 2))
                rule
                total(s.treeGross, b.grossMonthly * factor)
                step(s.cardYourSS, Theme.segEmployeeSS,
                     amount: b.employeeSSMonthly * factor,
                     rate: percent(TaxEngine.employeeSSRate, decimals: 0))
                step(s.cardIRS, Theme.segIRS,
                     amount: b.irsMonthly * factor,
                     rate: percent(b.irsRate))
                rule
                total(s.waterfallNet, b.netMonthly * factor, swatch: Theme.segNet)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// A running total: what the company pays, the gross, and what is left.
    ///
    /// The last one carries the green of the bar's net segment, so the row the
    /// reader is looking for is the one that matches the 56% above it.
    private func total(_ label: String, _ amount: Double, swatch: Color? = nil) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Reflow, do not shrink: past the threshold the label and the
                // figure stop fitting side by side, so the figure goes under.
                VStack(alignment: .leading, spacing: 2) {
                    totalLabel(label, swatch: swatch)
                    totalAmount(amount)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    totalLabel(label, swatch: swatch)
                    Spacer(minLength: 8)
                    totalAmount(amount)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func totalLabel(_ label: String, swatch: Color?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let swatch { square(swatch) }
            Text(label)
                .appFont(14, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func totalAmount(_ amount: Double) -> some View {
        Text(eur(amount))
            .appFont(18, weight: .medium)
            .foregroundStyle(Theme.textPrimary)
    }

    /// Something taken off on the way down, with its colour and its rate.
    private func step(_ label: String, _ color: Color, amount: Double, rate: String) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    stepLabel(label, color, rate: rate)
                    stepAmount(amount)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    stepLabel(label, color, rate: rate)
                    Spacer(minLength: 8)
                    stepAmount(amount)
                }
            }
        }
        .padding(.leading, 14)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func stepLabel(_ label: String, _ color: Color, rate: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            square(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .appFont(12)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(s.ofGross(rate))
                    .appFont(10)
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }

    /// A true minus sign, not a hyphen: it is the width of a digit, so the
    /// amounts line up, and VoiceOver reads it as "minus".
    private func stepAmount(_ amount: Double) -> some View {
        Text("\u{2212}\u{2009}" + eur(amount))
            .appFont(14, weight: .medium)
            .foregroundStyle(Theme.textSecondary)
    }

    /// The colour of this row's segment in the bar above. A shape rather than
    /// a glyph, so it is sized on the label's curve and cannot outgrow it.
    private func square(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: Theme.scaled(9, typeSize), height: Theme.scaled(9, typeSize))
            .accessibilityHidden(true)
    }

    private var rule: some View {
        Divider().overlay(Theme.cardBorder).padding(.vertical, 2)
    }
}

/// v0.6: withholding vs the estimated real annual IRS. Month to month the
/// employer withholds from the tables; the real tax settles the next year, so
/// there is usually a small refund or amount left to pay. Always yearly.
///
/// Phase two moved the tax-table note out of here and into "What this assumes",
/// which states the household, IRS Jovem and the tables for the whole screen.
/// What stays below is what explains THESE two numbers: IRS Jovem being in both,
/// the €1,000 of deductions and how much of it is used, and what the estimate
/// rests on (verification rule 7: a note sits inside the branch it explains).
struct AnnualSettlementCard: View {
    @EnvironmentObject private var store: SalaryStore
    /// Read for the scaled glyph boxes in the assumption lines.
    @Environment(\.dynamicTypeSize) private var typeSize

    private var s: Strings { store.s }
    private var b: SalaryBreakdown { store.breakdown }

    var body: some View {
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
            // inside the else, so the moment real IRS came out at zero, which is
            // exactly when the €1,000 credit cannot be used, the app stopped
            // mentioning that it had assumed it at all.
            settlementAssumptions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    /// What the two numbers above take for granted, always spelled out.
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
            // Centred line by line, not just as a block: on two lines a
            // centred frame with leading text reads as a misaligned paragraph,
            // and Home is a centred screen now.
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}
