import SwiftUI

/// How the salary is entered on the combined first step: paid 12x, 14x, or as a
/// yearly total. Maps to the store's pay schedule + yearly-input flag.
enum SalaryEntryMode: String, CaseIterable, Identifiable {
    case twelve, fourteen, yearly
    var id: String { rawValue }
    func label(pt: Bool) -> String {
        switch self {
        case .twelve: return "12x"
        case .fourteen: return "14x"
        case .yearly: return pt ? "Anual" : "Yearly"
        }
    }
    /// Yearly totals assume the common 14-payment schedule for the per-payment split.
    var schedule: PaySchedule { self == .twelve ? .twelve : .fourteen }
    var inputYearly: Bool { self == .yearly }
}

/// First-run flow, v0.8.2 edition.
///
/// Warm welcome + name, then the one mandatory salary step (amount + gross/net +
/// 12x/14x/yearly, all on one screen), then marital situation and dependants,
/// then ajudas de custo, then the four profile questions one by one. Every step
/// has an explicit OK button, so selecting an option never auto-advances; the
/// skippable steps also show a clear, larger Skip. Everything is skippable EXCEPT
/// the salary. The IRS Jovem exemption is set later in profileSeed.
struct OnboardingView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var step = 0

    @State private var nameText = ""
    @State private var amountText = ""
    @State private var kind: AmountKind = .gross
    @State private var entryMode: SalaryEntryMode = .fourteen
    @State private var ajudasText = ""
    @State private var maritalSel: MaritalSituation = .single
    @State private var dependentsSel: Int = 0
    @State private var ageBand: AgeBand?
    @State private var concelhoSel: String?
    @State private var education: EducationLevel?
    @State private var sectorSel: Sector?
    @State private var tenureYearsSel: Int = 3

    private var s: Strings { store.s }
    private let totalSteps = 9

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
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
                case 2: maritalStep
                case 3: dependentsStep
                case 4: ajudasStep
                case 5: profileStep(dimensionID: "age")
                case 6: concelhoStep
                case 7: profileStep(dimensionID: "education")
                default: sectorStep
                }
            }
            .padding(24)
        }
        // Tap empty space to drop the keyboard.
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
    }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var salaryValue: Double? {
        guard let v = Double(amountText), v > 0 else { return nil }
        return v
    }

    private func advance() {
        dismissKeyboard()
        withAnimation { step += 1 }
    }

    private func finish() {
        dismissKeyboard()
        store.name = trimmedName
        let raw = salaryValue ?? 1500
        store.schedule = entryMode.schedule
        store.inputYearly = entryMode.inputYearly
        store.amount = entryMode.inputYearly ? raw / entryMode.schedule.months : raw
        store.kind = kind
        store.ajudasMonthly = max(0, Double(ajudasText) ?? 0)
        store.maritalSituation = maritalSel
        store.dependents = dependentsSel
        store.ageBand = ageBand
        store.concelhoID = concelhoSel
        store.education = education
        store.sector = sectorSel
        store.tenureYears = (sectorSel != nil) ? tenureYearsSel : nil
        store.hasOnboarded = true
    }

    private var header: some View {
        HStack {
            if step > 0 {
                Button {
                    dismissKeyboard()
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
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .padding(.top, 10)

            SeedDots(count: totalSteps, current: 0)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }

    // MARK: Step 1, the salary (amount + gross/net + 12x/14x/yearly), all here

    private var salaryStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 22)
            Text(s.salaryQuestion(trimmedName.isEmpty ? nil : trimmedName))
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // gross/net
            Text(s.grossOrNet)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 24)
            SegmentedPicker(options: AmountKind.allCases, selection: $kind) { $0.label(pt: s.pt) }
                .padding(.top, 8)

            // 12x / 14x / yearly
            Text(s.howYouGetPaid)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 18)
            SegmentedPicker(options: SalaryEntryMode.allCases, selection: $entryMode) { $0.label(pt: s.pt) }
                .padding(.top, 8)
            Text(s.entryModeHint)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 6)

            // the amount, kept low so the keyboard never hides the toggles above it
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("€")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.textSecondary)
                TextField("1500", text: $amountText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(entryMode == .yearly ? s.perYearSuffix : s.perMonthSuffix)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.accent).frame(height: 2)
            }
            .padding(.top, 26)

            if salaryValue == nil {
                Text(s.salaryNeeded)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 10)
            }

            Spacer(minLength: 12)
            PrimaryButton(title: s.okButton) {
                if salaryValue != nil { advance() }
            }
            .opacity(salaryValue == nil ? 0.4 : 1)
        }
    }

    // MARK: Step 2, marital situation

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
            PrimaryButton(title: s.okButton) { advance() }
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

    // MARK: Step 3, dependants

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
            PrimaryButton(title: s.okButton) { advance() }
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

    // MARK: Step 4, ajudas de custo (skippable)

    private var ajudasStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 56)
            Text(s.onbAjudasTitle)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.onbAjudasSub)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("€")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: $ajudasText)
                    .keyboardType(.numberPad)
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
            .padding(.top, 40)

            Spacer()
            PrimaryButton(title: s.okButton) { advance() }
            bigSkipButton(s.skipStep) {
                ajudasText = ""
                advance()
            }
        }
    }

    // MARK: Steps 5 to 8, the profile, one question at a time

    private func profileStep(dimensionID id: String) -> some View {
        let isLast = step == totalSteps - 1
        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 36)
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
                        profileChip(dimensionID: id, option: option)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
            }

            Spacer(minLength: 4)
            // Selecting a chip only highlights it. OK confirms; Skip moves on.
            PrimaryButton(title: s.okButton) {
                if isLast { finish() } else { advance() }
            }
            bigSkipButton(s.skipQuestion) {
                setSelection(id, nil)
                if isLast { finish() } else { advance() }
            }
        }
    }

    private func profileOptions(_ id: String) -> [DimensionOption] {
        switch id {
        case "age": AgeBand.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label) }
        default: EducationLevel.allCases.map { DimensionOption(id: $0.rawValue, label: $0.label(pt: s.pt)) }
        }
    }

    private func selectedID(_ id: String) -> String? {
        switch id {
        case "age": ageBand?.rawValue
        default: education?.rawValue
        }
    }

    private func setSelection(_ id: String, _ optionID: String?) {
        switch id {
        case "age": ageBand = optionID.flatMap(AgeBand.init(rawValue:))
        default: education = optionID.flatMap(EducationLevel.init(rawValue:))
        }
    }

    // MARK: Step 6, município (v0.9.1, replaces the NUTS II region question)

    /// Asks for the município instead of the region. The region the comparison
    /// uses is derived from it and shown back straight away, so the trade is
    /// visible: one more specific answer, a correct region instead of a guessed
    /// one. See Concelhos.swift for why the district could not be the input.
    private var concelhoStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 36)
            Text(s.concelhoQuestion)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.concelhoWhy)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)

            ConcelhoPickerList(selectedID: $concelhoSel, onPick: nil, s: s)
                .padding(.top, 16)

            if let picked = ConcelhoCatalog.concelho(concelhoSel) {
                Text(s.concelhoDerived(picked.region.label))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 8)
            }

            Spacer(minLength: 4)
            PrimaryButton(title: s.okButton) { advance() }
            bigSkipButton(s.skipQuestion) {
                concelhoSel = nil
                advance()
            }
        }
    }

    // MARK: Step 8, sector + tenure (last step)

    private var sectorStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 30)
            Text(s.sectorQuestion)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.onbProfileWhy)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(Sector.allCases) { sector in
                        sectorChip(sector)
                    }
                }
                .padding(.top, 16)

                if sectorSel != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.tenureQuestion)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        HStack {
                            Text(tenureYearsSel == 0 ? TenureBand.lt1.label(pt: s.pt) : s.yearsText(tenureYearsSel))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .contentTransition(.numericText())
                            Spacer()
                            HStack(spacing: 16) {
                                stepperButton(system: "minus") {
                                    if tenureYearsSel > 0 { tenureYearsSel -= 1 }
                                }
                                .opacity(tenureYearsSel > 0 ? 1 : 0.35)
                                stepperButton(system: "plus") {
                                    if tenureYearsSel < 40 { tenureYearsSel += 1 }
                                }
                            }
                        }
                    }
                    .padding(.top, 18)
                }
            }

            Spacer(minLength: 4)
            PrimaryButton(title: s.okButton) { finish() }
            bigSkipButton(s.skipQuestion) {
                sectorSel = nil
                finish()
            }
        }
    }

    private func sectorChip(_ sector: Sector) -> some View {
        let isSelected = sector == sectorSel
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { sectorSel = sector }
        } label: {
            Text(sector.label(pt: s.pt))
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Color(hex: 0x06281C) : Theme.textPrimary)
                .multilineTextAlignment(.center)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: Theme.chipHeight)
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

    private func profileChip(dimensionID: String, option: DimensionOption) -> some View {
        let isSelected = option.id == selectedID(dimensionID)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { setSelection(dimensionID, option.id) }
        } label: {
            Text(option.label)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Color(hex: 0x06281C) : Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: Theme.chipHeight)
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

    /// A clear, full-width Skip for the steps where the info is optional.
    private func bigSkipButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        }
        .padding(.top, 10)
    }
}

// MARK: Shared controls

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0x06281C))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
