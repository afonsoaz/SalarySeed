# SalarySeed — v1.0.0

An iOS app that tells you what your salary in Portugal actually means: in your pocket, to your employer, against everyone else, over the next twenty years, and against the rest of the European Union.

**Every figure comes from published, openly licensed data**, and there is no other kind. GEP and INE for Portugal, Eurostat for Europe, the AT workbooks for tax. No crowdsourced number, no recruiter survey, no estimate from another app. If a figure is on screen, a public table stands behind it, and where no such table exists the app says so instead of drawing something.

**Nothing you enter leaves your phone.** Not as a setting, not as a promise: there is no networking code in this app at all beyond StoreKit talking to Apple about the €2.99 unlock. See "Where the data goes" below, which is short.

Concept and design rationale live in [`app-concept.md`](app-concept.md), next to this file. Every non-obvious decision in this repo is explained in a comment at the point it was made, including the ones that were wrong the first time.

## Where things are

```
Salary_App/                    <- the git repo root
  SalarySeed.xcodeproj         <- OPEN THIS ONE. The only project file in the repo.
  SalarySeed/                  <- every source file. Xcode compiles this whole folder.
    Engine/ Models/ Features/ Assets.xcassets/
  SalarySeed.storekit          <- the fake store, for running the purchase in the simulator
  Info.plist                   <- ONLY the keys Xcode cannot generate. See the comment in it
  tools/                       <- the Python that generated the bundled datasets,
                                  and check_privacy_manifest.sh, which runs on every build
  README.md  app-concept.md    <- this file and the design doc
  PRIVACY.md                   <- the privacy policy. Needs a contact line and a host
  _archive/                    <- not part of the app, gitignored
    deliveries/                   tarballs and patches
    data-sources/                 the workbooks the datasets came from
    old/                          dead directories kept only so nothing is lost
```

`SalarySeed/` is a folder-synchronized group, so **every `.swift` inside it is compiled whether or not git knows about it**. That is why nothing else is allowed to live there and why `_archive/` sits outside it.

## Run it

1. Open `SalarySeed.xcodeproj` in Xcode 16 or newer. The project uses folder-synchronized groups, so files added to `SalarySeed/` appear in Xcode automatically. The flip side, and it has bitten once: a file **removed from git** is not removed from disk, and folder-synchronized groups keep compiling it. After any `git reset --hard`, run `git clean -nd` and look at what it lists.
2. Pick an iPhone simulator and press Run. The shared scheme already points at `SalarySeed.storekit`, so the €2.99 purchase, the restore and a refund all work in the simulator with no App Store Connect product and no paid developer account. Buying costs nothing there; Xcode's Debug → StoreKit menu is where you undo it.

No dependencies, no account, no backend. Every figure is on-device: bundled datasets plus arithmetic. The only network traffic the app generates is StoreKit talking to Apple around the support sheet, which carries no app data.

## The five tabs

| Tab | What it answers |
|---|---|
| **Home** | What you earn now. Gross ↔ net, yearly figures, total cost to your employer, the full breakdown, and the annual IRS settlement with every assumption written out. |
| **Compare** | How that sits against other people, now. National percentile plus cohort comparisons by sector, tenure, age, education and region. |
| **Map** | Where it would sit differently. A Portuguese district choropleth, and a 27-tile grid of the European Union. |
| **Grow** | What it might become. Your pay projected over 5, 10 or 20 years, staying put against changing employer. |
| **Profile** | The inputs behind all of it, each with what it unlocks, and at the top the one place the app asks for money. |

## Data

Everything is published, openly licensed, and bundled. Nothing is scraped, and no crowdsourced or recruiter figure is embedded anywhere.

- **GEP-MTSSS, Quadros de Pessoal, October 2024** (CC BY 4.0). A near-census of private-sector employees. Quadro 104 for sector × tenure at the employer, Quadros 110 and 61 for sector × district with worker counts, Quadros 105/114/138 for education, region and age.
- **INE, Inquérito à Estrutura dos Ganhos 2022** (CC BY 4.0), for the shape of the national distribution.
- **Eurostat, Structure of Earnings Survey 2022** (`earn_ses22_24`, free reuse with attribution), for the European comparison.
- **CAOP / DGT** for the district boundaries, credited in-app.
- **Tax**: a real 2026 engine for **all three fiscal regions**. Continente, Açores and Madeira, each with its own withholding tables (generated from the AT workbooks and round-tripped, never transcribed) and its own annual rates. Social Security 11% and 23.75%, the three withholding tables from Despacho 233-A/2026, the nine annual escalões, the specific deduction, dependant credits, the €1,000 general-expense credit, and IRS Jovem in both the monthly withholding and the annual settlement.

## Architecture

```
SalarySeed/
  Engine/      pure computation, no SwiftUI
    TaxEngine            2026 IRS + Social Security, gross/net, annual settlement
    PercentileEngine     two-piece log-normal national distribution
    SalaryDataset        every published Portuguese figure, with provenance
    CohortEngine         percentile within a cohort
    DistrictDataset      sector x district means and counts
    DistrictShapes       CAOP outlines, projected and simplified
    DistrictComparison   the Portuguese map's readings and colour buckets
    EuroDataset          Eurostat SES: 17 NACE sections x 27 countries + price levels
    EuroComparison       the European map's ratios, ranks and colour buckets
    GrowthEngine         the projection: anchoring, stay and move paths, rates
  Features/    one folder per screen
  Models/      SalaryStore (the single source of truth), Localization, catalogues
    SupporterStore       StoreKit 2: the product, the entitlement, restore, refunds
    AccentTheme          the five accents, each carrying its own ink
    AppIcon              setAlternateIconName, and the guard that stops the alert
    AppConfig            the version, read from the bundle rather than typed
  Theme.swift  design tokens and the OKLCH diverging ramp
  PrivacyInfo.xcprivacy  the privacy manifest, checked against the build on every build
```

The engines never import SwiftUI and never read the store. Views never do arithmetic. Everything the user sees in words comes from `Models/Localization.swift`, in English and European Portuguese.

## Principles the code actually follows

These are not aspirations. Each one is enforced somewhere, and most were learned the hard way.

- **Say what the data cannot do, on the screen.** Thin cells carry a caveat. Sector is not job title. The district table has no tenure dimension, so it can shift a path and cannot bend it.
- **State every assumption, unconditionally.** If the app assumes the €1,000 credit or an IRS Jovem exemption, it says so in every branch, including the ones where the assumption turns out not to apply.
- **Recording is not exploring.** Changing your stored salary and trying a hypothetical are separate acts with separate UI. Grow's whole scenario lives in memory and never reaches `UserDefaults`.
- **Explain the answer, not the question.** A note that clarifies a figure or an unclear ask earns its place. A paragraph justifying why the app asks for something does not, and v0.12 deleted several.
- **Set the input people can reason about, show the one they act on.** The job-move lever is a percentage, because only a percentage means the same at a move in year 3 and a move in year 9. What it displays is the euro raise at each change, because that is what gets negotiated.
- **Never draw a shape the data does not have.** Six published tenure bands means a staircase, not a smooth curve, and the ten sectors whose pay falls between some bands are drawn falling.
- **Never mix survey levels; only ratios cross.** GEP and Eurostat measure different populations in different years, so a Portuguese salary is never placed beside a Eurostat mean. The European uplift is computed entirely inside Eurostat and then applied to your own salary.
- **Show the quantity the source publishes.** GEP publishes gross ganho, so the whole projection is gross. Net appears only where a single point is inspected.
- **Quote rates, not bare percentages.** A percentage with no time attached cannot be compared to a raise or to inflation. Anything labelled "per year" is the compounded rate of the path actually drawn.
- **A published table is not a law.** Quadro 104 measures what staying at one employer is worth, so the model does not hand someone who moves a tenure raise the survey never observed.
- **The summary is generated from the payload, never beside it.** The card that lists what will be sent decodes the actual row, so it cannot describe a field the payload lacks or hide one it has.
- **Ask for money once, where they came looking.** The support sheet opens from a button in the profile and from nowhere else. No countdown, no crossed-out price, no interstitial, no nagging on the tenth launch. An app whose whole argument is that it does not manipulate the reader cannot manipulate the reader at the till.
- **Show the thing, then ask.** The accent swatches are live before paying: tapping one recolours the whole app behind the sheet, and closing without buying puts it back. A locked feature you cannot see is a claim; one you can see is an offer.
- **The receipt is the truth, never the cache.** `UserDefaults` mirrors the entitlement only so the first frame does not flicker. `Transaction.currentEntitlements` overwrites it on every launch and `Transaction.updates` overwrites it on every refund, so a paid flag can never outlive the payment.

## Verifying changes without a compiler

Much of this app was built where no Swift toolchain was available, so correctness comes from a repeatable kit rather than from a build. It has caught a real bug in every version since v0.9.

1. Brace, paren and bracket balance, with strings, comments and interpolation stripped first.
2. ViewBuilder direct-child counts.
3. Every `s.<key>` cross-referenced against `Strings`, **and the reverse** — declared-but-unused keys, and dangling references to deleted types.
4. Enum case names against raw values in generated code.
5. A Python port of any new maths, round-tripped against its source. **Test the degenerate input**: the v0.11.1 model correction came from trying a job move with a zero raise.
6. Render a PNG and look at it. Cards as well as charts.
7. Grep for hard-coded counts that shadow a computed total.
8. Check that explanatory notes sit outside the branch they explain.
9. Check generated English ordinals and plurals.
10. Check that a rate shown as text agrees with the path drawn beside it.
11. Check the store's symbol surface: every `store.x` and `Engine.x` referenced from a view exists on the type. This is the check that catches a rename halfway done.
12. Check that doc comments do not reference symbols that no longer exist. v0.13 left two behind within an hour of writing them.
13. **Check that the tracked file list matches the files actually on disk.** Xcode's folder-synchronized groups compile every `.swift` under `SalarySeed/`, tracked or not, so a file git does not know about is still a file the compiler reads. This is the one check the others cannot substitute for: steps 3 and 11 scan the repo, and a file outside the repo is invisible to them by construction. v0.13 shipped four "unused" string deletions that were being used, by a file deleted from git in v0.10 that had never left the disk.
14. *(Was about the contribution payload. Moved to the `pool-backend` branch with the code it checked.)*
15. **Round-trip anything generated.** Emit the Swift from the source file, parse the Swift back, compare to the source. The regional tax tables are 45 rows nobody should ever retype.
16. **When a stored property's type or optionality changes, grep every use of it in the same edit.** A type checker does this for free; a regex kit cannot. v0.15.2 shipped a build error this would have caught.
17. **When a value becomes reachable that previously was not, grep every filter that used to exclude it.** v0.15 made Açores and Madeira selectable; a `filter { $0.cohort != nil }` written when they were unreachable then silently rendered them as unanswered. This failure has no error message and no crash, which is what makes it worth its own step.
18. **When a constant becomes computed, check that nothing it now reads reads it back.** v0.16 turned `Theme.ink` from a literal into `current.ink`, and the bulk edit that replaced 52 hardcoded ink values happily replaced the one inside `AccentTheme.ink` too. That single line made the two properties call each other until the stack ran out: no compiler error, no warning, a crash on the first frame. Grep the new computed property's own definition first, before anything else.
19. **When a design token stops being a constant, list the views that draw with it and check each one observes the thing that changes it.** SwiftUI cannot see a static change, so `Theme.accent` becoming computed made eight views quietly stale. The tempting fix, `.id(store.accent)` on the root, is worse than the bug: it rebuilds the whole tree and resets every `@State`, including the sheet the user is standing in while tapping the swatches. Grep for the token, then grep those files for the store.
20. **Check that every name in a build setting exists on disk, and spelt the same.** `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`, the `.appiconset` folder names and `AccentTheme.alternateIconName` have to agree three ways. Two of the three are strings no compiler ever reads, and the failure is a silent no-op at runtime.
21. **Check that a plist key Xcode was asked to generate actually arrived.** `INFOPLIST_KEY_` only maps the key names Xcode knows: `ITSAppUsesNonExemptEncryption` lands as a real boolean and `CFBundleLocalizations` is dropped on the floor with no warning at all. Anything set that way has to be read back out of the BUILT `Info.plist`, not out of the build settings. v1.0 checked before writing rather than after, which is the only reason there is a separate `Info.plist` in the repo.
22. **`onChange` does not fire for the value a view already has.** A trigger written as `onChange(of: scenePhase)` alone runs on backgrounding and returning and never on a cold launch, so v1.0's first send schedule only worked for people who had already been in the app. Nothing failed: the profile card looked healthy and did nothing. Any recurring trigger needs its `.task` counterpart, and the way to find out is step 9.
23. **`JSONEncoder` does not write keys in the order your `encode(to:)` calls them.** It fills a dictionary and serialises that, so the order is arbitrary and differs between calls. Anything that compares, signs or hashes encoded bytes needs `.sortedKeys`. Without it v1.1 re-uploaded an unchanged row on every launch, twice, for every user: the correct single document existed with the correct values, the app said "sent", and nothing anywhere looked wrong. Found only by logging what the server actually received.
24. **Firebase `onRequest` parses the body before your handler sees it.** Adding `express.json()` or `express.raw()` gets an already-consumed stream and leaves the body empty, so every request 400s including valid ones. The original bytes are on `req.rawBody`, and those are the ones a signature must be checked against; reconstructing them with `JSON.stringify` produces different bytes and fails every signature for reasons no log explains.
25. **When something is created for later use and the creation can fail, check the caller checked.** Especially Keychain writes, which fail silently and return a status nobody reads. The case that taught this created a durable identifier, ignored the failure, and left the app showing a confident status card over a feature that could not work.

## Where the data goes

Nowhere.

The app has no server, no account and no analytics. `grep -r URLSession SalarySeed`
returns nothing: there is no code path that could send your salary anywhere, which
is a stronger statement than a privacy policy and the reason the App Store label
reads "Data Not Collected" without qualification.

The one exception is not about you. StoreKit talks to Apple to fetch the product
price and complete the €2.99 purchase. Apple is the seller of record, so we never
see an Apple ID, a name or a payment detail, only an anonymous monthly total.

**A contribution pool was built, and deliberately not shipped.** It works: rows
reached Firestore through a Cloud Function, documents were named by keyed hash so
the token was never stored, erasure deleted and could not be used as an oracle,
and the security rules denied every client path. It is on the **`pool-backend`**
branch, which is `master` plus exactly that.

It is not here because collecting pay data makes the author a data controller, and
the lawyer, DPIA, processing record, retention policy, erasure duties and personal
liability that follow are out of proportion to a one-person app. The €2.99 is
unaffected either way: the App Store trader disclosure follows from taking money,
not from taking data.

## Version history

**v1.0.0** — The release, and it is smaller than what came before it. Everything the app shows comes from published data and nothing a user types ever leaves the phone, which is now a property of the code rather than a setting: there is no `URLSession` anywhere in the app and no endpoint to point one at.

The consent screen went, along with the contribution row, the pseudonymous token, the transport and the erasure path. All of it was finished and tested against a live Firestore emulator, and all of it is on the `pool-backend` branch. It is not here because collecting pay data makes a one-person app's author a data controller: a lawyer, a DPIA, a processing record, a retention policy, erasure duties and personal liability, none of which are proportionate to what the pool would have bought in its first year. The €2.99 unlock is untouched, because the App Store trader disclosure follows from taking money rather than from taking data.

What survived from the store-readiness work is the part that has nothing to do with the pool: the privacy manifest, `CFBundleLocalizations` so the App Store stops advertising a Portuguese app as English-only, `ITSAppUsesNonExemptEncryption`, the build phase that fails if the manifest goes missing or starts claiming to collect something, and the version read from the bundle rather than typed into a string that had said "v0.9.4" for six releases. Onboarding is nine steps instead of ten and ends on the sector question. `SupportSheet`'s Close button was quietly borrowing a string named `consentPreviewDone`, which the removal would have taken with it: it is now `closeButton`, which is the same v0.13 mistake caught before rather than after.

**v0.16** — The first time the app asks for money. A €2.99 non-consumable, bought from a button at the top of the profile and from nowhere else, which funds the app, promises whatever paid features come later at no further cost, and unlocks five accent colours: green, blue, purple, pink, amber. The colours are live before paying and revert on close, because the honest version of a paywall shows the thing first. `Theme.accent` and `Theme.ink` became computed, which meant replacing 52 hardcoded ink values across 20 files and taught the kit step 18. Each accent carries its own ink rather than deriving one, so the check on a pink swatch is readable. `Theme.segNet` stays seed green throughout: it is a data colour, not chrome, and a net-pay segment that changed meaning with the user's taste would be a lie. The home-screen icon follows the accent through `setAlternateIconName`, with the four variants generated from the green master by `tools/make_alternate_icons.py` and declared in the asset catalogue rather than by hand. StoreKit is the only source of entitlement truth; the cached flag exists purely to stop a first-frame flicker, and a refund takes the colours back through the `Transaction.updates` listener. `SalarySeed.storekit` and a shared scheme make the whole flow testable in the simulator with no developer account.

**v0.15.4** — Repository layout: `_archive/` for deliveries, data sources and dead directories, everything outside the folder-synchronized group so nothing stray is ever compiled.

**v0.15.3** — Three island bugs, one of them user-visible. The region dimension's option list was still filtered to regions with a published cohort, which was correct while the islands were unreachable and became a silent failure the moment they were not: picking a Madeira município stored fine and then rendered everywhere as though nothing had been chosen. Grow's island note claimed the district lever "does nothing", which was false — with no home district the model falls back to the national sector average, so it does move the path. And the map's "vs where I am" chip was offered to users with no district, where it lit up and changed nothing.

**v0.15.1 / v0.15.2** — `git clean` protection in `.gitignore`, and `ConcelhoCatalog.search` fixed after `Concelho.district` became optional.

**v0.15** — Açores and Madeira. The tax is the real work: `TaxEngine.TaxRegion`, the two regions' withholding tables generated from the AT workbooks and round-tripped against them, and the annual rates computed as the 30% differential both regions apply in 2026 rather than embedded as eighteen more numbers. `region` is deliberately not defaulted anywhere, so the compiler asks at every call site. 30 island concelhos, `Concelho.district` now optional because the islands have none, and the picker browses the two regions as their own sections. On the map they appear beside the mainland with no colour, because the Quadros de Pessoal are Continente-only and there is no figure to give them. Compare and Grow say what that costs.

**v0.14** — Consent reframed. The screen is now unskippable, with no default and two active buttons, and it argues for itself: what the pool is for, what a yes unlocks in a future version, and the row itself listed on the screen rather than behind a link. Both answers still continue into the app, because a screen that gates the app collects consent that is void under Article 7(4) and leaves a database with no lawful basis. The profile toggle became a status card that states what is happening, with the stop and the delete as plain text actions. New kit step 14: every payload field must appear in the summary that claims to describe it.

**v0.13.1** — Removed `RaiseSimulatorView`, deleted from git in v0.10 but still sitting on disk and still being compiled, where it was the only remaining user of four `Strings` keys that v0.12 deleted as unused. Committed the `DEVELOPMENT_TEAM` setting so `git reset --hard` stops wiping the signing config. Added kit step 13.

**v0.13** — Everything the app needs for crowd data, with nothing switched on. The pseudonymous token in the Keychain, deliberately surviving app deletion so erasure stays possible and shown in the profile as a copyable code. `Contribution`: 19 fields, a coarsening rule and a stated reason per field, a fixed wire shape that always writes every key. The consent copy corrected for a pseudonymous design, since the v0.12 wording said "anónimo", claimed nothing identifying the phone was shared, and never said whether withdrawal meant stop or delete. Delete-what-I-sent, and a sheet that prints the exact row. No endpoint, no scheduled question, nothing sent.

**v0.12** — A polish pass with one new screen. The onboarding salary step asks for the amount first and drops the labels over its own segments. The consent screen: at the end of onboarding, in plain language, with equally weighted buttons and a matching toggle in the profile. Grow's levers became "Change parameters", the job-move raise is shown in euros at every change rather than as a percentage, and tax and prices moved behind "Change more". The European map names its units "Salário absoluto (€)" and "Salário PPP (€)", explaining PPP only where PPP is selected. Plus the missing `%` in the salary explorer, two equal exit buttons in place of one accent button and a text link, a red part-time caveat, a green button that says what it does, and 36 orphaned strings deleted.

**v0.11.2** — Fixed country selection on the European grid, which was almost entirely untappable: tiles were placed with `.offset()` inside a `ZStack`, so they rendered outside their container's bounds and SwiftUI refused the taps. Rebuilt as rows, where hit testing is correct by construction. Full-codebase sweep for undefined symbols, duplicate declarations, non-exhaustive switches, unstable `ForEach` ids and unsafe indexing, plus a 5,184-scenario edge battery on the growth engine. This README rewritten from v0.5.

**v0.11.1** — Grow's break-even card leads with a compounded annual rate. The job-move premium became a percentage applied at every move, with both rates shown side by side. Every "per year" figure is now read off the drawn path. The mover's tenure ladder is frozen after the first move, which fixed a zero-raise move coming out ahead.

**v0.11** — The European half of the map. Eurostat SES 2022, 17 NACE sections and 27 countries, euros or purchasing power, with its own reciprocal-pair colour buckets because the Portuguese ones collapsed at European spread.

**v0.10 / v0.10.1** — Grow. Ratio anchoring, the stay-versus-move comparison, break-even, the lever system and the waterfall. Then gross-only, the projection hero card first, and the tabs reordered.

**v0.9 – v0.9.4** — Crowd-data signals and job titles; concelho in, with district and NUTS derived; the Portuguese map; a polish pass; the annual settlement's parts exposed, the salary explorer, and the record-versus-explore split.

**v0.6 – v0.8.3** — The real 2026 tax engine, the IRS Jovem assessor, swipe tabs, and the 24-sector by tenure cohort.

**v0.1 – v0.5** — Core calculator, real published percentile data, ajudas de custo as a first-class input, the branching detail trees, and one-question-at-a-time onboarding.

## Not done yet

Island cohort figures: the tax is real for all three regions, but the Quadros de Pessoal cover Continente only, so Açores and Madeira have no published comparison and the app says so wherever that bites. Tenure on the European map, where coverage is already measured. The pension model, which is still a placeholder and should fold into Grow's timeline. Self-employed mode. Variable pay in the tax engine. No full accessibility pass, and it is now the largest single piece of work left: 515 hardcoded `.system(size:)` calls, no `ScaledMetric` or `dynamicTypeSize` anywhere, and nine accessibility modifiers in the whole app. The supporter promise of "whatever comes later" has nothing to redeem yet, because there are no paid features beyond the colours.

The pool itself is not a loose end so much as a decision: it exists, it works, and it lives on `pool-backend`. Reviving it means accepting the controller obligations that come with it, and the branch is `master` plus exactly the backend, so the diff is the whole conversation.

## Honest limits

Estimates for guidance, not tax advice. The engine models regular monthly salary under 2026 rules for whichever of the three fiscal regions you are in, and does not know your health or education deductions. Cohort figures cover private-sector employees; public-function contracts sit outside the Quadros de Pessoal entirely, and the app says so once you tell it that is your situation. Within-cohort dispersions are modelling assumptions, not published values, while the national curve's are derived from published deciles. The European figures are 2022 against Portugal's 2024, which is exactly why the two are never added together.
