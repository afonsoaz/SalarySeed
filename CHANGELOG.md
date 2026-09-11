# Changelog

What changed in each version and why, including the bugs that shipped and what they cost.
Versions before 1.0 were never released; they are here because the mistakes in them are
the reason later versions are shaped the way they are.

**v1.2**: The payslip reader gets measured, and then gets a way to hand its figure back.

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
