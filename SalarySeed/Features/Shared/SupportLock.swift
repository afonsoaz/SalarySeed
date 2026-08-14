import SwiftUI

/// v1.0.1: what a non-supporter sees where Grow and the European map would be.
///
/// v1.0.1a REBUILT THIS AS AN OVERLAY. The first version was a full screen of its
/// own: a headline, a real computed figure, four bullets and a button. Every
/// piece of it was honest and it was still wrong, because it read as a
/// destination rather than as a hint. Somebody landing on the Grow tab saw a
/// well-made page about a thing they did not have, with no sense that a real
/// screen was sitting underneath it.
///
/// So the real screen is now drawn, blurred, and this sits on top of it. That
/// changes what the person is looking at: not an advert for a feature, but the
/// feature, out of focus. The shape of Grow's staircase and the 27 tiles of the
/// European grid are both recognisable through the blur, which does more to say
/// what is behind the payment than four bullet points did.
///
/// WHAT THIS COSTS, and it is worth being honest about because v0.16 wrote the
/// opposite rule. "Show the thing, then ask" was built on accent swatches that
/// recolour the app for real before payment, on the argument that a locked
/// feature you cannot see is a claim and one you can see is an offer. A blur is
/// deliberately between the two: you can see there is something there and you
/// cannot read it. That is a weaker promise than the swatches make, and it is
/// the trade Afonso chose after seeing both rendered, which is the right way for
/// that call to get made.
///
/// The blurred content is inert: no scrolling, no taps, no way to peer at a
/// figure by dragging. `allowsHitTesting(false)` rather than `.disabled`, because
/// disabled would grey the content out and the point is that it still looks like
/// itself.
struct SupportLock<Content: View>: View {
    @EnvironmentObject private var store: SalaryStore

    let title: String
    /// One or two lines. Anything longer turns the overlay back into a page.
    let blurb: String
    /// Bounds the blurred content, and MUST be set when the lock sits inside a
    /// scroll view rather than filling a tab.
    ///
    /// Found by rendering it. `MapView` wraps its whole screen in a `ScrollView`,
    /// so an unbounded lock became as tall as the European grid, and the card,
    /// centred in that, sat somewhere below the fold. The screen looked like a
    /// blurred map with no explanation and no way to pay, which is the worst
    /// possible version of this. Bounding the content makes the lock a block that
    /// fits on screen with the card centred in it.
    var contentHeight: CGFloat?
    /// Shifts the blurred content up so the peek lands on the part worth seeing.
    ///
    /// This is a CROP, the way you would frame a preview image, not a layout
    /// workaround. The European screen opens with a units toggle and a paragraph
    /// about which NACE section is being used, and the 27 tiles do not begin for
    /// another 200 points. Without the shift the blur showed two blocks of
    /// unreadable text, which says nothing about what is behind the payment.
    /// Grow needs none of this: its headline card is already the first thing.
    var contentOffsetY: CGFloat = 0
    @ViewBuilder let content: () -> Content

    @State private var showSupport = false

    private var s: Strings { store.s }

    var body: some View {
        ZStack {
            peek
            // Dims the whole thing a little so the card reads over the bright
            // parts of the chart. The card carries its own background too; one
            // layer alone either washes out the screen or loses the text.
            Theme.background.opacity(0.28)
            card
        }
        .frame(height: contentHeight)
        .clipped()
    }

    /// The blurred screen underneath.
    ///
    /// `fixedSize(vertical:)` IS THE WHOLE TRICK, and leaving it out produced a
    /// bug that looked like a wrong offset. `frame(height:)` PROPOSES that height
    /// to its child, so bounding the peek at 540 points did not crop the European
    /// screen, it squashed all nine of its sections into 540 points: the grid
    /// collapsed and the blur showed a compressed legend and country list instead
    /// of tiles. `fixedSize` tells the content to take its natural height whatever
    /// is proposed, and the container then clips it, which is what "a peek at the
    /// top of a tall screen" actually means.
    ///
    /// Only when bounded. Unbounded, the content is a full-screen scroll view
    /// with no natural height to fix.
    @ViewBuilder
    private var peek: some View {
        if let contentHeight {
            ZStack(alignment: .top) {
                Color.clear
                content()
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: contentOffsetY)
            }
            .frame(height: contentHeight, alignment: .top)
            .blur(radius: 6)
            .allowsHitTesting(false)
            // Clipped after the blur, or the halo bleeds past the edges and the
            // tab bar picks up a grey fringe.
            .clipped()
        } else {
            content()
                .blur(radius: 6)
                .allowsHitTesting(false)
                .clipped()
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            Image(systemName: "lock.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            Text(blurb)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Button { showSupport = true } label: {
                Text(s.lockButton)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 15))
            }
            .padding(.top, 20)
            Text(s.supportOneOff)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 9)
        }
        .padding(22)
        // TWO FILLS, and the first one is the point. `Theme.card` is
        // `white.opacity(0.05)`, a tint designed to sit ON the background: over
        // blurred content it does almost nothing, and the first render of this
        // card had the map showing straight through the text. So an opaque
        // background goes down first and the usual card tint sits on top of it,
        // which keeps the card looking like every other card in the app while
        // actually being opaque.
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.background)
                .overlay(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.cardBorder, lineWidth: 1))
        .padding(.horizontal, 28)
        .sheet(isPresented: $showSupport) { SupportSheet() }
    }
}
