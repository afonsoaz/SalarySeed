import SwiftUI

/// v0.8.3: pick your sector (GEP CAE) and your tenure in years. Both feed the
/// sector×tenure percentile in compareSeed. Shared by profileSeed and the
/// compare card. Local draft state commits only on "Save".
///
/// v0.9: the years asked for here are years AT THE CURRENT EMPLOYER. Quadro 104
/// bands "antiguidade na empresa", so asking about the sector put people in the
/// wrong cell. Only the wording changed; the value still lands in
/// `store.tenureYears` and indexes the same table.
struct SectorTenureSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    @State private var sel: Sector?
    @State private var years: Int = 3

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

                Text(s.sectorSheetTitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 14)
                Text(s.sectorNote)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 2)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                        ForEach(Sector.allCases) { sector in
                            chip(sector)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                }

                // Tenure only matters once a sector is chosen.
                if sel != nil {
                    Divider().overlay(Theme.cardBorder).padding(.vertical, 10)
                    Text(s.tenureQuestion)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    tenureStepper.padding(.top, 8)
                }

                Button {
                    store.sector = sel
                    store.tenureYears = (sel != nil) ? years : nil
                    dismiss()
                } label: {
                    Text(s.okButton)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x06281C))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.top, 12)

                if store.sector != nil {
                    Button {
                        store.sector = nil
                        store.tenureYears = nil
                        dismiss()
                    } label: {
                        Text(s.removeDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .underline()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            sel = store.sector
            years = store.tenureYears ?? 3
        }
    }

    private var tenureStepper: some View {
        HStack {
            Text(years == 0 ? TenureBand.lt1.label(pt: s.pt) : s.yearsText(years))
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
            Spacer()
            HStack(spacing: 16) {
                Button {
                    if years > 0 { withAnimation(.easeOut(duration: 0.12)) { years -= 1 } }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(years > 0 ? Theme.accent : Theme.textFaint)
                }
                Button {
                    if years < 40 { withAnimation(.easeOut(duration: 0.12)) { years += 1 } }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(years < 40 ? Theme.accent : Theme.textFaint)
                }
            }
        }
    }

    private func chip(_ sector: Sector) -> some View {
        let isSelected = sector == sel
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { sel = sector }
        } label: {
            Text(sector.label(pt: s.pt))
                .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
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
