import SwiftUI

/// v0.13: your own row, field by field, before you decide anything.
///
/// WHY THIS EXISTS. Every consent screen in every app describes the data in a
/// paragraph and then asks to be believed. This app cannot do that and stay
/// consistent with itself: the whole product is built on showing the arithmetic
/// rather than asserting the result, and a privacy promise is just another
/// unshown calculation. So the row is printed. If the paragraph and the JSON ever
/// disagree, the user finds out from the app rather than from a journalist.
///
/// It is also the fastest way to notice the thing that matters most here, which
/// is what is NOT in the list. There is no name, no email, no concelho, no marital
/// situation, no dependants, no device, no location.
struct ContributionPreviewSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dismiss) private var dismiss

    private var s: Strings { store.s }

    /// Read once, when the sheet opens. Taking the current year here rather than
    /// inside the engine keeps `Contribution` free of a clock, which is what lets
    /// the Python port check it.
    private var year: Int { Calendar.current.component(.year, from: Date()) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let row = store.contributionPreview(year: year) {
                        jsonBlock(row)
                    } else {
                        Text(s.consentPreviewNoSalary)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    notSentYet
                    doneButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(s.consentPreviewTitle)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(s.consentPreviewSub)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Monospaced on purpose. This is not prose and should not be dressed as it:
    /// looking like a record is part of what makes it credible as one.
    private func jsonBlock(_ row: Contribution) -> some View {
        Text(row.prettyJSON())
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Theme.textPrimary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private var notSentYet: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
            Text(s.consentPreviewNothingYet)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accentBorder, lineWidth: 1))
    }

    private var doneButton: some View {
        Button { dismiss() } label: {
            Text(s.consentPreviewDone)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 15))
        }
    }
}
