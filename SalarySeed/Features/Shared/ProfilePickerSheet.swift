import SwiftUI

/// Chip picker for one profile signal (age / region / education / profession).
/// Shared by compareSeed (locked layer rows) and profileSeed (add/edit rows).
struct ProfilePickerSheet: View {
    let dimension: CompareDimension
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    private var s: Strings { store.s }
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

                HStack(spacing: 10) {
                    SproutView(stage: previewStage, size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.dimSheetTitle(dimension.id))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        if let note = s.dimSheetNote(dimension.id) {
                            Text(note)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                }
                .padding(.top, 16)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(dimension.options(s.pt)) { option in
                        chip(option)
                    }
                }
                .padding(.top, 16)

                Text(s.sheetPrivacy)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 16)

                if selectedID != nil {
                    Button {
                        dimension.select(store, nil)
                        dismiss()
                    } label: {
                        Text(s.removeDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .underline()
                    }
                    .padding(.top, 12)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func chip(_ option: DimensionOption) -> some View {
        let isSelected = option.id == selectedID
        return Button {
            dimension.select(store, option.id)
            dismiss()
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
}
