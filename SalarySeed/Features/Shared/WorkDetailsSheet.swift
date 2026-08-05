import SwiftUI

/// v0.9: employer kind and working time, edited together.
/// v0.9.3: the career-total question is gone (see below).
///
/// These three belong on one screen because they are one thought ("what kind of
/// job is this"), and because employer kind changes what the app is allowed to
/// claim: a "função pública" answer means the GEP comparison does not describe
/// this user and every cohort card has to say so.
///
/// The sections are separate computed views on purpose. A ViewBuilder takes at
/// most ten children and this screen has more parts than that.
struct WorkDetailsSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var employer: EmployerKind?
    @State private var schedule: WorkSchedule?
    @State private var hours: Int = 40

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 34, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)

                    Text(s.workSheetTitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 14)

                    employerSection.padding(.top, 18)

                    Divider().overlay(Theme.cardBorder).padding(.vertical, 16)

                    timeSection

                    Text(s.collectedNotComparedNote)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    saveButton.padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            employer = store.employerKind
            schedule = store.workSchedule
            hours = store.weeklyHours ?? store.workSchedule?.defaultHours ?? 40
        }
    }

    // MARK: Sections

    private var employerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s.employerSheetTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)

            VStack(spacing: 7) {
                ForEach(EmployerKind.allCases) { kind in
                    employerRow(kind)
                }
            }
            .padding(.top, 9)

            if employer?.outsideGEP == true {
                caveatBox.padding(.top, 10)
            }
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s.scheduleAddHint)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 8) {
                ForEach(WorkSchedule.allCases) { option in
                    scheduleChip(option)
                }
            }
            .padding(.top, 9)

            if schedule != nil {
                Text(s.hoursQuestion)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 14)
                stepper(value: $hours, min: 1, max: 60, text: s.hoursText(hours))
                    .padding(.top, 6)
            }
        }
    }

    private var saveButton: some View {
        Button {
            commit()
            dismiss()
        } label: {
            Text(s.saveButton)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func commit() {
        store.employerKind = employer
        store.workSchedule = schedule
        store.weeklyHours = schedule == nil ? nil : hours
    }

    // MARK: Pieces

    private var caveatBox: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(s.publicCaveatTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.danger)
            Text(s.publicCaveatBody)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.dangerSoft, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.dangerBorder, lineWidth: 1)
        )
    }

    private func employerRow(_ kind: EmployerKind) -> some View {
        let isSelected = kind == employer
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { employer = kind }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textFaint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.label(pt: s.pt))
                        .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(Theme.textPrimary)
                    Text(kind.hint(pt: s.pt))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textFaint)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Theme.accentSoft : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.accentBorder : Theme.cardBorder, lineWidth: 1)
            )
        }
    }

    private func scheduleChip(_ option: WorkSchedule) -> some View {
        let isSelected = option == schedule
        return Button {
            withAnimation(.easeOut(duration: 0.12)) {
                schedule = option
                hours = store.weeklyHours ?? option.defaultHours
            }
        } label: {
            Text(option.label(pt: s.pt))
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    isSelected ? Theme.accent : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 11)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isSelected ? Theme.accent : Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    private func stepper(value: Binding<Int>, min lower: Int, max upper: Int, text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
            Spacer()
            HStack(spacing: 16) {
                Button {
                    if value.wrappedValue > lower {
                        withAnimation(.easeOut(duration: 0.12)) { value.wrappedValue -= 1 }
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(value.wrappedValue > lower ? Theme.accent : Theme.textFaint)
                }
                Button {
                    if value.wrappedValue < upper {
                        withAnimation(.easeOut(duration: 0.12)) { value.wrappedValue += 1 }
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(value.wrappedValue < upper ? Theme.accent : Theme.textFaint)
                }
            }
        }
    }
}

/// v0.9: gender, always skippable, reason shown before the options.
struct GenderSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 34, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Text(s.genderSheetTitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 14)

                Text(s.enrichWhy("gender"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                VStack(spacing: 7) {
                    ForEach(Gender.allCases) { option in
                        chip(option)
                    }
                }
                .padding(.top, 16)

                Text(s.sheetPrivacy)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 14)

                if store.gender != nil {
                    Button {
                        store.gender = nil
                        dismiss()
                    } label: {
                        Text(s.removeDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .underline()
                    }
                    .padding(.top, 12)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func chip(_ option: Gender) -> some View {
        let isSelected = option == store.gender
        return Button {
            store.gender = option
            dismiss()
        } label: {
            Text(option.label(pt: s.pt))
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 13)
                .background(
                    isSelected ? Theme.accent : Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Theme.accent : Theme.cardBorder, lineWidth: 1)
                )
        }
    }
}
