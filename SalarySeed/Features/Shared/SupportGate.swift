import SwiftUI

/// v1.0.1: what a non-supporter sees where Grow and the European map would be.
///
/// THIS REVERSES A v0.16 DECISION, deliberately, and the reasoning is worth
/// keeping because the old one was right for what the app was then. v0.16 said
/// the support sheet opens from the profile and from nowhere else: no
/// interstitial, no nag, ask once where they came looking. That fitted a €2.99
/// payment that unlocked five colours, where anything louder would have been
/// selling paint.
///
/// v1.0.1 puts two real features behind the payment, and a feature nobody can
/// find is not a feature. The tab has to say what it is. What the old decision
/// still forbids, and what this view is careful not to become, is a nag: it
/// appears only where the paid thing actually lives, it never interrupts
/// anything, it cannot pop up over a screen somebody was using, and there is no
/// counter, countdown or crossed-out price anywhere in it.
///
/// IT SHOWS ONE REAL NUMBER, computed from the user's own salary. That is the
/// other v0.16 decision, and this one is kept rather than reversed: the accent
/// swatches recolour the whole app before payment, because a locked feature you
/// cannot see is a claim and one you can see is an offer. A gate that only
/// described Grow in words would be asking people to buy a paragraph. The taste
/// is the honest version of the same figure they would get after paying, not a
/// teaser number picked to look good.
struct SupportGate: View {
    @EnvironmentObject private var store: SalaryStore

    /// SF Symbol for the header.
    let symbol: String
    let title: String
    let blurb: String
    /// The one computed figure. Absent when the profile does not have enough in
    /// it to produce one, in which case the gate degrades to words rather than
    /// showing a zero.
    var tasteLabel: String?
    var tasteValue: String?
    var tasteNote: String?
    /// What is behind the gate, one short line each.
    let bullets: [String]

    @State private var showSupport = false

    private var s: Strings { store.s }

    /// NO ScrollView of its own, deliberately.
    ///
    /// `MapView` already wraps its whole screen in one, and a vertical scroll
    /// view nested directly inside another gets an unbounded height proposal:
    /// it happens to render when the content fits and goes wrong the moment it
    /// does not, which is the worst way for a layout bug to behave. So this is
    /// plain content, and whoever places it decides whether it scrolls.
    /// `GrowView` wraps it; `MapView` does not need to.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let tasteLabel, let tasteValue {
                tasteCard(label: tasteLabel, value: tasteValue, note: tasteNote)
            }
            bulletList
            button
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showSupport) { SupportSheet() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.accent)
                Spacer()
            }
            .padding(.top, 22)
            Text(title)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
            Text(blurb)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
        }
    }

    /// The real figure, in the accent, formatted the way the paid screen would
    /// format it. It carries a note saying what it assumes, because a projection
    /// with its assumptions hidden is the kind of number this app does not print.
    private func tasteCard(label: String, value: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Theme.accent)
            if let note {
                Text(note)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder, lineWidth: 1))
        .padding(.top, 20)
    }

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(s.gateWhatYouGet)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 1)
            ForEach(bullets, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 14)
                        .padding(.top, 2)
                    Text(line)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 22)
    }

    /// One button, and it opens the sheet rather than the App Store.
    ///
    /// Nothing is bought from here. The gate's job is to say what is behind it;
    /// the price, the full list and the payment all live on the one sheet that
    /// has always been the only place money is asked for. Two places to buy
    /// would be two places to keep the price honest.
    private var button: some View {
        VStack(spacing: 0) {
            PrimaryButton(title: s.gateSeeWhatSupportGets) { showSupport = true }
            Text(s.supportOneOff)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .padding(.top, 26)
    }
}
