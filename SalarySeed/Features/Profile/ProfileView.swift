import SwiftUI

/// profileSeed (v0.2) — the "give to get" hub, now the sprout's home.
/// Profile completeness IS the sprout's growth stage: each planted signal grows it.
struct ProfileView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var showEditor = false
    @State private var activeDimension: CompareDimension?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("profileSeed")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.accent)
                        Text(store.displayName.map { "\($0)'s profile" } ?? "Your profile")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.top, 8)

                    yourSeedCard
                    currentSalaryCard
                    nameCard

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Add more, unlock more")
                        ForEach(CompareDimension.all) { dim in
                            dimensionRow(dim)
                        }
                        LockedRow(icon: "person.2", title: "Marital status / dependents", unlock: "Later: sharper IRS estimate")
                        LockedRow(icon: "doc.text", title: "CV upload", unlock: "Later: richest comparison + tips")
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.profileFilledCount)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("App")
                        InfoRow(label: "Language", value: "Auto (PT/EN) — coming soon")
                        InfoRow(label: "Premium", value: "Free tier (skeleton)")
                        InfoRow(label: "Privacy", value: "All data stays on this device")
                        InfoRow(label: "Data sources", value: "INE / GEP-MTSSS · CC BY 4.0")
                    }

                    Text("SalarySeed v0.2 · Estimates for guidance, not official tax or financial advice.")
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

    /// The sprout's home: profile completeness rendered as growth.
    private var yourSeedCard: some View {
        HStack(spacing: 16) {
            SproutView(stage: store.sproutStage, size: 64, sways: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your seed")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(1 + store.profileFilledCount) of 5 planted")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text("Each detail grows a sharper comparison — and feeds growthSeed later.")
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
                    Text("Your salary")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(eur(store.amount)) \(store.kind.label.lowercased()) · \(store.schedule.label)")
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
            Text("Name")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            TextField("Add your name", text: $store.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func dimensionRow(_ dim: CompareDimension) -> some View {
        Button { activeDimension = dim } label: {
            if let option = dim.selectedOption(in: store) {
                HStack(spacing: 12) {
                    Image(systemName: dim.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dim.shortName)
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
                        Text(dim.shortName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(dim.profileHint)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    Text("+ Add")
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
