import SwiftUI

/// v0.9: one question at a time, with the reason attached.
///
/// The next unanswered enrichment signal. It was a card on the Compare screen,
/// as tall as the comparisons above it, with the reason and the answers
/// spelled out on the page whether or not anybody wanted to answer. Phase two
/// made it one line on Compare in Portugal that opens the question in a sheet,
/// so the page reads as comparisons and the question is one tap away. The
/// sheet still gives the reason before the answers (no question without a
/// why), and "Not now" still pushes the question back for this session rather
/// than hiding it forever.

/// The line: what kind of thing it is, and the question itself.
struct QuickQuestionRow: View {
    @EnvironmentObject private var store: SalaryStore

    let signal: EnrichmentSignal
    let action: () -> Void

    private var s: Strings { store.s }

    var body: some View {
        Button(action: action) {
            GlyphLine(glyph: signal.icon, accessory: "chevron.right") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.enrichKicker)
                        .appFont(12)
                        .foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.leading)
                    Text(s.enrichQuestion(signal.rawValue))
                        .appFont(16, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.accentBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(RowPressStyle())
    }
}

/// The question, its reason, and the answers.
///
/// Simple choices are answered here in one tap, and the sheet closes. The two
/// that need more room (job title, bonus) hand over to their own sheet, which
/// the caller opens once this one has gone: `onHandOver` says which.
struct QuickQuestionSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    let signal: EnrichmentSignal
    let onHandOver: (EnrichmentSignal) -> Void
    let onSkip: () -> Void

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 34, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)

                    HStack(spacing: 9) {
                        Image(systemName: signal.icon)
                            .appFont(13)
                            .foregroundStyle(Theme.accent)
                            .accessibilityHidden(true)
                        Text(s.enrichKicker)
                            .appFont(12)
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        // What the sprout becomes once this is answered.
                        SproutView(stage: store.sproutStage(withExtra: 1), size: 24)
                            .accessibilityHidden(true)
                    }
                    .padding(.top, 16)

                    Text(s.enrichQuestion(signal.rawValue))
                        .appFont(20, weight: .medium)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    Text(s.enrichWhy(signal.rawValue))
                        .appFont(14)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    answerArea.padding(.top, 18)

                    HStack {
                        Text(s.enrichProgress(store.enrichmentAnswered, EnrichmentSignal.ordered.count))
                            .appFont(11)
                            .foregroundStyle(Theme.textFaint)
                        Spacer()
                        Button {
                            onSkip()
                            dismiss()
                        } label: {
                            Text(s.enrichSkip)
                                .appFont(13)
                                .foregroundStyle(Theme.textSecondary)
                                .underline()
                                .multilineTextAlignment(.trailing)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        // Two detents, never one: a single detent sends a downward drag that
        // starts in the scroll view to a detent gesture with nowhere to go, and
        // the sheet stops being dismissable by swiping (rule 26).
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    /// Answer, then close: the line behind moves on to the next question.
    private func answer(_ set: () -> Void) {
        set()
        dismiss()
    }

    @ViewBuilder
    private var answerArea: some View {
        switch signal {
        case .employerKind:
            VStack(spacing: 6) {
                ForEach(EmployerKind.allCases) { kind in
                    wideChip(kind.label(pt: s.pt)) { answer { store.employerKind = kind } }
                }
            }
        case .workSchedule:
            HStack(spacing: 8) {
                ForEach(WorkSchedule.allCases) { option in
                    chip(option.label(pt: s.pt)) {
                        answer {
                            store.workSchedule = option
                            if store.weeklyHours == nil { store.weeklyHours = option.defaultHours }
                        }
                    }
                }
            }
        case .gender:
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    chip(Gender.female.label(pt: s.pt)) { answer { store.gender = .female } }
                    chip(Gender.male.label(pt: s.pt)) { answer { store.gender = .male } }
                }
                HStack(spacing: 8) {
                    chip(Gender.other.label(pt: s.pt)) { answer { store.gender = .other } }
                    chip(Gender.preferNot.label(pt: s.pt)) { answer { store.gender = .preferNot } }
                }
            }
        case .jobTitle, .variablePay:
            // v0.12: the button says what pressing it DOES. It used to carry the
            // destination sheet's title, which meant the card asked "What do you
            // actually do?" and then offered a button reading "What do you do?",
            // so the only tappable thing on the card looked like a restatement of
            // the question rather than the way to answer it.
            Button {
                onHandOver(signal)
                dismiss()
            } label: {
                Text(s.enrichOpenLabel(signal.rawValue))
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private func chip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // Wraps rather than shrinks (reflow, do not shrink). The card it
            // came from shrank it to 82%, which a new sheet has no reason to.
            Text(label)
                .appFont(12.5)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: Theme.chipHeight)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        }
    }

    private func wideChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .appFont(13)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .appFont(10)
                    .foregroundStyle(Theme.textFaint)
                    .accessibilityHidden(true)
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

/// The sheet the quick question and profileSeed both drive.
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
