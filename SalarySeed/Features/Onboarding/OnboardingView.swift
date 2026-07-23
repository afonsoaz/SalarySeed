import SwiftUI

/// First-run flow: warm welcome + name, then one number, then two toggles, then value.
/// No account, still inside the 10-second promise. The name is skippable.
struct OnboardingView: View {
    @EnvironmentObject private var store: SalaryStore
    @State private var step = 0
    @State private var nameText = ""
    @State private var amountText = "1500"
    @State private var kind: AmountKind = .gross
    @State private var schedule: PaySchedule = .fourteen
    @FocusState private var amountFocused: Bool

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            // faint light at the top, part of the sprout personality pass
            RadialGradient(
                colors: [Theme.accent.opacity(0.07), .clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                switch step {
                case 0: welcomeStep
                case 1: salaryStep
                default: detailsStep
                }
            }
            .padding(24)
        }
    }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var header: some View {
        HStack {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.trailing, 8)
            }
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14))
                Text("SalarySeed")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.accent)
            Spacer()
            if step > 0 {
                SeedDots(count: 4, current: step)
            }
        }
    }

    // MARK: Step 0, welcome + name

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                SproutView(stage: 2, size: 92, animatesIn: true, sways: true)
                Spacer()
            }
            .padding(.top, 26)

            Text(s.welcomeTitle)
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 22)
            Text(s.welcomeSub)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .padding(.top, 9)

            Text(s.welcomeAskName)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 28)
            TextField(s.welcomeNamePlaceholder, text: $nameText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.accent).frame(height: 2)
                }

            HStack(spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 12))
                Text(s.welcomePrivacy)
                    .font(.system(size: 11.5))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 20)

            Spacer()
            PrimaryButton(title: s.welcomeButton) {
                withAnimation { step = 1 }
            }
            Button {
                nameText = ""
                withAnimation { step = 1 }
            } label: {
                Text(s.welcomeSkip)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 12)

            SeedDots(count: 4, current: 0)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }

    // MARK: Step 1, the one number

    private var salaryStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 64)
            Text(s.salaryTitle)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(trimmedName.isEmpty ? s.salarySub : s.salarySubNamed(trimmedName))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("€")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.textSecondary)
                TextField("1500", text: $amountText)
                    .keyboardType(.numberPad)
                    .focused($amountFocused)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(s.perMonthSuffix)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.accent).frame(height: 2)
            }
            .padding(.top, 44)

            Spacer()
            PrimaryButton(title: s.continueButton) {
                withAnimation { step = 2 }
            }
        }
        .onAppear { amountFocused = true }
    }

    // MARK: Step 2, a couple of details

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 34)
            Text(s.grossOrNet)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            SegmentedPicker(options: AmountKind.allCases, selection: $kind) { $0.label(pt: s.pt) }
                .padding(.top, 12)

            Text(s.howManyMonths)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 34)
            Text(s.monthsHint)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
            SegmentedPicker(options: PaySchedule.allCases, selection: $schedule) { $0.label(pt: s.pt) }
                .padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 13))
                Text(s.fiveSeconds)
                    .font(.system(size: 12))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 34)

            Spacer()
            PrimaryButton(title: s.revealButton) {
                store.name = trimmedName
                store.amount = Double(amountText) ?? 1500
                store.kind = kind
                store.schedule = schedule
                store.hasOnboarded = true
            }
        }
    }
}

// MARK: Shared controls

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: 0x06281C))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct SegmentedPicker<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selection == option ? Theme.accent : .clear,
                            in: RoundedRectangle(cornerRadius: 11)
                        )
                        .foregroundStyle(
                            selection == option ? Color(hex: 0x06281C) : Theme.textSecondary
                        )
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
