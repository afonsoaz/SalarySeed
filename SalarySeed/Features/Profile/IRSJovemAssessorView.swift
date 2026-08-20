import SwiftUI

/// v0.8: the IRS Jovem self-check. A few plain questions, then it tells the user
/// whether they qualify this year and for how much, and can set the exemption for
/// them. All logic lives in TaxEngine.assessJovem; this view only collects and shows.
struct IRSJovemAssessorView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var age = 28
    @State private var firstYear = 2021
    @State private var dependent: YesNo = .no
    @State private var otherRegime: YesNo = .no
    @State private var showResult = false
    @State private var applied = false

    private var s: Strings { store.s }

    private var assessment: TaxEngine.JovemAssessment {
        TaxEngine.assessJovem(
            age: age,
            firstIncomeYear: firstYear,
            isDependentThisYear: dependent == .yes,
            usedOtherRegime: otherRegime == .yes
        )
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    Text(s.jovemAssessIntro)
                        .appFont(13)
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(3)

                    ageCard
                    firstYearCard
                    yesNoCard(title: s.jovemDependentQ, selection: $dependent)
                    yesNoCard(title: s.jovemRegimeQ, selection: $otherRegime)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showResult = true
                            applied = false
                        }
                    } label: {
                        Text(s.jovemSeeResult)
                            .appFont(15, weight: .medium)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                    }

                    if showResult { resultCard }

                    Text(s.jovemDisclaimer)
                        .appFont(10)
                        .foregroundStyle(Theme.textFaint)
                        .lineSpacing(2)
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("IRS Jovem")
                    .appFont(12)
                    .foregroundStyle(Theme.accent)
                Text(s.jovemAssessTitle)
                    .appFont(22, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .appFont(24)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: Inputs

    private var ageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.jovemAgeQ)
                .appFont(14, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            stepperRow(value: $age, range: 16...70, unit: s.pt ? "anos" : "years")
            Text(s.jovemAgeHint)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var firstYearCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.jovemFirstYearQ)
                .appFont(14, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            stepperRow(value: $firstYear, range: 2000...TaxEngine.taxYear, unit: "")
            Text(s.jovemFirstYearHint)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func yesNoCard(title: String, selection: Binding<YesNo>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .appFont(14, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            SegmentedPicker(options: YesNo.allCases, selection: selection) {
                $0 == .yes ? s.yesWord : s.noWord
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stepperRow(value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            // verbatim: keep the year as "2021", not the locale-grouped "2 021".
            Text(verbatim: unit.isEmpty ? "\(value.wrappedValue)" : "\(value.wrappedValue) \(unit)")
                .appFont(20, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
            Spacer()
            HStack(spacing: 16) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        withAnimation(.easeOut(duration: 0.12)) { value.wrappedValue -= 1 }
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .appFont(24)
                        .foregroundStyle(value.wrappedValue > range.lowerBound ? Theme.accent : Theme.textFaint)
                }
                Button {
                    if value.wrappedValue < range.upperBound {
                        withAnimation(.easeOut(duration: 0.12)) { value.wrappedValue += 1 }
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .appFont(24)
                        .foregroundStyle(value.wrappedValue < range.upperBound ? Theme.accent : Theme.textFaint)
                }
            }
        }
    }

    // MARK: Result

    private var resultCard: some View {
        let a = assessment
        let months = max(store.schedule.months, 12)
        return VStack(alignment: .leading, spacing: 12) {
            if a.eligible {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(a.exemption * 100))%")
                        .appFont(40, weight: .medium)
                        .foregroundStyle(Theme.accent)
                    Text(s.jovemExemptThisYear)
                        .appFont(14)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let n = a.benefitYear {
                    Text(s.jovemBenefitYear(n))
                        .appFont(13)
                        .foregroundStyle(Theme.textPrimary)
                }
                Text(s.jovemCapLine(eur(a.annualCap), monthly: eur(a.annualCap / months)))
                    .appFont(12)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .appFont(20)
                        .foregroundStyle(Theme.danger)
                    Text(s.jovemNotEligible)
                        .appFont(16, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                }
                Text(reasonText(a.reason))
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            }

            Button {
                store.irsJovemExemption = a.exemption
                withAnimation(.easeOut(duration: 0.2)) { applied = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: applied ? "checkmark.circle.fill" : "arrow.down.circle")
                        .appFont(15)
                    Text(applied ? s.jovemApplied : s.jovemApply)
                        .appFont(14, weight: .medium)
                }
                .foregroundStyle(applied ? Theme.accent : Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    applied ? Theme.accentSoft : Theme.accent,
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(applied ? Theme.accentBorder : .clear))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accentBorder))
        .transition(.scale(scale: 0.97).combined(with: .opacity))
    }

    private func reasonText(_ reason: TaxEngine.JovemReason) -> String {
        switch reason {
        case .tooOld: return s.jovemReasonTooOld
        case .isDependent: return s.jovemReasonDependent
        case .otherRegime: return s.jovemReasonRegime
        case .exhausted: return s.jovemReasonExhausted
        case .notStarted: return s.jovemReasonNotStarted
        case .eligible: return ""
        }
    }
}

/// A plain yes/no answer for the assessor toggles.
enum YesNo: String, CaseIterable, Identifiable {
    case no, yes
    var id: String { rawValue }
}
