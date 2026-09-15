# Changelog

What changed in each version and why, including the bugs that shipped and what they cost.
Versions before 1.0 were never released; they are here because the mistakes in them are
the reason later versions are shaped the way they are.

**v1.4**: Home holds one number, and the rest is a scroll away.

Home had eleven blocks in one scroll, and the first screenful carried the pay figures, a
percentage card, an edit button and a share-of-cost bar before the reader had read anything.
It now holds the top bar, a one-line greeting and the net figure, sized to exactly one
screen, with an invitation at the bottom. Everything about what comes off the salary lives
below that line, which is where somebody goes looking for it.

**The default look moved, deliberately.** 30pt gross and net side by side became a 44pt net
figure over a 20pt gross annotation. The locked Type rules say `UIFontMetrics` returns the
design size unchanged at the default setting, so a change that moves the default look is a
design decision and has to be named as one. This is that. 44 was measured rather than
judged: it resolves to 67pt at `accessibility-extra-large`, where the widest figure the
screen ever draws is 334 points of the 335 available, so `minimumScaleFactor` never
engages. The old pair was in fact the cramped one, with 153 points per column.

Four things came off the screen and one merged. The "Update my salary" row is gone, and its
job moved onto the figure: the whole hero block is the button, with an 11pt pencil on the
label as the affordance, because a bare figure is not discoverable as a control and nothing
else in the app makes one tappable. The percentage card merged INTO `BreakdownBar` rather
than moving next to it, because the two were an echo: the card printed the percentage that
the bar's own net segment draws, forty points above it, with a second sentence saying the
same thing. The bar gained the headline it never had and `shareOfCost` was deleted rather
than left unreferenced. The period picker left the top bar for the fold, under the figure it
changes, which also deleted the v1.0.3 two-row accessibility branch: that branch existed
only because the 188pt picker was the immovable thing in the row, and a reflow for a row
that no longer overflows is a branch nobody can check.

**The fold had to be measured, and the obvious formula was wrong.** `minHeight` comes from a
`GeometryReader` in a `.background` on the ScrollView, never from its content, so the
measurement cannot feed back into itself. It uses `g.size.height` raw. Subtracting
`safeAreaInsets` looks obviously right and takes them off a number they have come off
already: on an iPhone 17 that is 584 points against 756, and the symptom is a fold ending a
third of the way up the screen with the next section sitting in plain sight beneath an
invitation to scroll to it. That was found by putting the number on screen rather than by
reasoning about it, which is the only reason it was found at all.

The see-more prompt is inline and not pinned, and rule 24 is the reason rather than an
oversight: `safeAreaInset(edge: .bottom)` is the right way to pin a control in a tab, but it
reserves its height permanently and would shrink the very viewport the fold is sized to,
and animating that inset away to hide the prompt is the layout feedback loop. It hides with
opacity and never with `if`, because removing it shortens the content, which can move the
scroll offset, which can flip the condition that hid it straight back. Two thresholds 16
points apart stop it fluttering at the boundary.

Known and not fixed: `SegmentedPicker` at an accessibility size runs "Mês ×12" and "Mês ×14"
together with no gap. It did that before on its own row too, so nothing regressed, but the
picker is now a permanent resident of the fold and it is more visible there.

**v1.3**: Everything is free, and the payment is switched off rather than deleted.

Afonso is on a J-1 visa and is not authorised to work, so a launch that earns nothing is the
one he can make. Grow, the European half of the map, the five accents and the alternate
icons were behind a €4.99 non-consumable and are now simply part of the app.

The interesting part is what was NOT done. The payment is not on a branch and it is not
deleted: `AppConfig.monetisation` is a constant with two cases, and `.free` is what ships.
`SupporterStore.isSupporter` is forced true in `init`, `start` returns before the first
StoreKit call, and `ProfileView.supportCard` draws nothing. That is the whole change. All
five gates in the app read that one boolean, so Grow, the European grid, the padlock on the
accent swatches and the dimmed swatches themselves all came right with no edit at the call
sites, and `SupportLock` and `SupportSheet` are still compiled on every build with nothing
able to reach them.

A branch was the obvious alternative and this repo already ran that experiment. `pool-backend`
was parked at v1.0, and by v1.2 it was two releases and about two hundred files behind
master, because nothing compiles a branch nobody checks out. A constant cannot rot that way:
both halves go through the compiler every time, and the release check is to flip it to
`.supporter`, confirm the gates and the simulator purchase still work, and flip it back.
That was done, and they do.

**One thing that looks like a shortcut and is a bug.** Making the free build entitled by
calling the existing `apply(true, to:)` would also write `true` into the
`supporter.entitled` cache. The cache exists to stop a first-frame flicker, so a stale
`true` would show the paid screens to somebody who had not paid for exactly one frame on
the day the payment came back. Free mode sets the published property and leaves the cache
alone. A v1.2 payer's own cached `true` is left alone too, which is the same rule pointing
the other way.

**The thank-you card was the near miss.** With `isSupporter` true, Profile's support card
would have drawn "You are a SalarySeed supporter. Whatever comes later is yours." at every
single user, none of whom paid anything. The card is gone entirely in a free build. No copy
was added or changed anywhere, so `docs/copy.md` still round-trips at 591 pairs, and the
roughly 26 support and lock pairs sit in `Localization.swift` waiting.

If the payment ever returns it cannot be taken from the people who already have these
screens. `AppTransaction.shared.originalAppVersion` says which version somebody first
downloaded, it is iOS 16 and up so the iOS 17 floor is fine, and anyone at or below 1.3 has
to stay entitled for nothing. That is retroactive, so it needs no flag stored now, and there
is none.

`README.md` and `PRIVACY.md` were rewritten in the same commit. The privacy claim got
stronger rather than weaker: there is no longer one exception for StoreKit, because in a
free build no code path in the app opens a network connection at all. The App Store privacy
answers and `PrivacyInfo.xcprivacy` did not change, because they were always about storage
and nothing about storage moved.

**v1.2**: The payslip checker becomes a tab, the bottom bar becomes Apple's, and the reader
gets measured.

The checker was the most interesting thing in the app and it was a card near the bottom of
Home, behind a full-screen cover. It is a tab now, with a landing screen that says what the
ten checks are before it asks for a file rather than after. A native iPhone tab bar shows
five items and collapses the rest into a system "More" list, so something had to leave, and
it was Profile: it is the only one of the six that is settings rather than an answer, and it
is now reached from the top of Home. That slot cost nothing, because it held a pencil that
opened the same thing as the full-width button two rows below it.

The bar itself is Apple's. It was a paged `TabView` with a hand-drawn bar pushed in through
`safeAreaInset`, which meant the app had no UIKit tab bar anywhere in it, and paid for
swiping between tabs with everything the real control does for free: the material, the
scroll-edge effect, minimising on scroll, the accessibility semantics, and on iOS 26 the
glass, which arrives with no code as long as nothing sets `UITabBar.appearance()` to
something opaque. Swiping between tabs is gone and so is Grow's permanently tinted item; a
real tab bar tints the selected item and only that one.

**One promise got narrower and it is worth saying exactly how.** A tab has no closing
moment, so "close this screen and it is gone" stopped being true and had to go. What
replaced it is smaller and exact: nothing about a payslip is ever written to the phone,
there is no history, and the reading is replaced when you check another or gone when the app
quits. What genuinely changed is the window. A verdict now sits in memory for as long as the
app is alive, rather than until a screen closes. `PRIVACY.md`, the privacy manifest's comment
and the copy on the screen all say the new thing, in the same commit. The App Store privacy
answers did not change, because nothing reaches storage, which is the only thing they are
about.

Three bugs found by running it rather than by reading it. The profile button was the sprout
first, which was the tempting answer because the sprout already grows with the profile: on
screen it was a second sprout eighteen points from the wordmark's, and at stage 1, where
somebody who just finished onboarding actually is, it draws a hairline stalk that reads as a
smudge. It is a person now. The pinned buttons in three payslip steps were siblings under a
scroll view, which was the same thing as a `safeAreaInset` in a cover and is not in a tab:
iOS 26's bar floats over the content and does not reserve room, so the bar was winning taps
meant for the button. And Grow's blurred peek looked broken until the profile had a sector
in it, which turned out to be the screen behaving correctly.

Home's efficiency card is a percentage. It read "Of every €100 your company spends," over
"€63 reaches your pocket"; `efficiency` is a ratio, and €100 was a device for making a
ratio picturable. It is now "63%" with the sentence beside it, whole numbers, and
deliberately not through `HomeView.pct`, which formats with a POSIX decimal point and would
have printed "63.4%" next to a "1 234,56 €".

The support sheet could barely be closed and overflowed sideways, and both were real.
`.presentationDetents([.large])` was the first: once a sheet declares detents, a downward
drag beginning inside a scroll view is routed to the detent gesture, and with only `.large`
in the set there is nowhere to travel, so it rubber-banded instead of dismissing. The few
points of grabber at the top were the only thing that worked, and the non-supporter path had
no close button at all, so the one reader with a reason to leave without paying was the one
with no way to do it. The detents are gone and there is an X. The overflow was two places
that could not scroll because they were never in the scroll view: an emoji in a frame
hardcoded at 24 points while the glyph itself scaled with Dynamic Type, and a
"Restaurar compra / Pagamento único" row with no reflow branch, which in Portuguese is 43
characters at 12pt against a 375 point screen.

**`docs/copy.md`** is every line of prose in the app, 590 pairs in both languages, grouped by
screen. Generated by `tools/dump_copy.py` from the file that ships, because a hand-written
copy of 590 strings is wrong the day after it is written, and `--verify` reads it back and
proves it still matches. It refuses to skip quietly: if a `t(` call is a shape the scanner
cannot read, it fails rather than producing a document that is simply shorter than the app.
That caught `perPeriod`, which hid its pair inside two ternaries, and `payslipWhatItems`,
which was written as one ternary over two arrays. Both are pairs now.

And the reader got measured, which is the half of this release that is not about screens.

The reader had never been measured. It was built against two real payslips, both since
deleted from this machine on purpose, and the four files that make a judgement about a page
had no automated coverage at all. `tools/payslip_corpus` generates payslips whose every
figure comes from the app's own `TaxEngine`, so unlike a real payslip they have an answer
key, and `tools/score_payslip_corpus.py` scores the shipping reader against 24 of them
across three extraction paths and 144 degraded images. Results in
`docs/payslip-accuracy.md`, along with what the corpus cannot tell you, which is most of
what a sceptic would ask.

Two metrics fail that script and nothing else does: a `wrong` finding on a page generated
to be correct, and a verdict on something that is not a payslip. Both are zero, as is the
number that decides whether a payslip may fill in somebody's salary: a gross that was wrong
and silently accepted. The gross survives a poor photograph better than anything else on the
page, because it is recovered from the 11% Social Security identity rather than from a
label, and its score is identical from a clean render down to a bad photo.

It found a real bug first. Thousands separated by a space were being dropped from every
figure on the PDF text path: "2 400,00" read as 400,00. The join tolerance that rejoins a
thousands group was measured against Vision's real per-word extents, where a thousands space
is narrower than a digit, but the text path synthesises its coordinates from character
offsets, where a single space is always exactly one character width and the tolerance could
never be met. Portuguese payslips commonly print 1 234,56. It failed safe, so all ten checks
declined rather than accusing anybody, which is why nobody noticed. The one fixture in the
repo prints 2.400,00 with a dot.

Then the feature that measurement was for. The checker now ends by asking whether the
monthly gross it read should become your salary, and onboarding offers to read a payslip
instead of typing a number. The ask comes AFTER the verdict, never on the way to it, so the
decision is made knowing what the app just found wrong with the payslip. `PayslipSalary`
refuses rather than guesses, with four named reasons, and cross-checks the gross it found by
the 11% identity against the printed earnings total. It never proposes a net, because a
payslip's liquido is not the app's net salary. Onboarding fills the FIELD and not the store,
so `commitAnswers()` is still the only writer and a misread payslip is a wrong number you
can see and fix.

That narrows a promise `PRIVACY.md` made in absolute terms, and the sentence has been
rewritten rather than reasoned around: the file and everything read from it are gone when
the screen closes, and the only thing that can outlive it is a figure you tapped to keep.
Nothing else follows it, and a flag recording that a number came from a payslip is
explicitly forbidden, because that is a one-bit payslip history.

**The polish pass, after the rest of v1.2 was working.** Afonso pointed at two things and
both turned out to be classes rather than instances.

"Weird spacing in the 2nd line" on the Profile rows was SwiftUI centring the text inside a
`Button` label, which it does unless told otherwise. A one-line title never reveals it; a
subtitle that wraps does, and the second line sits centred under a left-aligned first one.
Twelve rows had it.

The sentence beside Home's percentage was aligned to the figure's baseline, so on the two
lines it actually occupies the figure clung to the first and the second hung below it. It is
centred now.

Chasing the first one turned up eight copies of the same row in Profile and Compare, each
with three faults: an icon in a `frame(width: 28)` while the glyph scaled with the reader's
text size, so it drew out of its box and over the title; a "+ Adicionar" pill with no line
limit, which broke mid-word into "+ Adicion / ar"; and no reflow at all, so the title column
came out about ninety points wide and every word wrapped. `SignalRow` is now one row used
eight times. The scaling-glyph bug had already been found and fixed twice before, in
`PayslipSourceStep` and `SupportSheet`, and neither fix could reach these because there was
nothing shared to fix. `tools/audit_layout.py` looks for both shapes now; it found six more
fixed boxes after the migration, and they are fixed too.

Every rate in the app was formatted with `String(format: "%.1f%%")`, which is C rather than
a formatter and writes a POSIX decimal point whatever the language. Home read "2400 EUR" and
"80.8% do custo" in the same card, eleven points apart, one number Portuguese and the next
American. `percent(_:decimals:signed:)` in `Theme` is the one path now, in the pt_PT locale
`eur` has always used.

Scrolled content ran straight under the status bar, white on near-black, so figures read
through the clock. `scrollEdgeEffectStyle(.soft, for: .top)` is the iOS 26 API for exactly
this, and it does nothing here, because the effect is drawn by a bar at that edge and none of
these screens has one. A scrim in the page's own colour does the job: invisible where there
is nothing under it, and the content dissolves into it instead of meeting a line.

`.tabBarMinimizeBehavior(.onScrollDown)` came out again. It was added in v1.2 because it is
what iOS 26 does, and on screen it collapsed the bar to a circle that floated over a card and
cut a line of text in half, while putting the other four tabs out of reach until you scrolled
back up.

**And one process bug worth recording.** There are two `SalarySeed-*` DerivedData folders on
this machine, one abandoned since July, and the shell used to pick a build directory with
`find ... | head -1`. It picked the stale one, installed a July binary, and a screenshot
taken to confirm a fix showed an app that did not have it. Nothing errored; the tab bar
quietly had the old tabs in it. `tools/run_sim.sh` asks `xcodebuild -showBuildSettings` which
folder this scheme actually builds into, and prints the binary's timestamp.

**The profile gets found.** v1.2 moved Profile out of the tab bar and left one grey glyph on
one screen as the way back in, which is thin for the screen every cohort in the app is
computed from. It is accent green now and it is in all five headers.

Two of the five had to make room. Compare's top-right held a sprout and "3 de 10" that said
something true and led nowhere, eighteen points from a second sprout in Home's own corner;
the count moved to the new card and the slot now holds the way in. Grow handed its entire
screen to `SupportLock`, title included, so a button there would have been blurred and inert
for exactly the people who have not paid: the title row is lifted out of the lock, which also
makes the locked screen read as "this screen, out of focus" rather than "everything, out of
focus", which is what that component's own comment says it is for.

**Home says what is missing.** A green card above the detail section: how many of the ten
profile signals are filled, why that matters, and a tap into Profile. It disappears at 10/10
and cannot be dismissed, which is not the same thing as a nag: it never interrupts, never
counts launches, has no countdown and no second ask. It reads `store.signalTotal` rather than
the number 10, because the card in Profile that hard-coded a total spent several releases
reading "11 de 5" after the profile grew underneath it.

Compare keeps its one-question-at-a-time card. Dropping it there was the plan for about ten
minutes, until it turned out Compare was its only caller and the deletion would have taken
`Enrichment.swift` and forty-six copy pairs out of a document that is currently being
reviewed.

Two layout bugs found by looking. The payslip header aligned on `.firstTextBaseline`, which
asks an `Image` for a baseline it does not have and gets its bottom edge instead, so the new
44 point button dragged "payslipSeed" 44 points down the screen; it looked exactly like a
navigation bar appearing, and hiding the toolbar changed nothing. And the card's sprout was
drawn at 30 points, which at three of ten is a thin seedling in an empty column: the state
the card spends most of its life in was the state it looked worst in.


**v1.1**: The payslip checker, and the reader gets something that can actually run it.

Give it a PDF or a photograph of a recibo de vencimento and it tells you what is wrong, what checks out, and what is worth knowing. Free, on the device, and nothing is kept: the file is read into memory, checked, and gone when the screen closes. There is no history, and adding one would change `PRIVACY.md`, the privacy manifest and the App Store privacy answers in the same commit, which is why the manifest now says so in a comment.

The idea worth protecting is that no name reaches a verdict the arithmetic has not agreed with. Ten checks, and each one that cannot run says so on screen with the reason, because a check that quietly did not happen reads as a check that passed. On both real payslips four or five do not run, since the tax engine models a month as gross times a schedule and neither payslip is shaped like that. A figure we had to guess at is capped at "worth knowing" and can never reach "wrong". And a total has to be a total of something: a payslip carries several figures satisfying earnings minus deductions equals net, year-to-date summaries among them, and one its own lines do not add up to is not believed.

That last rule earned itself during this release. Driving the real app, Vision read "1 923,35" as "4,12", so the net identity latched onto the annual accumulated block instead, where 3 187,40 minus 1 076,15 really is 2 111,25. The deductions total it implied was not supported by any named run, so it was retracted and two checks reported themselves as not run. The alternative was accusing somebody's payslip of being 187,90 short. Nothing in the reader is deterministic across input paths, and that is exactly why the rule is there.

**`tools/payslip_probe`** is the compiled probe the reader's own plan deferred. `verify_payslip_reader.py` can check anything expressible as a rule restated in Python, which covered the money parser, the homoglyph table and the tolerance ordering, and could not touch the four files that make a judgement about a page rather than restate a table. The probe compiles those files, unmodified, and prints what they decide about a real file. It found the bugs below.

Fixed, all of them found by running the thing: the four engine checks reported `taxBaseNotGross` when the truth was that a figure had never been found, so the screen told a reader their employer withholds on something other than gross when the app had simply not read the base. `ssBase` claimed high confidence unconditionally while the contribution beside it computed its own, so a photographed payslip reported its gross as certain with every other figure on the page uncertain; it now follows the same rule and uses the weak-window flag that had been recorded and read by nothing. Two errors were cancelling each other in the classifier: a column test that mislabelled every deduction as an earning on the layout that stacks the two blocks, and a label fallback that quietly undid it, so the reading came out right for the wrong reason and either fix alone would have broken it. A guard in `inferSideOfUnnamedLines` ended in a condition that could never be false, which hid which of its two cases was load-bearing; it is the one the comment said was left alone. A reading that cleared the not-a-payslip gate with nothing identifiable in it showed "nothing on this payslip contradicts itself" over a page we had failed to read. And typing a half-finished number into a review field deleted the figure, because the parser returns nothing for both "cleared" and "not a number yet".

Removed: a skip reason with copy in two languages that nothing ever emitted, a property naming which checks compare equality that nothing read, and an at-most-once invariant that nothing enforced. A second copy of a rule that nothing consults is one more thing to keep in step.

Layout, on five screens nobody had looked at: the header above every step becomes two rows past the accessibility threshold instead of wrapping a title to four lines beside an unmoved button, and its close button, the only way out of the flow, was under Apple's 44 point minimum at the default size. The review rows reflowed only past `isAccessibilitySize`, which is false for the three sizes where they actually stopped fitting. The results screen had no exit of its own. Verified by hand at `large` and `accessibility-extra-large` on all five, and the default look is unchanged.

Plus the review screen stopped telling people their PDF came from a photo, which it had been doing to one of the two real payslips.

**v1.0.4**: The tax engine gets a test, and four things that were wrong get fixed.

There is no test target in this project, so the part of the app where being wrong matters most had never been checked by anything but reading. `tools/verify_tax_engine.py` now does it, and it passes. It parses the withholding tables straight out of `TaxEngine.swift`, so it checks the code that ships rather than a copy that can drift. It round-trips the Açores and Madeira tables against the AT workbooks they were generated from, every bracket and rate and parcela and formula. It replays the workbooks' own published effective-rate column back through the engine's arithmetic, 63 independent points, which tests the formula and not just the transcription. And it checks the four things no source document can tell you: that net never falls as gross rises, that each region's minimum wage withholds nothing, that the annual médias agree with their normal rates, and that net to gross inverts exactly.

All of it passes. Continente is the gap: its table comes from a Despacho and there is no workbook for it here, so it is covered by the invariants and by nothing else.

Two claims turned out to be wrong. A comment said the Açores table was exactly 0.70 of the Continente one on all twelve rates; it is eleven of twelve, and on the twelfth AT rounded the other way. And the settlement note said your real deductions "can shift" the result, which was far too mild: on a salary between about €1,100 and €1,900 the withholding runs slightly *under* the real IRS, so the refund the card shows exists entirely because the app assumed €1,000 of deductions on your behalf. Collect none and you owe money instead. The note now says that.

Two more Dynamic Type breaks surfaced on the two screens that had never been looked at, because they sit behind the support payment: Grow truncated "Daqui a 10 anos, se fi…" and broke "Custa à empresa" mid-word, and the European map shortened Portugal to "Portu…". All three now reflow instead. Plus the Portuguese opening line stopped saying *compreender*, which nobody says out loud, and one pair of straight quotes became proper ones.

**v1.0.3**: The app follows the reader's text size. It never did before.

SwiftUI's `.system(size:)` looks like a design size and is really a fixed point count: it ignores Dynamic Type completely. The app had 493 of them and not one `ScaledMetric`, so setting an iPhone to the largest text size and opening SalarySeed changed nothing at all, not by a pixel. For an app about pay and pensions, read by people who are older on average than a game's audience, that was the worst thing left in it.

Every one of those call sites now goes through `.appFont(_:weight:)`, which asks `UIFontMetrics` what the reader's size is. At the default setting `UIFontMetrics` returns the design size unchanged, so this release is pixel-identical to v1.0.2 for anybody who never opened Settings. The scaling curve is picked from the design size, so a 10pt footnote grows proportionally more than a 34pt hero number, which is how Apple's own text styles behave and what stops captions turning into headlines.

About half the work was layout, because bigger text has to go somewhere. Onboarding's plain steps scroll now instead of squeezing their own headlines into "Vamos compree…". Home's top bar becomes two rows past the accessibility sizes rather than breaking the wordmark into "Salar / ySee / d". Section labels stack above their hints instead of splitting mid-word into "DISTRIBUIÇÃ / O NACIONAL". Nothing shrinks to fit: shrinking text is the opposite of what the reader asked for.

Verified by hand at `accessibility-extra-large` on onboarding, Home, Compare, the Portugal map, Profile and the support sheet. Grow, the European map and the deeper sheets have not been checked yet, and nor has anything above that size. VoiceOver is untouched and remains the accessibility work still outstanding.

**v1.0.2**: Four copy fixes, one of which was a wrong statement about the app's own maths.

The footer under Home said every figure came from the 2026 tables "for the Continente", unconditionally, and had said so since v0.6. v0.15 added real Açores and Madeira tables and did not come back for this line, so an islander whose numbers *were* computed regionally was told, in the only sentence on the screen that names a table, that they were not. It now names the region it used, with the article Portuguese needs for each. The app was doing the right thing and confessing to the wrong one.

The support sheet lost its "no ads" bullet. Charging for the absence of something the app never had is not a benefit, and it was the one line on that screen a review would quote back. What the money funds is already the first thing the sheet says. The remaining bullets are things you get: Grow, the European map, the accents, and everything built later. Portuguese there also stopped saying *features* and *pagos* and started saying *funcionalidades* and *pagas*.

Onboarding's salary step used to say the salary was the only thing needed, directly above a progress bar promising seven more questions. It now says what it is actually there for, which is that the button will not move until a number is typed.

And *indústrias extractivas* became *extrativas*, which is the spelling every other label on the same picker had already been using.

**v1.0.1**: The support payment goes to €4.99 and starts unlocking something. Grow and the European half of the map are now behind it, alongside the accents and the standing promise that everything built later is included. Portugal's map, Home and Compare stay free, because the app's own country is what the app is for.

This reverses half of a v0.16 decision on purpose. That version said the support sheet opens from the profile and from nowhere else, which was right when the payment bought five colours and anything louder would have been selling paint. A feature nobody can find is not a feature, so Grow and the European map now show a gate where the paid thing lives. What stays forbidden is everything the old rule was really aimed at: interstitials, launch-count nags, countdowns, crossed-out prices, and prompts over a screen somebody was already using. The sheet is still the only place money is asked for.

Both gates are the real screen, blurred and inert, with a small card over it. The first version was a page of its own with a headline, a real computed figure and four bullets; every word of it was true and it still read as a destination rather than a hint, which is what rendering it showed. A blur is a weaker promise than v0.16's accent swatches, which recolour the app for real before payment: you can see something is there and you cannot read it. That trade was made deliberately, after looking at both.

The support sheet was cut to two sentences and five lines, each with a bold accent lead so the list can be read by scanning. It says what it is: a way to keep the app free of ads and paid for, with a few extra things attached.

The price rises on the SAME product id, in App Store Connect, which is what keeps everyone who paid €2.99 entitled to all of it. A new product at a new price would have stranded them and broken the promise the sheet makes. The buy button also moved below the scroll: five benefits instead of three pushed it off the bottom of a 6.1-inch screen, and a payment button that has to be scrolled to is not a decision anyone declined.


**v1.0.0**: The release, and it is smaller than what came before it. Everything the app shows comes from published data and nothing a user types ever leaves the phone, which is now a property of the code rather than a setting: there is no `URLSession` anywhere in the app and no endpoint to point one at.

The consent screen went, along with the contribution row, the pseudonymous token, the transport and the erasure path. All of it was finished and tested against a live Firestore emulator, and all of it is on the `pool-backend` branch. It is not here because collecting pay data turns a one-person app into something with real compliance obligations, and that was out of proportion to what the pool would have been worth in its first year. The €2.99 unlock is untouched, because the App Store trader disclosure follows from taking money rather than from taking data.

What survived from the store-readiness work is the part that has nothing to do with the pool: the privacy manifest, `CFBundleLocalizations` so the App Store stops advertising a Portuguese app as English-only, `ITSAppUsesNonExemptEncryption`, the build phase that fails if the manifest goes missing or starts claiming to collect something, and the version read from the bundle rather than typed into a string that had said "v0.9.4" for six releases. Onboarding is nine steps instead of ten and ends on the sector question. `SupportSheet`'s Close button was quietly borrowing a string named `consentPreviewDone`, which the removal would have taken with it: it is now `closeButton`, which is the same v0.13 mistake caught before rather than after.

**v0.16**: The first time the app asks for money. A €2.99 non-consumable, bought from a button at the top of the profile and from nowhere else, which funds the app, promises whatever paid features come later at no further cost, and unlocks five accent colours: green, blue, purple, pink, amber. The colours are live before paying and revert on close, because the honest version of a paywall shows the thing first. `Theme.accent` and `Theme.ink` became computed, which meant replacing 52 hardcoded ink values across 20 files and taught the kit step 18. Each accent carries its own ink rather than deriving one, so the check on a pink swatch is readable. `Theme.segNet` stays seed green throughout: it is a data colour, not chrome, and a net-pay segment that changed meaning with the user's taste would be a lie. The home-screen icon follows the accent through `setAlternateIconName`, with the four variants generated from the green master by `tools/make_alternate_icons.py` and declared in the asset catalogue rather than by hand. StoreKit is the only source of entitlement truth; the cached flag exists purely to stop a first-frame flicker, and a refund takes the colours back through the `Transaction.updates` listener. `SalarySeed.storekit` and a shared scheme make the whole flow testable in the simulator with no developer account.

**v0.15.4**: Repository layout: `_archive/` for deliveries, data sources and dead directories, everything outside the folder-synchronized group so nothing stray is ever compiled.

**v0.15.3**: Three island bugs, one of them user-visible. The region dimension's option list was still filtered to regions with a published cohort, which was correct while the islands were unreachable and became a silent failure the moment they were not: picking a Madeira município stored fine and then rendered everywhere as though nothing had been chosen. Grow's island note claimed the district lever "does nothing", which was false, with no home district the model falls back to the national sector average, so it does move the path. And the map's "vs where I am" chip was offered to users with no district, where it lit up and changed nothing.

**v0.15.1 / v0.15.2**: `git clean` protection in `.gitignore`, and `ConcelhoCatalog.search` fixed after `Concelho.district` became optional.

**v0.15**: Açores and Madeira. The tax is the real work: `TaxEngine.TaxRegion`, the two regions' withholding tables generated from the AT workbooks and round-tripped against them, and the annual rates computed as the 30% differential both regions apply in 2026 rather than embedded as eighteen more numbers. `region` is deliberately not defaulted anywhere, so the compiler asks at every call site. 30 island concelhos, `Concelho.district` now optional because the islands have none, and the picker browses the two regions as their own sections. On the map they appear beside the mainland with no colour, because the Quadros de Pessoal are Continente-only and there is no figure to give them. Compare and Grow say what that costs.

**v0.14**: Consent reframed. The screen is now unskippable, with no default and two active buttons, and it argues for itself: what the pool is for, what a yes unlocks in a future version, and the row itself listed on the screen rather than behind a link. Both answers still continue into the app, because a screen that gates the app collects consent that is void under Article 7(4) and leaves a database with no lawful basis. The profile toggle became a status card that states what is happening, with the stop and the delete as plain text actions. New kit step 14: every payload field must appear in the summary that claims to describe it.

**v0.13.1**: Removed `RaiseSimulatorView`, deleted from git in v0.10 but still sitting on disk and still being compiled, where it was the only remaining user of four `Strings` keys that v0.12 deleted as unused. Committed the `DEVELOPMENT_TEAM` setting so `git reset --hard` stops wiping the signing config. Added kit step 13.

**v0.13**: Everything the app needs for crowd data, with nothing switched on. The pseudonymous token in the Keychain, deliberately surviving app deletion so erasure stays possible and shown in the profile as a copyable code. `Contribution`: 19 fields, a coarsening rule and a stated reason per field, a fixed wire shape that always writes every key. The consent copy corrected for a pseudonymous design, since the v0.12 wording said "anónimo", claimed nothing identifying the phone was shared, and never said whether withdrawal meant stop or delete. Delete-what-I-sent, and a sheet that prints the exact row. No endpoint, no scheduled question, nothing sent.

**v0.12**: A polish pass with one new screen. The onboarding salary step asks for the amount first and drops the labels over its own segments. The consent screen: at the end of onboarding, in plain language, with equally weighted buttons and a matching toggle in the profile. Grow's levers became "Change parameters", the job-move raise is shown in euros at every change rather than as a percentage, and tax and prices moved behind "Change more". The European map names its units "Salário absoluto (€)" and "Salário PPP (€)", explaining PPP only where PPP is selected. Plus the missing `%` in the salary explorer, two equal exit buttons in place of one accent button and a text link, a red part-time caveat, a green button that says what it does, and 36 orphaned strings deleted.

**v0.11.2**: Fixed country selection on the European grid, which was almost entirely untappable: tiles were placed with `.offset()` inside a `ZStack`, so they rendered outside their container's bounds and SwiftUI refused the taps. Rebuilt as rows, where hit testing is correct by construction. Full-codebase sweep for undefined symbols, duplicate declarations, non-exhaustive switches, unstable `ForEach` ids and unsafe indexing, plus a 5,184-scenario edge battery on the growth engine. This README rewritten from v0.5.

**v0.11.1**: Grow's break-even card leads with a compounded annual rate. The job-move premium became a percentage applied at every move, with both rates shown side by side. Every "per year" figure is now read off the drawn path. The mover's tenure ladder is frozen after the first move, which fixed a zero-raise move coming out ahead.

**v0.11**: The European half of the map. Eurostat SES 2022, 17 NACE sections and 27 countries, euros or purchasing power, with its own reciprocal-pair colour buckets because the Portuguese ones collapsed at European spread.

**v0.10 / v0.10.1**: Grow. Ratio anchoring, the stay-versus-move comparison, break-even, the lever system and the waterfall. Then gross-only, the projection hero card first, and the tabs reordered.

**v0.9  to  v0.9.4**: Crowd-data signals and job titles; concelho in, with district and NUTS derived; the Portuguese map; a polish pass; the annual settlement's parts exposed, the salary explorer, and the record-versus-explore split.

**v0.6  to  v0.8.3**: The real 2026 tax engine, the IRS Jovem assessor, swipe tabs, and the 24-sector by tenure cohort.

**v0.1  to  v0.5**: Core calculator, real published percentile data, ajudas de custo as a first-class input, the branching detail trees, and one-question-at-a-time onboarding.
