# SalarySeed — v0.13.1

An iOS app that tells you what your salary in Portugal actually means: in your pocket, to your employer, against everyone else, over the next twenty years, and against the rest of the European Union.

Concept and design rationale live in [`../app-concept.md`](../app-concept.md). Every non-obvious decision in this repo is explained in a comment at the point it was made, including the ones that were wrong the first time.

## Run it

1. Open `SalarySeed.xcodeproj` in Xcode 16 or newer. The project uses folder-synchronized groups, so files added to `SalarySeed/` appear in Xcode automatically. The flip side, and it has bitten once: a file **removed from git** is not removed from disk, and folder-synchronized groups keep compiling it. After any `git reset --hard`, run `git clean -nd` and look at what it lists.
2. Pick an iPhone simulator and press Run.

No dependencies, no backend, no account, no network calls. Everything is on-device: bundled datasets plus arithmetic. v0.13 added the shape of a future contribution, but `ContributionService.endpoint` is nil and nothing has ever been sent, by anyone.

## The five tabs

| Tab | What it answers |
|---|---|
| **Home** | What you earn now. Gross ↔ net, yearly figures, total cost to your employer, the full breakdown, and the annual IRS settlement with every assumption written out. |
| **Compare** | How that sits against other people, now. National percentile plus cohort comparisons by sector, tenure, age, education and region. |
| **Map** | Where it would sit differently. A Portuguese district choropleth, and a 27-tile grid of the European Union. |
| **Grow** | What it might become. Your pay projected over 5, 10 or 20 years, staying put against changing employer. |
| **Profile** | The inputs behind all of it, each with what it unlocks, plus the data-sharing consent: the toggle, the code, the delete, and the row itself. |

## Data

Everything is published, openly licensed, and bundled. Nothing is scraped, and no crowdsourced or recruiter figure is embedded anywhere.

- **GEP-MTSSS, Quadros de Pessoal, October 2024** (CC BY 4.0). A near-census of private-sector employees. Quadro 104 for sector × tenure at the employer, Quadros 110 and 61 for sector × district with worker counts, Quadros 105/114/138 for education, region and age.
- **INE, Inquérito à Estrutura dos Ganhos 2022** (CC BY 4.0), for the shape of the national distribution.
- **Eurostat, Structure of Earnings Survey 2022** (`earn_ses22_24`, free reuse with attribution), for the European comparison.
- **CAOP / DGT** for the district boundaries, credited in-app.
- **Tax**: a real 2026 Continente engine. Social Security 11% and 23.75%, the three withholding tables from Despacho 233-A/2026, the nine annual escalões, the specific deduction, dependant credits, the €1,000 general-expense credit, and IRS Jovem in both the monthly withholding and the annual settlement.

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
    Contribution         the one row that would ever leave the phone, and its coarsening
  Features/    one folder per screen
  Models/      SalaryStore (the single source of truth), Localization, catalogues
  Theme.swift  design tokens and the OKLCH diverging ramp
```

The engines never import SwiftUI and never read the store. Views never do arithmetic. Everything the user sees in words comes from `Models/Localization.swift`, in English and European Portuguese.

## Principles the code actually follows

These are not aspirations. Each one is enforced somewhere, and most were learned the hard way.

- **Say what the data cannot do, on the screen.** Thin cells carry a caveat. Sector is not job title. The district table has no tenure dimension, so it can shift a path and cannot bend it.
- **State every assumption, unconditionally.** If the app assumes the €1,000 credit or an IRS Jovem exemption, it says so in every branch, including the ones where the assumption turns out not to apply.
- **Recording is not exploring.** Changing your stored salary and trying a hypothetical are separate acts with separate UI. Grow's whole scenario lives in memory and never reaches `UserDefaults`.
- **Explain the answer, not the question.** A note that clarifies a figure or an unclear ask earns its place. A paragraph justifying why the app asks for something does not, and v0.12 deleted several.
- **Set the input people can reason about, show the one they act on.** The job-move lever is a percentage, because only a percentage means the same at a move in year 3 and a move in year 9. What it displays is the euro raise at each change, because that is what gets negotiated.
- **A consent flag has three states.** Never asked, asked and declined, asked and agreed. Collapsing the first two into one `Bool` turns a refusal into a fresh install and makes the app ask again forever.
- **Never draw a shape the data does not have.** Six published tenure bands means a staircase, not a smooth curve, and the ten sectors whose pay falls between some bands are drawn falling.
- **Never mix survey levels; only ratios cross.** GEP and Eurostat measure different populations in different years, so a Portuguese salary is never placed beside a Eurostat mean. The European uplift is computed entirely inside Eurostat and then applied to your own salary.
- **Show the quantity the source publishes.** GEP publishes gross ganho, so the whole projection is gross. Net appears only where a single point is inspected.
- **Quote rates, not bare percentages.** A percentage with no time attached cannot be compared to a raise or to inflation. Anything labelled "per year" is the compounded rate of the path actually drawn.
- **A published table is not a law.** Quadro 104 measures what staying at one employer is worth, so the model does not hand someone who moves a tenure raise the survey never observed.
- **Define the payload by subtraction.** Every field has to earn its place by being able to change an aggregate. One that cannot is not neutral, it is a fingerprint bit. The concelho never leaves the phone; the region goes instead.
- **Show the row, do not describe it.** A consent screen that explains the data in a paragraph asks to be believed. This one prints the JSON.
- **Stopping and deleting are different acts.** The toggle keeps the code, because the code is the only thing that makes deletion possible later.

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

## Version history

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

Açores and Madeira (the publication covers Continente). Tenure on the European map, where coverage is already measured. The pension model, which is still a placeholder and should fold into Grow's timeline. Self-employed mode. Variable pay in the tax engine. A real app icon. No premium or IAP yet, and no full accessibility pass. And the pooling itself: v0.12 asks for consent and records the answer, but there is no backend and no network call anywhere in the app, so nothing is uploaded from anyone, consenting or not.

## Honest limits

Estimates for guidance, not tax advice. The engine models regular monthly salary under 2026 Continente rules and does not know your health or education deductions. Cohort figures cover private-sector employees; public-function contracts sit outside the Quadros de Pessoal entirely, and the app says so once you tell it that is your situation. Within-cohort dispersions are modelling assumptions, not published values, while the national curve's are derived from published deciles. The European figures are 2022 against Portugal's 2024, which is exactly why the two are never added together.
