import SwiftUI

/// Chip picker for one profile signal (age / region / education / profession).
/// Shared by compareSeed (locked layer rows) and profileSeed (add/edit rows).
struct ProfilePickerSheet: View {
    let dimension: CompareDimension
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    private var s: Strings { store.s }

    /// Two chips across normally. Past an accessibility size one, with the
    /// label wrapping: two columns shrank "Higher (degree or more)" and still
    /// cut it to an ellipsis, so the reader could not read what they picked.
    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 150), spacing: 8)]
    }
    private var selectedID: String? { dimension.selectedID(store) }

    /// Preview: what the sprout will look like once this detail is planted.
    private var previewStage: Int {
        store.sproutStage(withExtra: selectedID == nil ? 1 : 0)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 34, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                // Scrolls, and can be pulled up to full height, for the room a
                // single column takes. Two detents, not one (rule 26).
                ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    SproutView(stage: previewStage, size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.dimSheetTitle(dimension.id))
                            .appFont(16, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                        if let note = s.dimSheetNote(dimension.id) {
                            Text(note)
                                .appFont(10)
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                }
                .padding(.top, 16)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(dimension.options(s.pt)) { option in
                        chip(option)
                    }
                }
                .padding(.top, 16)

                Text(s.sheetPrivacy)
                    .appFont(10)
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 16)

                if selectedID != nil {
                    Button {
                        dimension.select(store, nil)
                        dismiss()
                    } label: {
                        Text(s.removeDetail)
                            .appFont(12)
                            .foregroundStyle(Theme.textSecondary)
                            .underline()
                    }
                    .padding(.top, 12)
                }
                }
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func chip(_ option: DimensionOption) -> some View {
        let isSelected = option.id == selectedID
        return Button {
            dimension.select(store, option.id)
            dismiss()
        } label: {
            Text(option.label)
                .appFont(13, weight: isSelected ? .medium : .regular)
                .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.82)
                .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
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
}
