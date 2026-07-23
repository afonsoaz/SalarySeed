import SwiftUI

/// profileSeed: the "give to get" hub and the sprout's home.
/// Profile completeness IS the sprout's growth stage.
/// v0.3: language switch lives here (Auto / English / Português).
struct ProfileView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var showEditor = false
    @State private var activeDimension: CompareDimension?

    private var s: Strings { store.s }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("profileSeed")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.accent)
                        Text(s.profileTitle(store.displayName))
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.top, 8)

                    yourSeedCard
                    currentSalaryCard
                    nameCard

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(s.addMore)
                        ForEach(CompareDimension.all) { dim in
                            dimensionRow(dim)
                        }
                        LockedRow(icon: "doc.text", title: s.cvTitle, unlock: s.cvHint)
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)

                    taxSection

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(s.appSection)
                        languageCard
                        InfoRow(label: s.premiumLabel, value: s.premiumValue)
                        InfoRow(label: s.privacyLabel, value: s.privacyValue)
                        InfoRow(label: s.sourcesLabel, value: s.sourcesValue)
                    }

                    Text(s.profileFooter)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textFaint)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .sheet(isPresented: $showEditor) { SalaryEditorView() }
            .sheet(item: $activeDimension) { dim in
                ProfilePickerSheet(dimension: dim)
            }
        }
    }

    // MARK: Tax details (v0.6)

    /// Marital situation + dependants (also set in onboarding) and the IRS Jovem
    /// exemption, which lives only here. All three feed the real 2026 IRS estimate.
    private var taxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.taxSection)

            VStack(spacing: 14) {
                HStack {
                    Text(s.maritalLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Picker(s.maritalLabel, selection: $store.maritalSituation) {
                        ForEach(MaritalSituation.allCases) { m in
                            Text(m.label(pt: s.pt)).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accent)
                }

                Divider().overlay(Theme.cardBorder)

                HStack {
                    Text(s.dependentsLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            if store.dependents > 0 { store.dependents -= 1 }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(store.dependents > 0 ? Theme.accent : Theme.textFaint)
                        }
                        Text("\(store.dependents)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(minWidth: 18)
                        Button {
                            if store.dependents < 12 { store.dependents += 1 }
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
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
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text(s.irsJovemTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(s.irsJovemSub)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)

            HStack(spacing: 6) {
                ForEach(ProfileView.jovemOptions, id: \.value) { option in
                    jovemChip(option)
                }
            }
            .padding(.top, 2)

            Text(s.irsJovemNote)
                .font(.system(size: 10))
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? Color(hex: 0x06281C) : Theme.textSecondary)
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
    private var yourSeedCard: some View {
        HStack(spacing: 16) {
            SproutView(stage: store.sproutStage, size: 64, sways: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.yourSeed)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text(s.planted(1 + store.profileFilledCount, of: 5))
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(s.seedSub)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var currentSalaryCard: some View {
        Button { showEditor = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.yourSalary)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(eur(store.amount)) \(store.kind.label(pt: s.pt).lowercased()) · \(store.schedule.label(pt: s.pt))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accent)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var nameCard: some View {
        HStack {
            Text(s.nameLabel)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            TextField(s.namePlaceholder, text: $store.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    /// v0.3: language choice. Auto follows the device; English and Português force it.
    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.languageLabel)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
            SegmentedPicker(options: AppLanguage.allCases, selection: $store.language) {
                $0.label(pt: s.pt)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func dimensionRow(_ dim: CompareDimension) -> some View {
        Button { activeDimension = dim } label: {
            if let option = dim.selectedOption(in: store, pt: s.pt) {
                HStack(spacing: 12) {
                    Image(systemName: dim.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.dimShort(dim.id))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(option.label)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: dim.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.dimShort(dim.id))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(s.dimProfileHint(dim.id))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    Text(s.addPill)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: 0x06281C))
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
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
