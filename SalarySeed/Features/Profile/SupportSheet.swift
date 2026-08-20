import SwiftUI

/// v0.16: the one place the app asks for money.
///
/// A sheet rather than a dialog, because three benefits, a price, a restore and
/// a legal line is more than a dialog should hold, and because a dialog is a
/// thing you dismiss while a sheet is a thing you read.
///
/// WHAT THIS DELIBERATELY DOES NOT DO. No countdown, no "limited time", no
/// crossed-out higher price, no nagging on the tenth launch, no interstitial
/// anywhere else in the app. It opens when someone taps a button in their own
/// profile and at no other moment. An app whose entire argument is that it does
/// not manipulate the reader cannot manipulate the reader here.
///
/// The colour swatches are live BEFORE buying. Tapping one previews it across
/// the whole app behind the sheet, and closing without paying puts it back. That
/// is the honest version of a paywall: show the thing, then ask.
struct SupportSheet: View {
    @EnvironmentObject private var store: SalaryStore
    @EnvironmentObject private var supporter: SupporterStore
    @Environment(\.dismiss) private var dismiss

    /// What the accent was when the sheet opened, so a preview can be undone.
    @State private var accentOnOpen: AccentTheme?
    @State private var previewing: AccentTheme?

    private var s: Strings { store.s }

    /// v1.0.1 PINNED THE ACTIONS BELOW THE SCROLL.
    ///
    /// The benefit list went from three items to five, which pushed the price and
    /// the buy button off the bottom of a 6.1-inch screen. A payment button that
    /// has to be scrolled to is not a decision somebody declined, it is one they
    /// never saw, and the fix is the same one the onboarding consent step used
    /// for the same reason: the content scrolls, the choice does not move.
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        benefits.padding(.top, 22)
                        swatches.padding(.top, 22)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 22)
                }
                VStack(alignment: .leading, spacing: 0) {
                    // A hairline over the pinned actions. Without it the content
                    // scrolling underneath just stops mid-swatch, which reads as
                    // a clipping bug rather than as "there is more above". The
                    // rule is what makes the pinned area look like a bar.
                    Rectangle()
                        .fill(Theme.cardBorder)
                        .frame(height: 1)
                        .padding(.bottom, 14)
                    errorLine
                    actions.padding(.top, 4)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { accentOnOpen = store.accent }
        .onDisappear { revertPreview() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                SproutView(stage: 5, size: 78, animatesIn: true, sways: true)
                Spacer()
            }
            Text(s.supportTitle)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
            Text(s.supportBody)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

    // MARK: The three

    /// v1.0.1: five, and the order is the argument.
    ///
    /// What it funds comes first, because that is the honest reason and the one
    /// that survives if somebody thinks the features are thin. The two real
    /// screens come next. Colours fourth, because leading with them would make
    /// this feel like selling paint. The promise about later comes last, which
    /// is where a commitment belongs: it is what you are left holding after the
    /// list of things you can already see.
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(zip(glyphs, s.supportBenefits)), id: \.0) { glyph, item in
                benefit(glyph, lead: item.lead, rest: item.rest)
            }
        }
    }

    /// One glyph per benefit, in the same order. `zip` truncates to the shorter
    /// of the two, so a glyph left behind here after a benefit is cut would
    /// silently drop the LAST benefit off the screen rather than error. v1.0.2
    /// cut the "no ads" line and its 🌱 together for that reason.
    private let glyphs = ["📈", "🇪🇺", "🎨", "🎁"]

    /// The lead is bold and in the accent so the list can be read by scanning
    /// only the first few words of each line, which is what people actually do
    /// with a list of five. Built by concatenating two `Text` values rather than
    /// with an `AttributedString`: the two halves come from `Strings` already
    /// separated, so there is no marker inside a sentence for a translation to
    /// lose track of.
    private func benefit(_ glyph: String, lead: String, rest: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(glyph)
                .font(.system(size: 17))
                .frame(width: 24, alignment: .leading)
            (Text(lead).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.accent)
             + Text(" ")
             + Text(rest).font(.system(size: 13.5)).foregroundColor(Theme.textSecondary))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Colours, previewable before paying

    private var swatches: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(s.supportColourTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                ForEach(AccentTheme.allCases) { theme in
                    swatch(theme)
                }
            }
            Text(supporter.isSupporter ? s.supportIconNote : s.supportColourLocked)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func swatch(_ theme: AccentTheme) -> some View {
        let isOn = store.accent == theme
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                previewing = theme
                store.accent = theme
            }
            // The home-screen icon follows only for people who have paid. A
            // preview that rewrote the icon would put a colour on the home
            // screen that the sheet is about to take back, and iOS would show
            // its system alert for a change nobody bought.
            if supporter.isSupporter { AppIcon.apply(theme) }
        } label: {
            Circle()
                .fill(theme.accent)
                .frame(height: 40)
                .overlay(
                    Circle().stroke(Theme.textPrimary.opacity(isOn ? 0.9 : 0), lineWidth: 2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .opacity(isOn ? 1 : 0)
                )
                .accessibilityLabel(theme.label(pt: s.pt))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Errors

    @ViewBuilder
    private var errorLine: some View {
        if let code = supporter.lastError, let text = s.supportError(code) {
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
        }
    }

    // MARK: Buy, restore, close

    @ViewBuilder
    private var actions: some View {
        if supporter.isSupporter {
            thanks
        } else {
            buy
        }
    }

    private var thanks: some View {
        VStack(spacing: 12) {
            Text(s.supportThanksTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text(s.supportThanksBody)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { commitAndClose() } label: {
                Text(s.closeButton)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 15))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var buy: some View {
        VStack(spacing: 12) {
            Button {
                Task { await supporter.purchase(applyingTo: store) }
            } label: {
                Group {
                    if supporter.isPurchasing {
                        ProgressView().tint(Theme.ink)
                    } else if let price = supporter.displayPrice {
                        Text(s.supportCTA(price))
                    } else {
                        Text(s.supportPriceLoading)
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
            }
            // Disabled rather than hidden while the price is unknown: a button
            // that vanishes reads as a bug, one that waits reads as a moment.
            .disabled(supporter.product == nil || supporter.isPurchasing)
            .opacity(supporter.product == nil ? 0.5 : 1)

            if supporter.product == nil {
                Text(s.supportUnavailable)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Button {
                    Task { await supporter.restore(applyingTo: store) }
                } label: {
                    Text(s.supportRestore)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .underline()
                }
                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
                Text(s.supportOneOff)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Preview bookkeeping

    private func commitAndClose() {
        previewing = nil
        dismiss()
    }

    /// A non-supporter who played with the swatches gets their old colour back.
    /// A supporter keeps whatever they last tapped, because for them it was not
    /// a preview, it was the setting.
    private func revertPreview() {
        guard !supporter.isSupporter, let accentOnOpen, previewing != nil else { return }
        store.accent = accentOnOpen
    }
}
