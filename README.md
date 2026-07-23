# SalarySeed — v0.3

Preliminary iOS build of the SalarySeed concept (`../app-concept.md`). Everything works end-to-end, but rates and data are placeholders. A frozen copy of the previous version lives in `../SalarySeed_v0.2/`.

## Run it

1. Open `SalarySeed.xcodeproj` in Xcode 16 or newer (uses folder-synchronized groups, so new files added to the `SalarySeed/` folder appear in Xcode automatically).
2. Pick an iPhone simulator, press Run.

No dependencies, no backend, no account. Everything on-device.

## What's new in v0.3

- **Two languages: English + European Portuguese (informal "tu").** The app follows the device language by default and the user can switch (Auto / English / Português) in the profile tab. Implemented as a small custom layer (`Models/Localization.swift`) instead of system localization, so the language switches at runtime without a restart. All user-facing copy lives in one string table (`Strings`), read through `store.s`.
- **Copy pass.** All text rewritten in plain, direct language, in both languages. No em dashes, no filler.

## What's in the app (v0.1 + v0.2)

- **Onboarding** with a welcome screen that asks for a name (skippable), then salary, then gross/net and 12/14 months. Seed-dot progress.
- **Home (netSeed)**: greeting, gross/net heroes with count-up and a leaf unfurl, cost-to-employer, where-the-money-goes bar, detail cards, national percentile, what-if nudges, locked growthSeed teaser ("Steps to improve your salary", coming in a later version).
- **compareSeed**: national percentile plus one comparison layer per filled profile signal (age band, NUTS II region, education, occupation group), each with a percentile bar, median caption, thin-sample and edge caveats, and source lines. Signals are added via chip picker sheets.
- **profileSeed**: "Your seed" sprout hero (profile completeness = growth stage), salary and name editing, add/edit rows for the four signals, language switch, privacy and source notes.
- **raiseSeed** and **futureSeed** sheets from Home.

## Structure

```
SalarySeed/
├── SalarySeedApp.swift      entry point, routes onboarding vs tabs
├── RootTabView.swift        Home · Compare · Profile
├── Theme.swift              colors + € formatting
├── Models/
│   ├── SalaryStore.swift    inputs + name + profile signals + language, persistence
│   ├── ProfileSignals.swift age/region/education/occupation enums, STABLE IDs
│   └── Localization.swift   AppLanguage + the full EN/PT string table
├── Engine/
│   ├── TaxEngine.swift      gross↔net, IRS approximation, SS rates  ⚠️ placeholders
│   ├── PercentileEngine.swift  national percentile interpolation  ⚠️ placeholder data
│   └── CohortEngine.swift   cohort cells + log-normal percentile  ⚠️ mock medians
└── Features/
    ├── Shared/              SproutKit (sprout, seed dots, leaf, count-up), picker sheet
    ├── Onboarding/ Home/ Compare/ Raise/ Future/ Profile/
```

## Data notes (compareSeed layers)

Cohort cells are shaped like real GEP/MTSSS "Quadros de Pessoal" cuts (dados.gov.pt, CC BY 4.0, commercial use OK with attribution): one-dimensional cells of `(median, sigma, thin)`. Swapping the mock medians in `CohortEngine.swift` for real published values is a data change, not a UI change. Cohort percentiles are modelled log-normal around the cell median. Coverage: private-sector employees only (no civil servants, no self-employed). The UI says so where it matters.

## Known placeholders (before anything real)

- **IRS withholding** is a simplified progressive approximation. Replace with the official *tabelas de retenção na fonte*, versioned by year, with marital status/dependents/region.
- **SS rates** (11% / 23.75%) unverified.
- **National percentile data** is illustrative. Replace with a bundled JSON of real INE distribution buckets plus "Fonte: INE, <year>" attribution.
- **Cohort medians/sigmas** in `CohortEngine.swift` are mock values. Replace with real GEP/Quadros de Pessoal tables (same shape).
- **futureSeed pension math** is a stub (2%/year heuristic). Needs the real Segurança Social formula.
- No premium/IAP yet, no full accessibility pass. PT translations are informal ("tu") by design.
