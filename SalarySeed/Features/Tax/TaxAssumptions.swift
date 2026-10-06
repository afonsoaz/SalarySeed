import SwiftUI

/// What the figures on Tax take for granted, stated and editable in one place.
///
/// PHASE TWO MOVED THESE HERE FROM PROFILE, and the reason is a locked rule
/// rather than tidiness: "state every assumption, unconditionally". Every IRS
/// figure on this screen depends on whether the reader is married, how many
/// dependants they have, whether IRS Jovem applies and which region's tables
/// were used, and until now the screen said none of the first three. The
/// answers lived in Profile's "Tax details", a screen away from the numbers
/// they change. Afonso chose to move them rather than show them in both places,
/// because two places to change one answer is an echo.
///
/// None of them is a profile signal, so moving them changed nothing about the
/// sprout or the "x of 10" count. The tax tables follow the município, which is
/// a profile answer and stays in Profile; tapping the row here opens the same
/// sheet Profile and Compare use, so all three always agree.
struct TaxAssumptions: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var showJovem = false
    @State private var showAssessor = false
    @State private var showConcelho = false

    private var s: Strings { store.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.taxAssumesTitle)

            VStack(spacing: 14) {
                maritalRow
                Divider().overlay(Theme.cardBorder)
                dependantsRow
                Divider().overlay(Theme.cardBorder)
                jovemRow
                if showJovem {
                    jovemDetail
                        .transition(.opacity)
                }
                Divider().overlay(Theme.cardBorder)
                tablesRow
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            // v0.15: which IRS tables produced these numbers. An islander needs
            // to know their figures are already regional, and a reader with no
            // município needs to know the app guessed. Silence would look the
            // same in both cases. The row above states the region either way.
            if store.taxRegionAssumed {
                footnote(s.taxRegionAssumedNote)
            } else if store.taxRegion != .continente {
                footnote(s.taxRegionNote(store.taxRegion.label(pt: s.pt)))
            }
        }
        .sheet(isPresented: $showAssessor) { IRSJovemAssessorView() }
        .sheet(isPresented: $showConcelho) { ConcelhoSheet() }
    }

    // MARK: Household

    /// v0.9.3 (in Profile): short labels and a fixed row height. "Casado, dois
    /// titulares" wrapped, which made this row taller than the dependants row
    /// underneath and the card look misaligned.
    private var maritalRow: some View {
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
        .frame(minHeight: Theme.fiscalRowHeight)
    }

    private var dependantsRow: some View {
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
                    .frame(minWidth: Theme.scaled(18, typeSize))
                Button {
                    if store.dependents < 12 { store.dependents += 1 }
                } label: {
                    Image(systemName: "plus.circle")
                        .appFont(20)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .frame(minHeight: Theme.fiscalRowHeight)
    }

    // MARK: IRS Jovem

    /// The state, always: "Off" or the share exempt. Tapping it opens the way to
    /// change it in place, rather than the whole explanation sitting open for
    /// the many readers it does not apply to.
    private var jovemRow: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { showJovem.toggle() }
        } label: {
            HStack {
                Text(s.irsJovemTitle)
                    .appFont(14)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(jovemValue)
                    .appFont(14, weight: store.irsJovemExemption > 0 ? .medium : .regular)
                    .foregroundStyle(store.irsJovemExemption > 0 ? Theme.accent : Theme.textSecondary)
                Image(systemName: "chevron.down")
                    .appFont(11, weight: .semibold)
                    .foregroundStyle(Theme.textFaint)
                    .rotationEffect(.degrees(showJovem ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.fiscalRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // No `.accessibilityValue` and no `.isSelected`, both removed in review:
        // the value is already a Text in the label, so VoiceOver read it twice
        // ("IRS Jovem, Off, Off"), and "selected" claimed a choice had been made
        // when the row had only been opened.
    }

    private var jovemValue: String {
        store.irsJovemExemption > 0
            ? s.irsJovemExemptValue(Int((store.irsJovemExemption * 100).rounded()))
            : s.irsJovemOff
    }

    /// What Profile's IRS Jovem card held: the guided check, then the manual
    /// fallback. Moved as it was, inside the card it now belongs to.
    private var jovemDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.irsJovemSub)
                .appFont(11.5)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Primary path: the guided eligibility check.
            Button { showAssessor = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .appFont(13)
                        .accessibilityHidden(true)
                    Text(s.irsJovemCheck)
                        .appFont(13, weight: .medium)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .appFont(11)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Theme.accent)
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.accentBorder))
            }

            // Manual fallback: set the exemption by hand.
            Text(s.irsJovemManual)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 4)

            // Five chips across fit at the default size; past an accessibility
            // size they would break "100%" in two, so they reflow onto rows of
            // three instead. Reflow, do not shrink.
            if typeSize.isAccessibilitySize {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                          spacing: 6) {
                    ForEach(Self.jovemOptions, id: \.value) { option in
                        jovemChip(option)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(Self.jovemOptions, id: \.value) { option in
                        jovemChip(option)
                    }
                }
            }

            Text(s.irsJovemNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Tables

    /// The region, always, and where it came from. A tap opens the município
    /// sheet, the only thing that can change it.
    private var tablesRow: some View {
        Button { showConcelho = true } label: {
            HStack(alignment: .center) {
                Text(s.taxTablesLabel)
                    .appFont(14)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(store.taxRegion.label(pt: s.pt))
                        .appFont(14, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.concelho?.name ?? s.taxTablesAssumed)
                        .appFont(11)
                        .foregroundStyle(store.taxRegionAssumed ? Theme.accent : Theme.textFaint)
                }
                .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.fiscalRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .appFont(10)
            .foregroundStyle(Theme.textFaint)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
