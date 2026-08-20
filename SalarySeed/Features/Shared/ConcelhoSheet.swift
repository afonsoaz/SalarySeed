import SwiftUI

/// v0.9.1: pick your município. Search first, browse by district second.
///
/// Reused in three places (compareSeed, profileSeed, onboarding), so the list
/// itself is a separate view from the sheet chrome around it.
///
/// The selected row always shows the derived NUTS 2024 region underneath. That
/// derivation is the whole reason the question changed from region to município,
/// and hiding it would make the comparison look like it came from nowhere.
struct ConcelhoPickerList: View {
    @Binding var selectedID: String?
    /// Called after a pick, so the sheet can dismiss and onboarding can stay put.
    var onPick: ((Concelho) -> Void)?

    let s: Strings

    @State private var query: String = ""
    @State private var expanded: ConcelhoGroup?

    /// Written out rather than left to the memberwise initializer, because this
    /// is the one new view that takes parameters from another file and also holds
    /// private @State.
    init(selectedID: Binding<String?>, onPick: ((Concelho) -> Void)? = nil, s: Strings) {
        self._selectedID = selectedID
        self.onPick = onPick
        self.s = s
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var results: [Concelho] { ConcelhoCatalog.search(query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField

            ScrollView {
                if searching {
                    resultsList
                } else {
                    districtList
                }
            }
            .padding(.top, 10)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .appFont(14)
                .foregroundStyle(Theme.textSecondary)
            TextField(s.concelhoSearchPlaceholder, text: $query)
                .appFont(15)
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if searching {
                Button {
                    query = ""
                    dismissKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .appFont(15)
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var resultsList: some View {
        if results.isEmpty {
            Text(s.concelhoNoResults)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 20)
        } else {
            VStack(spacing: 6) {
                ForEach(results) { item in
                    row(item, showDistrict: true)
                }
            }
            .padding(.bottom, 12)
        }
    }

    private var districtList: some View {
        VStack(spacing: 6) {
            ForEach(ConcelhoCatalog.groups) { group in
                districtSection(group)
            }
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func districtSection(_ group: ConcelhoGroup) -> some View {
        let isOpen = expanded == group
        VStack(spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    expanded = isOpen ? nil : group
                }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "map")
                        .appFont(14)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)
                    Text(group.label)
                        .appFont(14)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .appFont(11)
                        .foregroundStyle(Theme.textFaint)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 13)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            }

            if isOpen {
                ForEach(ConcelhoCatalog.concelhos(in: group)) { item in
                    row(item, showDistrict: false)
                }
            }
        }
    }

    private func row(_ item: Concelho, showDistrict: Bool) -> some View {
        let isSelected = item.id == selectedID
        return Button {
            selectedID = item.id
            dismissKeyboard()
            onPick?(item)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .appFont(14, weight: isSelected ? .medium : .regular)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle(item, showDistrict: showDistrict))
                        .appFont(10)
                        .foregroundStyle(isSelected ? Theme.ink.opacity(0.7) : Theme.textFaint)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .appFont(12, weight: .semibold)
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Theme.accent : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isSelected ? Theme.accent : Theme.cardBorder, lineWidth: 1)
            )
        }
    }

    /// Selected rows always show the region the comparison will actually use.
    /// Browsing inside a district would repeat the district name on every row,
    /// so there it shows only the region.
    private func subtitle(_ item: Concelho, showDistrict: Bool) -> String {
        // v0.15: island concelhos have no district, so the region carries the row
        // on its own rather than showing an empty prefix.
        if showDistrict {
            guard let district = item.district else { return item.region.label }
            return "\(district.label) · \(item.region.label)"
        }
        return item.region.label
    }
}

/// The sheet wrapper used by compareSeed and profileSeed.
struct ConcelhoSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }

            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 34, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                header.padding(.top, 14)

                ConcelhoPickerList(
                    selectedID: Binding(
                        get: { store.concelhoID },
                        set: { store.concelhoID = $0 }
                    ),
                    onPick: { _ in dismiss() },
                    s: s
                )
                .padding(.top, 14)

                if store.concelhoID != nil {
                    Button {
                        store.concelhoID = nil
                        dismiss()
                    } label: {
                        Text(s.removeDetail)
                            .appFont(12)
                            .foregroundStyle(Theme.textSecondary)
                            .underline()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var header: some View {
        HStack(spacing: 10) {
            SproutView(stage: store.sproutStage(withExtra: store.concelhoID == nil ? 1 : 0), size: 26)
            Text(s.concelhoSheetTitle)
                .appFont(17, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
