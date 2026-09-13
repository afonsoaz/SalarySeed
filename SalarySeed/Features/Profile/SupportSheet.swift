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
    /// Read here, not just inside `.appFont`, because `benefit` builds a `Font`
    /// by hand and this is what makes the sheet redraw when the reader's text
    /// size changes.
    @Environment(\.dynamicTypeSize) private var typeSize

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
        // v1.2 REMOVED `.presentationDetents([.large])`, which was why this
        // sheet could barely be closed.
        //
        // Once a sheet declares detents, UIKit routes a downward drag that
        // begins inside a scroll view to the DETENT gesture rather than to the
        // dismiss gesture. With only `.large` in the set there is no smaller
        // detent to travel to, so the drag rubber-banded and snapped back, and
        // the only thing that actually dismissed the sheet was the few points
        // of grabber at the very top. A sheet with no detents at all gets the
        // plain drag-anywhere-to-dismiss behaviour back.
        //
        // The other six sheets in the app declare the same thing and were left
        // alone: this is the one that was reported, and changing the house
        // pattern everywhere is a separate decision.
        .presentationDragIndicator(.visible)
        .onAppear { accentOnOpen = store.accent }
        .onDisappear { revertPreview() }
    }

    // MARK: Header

    /// v1.2 GAVE THIS SHEET A CLOSE BUTTON.
    ///
    /// There was one, and only on the `thanks` path: somebody who had already
    /// paid could close the sheet with a button, and somebody who had not could
    /// not. So the one reader with a reason to leave without acting was the one
    /// with no way to do it but a drag that did not work. It is an X rather
    /// than a full-width button because the full-width button on this screen is
    /// the one that takes money, and two of those would be a dark pattern
    /// pointed the wrong way.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                SproutView(stage: 5, size: 78, animatesIn: true, sways: true)
                    .accessibilityHidden(true)
                Spacer()
            }
            .overlay(alignment: .topTrailing) { closeButton }
            Text(s.supportTitle)
                .appFont(26, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
            Text(s.supportBody)
                .appFont(13.5)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

    /// Scales with the glyph inside it, and sits at Apple's 44 point minimum
    /// at the default size. Same shape as `PayslipCheckFlow.closeButton`.
    private var closeButton: some View {
        Button { commitAndClose() } label: {
            Image(systemName: "xmark")
                .appFont(14, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: max(44, Theme.scaled(34, typeSize)),
                       height: max(44, Theme.scaled(34, typeSize)))
                .background(Theme.card, in: Circle())
        }
        .accessibilityLabel(s.closeButton)
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
            // v1.2: the box scales with the glyph. `appFont(17)` takes this
            // emoji to roughly three times the size at the largest settings
            // inside a frame hardcoded at 24, and `frame` does not clip, so it
            // overdrew its own box and pushed into the text column beside it.
            // Exactly the bug already fixed in `PayslipSourceStep.choice`.
            Text(glyph)
                .appFont(17)
                .frame(width: Theme.scaled(24, typeSize), alignment: .leading)
                .accessibilityHidden(true)
            // The only place in the app that cannot use `.appFont`. That modifier
            // returns a View, and `Text + Text` needs both halves to still be
            // `Text`, so these two take the scaled size as a plain `Font`. Same
            // metrics, same result, spelled out because concatenation forces it.
            (Text(lead).font(.system(size: Theme.scaled(13.5, typeSize), weight: .semibold)).foregroundColor(Theme.accent)
             + Text(" ")
             + Text(rest).font(.system(size: Theme.scaled(13.5, typeSize))).foregroundColor(Theme.textSecondary))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Colours, previewable before paying

    private var swatches: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(s.supportColourTitle)
                .appFont(11, weight: .medium)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                ForEach(AccentTheme.allCases) { theme in
                    swatch(theme)
                }
            }
            Text(supporter.isSupporter ? s.supportIconNote : s.supportColourLocked)
                .appFont(10.5)
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
                        .appFont(13, weight: .bold)
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
                .appFont(11.5)
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
                .appFont(17, weight: .medium)
                .foregroundStyle(Theme.accent)
            Text(s.supportThanksBody)
                .appFont(12.5)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { commitAndClose() } label: {
                Text(s.closeButton)
                    .appFont(15, weight: .semibold)
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
                .appFont(16, weight: .semibold)
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
                    .appFont(11)
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // v1.2: this row is OUTSIDE the scroll view, so when it did not
            // fit it could not scroll and simply ran past the edge of the
            // sheet. Two single-line labels with no reflow branch, and in
            // Portuguese "Restaurar compra · Pagamento único, não é
            // subscrição" is 43 characters at 12pt against a 375pt screen
            // less 44pt of padding. It stacks past the threshold now, the way
            // every other row in the app that stopped fitting does.
            footerRow
        }
    }

    @ViewBuilder
    private var footerRow: some View {
        let restore = Button {
            Task { await supporter.restore(applyingTo: store) }
        } label: {
            Text(s.supportRestore)
                .appFont(12, weight: .medium)
                .foregroundStyle(Theme.textSecondary)
                .underline()
                .fixedSize(horizontal: false, vertical: true)
        }
        let oneOff = Text(s.supportOneOff)
            .appFont(12)
            .foregroundStyle(Theme.textFaint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

        if typeSize.isAccessibilitySize {
            VStack(spacing: 8) { restore; oneOff }
                .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 6) {
                restore
                Text("·")
                    .appFont(12)
                    .foregroundStyle(Theme.textFaint)
                oneOff
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
