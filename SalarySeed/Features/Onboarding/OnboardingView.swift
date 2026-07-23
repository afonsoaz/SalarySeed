import SwiftUI

/// First-run flow, v0.6 edition.
///
/// Warm welcome + name, then the one mandatory number (the salary), then the
/// gross/net and months toggles, then marital situation and dependants (for a
/// real IRS estimate), then ajudas de custo, then the four profile questions
/// asked one by one: age, region, education, profession. Marital and dependants
/// have sensible defaults (single, 0); everything is skippable EXCEPT the salary.
/// The IRS Jovem exemption is set later in profileSeed. Answers commit at the end.
struct OnboardingView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var step = 0

    @State private var nameText = ""
    @State private var amountText = ""
    @State private var kind: AmountKind = .gross
    @State private var schedule: PaySchedule = .fourteen
    @State private var ajudasText = ""
    @State private var maritalSel: MaritalSituation = .single
    @State private var dependentsSel: Int = 0
    @State private var ageBand: AgeBand?
    @State private var region: PTRegion?
    @State private var education: EducationLevel?
    @State private var occupation: OccupationGroup?
    @FocusState private var amountFocused: Bool
    @FocusState private var ajudasFocused: Bool

    private var s: Strings { store.s }
    private let totalSteps = 10

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            // faint light at the top, part of the sprout personality pass
            RadialGradient(
                colors: [Theme.accent.opacity(0.07), .clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                switch step {
                case 0: welcomeStep
                case 1: salaryStep
                case 2: detailsStep
                case 3: maritalStep
                case 4: dependentsStep
                case 5: ajudasStep
                case 6: profileStep(dimensionID: "age")
                case 7: profileStep(dimensionID: "region")
                case 8: profileStep(dimensionID: "education")
                default: profileStep(dimensionID: "occupation")
                }
            }
            .padding(24)
        }
    }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var salaryValue: Double? {
        guard let v = Double(amountText), v > 0 else { return nil }
        return v
    }

    private func advance() {
        withAnimation { step += 1 }
    }

    private func finish() {
        store.name = trimmedName
        store.amount = salaryValue ?? 1500
        store.kind = kind
        store.schedule = schedule
        store.ajudasMonthly = max(0, Double(ajudasText) ?? 0)
        store.maritalSituation = maritalSel
        store.dependents = dependentsSel
        store.ageBand = ageBand
        store.region = region
        store.education = education
        store.occupation = occupation
        store.hasOnboarded = true
    }

    private var header: some View {
        HStack {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.trailing, 8)
            }
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14))
                Text("SalarySeed")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.accent)
            Spacer()
            if step > 0 {
                SeedDots(count: totalSteps, current: step)
            }
        }
    }

    // MARK: Step 0, welcome + name

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                SproutView(stage: 2, size: 92, animatesIn: true, sways: true)
                Spacer()
            }
            .padding(.top, 26)

            Text(s.welcomeTitle)
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 22)
            Text(s.welcomeSub)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.top, 9)

            Text(s.welcomeAskName)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 28)
            TextField(s.welcomeNamePlaceholder, text: $nameText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.accent).frame(height: 2)
                }

            HStack(spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 12))
                Text(s.welcomePrivacy)
                    .font(.system(size: 11.5))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 20)

            Spacer()
            PrimaryButton(title: s.welcomeButton) { advance() }
            Button {
                nameText = ""
                advance()
            } label: {
                Text(s.welcomeSkip)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 12)

            SeedDots(count: totalSteps, current: 0)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }

    // MARK: Step 1, the one number (the only mandatory answer)

    private var salaryStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 64)
            Text(s.salaryTitle)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(trimmedName.isEmpty ? s.salarySub : s.salarySubNamed(trimmedName))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("€")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.textSecondary)
                TextField("1500", text: $amountText)
                    .keyboardType(.numberPad)
                    .focused($amountFocused)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(s.perMonthSuffix)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.accent).frame(height: 2)
            }
            .padding(.top, 44)

            if salaryValue == nil {
                Text(s.salaryNeeded)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 12)
            }

            Spacer()
            PrimaryButton(title: s.continueButton) {
                if salaryValue != nil { advance() }
            }
            .opacity(salaryValue == nil ? 0.4 : 1)
        }
        .onAppear { amountFocused = true }
    }

    // MARK: Step 2, gross/net + months

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 34)
            Text(s.grossOrNet)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            SegmentedPicker(options: AmountKind.allCases, selection: $kind) { $0.label(pt: s.pt) }
                .padding(.top, 12)

            Text(s.howManyMonths)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 34)
            Text(s.monthsHint)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
            SegmentedPicker(options: PaySchedule.allCases, selection: $schedule) { $0.label(pt: s.pt) }
                .padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 13))
                Text(s.fiveSeconds)
                    .font(.system(size: 12))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 34)

            Spacer()
            PrimaryButton(title: s.continueButton) { advance() }
        }
    }

    // MARK: Step 3, marital situation (for a real IRS estimate)

    private var maritalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)
            Text(s.onbMaritalTitle)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.onbMaritalSub)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(MaritalSituation.allCases) { option in
                    maritalRow(option)
                }
            }
            .padding(.top, 24)

            Spacer()
            PrimaryButton(title: s.continueButton) { advance() }
        }
    }

    private func maritalRow(_ option: MaritalSituation) -> some View {
        let isSelected = option == maritalSel
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { maritalSel = option }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label(pt: s.pt))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isSelected ? Color(hex: 0x06281C) : Theme.textPrimary)
                    Text(option.hint(pt: s.pt))
                        .font(.system(size: 11.5))
                        .foregroundStyle(isSelected ? Color(hex: 0x06281C).opacity(0.75) : Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x06281C))
                }
            }
            .padding(14)
            .background(
                isSelected ? Theme.accent : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.accent : Theme.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: Step 4, dependants

    private var dependentsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)
            Text(s.onbDependentsTitle)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.onbDependentsSub)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.top, 8)

            HStack(spacing: 22) {
                stepperButton(system: "minus") {
                    if dependentsSel > 0 { dependentsSel -= 1 }
                }
                .opacity(dependentsSel > 0 ? 1 : 0.35)

                VStack(spacing: 2) {
                    Text("\(dependentsSel)")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text(s.dependentsUnit(dependentsSel))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minWidth: 120)

                stepperButton(system: "plus") {
                    if dependentsSel < 12 { dependentsSel += 1 }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)

            Spacer()
            PrimaryButton(title: s.continueButton) { advance() }
        }
    }

    private func stepperButton(system: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { action() }
        } label: {
            Image(systemName: system)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 52, height: 52)
                .background(Theme.accentSoft, in: Circle())
                .overlay(Circle().stroke(Theme.accentBorder))
        }
    }

    // MARK: Step 5, ajudas de custo (skippable)

    private var ajudasStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 64)
            Text(s.onbAjudasTitle)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.onbAjudasSub)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("€")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: $ajudasText)
                    .keyboardType(.numberPad)
                    .focused($ajudasFocused)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(s.perMonthSuffix)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.danger.opacity(0.7)).frame(height: 2)
            }
            .padding(.top, 44)

            Text(s.editorAjudasNote)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .padding(.top, 12)

            Spacer()
            PrimaryButton(title: s.continueButton) { advance() }
            skipButton {
                ajudasText = ""
                advance()
            }
        }
    }

    // MARK: Steps 6 to 9, the profile, one question at a time

    private func profileStep(dimensionID id: String) -> some View {
        let isLast = step == totalSteps - 1
        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)
            Text(s.dimSheetTitle(id))
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            if let note = s.dimSheetNote(id) {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 4)
            }
            Text(s.onbProfileWhy)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(profileOptions(id)) { option in
                        profileChip(dimensionID: id, option: option, isLast: isLast)
                    }
                }
                .padding(.top, 20)
            }

            Spacer(minLength: 0)
            skipButton {
                setSelection(id, nil)
                if isLast { finish() } else { advance() }
            }
        }
    }

    private func profileOptions(_ id: String) -> [DimensionOption] {
        switch id {
        case "age": AgeBand.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label) }
        // Only regions with published data, same rule as compareSeed.
        case "region": PTRegion.allCases.filter { $0.cohort != nil }.map { DimensionOption(id: $0.rawValue, label: $0.label) }
        case "education": EducationLevel.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label(pt: s.pt)) }
        default: OccupationGroup.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label(pt: s.pt)) }
        }
    }

    private func selectedID(_ id: String) -> String? {
        switch id {
        case "age": ageBand?.rawValue
        case "region": region?.rawValue
        case "education": education?.rawValue
        default: occupation?.rawValue
        }
    }

    private func setSelection(_ id: String, _ optionID: String?) {
        switch id {
        case "age": ageBand = optionID.flatMap(AgeBand.init(rawValue:))
        case "region": region = optionID.flatMap(PTRegion.init(rawValue:))
        case "education": education = optionID.flatMap(EducationLevel.init(rawValue:))
        default: occupation = optionID.flatMap(OccupationGroup.init(rawValue:))
        }
    }

    private func profileChip(dimensionID: String, option: DimensionOption, isLast: Bool) -> some View {
        let isSelected = option.id == selectedID(dimensionID)
        return Button {
            setSelection(dimensionID, option.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if isLast { finish() } else { advance() }
            }
        } label: {
            Text(option.label)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Color(hex: 0x06281C) : Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
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

    private func skipButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(s.skipStep)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 12)
    }
}

// MARK: Shared controls

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: 0x06281C))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct SegmentedPicker<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selection == option ? Theme.accent : .clear,
                            in: RoundedRectangle(cornerRadius: 11)
                        )
                        .foregroundStyle(
                            selection == option ? Color(hex: 0x06281C) : Theme.textSecondary
                        )
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
