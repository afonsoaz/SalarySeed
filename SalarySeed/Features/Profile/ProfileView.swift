import SwiftUI
import UIKit

/// profileSeed: the "give to get" hub and the sprout's home.
/// Profile completeness IS the sprout's growth stage.
/// v0.3: language switch lives here (Auto / English / Português).
struct ProfileView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var showEditor = false
    @State private var showJovemAssessor = false
    @State private var showSectorSheet = false
    @State private var activeDimension: CompareDimension?
    // v0.9
    @State private var activeSignalSheet: SignalSheet?
    // v0.9.1
    @State private var showConcelhoSheet = false
    // v0.9.4
    @State private var showExplorer = false
    @State private var askingSalaryChange = false
    // v0.16
    @EnvironmentObject private var supporter: SupporterStore
    @State private var showSupport = false

    private var s: Strings { store.s }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("profileSeed")
                        .appFont(12)
                        .foregroundStyle(Theme.accent)
                    Text(s.profileTitle(store.displayName))
                        .appFont(22, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 8)

                supportCard
                progressCard
                currentSalaryCard
                nameCard

                demographicsSection
                workSection
                taxSection
                appSection

                Text(s.profileFooter)
                    .appFont(10)
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .sheet(isPresented: $showEditor) { SalaryEditorView() }
        .sheet(isPresented: $showExplorer) { SalaryExplorerSheet() }
        .salaryChangeConfirmation(
            isPresented: $askingSalaryChange,
            s: s,
            onChange: { showEditor = true },
            onExplore: { showExplorer = true }
        )
        .sheet(isPresented: $showJovemAssessor) { IRSJovemAssessorView() }
        .sheet(isPresented: $showSectorSheet) { SectorTenureSheet() }
        .sheet(item: $activeSignalSheet) { SignalSheetView(sheet: $0) }
        .sheet(isPresented: $showConcelhoSheet) { ConcelhoSheet() }
        .sheet(isPresented: $showSupport) { SupportSheet() }
        .sheet(item: $activeDimension) { dim in
            ProfilePickerSheet(dimension: dim)
        }
    }

    // MARK: Your work (v0.9)

    /// The signals added in v0.9. None of them are compared against yet, and the
    /// footnote says so: an app that asks for something and then pretends it is
    /// being used has spent trust it will need later.
    /// v0.9.3: the profile is grouped by what the question is ABOUT rather than by
    /// which version added it. Demographics, then the job, then tax.
    private var demographicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.demographicsTitle)

            ForEach(CompareDimension.all) { dim in
                dimensionRow(dim)
            }

            signalRow(
                icon: "person.2",
                title: s.genderRowTitle,
                value: store.gender?.label(pt: s.pt),
                hint: s.genderAddHint
            ) { activeSignalSheet = .gender }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.appSection)
            languageCard
            accentCard
            // The "Premium: free version" row went in v0.16. There is a real
            // purchase now, and its state is said twice on this screen already:
            // the card at the top, and the lock on the colour picker. A third
            // line that only ever reads "free version" would be wrong for
            // everyone who paid.
            InfoRow(label: s.privacyLabel, value: s.privacyValue)
            InfoRow(label: s.sourcesLabel, value: s.sourcesValue)
            // v1.0: which build this is. Nobody needs it until something is
            // wrong, and then it is the first thing anyone asks for.
            InfoRow(label: s.versionLabel, value: AppConfig.versionLine)
        }
    }

    // MARK: Support (v0.16)

    /// The first thing on the tab, above even the sprout.
    ///
    /// Accent-filled before purchase and quiet after, because the two states are
    /// asking for different things: one wants to be noticed, the other only needs
    /// to confirm that something happened. A supporter should not be sold to
    /// every time they open their own profile.
    @ViewBuilder
    private var supportCard: some View {
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

    /// The colour picker: always visible, only usable by supporters.
    ///
    /// Visible-but-locked rather than hidden, because the thing being sold should
    /// be something you can see. Tapping a locked swatch opens the sheet rather
    /// than doing nothing, so the lock explains itself instead of just refusing.
    private var accentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(s.supportColourTitle)
                    .appFont(12)
                    .foregroundStyle(Theme.textSecondary)
                if !supporter.isSupporter {
                    Image(systemName: "lock.fill")
                        .appFont(9)
                        .foregroundStyle(Theme.textFaint)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                ForEach(AccentTheme.allCases) { theme in
                    accentSwatch(theme)
                }
            }
            Text(supporter.isSupporter ? s.supportIconNote : s.supportColourLocked)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func accentSwatch(_ theme: AccentTheme) -> some View {
        let isOn = store.accent == theme
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
                .frame(height: 34)
                .opacity(supporter.isSupporter ? 1 : 0.45)
                .overlay(Circle().stroke(Theme.textPrimary.opacity(isOn ? 0.9 : 0), lineWidth: 2))
                .overlay(
                    Image(systemName: "checkmark")
                        .appFont(12, weight: .bold)
                        .foregroundStyle(theme.ink)
                        .opacity(isOn && supporter.isSupporter ? 1 : 0)
                )
                .accessibilityLabel(theme.label(pt: s.pt))
        }
        .frame(maxWidth: .infinity)
    }

    private var workSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.workSectionTitle)

            sectorRow

            signalRow(
                icon: "person.text.rectangle",
                title: s.jobRowTitle,
                value: store.jobTitle?.label(pt: s.pt),
                hint: s.jobAddHint
            ) { activeSignalSheet = .jobTitle }

            signalRow(
                icon: "building.columns",
                title: s.employerRowTitle,
                value: store.employerKind?.label(pt: s.pt),
                hint: s.employerAddHint
            ) { activeSignalSheet = .work }

            signalRow(
                icon: "clock",
                title: s.scheduleRowTitle,
                value: scheduleValue,
                hint: s.scheduleAddHint
            ) { activeSignalSheet = .work }

            signalRow(
                icon: "gift",
                title: s.variableRowTitle,
                value: variableValue,
                hint: s.variableAddHint
            ) { activeSignalSheet = .variablePay }

            Text(s.collectedNotComparedNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)
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

    /// One row of the v0.9 work section: filled shows the value and a pencil,
    /// empty shows the reason to fill it and an add pill. Same shape as the
    /// existing sector and dimension rows so the section does not read as bolted on.
    private func signalRow(
        icon: String,
        title: String,
        value: String?,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .appFont(18)
                    .foregroundStyle(value == nil ? Theme.textSecondary : Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appFont(14, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                    Text(value ?? hint)
                        .appFont(11)
                        .foregroundStyle(value == nil ? Theme.accent : Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if value == nil {
                    Text(s.addPill)
                        .appFont(11, weight: .medium)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9))
                } else {
                    Image(systemName: "pencil")
                        .appFont(14)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .opacity(value == nil ? 0.9 : 1)
        }
    }

    // MARK: Tax details (v0.6)

    /// Marital situation + dependants (also set in onboarding) and the IRS Jovem
    /// exemption, which lives only here. All three feed the real 2026 IRS estimate.
    private var taxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.taxSection)

            VStack(spacing: 14) {
                // v0.9.3: short labels and a fixed row height. "Casado, dois
                // titulares" wrapped, which made this row taller than the
                // dependants row underneath and the section look misaligned.
                HStack {
                    Text(s.maritalLabel)
                        .appFont(14)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Picker(s.maritalLabel, selection: $store.maritalSituation) {
                        ForEach(MaritalSituation.allCases) { m in
                            Text(m.shortLabel(pt: s.pt)).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accent)
                    .lineLimit(1)
                    .fixedSize()
                }
                .frame(height: Theme.fiscalRowHeight)

                Divider().overlay(Theme.cardBorder)

                HStack {
                    Text(s.dependentsLabel)
                        .appFont(14)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            if store.dependents > 0 { store.dependents -= 1 }
                        } label: {
                            Image(systemName: "minus.circle")
                                .appFont(20)
                                .foregroundStyle(store.dependents > 0 ? Theme.accent : Theme.textFaint)
                        }
                        Text("\(store.dependents)")
                            .appFont(16, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(minWidth: 18)
                        Button {
                            if store.dependents < 12 { store.dependents += 1 }
                        } label: {
                            Image(systemName: "plus.circle")
                                .appFont(20)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .frame(height: Theme.fiscalRowHeight)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            irsJovemCard
        }
    }

    private var irsJovemCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .appFont(12)
                    .foregroundStyle(Theme.accent)
                Text(s.irsJovemTitle)
                    .appFont(14, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(s.irsJovemSub)
                .appFont(11.5)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)

            // Primary path: the guided eligibility check.
            Button { showJovemAssessor = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .appFont(13)
                    Text(s.irsJovemCheck)
                        .appFont(13, weight: .medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .appFont(11)
                }
                .foregroundStyle(Theme.accent)
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.accentBorder))
            }
            .padding(.top, 2)

            // Manual fallback: set the exemption by hand.
            Text(s.irsJovemManual)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 4)

            HStack(spacing: 6) {
                ForEach(ProfileView.jovemOptions, id: \.value) { option in
                    jovemChip(option)
                }
            }

            Text(s.irsJovemNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
    }

    static let jovemOptions: [(label: String, value: Double)] = [
        ("100%", 1.0), ("75%", 0.75), ("50%", 0.5), ("25%", 0.25), ("Off", 0.0),
    ]

    private func jovemChip(_ option: (label: String, value: Double)) -> some View {
        let isSelected = abs(store.irsJovemExemption - option.value) < 0.001
        let title = option.value == 0 ? s.irsJovemOff : option.label
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { store.irsJovemExemption = option.value }
        } label: {
            Text(title)
                .appFont(12, weight: .medium)
                .foregroundStyle(isSelected ? Theme.ink : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    isSelected ? Theme.accent : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 9)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(isSelected ? Theme.accent : Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    /// The sprout's home: profile completeness rendered as growth.
    /// v0.9.3: the sprout stays, the seed vocabulary does not. The wording used
    /// to say "a tua semente" and count "1 of 5", which was already wrong: v0.9
    /// grew the profile from 4 signals to 10 while this card kept a hard-coded 5,
    /// so a fully filled profile read "11 de 5". It now counts the real signals,
    /// and turns green when there is nothing left to ask.
    private var progressCard: some View {
        let filled = store.profileFilledCount
        let total = store.signalTotal
        let done = filled >= total
        return HStack(spacing: 16) {
            SproutView(stage: store.sproutStage, size: 64, sways: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(done ? s.profileDoneTitle : s.profileProgressTitle)
                    .appFont(13)
                    .foregroundStyle(done ? Theme.accent : Theme.textSecondary)
                Text(s.profileProgressCount(filled, total))
                    .appFont(19, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text(done ? s.profileDoneSub : s.profileProgressSub)
                    .appFont(11.5)
                    .foregroundStyle(done ? Theme.accent : Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(done ? Theme.accentSoft : Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(done ? Theme.accentBorder : Color.clear, lineWidth: 1)
        )
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: filled)
    }

    private var currentSalaryCard: some View {
        Button { askingSalaryChange = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.yourSalary)
                        .appFont(12)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(eur(store.amount)) \(store.kind.label(pt: s.pt).lowercased()) · \(store.schedule.label(pt: s.pt))")
                        .appFont(16, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Image(systemName: "pencil")
                    .appFont(14)
                    .foregroundStyle(Theme.accent)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var nameCard: some View {
        HStack {
            Text(s.nameLabel)
                .appFont(14)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            TextField(s.namePlaceholder, text: $store.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .appFont(14, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    /// v0.3: language choice. Auto follows the device; English and Português force it.
    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.languageLabel)
                .appFont(14)
                .foregroundStyle(Theme.textPrimary)
            SegmentedPicker(options: AppLanguage.allCases, selection: $store.language) {
                $0.label(pt: s.pt)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Sector + tenure, opened as one sheet. Shows the current pick or an add prompt.
    private var sectorRow: some View {
        Button { showSectorSheet = true } label: {
            if let sector = store.sector {
                HStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .appFont(18)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.sectorRowTitle)
                            .appFont(14, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                        Text(sectorSubtitle(sector))
                            .appFont(11)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "pencil")
                        .appFont(14)
                        .foregroundStyle(Theme.accent)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .appFont(18)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.sectorRowTitle)
                            .appFont(14, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                        Text(s.sectorAddHint)
                            .appFont(11)
                            .foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    Text(s.addPill)
                        .appFont(11, weight: .medium)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9))
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .opacity(0.9)
            }
        }
    }

    /// "Torres Vedras · Oeste e Vale do Tejo". The derived region is always shown,
    /// because it is what the comparison actually uses.
    private func concelhoSubtitle(_ regionLabel: String) -> String {
        guard let concelho = store.concelho else { return regionLabel }
        return "\(concelho.name) · \(concelho.region.label)"
    }

    private func sectorSubtitle(_ sector: Sector) -> String {
        if let y = store.tenureYears {
            return "\(sector.label(pt: s.pt)) · \(s.yearsText(y))"
        }
        return sector.label(pt: s.pt)
    }

    private func dimensionRow(_ dim: CompareDimension) -> some View {
        Button {
            // v0.9.1: region is derived, so its row opens the município search.
            if dim.usesConcelhoPicker { showConcelhoSheet = true } else { activeDimension = dim }
        } label: {
            if let option = dim.selectedOption(in: store, pt: s.pt) {
                HStack(spacing: 12) {
                    Image(systemName: dim.icon)
                        .appFont(18)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dim.usesConcelhoPicker ? s.concelhoRowTitle : s.dimShort(dim.id))
                            .appFont(14, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                        Text(dim.usesConcelhoPicker ? concelhoSubtitle(option.label) : option.label)
                            .appFont(11)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "pencil")
                        .appFont(14)
                        .foregroundStyle(Theme.accent)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: dim.icon)
                        .appFont(18)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dim.usesConcelhoPicker ? s.concelhoRowTitle : s.dimShort(dim.id))
                            .appFont(14, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                        Text(dim.usesConcelhoPicker ? s.concelhoAddHint : s.dimProfileHint(dim.id))
                            .appFont(11)
                            .foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    Text(s.addPill)
                        .appFont(11, weight: .medium)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9))
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .opacity(0.9)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .appFont(14)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
