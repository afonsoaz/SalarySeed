import SwiftUI
import AVFoundation
import UIKit

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
    /// Read for the header only. See `header`.
    @Environment(\.dynamicTypeSize) private var typeSize
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
    /// v1.4: the payslip route, which is now step 1 rather than a link under
    /// step 2's OK button. Every one of these is only ever a way to fill the
    /// amount FIELD in; `commitAnswers()` is still the only thing in this file
    /// that writes anything to the store.
    @State private var pendingPayslip: PayslipInput?
    @State private var importing = false
    @State private var scanning = false
    /// The scan, held for the length of one dismissal. See `sourceChoiceStep`.
    @State private var scannedPage: Data?
    @State private var cameraRefused = false
    @State private var cameraFailed = false
    @State private var camera: CameraAccess = .unavailable

    private var s: Strings { store.s }
    /// Nine QUESTIONS, which as of v1.4 is not the same as nine screens: step 1
    /// is a fork asking where the salary should come from, and it stores
    /// nothing. Renamed from `totalSteps` for that reason, because a constant
    /// called `totalSteps` that is not the number of steps is rule 19 in a
    /// property name. See `dotIndex`.
    ///
    /// v0.12 through v0.16 ended on a consent screen asking to pool the
    /// answers; there is no pool, so there is nothing to ask, and the sector
    /// step is still the end.
    private let totalQuestions = 9

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
                // v1.0.3 MADE THE STEPS SCROLL, and it is the Dynamic Type fix
                // rather than a layout preference.
                //
                // Every step is a column ending in a Spacer and a button. With no
                // scroll view the column can never be taller than the screen, so
                // once the reader's text no longer fits, SwiftUI takes the space
                // back out of the Text views: the welcome headline truncated to
                // "Vamos compree…" and the privacy line lost its last word. A
                // ScrollView gives the column unbounded height, so the text takes
                // the size it actually wants and the overflow becomes a scroll.
                //
                // `minHeight: geo.size.height` is what keeps the default look
                // identical. Without it the column shrinks to its content and the
                // Spacer stops pushing, which would lift every button up the
                // screen for the readers who changed nothing.
                // ONLY the plain columns get wrapped. Steps 6 to 9 are the four
                // pickers, and each already owns a ScrollView around its list or
                // grid with the buttons pinned under it. Wrapping those a second
                // time gives the inner scroll unbounded height, so it stops
                // scrolling and grows instead, and OK slides off the bottom of
                // the screen. That is exactly what happened to the concelho step
                // the first time this was written.
                //
                // `sourceChoiceStep` DOES get wrapped: it is a plain column of
                // prose, three rows and a footnote, and it owns no scroll view
                // of its own. That is also why it does not reuse
                // `PayslipSourceStep`, whose body IS a ScrollView. See the note
                // on `PayslipSourceRow`.
                switch step {
                case 0: scrollingStep { welcomeStep }
                case 1: scrollingStep { sourceChoiceStep }
                case 2: scrollingStep { salaryStep }
                case 3: scrollingStep { maritalStep }
                case 4: scrollingStep { dependentsStep }
                case 5: scrollingStep { ajudasStep }
                case 6: profileStep(dimensionID: "age")
                case 7: concelhoStep
                case 8: profileStep(dimensionID: "education")
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

    /// Which of the nine questions the current screen belongs to.
    ///
    /// The source choice at step 1 is not a tenth question, it is the first half
    /// of the salary one: it stores nothing, `commitAnswers()` reads nothing
    /// from it, and it cannot be skipped. So it shares the salary's dot and
    /// every screen after it is one behind its step number. Without this the
    /// progress indicator would claim ten questions and answer one of them by
    /// being walked past.
    private var dotIndex: Int { step <= 1 ? step : step - 1 }

    private func advance() {
        dismissKeyboard()
        withAnimation { step += 1 }
    }

    /// Writes every answer to the store in one go.
    ///
    /// Called from the last step rather than from each step as it is answered,
    /// so a half-finished run leaves the store untouched. `hasOnboarded` is set
    /// separately in `finish`.
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

    /// The last act. Writes the answers and opens the app.
    ///
    /// `hasOnboarded` is set here and nowhere else, so a launch killed part way
    /// through still reopens onboarding rather than dropping someone into an app
    /// with a salary they never confirmed.
    private func finish() {
        dismissKeyboard()
        commitAnswers()
        store.hasOnboarded = true
    }

    /// A step that is one column of text ending in a button.
    ///
    /// `minHeight: geo.size.height` is what keeps the default look identical to
    /// v1.0.2. Without it the column shrinks to fit its content, the trailing
    /// Spacer stops pushing, and every button rises up the screen for the readers
    /// who never changed their text size. With it, the column is exactly the
    /// screen until the text needs more, and only then does it scroll.
    private func scrollingStep<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        // Built once, here, rather than inside the GeometryReader: that closure
        // escapes, and a non-escaping @ViewBuilder parameter cannot go into it.
        let built = content()
        return GeometryReader { geo in
            ScrollView {
                built.frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        HStack {
            if step > 0 {
                Button {
                    dismissKeyboard()
                    withAnimation { step -= 1 }
                } label: {
                    Image(systemName: "arrow.left")
                        .appFont(15)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.trailing, 8)
            }
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .appFont(14)
                // THE WORDMARK COMES OFF AT AN ACCESSIBILITY TEXT SIZE, and
                // that is a deliberate choice between three bad options.
                //
                // Three things share this row from step 1 on: a back arrow, the
                // mark, and nine progress dots. At `accessibilityExtraLarge`
                // they stop fitting, and until v1.4 the wordmark wrapped to
                // "SalarySee / d". `HomeView.brandMark` has carried
                // `lineLimit(1)` since v1.0.3 with the note that a wordmark
                // which wraps is a typo as far as the reader is concerned, and
                // this is the second copy of that mark, which never got the
                // fix. But `lineLimit(1)` alone only trades the wrap for
                // "SalaryS…", and a truncated wordmark is mangled too.
                //
                // The arrow and the dots are both functional and the wordmark
                // is decoration on a screen that already carries a headline, so
                // the decoration is what goes. "Reflow, do not shrink" applied
                // to a row rather than to a paragraph. The leaf stays, so the
                // row still says whose app this is. Below the threshold nothing
                // changes at all, and `lineLimit(1)` stays as the backstop.
                if !typeSize.isAccessibilitySize {
                    Text("SalarySeed")
                        .appFont(13, weight: .medium)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(Theme.accent)
            .accessibilityHidden(true)
            Spacer(minLength: 8)
            if step > 0 {
                SeedDots(count: totalQuestions, current: dotIndex)
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
                .appFont(27, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 22)
            Text(s.welcomeSub)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.top, 9)

            Text(s.welcomeAskName)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 28)
            TextField(s.welcomeNamePlaceholder, text: $nameText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .appFont(24, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.accent).frame(height: 2)
                }

            // .top, because at a large text size this line wraps to three and a
            // centred lock floats beside the middle of them.
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock")
                    .appFont(12)
                Text(s.welcomePrivacy)
                    .appFont(11.5)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .padding(.top, 10)

            SeedDots(count: totalQuestions, current: 0)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }

    // MARK: Step 1, where the salary comes from

    /// v1.4 REVERSED v1.2 ON THIS, and the argument it overturned is worth
    /// keeping because it was a real one.
    ///
    /// v1.2 put the payslip under step 2's OK button as a quiet two-line link,
    /// on the reasoning that "typing stays the default: somebody on their first
    /// run has no reason to trust this app yet, and asking them for a document
    /// before asking them for a number would be the wrong first thing to say."
    ///
    /// What that argument gets right is that trust has to come first. What it
    /// gets wrong is treating the screen order as the only way to give it. The
    /// welcome step still comes first and still carries the privacy line, so
    /// nothing is asked for before the app has said what it is; and a payslip
    /// gives the exact figure and gets checked on the way past, where a typed
    /// number is a guess the whole app then does arithmetic on. Burying the
    /// better route to protect a reader from being offered it is not a kindness.
    ///
    /// Every row here is its own action and there is no OK button, because this
    /// is a fork rather than a question. All three land on step 2: the payslip
    /// routes with the field already filled, typing with it empty.
    private var sourceChoiceStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 22)
            Text(s.onbSourceTitle)
                .appFont(27, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.onbSourceSub)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)

            VStack(spacing: 10) {
                Button { dismissKeyboard(); importing = true } label: {
                    PayslipSourceRow(icon: "doc.text.fill", title: s.payslipPickFile,
                                     subtitle: s.onbSourceFileSub, accented: true)
                }
                // Not drawn where there is no usable camera, which includes
                // every simulator. A row that opens a black screen is worse
                // than a row that is not there.
                if camera != .unavailable {
                    Button(action: startScan) {
                        PayslipSourceRow(icon: "camera.fill", title: s.payslipPickCamera,
                                         subtitle: s.payslipPickCameraSub)
                    }
                }
                Button { dismissKeyboard(); advance() } label: {
                    PayslipSourceRow(icon: "keyboard", title: s.onbTypeItMyself,
                                     subtitle: s.onbSourceTypeSub)
                }
            }
            .padding(.top, 24)

            // Inline, never an alert: an alert saying "could not do it" with an
            // OK button is a dead end, and the routes that DO work are on the
            // screen behind it.
            if cameraRefused {
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.payslipCameraRefused)
                        .appFont(11.5)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(s.payslipCameraOpenSettings)
                            .appFont(11.5, weight: .semibold)
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.top, 14)
            } else if cameraFailed {
                Text(s.payslipCameraFailed)
                    .appFont(11.5)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock")
                    .appFont(12)
                    .accessibilityHidden(true)
                Text(s.onbReadFromPayslipSub)
                    .appFont(11.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 20)

            Spacer(minLength: 12)
        }
        .onAppear { camera = CameraAccess.current }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.pdf, .image],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                pendingPayslip = PayslipInput(kind: .file(url))
            }
        }
        // THE SCAN IS HANDED OVER IN `onDismiss`, not in the delegate callback.
        // Setting `scanning = false` and `pendingPayslip` in the same turn
        // presents the check onto a controller that is still going down, and
        // the failure is silent: the scanner slides away and the reader is back
        // here with nothing having happened and no error anywhere.
        .fullScreenCover(isPresented: $scanning, onDismiss: {
            if let page = scannedPage {
                scannedPage = nil
                pendingPayslip = PayslipInput(kind: .image(page))
            }
        }) {
            DocumentScanner(
                onScan: { scannedPage = $0; scanning = false },
                onCancel: { scanning = false },
                onFailure: { scanning = false; cameraFailed = true })
                .ignoresSafeArea()
        }
        // No context. At step 1 the reader has not said where they live,
        // whether they are married or how many dependants they have, so the
        // checks that need the tax tables cannot run and say so. The ones that
        // only need the payslip to agree with itself still do.
        //
        // Nothing here writes to the store. The proposal fills the FIELD on the
        // next step, the reader sees it and presses OK, and `commitAnswers()`
        // remains the only writer in this file. A misread payslip is then a
        // wrong number sitting visibly in a text field, one keystroke from
        // being fixed and gone entirely if this run is abandoned.
        //
        // One `onDismiss` covers every way out of the check: took the figure,
        // kept their own, closed it, or gave up through the unreadable screen's
        // "Type it myself". The `step == 1` guard makes a re-entry from anywhere
        // else a no-op, so `advance()` can never fire twice.
        .fullScreenCover(item: $pendingPayslip, onDismiss: {
            if step == 1 { advance() }
        }) { input in
            PayslipCheckCover(context: nil, starting: input, onAccept: { proposal in
                // Integer euros, because the field is a number pad and this is
                // the same rounding `SalaryEditorView` already does. The figure
                // the reader confirms by pressing OK is the one they can see.
                amountText = String(Int((Double(proposal.monthlyGrossCents) / 100).rounded()))
                kind = .gross
                if let ajudas = proposal.ajudasMonthlyCents {
                    ajudasText = String(Int((Double(ajudas) / 100).rounded()))
                }
            })
        }
    }

    /// Ask, or say why we cannot. Three states, three outcomes. Rule 21.
    private func startScan() {
        dismissKeyboard()
        cameraFailed = false
        switch CameraAccess.current {
        case .ready:
            cameraRefused = false
            scanning = true
        case .needsAsking:
            // The completion arrives on an arbitrary queue.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { cameraRefused = false; scanning = true }
                    else { cameraRefused = true }
                }
            }
        case .refused:
            cameraRefused = true
        case .unavailable:
            // The row is not drawn in this case, so this is unreachable. Here
            // so the switch cannot go stale if that ever changes.
            camera = .unavailable
        }
    }

    // MARK: Step 2, the salary (amount + gross/net + 12x/14x/yearly), all here

    private var salaryStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 22)
            Text(s.salaryQuestion(trimmedName.isEmpty ? nil : trimmedName))
                .appFont(27, weight: .medium)
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
                    .appFont(28)
                    .foregroundStyle(Theme.textSecondary)
                TextField("1500", text: $amountText)
                    .keyboardType(.numberPad)
                    .appFont(38, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                Text(entryMode == .yearly ? s.perYearSuffix : s.perMonthSuffix)
                    .appFont(15)
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
                    .appFont(12)
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

    // MARK: Step 3, marital situation

    private var maritalStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)
            Text(s.onbMaritalTitle)
                .appFont(26, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            Text(s.onbMaritalSub)
                .appFont(13)
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
                        .appFont(15, weight: .medium)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
                    Text(option.hint(pt: s.pt))
                        .appFont(11.5)
                        .foregroundStyle(isSelected ? Theme.ink.opacity(0.75) : Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .appFont(13, weight: .semibold)
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

    // MARK: Step 4, dependants

    private var dependentsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 40)
            Text(s.onbDependentsTitle)
                .appFont(26, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            Text(s.onbDependentsSub)
                .appFont(13)
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
                        .appFont(46, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text(s.dependentsUnit(dependentsSel))
                        .appFont(12)
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
                .appFont(18, weight: .medium)
                .foregroundStyle(Theme.accent)
                .frame(width: 52, height: 52)
                .background(Theme.accentSoft, in: Circle())
                .overlay(Circle().stroke(Theme.accentBorder))
        }
    }

    // MARK: Step 5, ajudas de custo (skippable)

    private var ajudasStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 56)
            Text(s.onbAjudasTitle)
                .appFont(28, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.onbAjudasSub)
                .appFont(13.5)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("€")
                    .appFont(30)
                    .foregroundStyle(Theme.textSecondary)
                TextField("0", text: $ajudasText)
                    .keyboardType(.numberPad)
                    .appFont(42, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                Text(s.perMonthSuffix)
                    .appFont(15)
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

    // MARK: Steps 6 to 9, the profile, one question at a time

    private func profileStep(dimensionID id: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 36)
            Text(s.dimSheetTitle(id))
                .appFont(26, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            if let note = s.dimSheetNote(id) {
                Text(note)
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 4)
            }
            Text(s.onbProfileWhy)
                .appFont(13)
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

    // MARK: Step 7, município (v0.9.1, replaces the NUTS II region question)

    /// Asks for the município instead of the region. The region the comparison
    /// uses is derived from it and shown back straight away, so the trade is
    /// visible: one more specific answer, a correct region instead of a guessed
    /// one. See Concelhos.swift for why the district could not be the input.
    private var concelhoStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 36)
            Text(s.concelhoQuestion)
                .appFont(26, weight: .medium)
                .foregroundStyle(Theme.textPrimary)

            ConcelhoPickerList(selectedID: $concelhoSel, onPick: nil, s: s)
                .padding(.top, 20)

            if let picked = ConcelhoCatalog.concelho(concelhoSel) {
                Text(s.concelhoDerived(picked.region.label))
                    .appFont(12)
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

    // MARK: Step 9, sector + tenure (last question)

    private var sectorStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 30)
            Text(s.sectorQuestion)
                .appFont(26, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(s.onbProfileWhy)
                .appFont(13)
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
                            .appFont(14, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                        HStack {
                            Text(tenureYearsSel == 0 ? TenureBand.lt1.label(pt: s.pt) : s.yearsText(tenureYearsSel))
                                .appFont(20, weight: .medium)
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
                .appFont(12.5, weight: isSelected ? .medium : .regular)
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
                .appFont(13, weight: isSelected ? .medium : .regular)
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
                .appFont(15, weight: .medium)
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
                .appFont(16, weight: .semibold)
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
                        .appFont(13, weight: .medium)
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
