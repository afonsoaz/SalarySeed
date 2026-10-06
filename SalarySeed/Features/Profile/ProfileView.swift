import SwiftUI

/// profileSeed: your answers, and the app.
///
/// Phase two (agreed with Afonso) made it the Settings shape: a centred header,
/// then one card per section with a line per answer. It was ten separate cards,
/// most of them with a bright "+ Add" pill, and the version said twice.
///
/// THE SPROUT IS THE PROFILE'S FACE. Profile completeness has always been the
/// sprout's growth stage, so it sits where a profile picture would, centred
/// like Home's figure, on a soft disc so that even the first hairline stage
/// reads as a seedling and not as a smudge (rule 25). The name under it is the
/// one thing the app calls you, and tapping it renames you.
///
/// THE SALARY IS NOT HERE, on purpose. It lives on Home, where the "Update my
/// salary" bubble changes it, schedule included. Profile used to carry
/// it as well, behind "Has your salary actually changed?", which made two doors
/// to one number on two screens. The tax answers live on Tax, beside the
/// figures they change. Profile is about you and the app.
struct ProfileView: View {
    @EnvironmentObject private var store: SalaryStore
    // v0.16. Read for the dormant support card and the colour lock, both of
    // which only ever draw in a paid build.
    @EnvironmentObject private var supporter: SupporterStore
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var showSectorSheet = false
    @State private var activeDimension: CompareDimension?
    // v0.9
    @State private var activeSignalSheet: SignalSheet?
    // v0.9.1
    @State private var showConcelhoSheet = false
    // v0.16
    @State private var showSupport = false
    @State private var editingName = false
    @State private var draftName = ""

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
            // A nil section adds no spacing to the stack, so the support card,
            // which draws nothing in a free build, moves nothing.
            VStack(alignment: .leading, spacing: 28) {
                header
                supportCard
                aboutYou
                yourWork
                appSection
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .sheet(isPresented: $showSectorSheet) { SectorTenureSheet() }
        .sheet(item: $activeSignalSheet) { SignalSheetView(sheet: $0) }
        .sheet(isPresented: $showConcelhoSheet) { ConcelhoSheet() }
        .sheet(isPresented: $showSupport) { SupportSheet() }
        .sheet(item: $activeDimension) { ProfilePickerSheet(dimension: $0) }
        .alert(s.nameAlertTitle, isPresented: $editingName) {
            TextField(s.nameLabel, text: $draftName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button(s.saveButton) {
                store.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .keyboardShortcut(.defaultAction)
            Button(s.cancelButton, role: .cancel) {}
        } message: {
            Text(s.nameAlertMessage)
        }
    }

    // MARK: The header

    /// The sprout, your name, and how much of the profile is answered.
    ///
    /// v0.9.3 counted the real signals rather than a hard-coded five (a full
    /// profile used to read "11 de 5"), and the finished state still turns the
    /// line green when there is nothing left to ask.
    private var header: some View {
        let filled = store.profileFilledCount
        let total = store.signalTotal
        let done = filled >= total
        return VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                    .overlay(Circle().stroke(Theme.accentBorder, lineWidth: 1))
                SproutView(stage: store.sproutStage, size: 76, sways: true)
                    .offset(y: 2)
            }
            .frame(width: 104, height: 104)
            .accessibilityHidden(true)

            nameButton
                .padding(.top, 16)

            // The count stays when it is complete, in green: "Está tudo" on its
            // own under a name read as a sentence cut short.
            Text(s.profileDetailsCount(filled, total))
                .appFont(15, weight: .medium)
                .foregroundStyle(done ? Theme.accent : Theme.textSecondary)
                .contentTransition(.numericText())
                .padding(.top, 6)
            Text(done ? s.profileDoneSub : s.profileProgressSub)
                .appFont(13)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: filled)
    }

    /// The name, centred, with a small pencil hanging off it. An invisible
    /// block the pencil's width sits on the left, so the NAME is what is on the
    /// centre line, the way Home's figure carries its leaf. With no name the
    /// line is "Add your name" in green, which already says what a tap does,
    /// so the pencil goes.
    private var nameButton: some View {
        let pencil = Theme.scaled(16, typeSize)
        let named = store.displayName != nil
        return Button {
            // The trimmed name, not the stored one: before phase two the field
            // wrote straight to the store, so an older install can hold a name
            // with stray spaces, or only spaces.
            draftName = store.displayName ?? ""
            editingName = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if named { Color.clear.frame(width: pencil, height: 1) }
                Text(store.displayName ?? s.namePlaceholder)
                    .appFont(28, weight: .medium)
                    .foregroundStyle(named ? Theme.textPrimary : Theme.accent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if named {
                    Image(systemName: "pencil")
                        .appFont(14, weight: .semibold)
                        .foregroundStyle(Theme.textFaint)
                        .frame(width: pencil)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel(store.displayName.map { "\(s.nameLabel): \($0)" } ?? s.namePlaceholder)
        .accessibilityHint(s.nameEditHint)
    }

    // MARK: Support (v0.16)

    /// The first card on the screen, under the header, in a paid build.
    ///
    /// v1.3: THERE IS NO CARD AT ALL IN A FREE BUILD, and drawing the thank-you
    /// state instead would have been the easy mistake. `isSupporter` is forced
    /// true when `AppConfig.monetisation` is `.free`, so the second branch below
    /// would otherwise draw "You are a SalarySeed supporter" at somebody who
    /// never paid anything.
    ///
    /// Accent-filled before purchase and quiet after, because the two states are
    /// asking for different things: one wants to be noticed, the other only needs
    /// to confirm that something happened. A supporter should not be sold to
    /// every time they open their own profile.
    @ViewBuilder
    private var supportCard: some View {
        if AppConfig.monetisation == .supporter {
            if supporter.isSupporter {
                Button { showSupport = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .appFont(13)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.supportThanksTitle)
                                .appFont(13, weight: .medium)
                                .foregroundStyle(Theme.textPrimary)
                            Text(s.supportThanksBody)
                                .appFont(10.5)
                                .foregroundStyle(Theme.textFaint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder, lineWidth: 1))
                }
            } else {
                Button { showSupport = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .appFont(18)
                            .foregroundStyle(Theme.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.supportButton)
                                .appFont(16, weight: .semibold)
                                .foregroundStyle(Theme.ink)
                            Text(s.supportOneOff)
                                .appFont(11)
                                .foregroundStyle(Theme.ink.opacity(0.75))
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .appFont(13, weight: .semibold)
                            .foregroundStyle(Theme.ink.opacity(0.6))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: Your answers

    /// v0.9.3: the profile is grouped by what the question is ABOUT rather than
    /// by which version added it. About you, then the job. Tax was third until
    /// phase two moved it onto the Tax screen.
    private var aboutYou: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.demographicsTitle)
            LineCard {
                ForEach(CompareDimension.all) { dim in
                    dimensionLine(dim)
                    GlyphLineDivider()
                }
                answerLine(glyph: "person.2", title: s.genderRowTitle,
                           value: store.gender?.label(pt: s.pt), hint: s.genderAddHint) {
                    activeSignalSheet = .gender
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)
    }

    /// The signals added in v0.9 are not compared against yet, and the note
    /// under the card says so: an app that asks for something and then
    /// pretends it is being used has spent trust it will need later.
    private var yourWork: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.workSectionTitle)
            LineCard {
                // Sector and time at the company, answered in one sheet.
                answerLine(glyph: "building.2", title: s.sectorRowTitle,
                           value: store.sector.map(sectorValue), hint: s.sectorAddHint) {
                    showSectorSheet = true
                }
                GlyphLineDivider()
                answerLine(glyph: "person.text.rectangle", title: s.jobRowTitle,
                           value: store.jobTitle?.label(pt: s.pt), hint: s.jobAddHint) {
                    activeSignalSheet = .jobTitle
                }
                GlyphLineDivider()
                answerLine(glyph: "building.columns", title: s.employerRowTitle,
                           value: store.employerKind?.label(pt: s.pt), hint: s.employerAddHint) {
                    activeSignalSheet = .work
                }
                GlyphLineDivider()
                answerLine(glyph: "clock", title: s.scheduleRowTitle,
                           value: scheduleValue, hint: s.scheduleAddHint) {
                    activeSignalSheet = .work
                }
                GlyphLineDivider()
                answerLine(glyph: "gift", title: s.variableRowTitle,
                           value: variableValue, hint: s.variableAddHint) {
                    activeSignalSheet = .variablePay
                }
            }
            Text(s.collectedNotComparedNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)
    }

    /// One answer: its glyph, what it is, and the answer under it, or, with no
    /// answer yet, what answering it gets you, in green with a plus. The
    /// "+ Add" pills went with phase two: five of them down one card shouted
    /// louder than the answers.
    private func answerLine(glyph: String, title: String, value: String?, hint: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            GlyphLine(glyph: glyph,
                      accessory: value == nil ? "plus" : "chevron.right",
                      accessoryTint: value == nil ? Theme.accent : Theme.textFaint,
                      dimmedTile: value == nil) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appFont(16, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(value ?? hint)
                        .appFont(13)
                        .foregroundStyle(value == nil ? Theme.accent : Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // `GlyphLine` aligns its words leading already; said here too,
                // because this is a Button label and rule 27 is not something
                // to leave to a component three files away.
                .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(RowPressStyle())
    }

    /// v0.9.1: the region is derived from the município, so its line opens the
    /// município search; the others open their chip picker.
    private func dimensionLine(_ dim: CompareDimension) -> some View {
        let title = dim.usesConcelhoPicker ? s.concelhoRowTitle : s.dimShort(dim.id)
        let value = dim.selectedOption(in: store, pt: s.pt).map {
            dim.usesConcelhoPicker ? concelhoValue($0.label) : $0.label
        }
        let hint = dim.usesConcelhoPicker ? s.concelhoAddHint : s.dimProfileHint(dim.id)
        return answerLine(glyph: dim.icon, title: title, value: value, hint: hint) {
            if dim.usesConcelhoPicker { showConcelhoSheet = true } else { activeDimension = dim }
        }
    }

    /// "Torres Vedras · Oeste e Vale do Tejo". The derived region is always
    /// shown, because it is what the comparison actually uses.
    private func concelhoValue(_ regionLabel: String) -> String {
        guard let concelho = store.concelho else { return regionLabel }
        return "\(concelho.name) · \(concelho.region.label)"
    }

    private func sectorValue(_ sector: Sector) -> String {
        s.sectorCohort(sector.label(pt: s.pt), tenure: store.tenureYears.map { s.yearsText($0) })
    }

    private var scheduleValue: String? {
        guard let schedule = store.workSchedule else { return nil }
        if let hours = store.weeklyHours {
            return "\(schedule.label(pt: s.pt)) · \(s.hoursText(hours))"
        }
        return schedule.label(pt: s.pt)
    }

    private var variableValue: String? {
        guard let amount = store.variableAnnual else { return nil }
        return amount > 0 ? s.variableYearly(eur(amount)) : s.variableNone
    }

    // MARK: The app

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.appSection)
            LineCard {
                languageLine
                GlyphLineDivider()
                colourLine
                GlyphLineDivider()
                // The "Premium: free version" row went in v0.16, and stays gone:
                // the purchase state is said by the support card and by the
                // colour lock, in a paid build, and by nothing in a free one.
                infoLine(glyph: "lock.shield", label: s.privacyLabel, value: s.privacyValue)
                GlyphLineDivider()
                infoLine(glyph: "books.vertical", label: s.sourcesLabel, value: s.sourcesValue)
            }
        }
    }

    /// v0.3: Auto follows the device; English and Português force it. A menu
    /// on the line, the way Settings picks one of a few, rather than the loud
    /// segmented control it was: that one is for questions, this is a setting.
    private var languageLine: some View {
        GlyphLine(glyph: "globe") {
            Text(s.languageLabel)
                .appFont(16, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                // The menu beside it says "Language" itself, with its value.
                .accessibilityHidden(true)
        } trailing: {
            Menu {
                Picker(selection: $store.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label(pt: s.pt)).tag($0) }
                } label: {
                    EmptyView()
                }
            } label: {
                HStack(spacing: 5) {
                    Text(store.language.label(pt: s.pt))
                        .appFont(15)
                    Image(systemName: "chevron.up.chevron.down")
                        .appFont(11, weight: .semibold)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(s.languageLabel)
            .accessibilityValue(store.language.label(pt: s.pt))
        }
    }

    /// The colour picker. Always visible; usable by everyone in a free build, and
    /// only by supporters in a paid one.
    ///
    /// v1.3: the padlock, the dimmed swatches and the "supporters choose the
    /// colour" line below all read `supporter.isSupporter`, which is forced true
    /// in a free build, so this line comes right on its own with no edit. The
    /// note under the swatches already picks `supportIconNote`, which is the
    /// correct sentence for a free app.
    ///
    /// In a paid build it is visible-but-locked rather than hidden, because the
    /// thing being sold should be something you can see. Tapping a locked swatch
    /// opens the sheet rather than doing nothing, so the lock explains itself
    /// instead of just refusing.
    ///
    /// The swatches sit UNDER the line rather than in it, so the glyph stays
    /// beside its title; inside the line, the glyph was centred on the whole
    /// block and floated level with the swatches.
    private var colourLine: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlyphLine(glyph: "paintpalette") {
                HStack(spacing: 6) {
                    Text(s.supportColourTitle)
                        .appFont(16, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !supporter.isSupporter {
                        Image(systemName: "lock.fill")
                            .appFont(11)
                            .foregroundStyle(Theme.textFaint)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(AccentTheme.allCases) { theme in
                        accentSwatch(theme)
                    }
                }
                Text(supporter.isSupporter ? s.supportIconNote : s.supportColourLocked)
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, typeSize.isAccessibilitySize ? 16 : 16 + Theme.scaled(32, typeSize) + 14)
            .padding(.trailing, 16)
            .padding(.bottom, 14)
        }
    }

    private func accentSwatch(_ theme: AccentTheme) -> some View {
        let isOn = store.accent == theme
        // Scaled with the reader's text, and the tick is drawn as a share of
        // the circle, so the two cannot drift apart: a fixed circle around a
        // tick that grew on its own curve filled up at an accessibility size.
        // Capped, because five of them must fit a 375 point phone at the
        // largest size (AX5 would make each about 57 points).
        let side = min(Theme.scaled(32, typeSize), 48)
        return Button {
            guard supporter.isSupporter else {
                showSupport = true
                return
            }
            withAnimation(.easeOut(duration: 0.18)) { store.accent = theme }
            AppIcon.apply(theme)
        } label: {
            Circle()
                .fill(theme.accent)
                .frame(width: side, height: side)
                .opacity(supporter.isSupporter ? 1 : 0.45)
                .overlay(Circle().stroke(Theme.textPrimary.opacity(isOn ? 0.9 : 0), lineWidth: 2))
                .overlay(
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.bold)
                        .frame(width: side * 0.38, height: side * 0.38)
                        .foregroundStyle(theme.ink)
                        .opacity(isOn && supporter.isSupporter ? 1 : 0)
                )
                // Apple's 44 point minimum, without drawing a bigger swatch.
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.label(pt: s.pt))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// A line that states something and opens nothing, so it has no chevron.
    private func infoLine(glyph: String, label: String, value: String) -> some View {
        GlyphLine(glyph: glyph) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .appFont(16, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: The foot

    /// Which build this is, and what every figure in the app is.
    ///
    /// v1.0 added the version, read from the bundle rather than typed: the
    /// footer said "v0.9.4" through six releases. Nobody needs it until
    /// something is wrong, and then it is the first thing anyone asks for, so
    /// it is small and at the foot. It was a row AND the footer until phase
    /// two; once is enough.
    private var footer: some View {
        VStack(spacing: 4) {
            Text("SalarySeed \(AppConfig.versionLine)")
                .appFont(12, weight: .medium)
                .foregroundStyle(Theme.textSecondary)
            Text(s.profileFooter)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}
