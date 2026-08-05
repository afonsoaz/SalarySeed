import SwiftUI

/// v0.9: pick your job from the curated catalogue.
///
/// Search first, browse by family second. Free text is deliberately not offered:
/// "consultor IT", "IT consultant" and "consultora informática" have to land in
/// one cell, and once free text is allowed that never happens again.
struct JobTitleSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var expanded: JobFamily?

    private var s: Strings { store.s }

    private var results: [JobTitle] {
        JobTitleCatalog.search(query, pt: s.pt)
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

                HStack(spacing: 10) {
                    SproutView(stage: store.sproutStage(withExtra: store.jobTitleID == nil ? 1 : 0), size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.jobSheetTitle)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(s.jobNotCompared)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 14)

                searchField.padding(.top, 14)

                ScrollView {
                    if searching {
                        resultsList
                    } else {
                        familyList
                    }
                }
                .padding(.top, 10)

                if store.jobTitleID != nil {
                    Button {
                        store.jobTitleID = nil
                        dismiss()
                    } label: {
                        Text(s.removeDetail)
                            .font(.system(size: 12))
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

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            TextField(s.jobSearchPlaceholder, text: $query)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if searching {
                Button {
                    query = ""
                    dismissKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
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
            Text(s.jobNoResults)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 20)
        } else {
            VStack(spacing: 6) {
                ForEach(results) { title in
                    row(title, showFamily: true)
                }
            }
            .padding(.bottom, 12)
        }
    }

    private var familyList: some View {
        VStack(spacing: 6) {
            ForEach(JobFamily.allCases) { family in
                familySection(family)
            }
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func familySection(_ family: JobFamily) -> some View {
        let isOpen = expanded == family
        VStack(spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    expanded = isOpen ? nil : family
                }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: family.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 24)
                    Text(family.label(pt: s.pt))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 13)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            }

            if isOpen {
                ForEach(JobTitleCatalog.titles(in: family)) { title in
                    row(title, showFamily: false)
                }
            }
        }
    }

    private func row(_ title: JobTitle, showFamily: Bool) -> some View {
        let isSelected = title.id == store.jobTitleID
        return Button {
            store.jobTitleID = title.id
            dismissKeyboard()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.label(pt: s.pt))
                        .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    if showFamily {
                        Text(title.family.label(pt: s.pt))
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? Theme.ink.opacity(0.7) : Theme.textFaint)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
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
}
