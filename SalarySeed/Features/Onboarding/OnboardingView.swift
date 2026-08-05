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
    @State private var showConsentPreview = false

    private var s: Strings { store.s }
    /// v0.12: nine questions and then the consent screen, which is asked last on
    /// purpose. Consent has to be specific about what is being shared, and until
    /// the answers exist there is nothing specific to point at.
    private let totalSteps = 10

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
                case 8: sectorStep
                default: consentStep
                }
            }
            .padding(24)
        }
        // Tap empty space to drop the keyboard.
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
        .sheet(isPresented: $showConsentPreview) { ContributionPreviewSheet() }
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

    /// v0.13: the answers are written to the store one step BEFORE the end.
    ///
    /// The consent screen offers to show the exact row that would be sent, and
    /// that row is built by reading the store. If the answers were still sitting
    /// in `@State` at that point, the preview would truthfully render the
    /// PREVIOUS contents of the store, which for a first run is a €1.500 default
    /// nobody typed. A preview that shows the wrong number is worse than no
    /// preview, so the answers land first and consent is decided against them.
    ///
    /// `hasOnboarded` stays false until the last screen, so a launch killed in
    /// between still reopens onboarding.
    private func commitAnswers() {
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
    }

    /// The last act. `consent` is a required argument rather than a defaulted
    /// one so no future caller can finish onboarding without deciding what it is.
    ///
    /// Granting creates the token; declining does not, and declining is not a
    /// silent state either: it is recorded, so the app can tell "asked and said
    /// no" apart from "never asked" and never raises the subject again.
    private func finish(consent: Bool) {
        dismissKeyboard()
        commitAnswers()
        if consent { store.grantDataSharing() } else { store.revokeDataSharing() }
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

            // v0.12: the amount comes FIRST and the two pickers sit under it with
            // no labels and no hint. The question above already says what the
            // number is, and the segments say what they are: "Bruto / Líquido"
            // and "12x / 14x / Anual" need no sentence introducing them. The old
            // order put the field last so the keyboard could not cover the
            // toggles; that trade is not needed, because the field is now near
            // the top of the screen and the keyboard rises from the bottom, so
            // everything above the OK button stays visible while typing.
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
            .padding(.top, 28)

            // gross/net
            SegmentedPicker(options: AmountKind.allCases, selection: $kind) { $0.label(pt: s.pt) }
                .padding(.top, 22)

            // 12x / 14x / yearly
            SegmentedPicker(options: SalaryEntryMode.allCases, selection: $entryMode) { $0.label(pt: s.pt) }
                .padding(.top, 10)

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
                        .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
                    Text(option.hint(pt: s.pt))
                        .font(.system(size: 11.5))
                        .foregroundStyle(isSelected ? Theme.ink.opacity(0.75) : Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
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
        VStack(alignment: .leading, spacing: 0) {
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
            PrimaryButton(title: s.okButton) { advance() }
            bigSkipButton(s.skipQuestion) {
                setSelection(id, nil)
                advance()
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

            ConcelhoPickerList(selectedID: $concelhoSel, onPick: nil, s: s)
                .padding(.top, 20)

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

    // MARK: Step 8, sector + tenure (last question)

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
            PrimaryButton(title: s.okButton) {
                commitAnswers()
                advance()
            }
            bigSkipButton(s.skipQuestion) {
                sectorSel = nil
                commitAnswers()
                advance()
            }
        }
    }

    // MARK: Step 9, the consent screen (v0.12, copy v0.13, reframed v0.14)

    /// Asked once, at the end, when there is something concrete to consent to.
    ///
    /// v0.14 MADE THE SCREEN UNSKIPPABLE AND THE ANSWER FREE, and the distance
    /// between those two is the entire design. There is no skip, no dismiss, no
    /// default and no pre-selection: the only way past is to press one of two
    /// buttons. But BOTH buttons continue into the app, and the app is identical
    /// either way.
    ///
    /// The obvious alternative, "agree or the app closes", is wrong twice.
    /// Practically, iOS has no sanctioned way for an app to terminate itself, so
    /// it would be a dead end rather than an exit. Legally, consent conditioned
    /// on using the service is presumed NOT freely given (GDPR Art. 7(4),
    /// Recital 43), the pooling is plainly not necessary to compute anyone's
    /// tax, and void consent would leave a database with no lawful basis. That
    /// is strictly worse than not collecting: the data, and no right to use it.
    ///
    /// So the copy carries the weight the wall would have carried. It says what
    /// the pool is for, shows the actual row instead of describing it, explains
    /// the code, and says what a yes unlocks in a future version. A screen that
    /// argues for itself converts better than one that traps.
    ///
    /// It scrolls, because the row is on it. The two buttons stay pinned below,
    /// so no amount of content can push the decision off screen.
    private var consentStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    consentHeader
                    consentPoints
                    consentRowBlock
                }
                .padding(.bottom, 18)
            }
            consentActions
        }
    }

    private var consentHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                SproutView(stage: 4, size: 64, animatesIn: true, sways: true)
                Spacer()
            }
            .padding(.top, 14)
            Text(s.consentTitle)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
            Text(s.consentBody)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            // v0.14: the reason to say yes, stated as what it produces rather
            // than as a favour asked.
            Text(s.consentUnlocks)
                .font(.system(size: 13))
                .foregroundStyle(Theme.accent)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

    private var consentPoints: some View {
        VStack(alignment: .leading, spacing: 7) {
            consentPoint(icon: "checkmark.circle", text: s.consentPointShared)
            consentPoint(icon: "xmark.circle", text: s.consentPointNotShared)
            consentPoint(icon: "key", text: s.consentPointCode)
            consentPoint(icon: "trash", text: s.consentPointDelete)
        }
        .padding(.top, 16)
    }

    /// v0.14: the row, on the screen, not behind a link. Everything above is a
    /// description of the data. This is the data, decoded from the payload
    /// itself, so it cannot describe a row the app would not actually send.
    @ViewBuilder
    private var consentRowBlock: some View {
        let year = Calendar.current.component(.year, from: Date())
        VStack(alignment: .leading, spacing: 8) {
            Text(s.consentWhatIsSent)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            if let row = store.contributionPreview(year: year) {
                ContributionSummaryCard(row: row, s: s)
                Button { showConsentPreview = true } label: {
                    Text(s.consentPreviewButton)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .underline()
                }
            } else {
                Text(s.consentPreviewNoSalary)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .padding(.top, 18)
    }

    /// Pinned below the scroll view. Both full width, both reachable without
    /// scrolling, neither pre-selected, and the line underneath is the sentence
    /// that makes the choice free rather than a toll gate.
    private var consentActions: some View {
        VStack(spacing: 0) {
            PrimaryButton(title: s.consentAccept) { finish(consent: true) }
            bigSkipButton(s.consentDecline) { finish(consent: false) }
            Text(s.consentEitherWay)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .padding(.top, 4)
    }

    private func consentPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.accent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectorChip(_ sector: Sector) -> some View {
        let isSelected = sector == sectorSel
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { sectorSel = sector }
        } label: {
            Text(sector.label(pt: s.pt))
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
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
                .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
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
                .foregroundStyle(Theme.ink)
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
                            selection == option ? Theme.ink : Theme.textSecondary
                        )
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
