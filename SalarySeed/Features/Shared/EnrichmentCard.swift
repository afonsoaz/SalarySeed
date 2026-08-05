import SwiftUI

/// v0.9: one question at a time, with the reason attached.
///
/// The card shows the next unanswered enrichment signal. Simple choices are
/// answered right here in one tap; the two that need more room (job title,
/// bonus) hand off to a sheet. "Not now" pushes the question to the back for
/// this session rather than hiding it forever.
struct EnrichmentCard: View {
    let signal: EnrichmentSignal
    let onOpenSheet: (EnrichmentSignal) -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var store: SalaryStore

    private var s: Strings { store.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: signal.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent)
                Text(s.enrichKicker)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
                Spacer()
                SproutView(stage: store.sproutStage(withExtra: 1), size: 20)
            }

            Text(s.enrichQuestion(signal.rawValue))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)

            Text(s.enrichWhy(signal.rawValue))
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            answerArea.padding(.top, 13)

            HStack {
                Text(s.enrichProgress(store.enrichmentAnswered, EnrichmentSignal.ordered.count))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
                Spacer()
                Button(action: onSkip) {
                    Text(s.enrichSkip)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .underline()
                }
            }
            .padding(.top, 12)
        }
        .padding(15)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.accentBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var answerArea: some View {
        switch signal {
        case .employerKind:
            VStack(spacing: 6) {
                ForEach(EmployerKind.allCases) { kind in
                    wideChip(kind.label(pt: s.pt)) { store.employerKind = kind }
                }
            }
        case .workSchedule:
            HStack(spacing: 8) {
                ForEach(WorkSchedule.allCases) { option in
                    chip(option.label(pt: s.pt)) {
                        store.workSchedule = option
                        if store.weeklyHours == nil { store.weeklyHours = option.defaultHours }
                    }
                }
            }
        case .gender:
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    chip(Gender.female.label(pt: s.pt)) { store.gender = .female }
                    chip(Gender.male.label(pt: s.pt)) { store.gender = .male }
                }
                HStack(spacing: 8) {
                    chip(Gender.other.label(pt: s.pt)) { store.gender = .other }
                    chip(Gender.preferNot.label(pt: s.pt)) { store.gender = .preferNot }
                }
            }
        case .jobTitle, .variablePay:
            // v0.12: the button says what pressing it DOES. It used to carry the
            // destination sheet's title, which meant the card asked "What do you
            // actually do?" and then offered a button reading "What do you do?",
            // so the only tappable thing on the card looked like a restatement of
            // the question rather than the way to answer it.
            Button { onOpenSheet(signal) } label: {
                Text(s.enrichOpenLabel(signal.rawValue))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.14)) { action() }
        } label: {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: Theme.chipHeight)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    private func wideChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.14)) { action() }
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
        }
    }
}

/// The sheet the enrichment card and profileSeed both drive.
enum SignalSheet: String, Identifiable {
    case jobTitle, work, variablePay, gender
    var id: String { rawValue }

    static func from(_ signal: EnrichmentSignal) -> SignalSheet {
        switch signal {
        case .jobTitle: return .jobTitle
        case .variablePay: return .variablePay
        case .gender: return .gender
        case .employerKind, .workSchedule: return .work
        }
    }
}

/// One place that maps a `SignalSheet` to its view, so compareSeed and
/// profileSeed cannot drift apart.
struct SignalSheetView: View {
    let sheet: SignalSheet

    var body: some View {
        switch sheet {
        case .jobTitle: JobTitleSheet()
        case .work: WorkDetailsSheet()
        case .variablePay: VariablePaySheet()
        case .gender: GenderSheet()
        }
    }
}
