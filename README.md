# SalarySeed — v0.2

Preliminary iOS build of the SalarySeed concept (`../app-concept.md`). Everything works end-to-end, but rates and data are placeholders.

## Run it

1. Open `SalarySeed.xcodeproj` in Xcode 16 or newer (uses folder-synchronized groups — new files added to the `SalarySeed/` folder appear in Xcode automatically).
2. Pick an iPhone simulator, press Run.

No dependencies, no backend, no account — everything on-device.

## What's new in v0.2

- **Welcome moment** — a warm first-open screen ("Let's plant your seed") that asks for a name (skippable), before the salary question. The name personalizes the reveal ("Hey {name}"), Home, and profileSeed. Seed-dot progress: completed steps sprout into tiny leaves.
- **Layered compareSeed** — the national percentile stays as the hero; each filled profile signal (age band, NUTS II region, education, occupation group) adds a "vs. people like you" layer with its own percentile bar (median tick fixed at 50%), €-to-median caption, and source line. Thin cohorts show a "rough estimate — small sample" chip; results beyond p3/p97 are softened to "edge of the data". Signals are captured via chip picker sheets, reachable from both compareSeed and profileSeed.
- **Living sprout** — one parametric, code-drawn sprout (`SproutView`, stages 0–5 = 1 + filled profile signals) appears in profileSeed's "Your seed · n of 5 planted" hero, the Home brand mark, the compareSeed header, and the picker sheets. Micro-interactions: leaf unfurls next to the net hero on count-up (`UnfurlingLeaf` + `RollingEuro`), grow-in on welcome, pop on growth, idle sway, faint radial glow.
- **growthSeed groundwork (v0.3)** — a locked "Your next step, suggested · coming soon" card on Home. No advice logic or content; the profile signals above are stored as stable enum IDs (`Models/ProfileSignals.swift`) that the future advice engine will consume.

## What's in the skeleton (from v0.1)

- **Home (netSeed)** — gross/net hero, monthly/yearly toggle, "€X of every €100 reaches your pocket", where-the-money-goes bar, detail cards, percentile line, what-if nudges.
- **raiseSeed** — net-raise slider → true employer cost (sheet from Home).
- **futureSeed** — ajudas de custo slider → today's gain vs. tomorrow's loss (sheet from Home).

## Structure

```
SalarySeed/
├── SalarySeedApp.swift      entry point, routes onboarding vs tabs
├── RootTabView.swift        Home · Compare · Profile
├── Theme.swift              colors from the mockup + € formatting
├── Models/
│   ├── SalaryStore.swift    inputs + name + profile signals, persistence, breakdown
│   └── ProfileSignals.swift age/region/education/occupation enums — STABLE IDs
├── Engine/
│   ├── TaxEngine.swift      gross↔net, IRS approximation, SS rates  ⚠️ placeholders
│   ├── PercentileEngine.swift  national percentile interpolation  ⚠️ placeholder data
│   └── CohortEngine.swift   cohort cells + log-normal percentile  ⚠️ mock medians
└── Features/
    ├── Shared/              SproutKit (sprout, seed dots, leaf, count-up), picker sheet
    ├── Onboarding/ Home/ Compare/ Raise/ Future/ Profile/
```

Tax/comparison logic is UI-independent (Engine/) so it can be reused later, as decided.

## Data notes (compareSeed layers)

Cohort cells are shaped like real GEP/MTSSS "Quadros de Pessoal" cuts (dados.gov.pt, CC BY 4.0 — commercial use OK with attribution): one-dimensional cells of `(median, sigma, thin)`. Swapping the mock medians in `CohortEngine.swift` for real published values is a data change, not a UI change. Cohort percentiles are modelled log-normal around the cell median. Coverage: private-sector employees only (no civil servants, no self-employed) — the UI says so where it matters.

## Known placeholders (before anything real)

- **IRS withholding** is a simplified progressive approximation — must be replaced with the official *tabelas de retenção na fonte*, versioned by year, with marital status/dependents/region.
- **SS rates** (11% / 23.75%) unverified.
- **National percentile data** is illustrative — replace with a bundled JSON of real INE distribution buckets + "Fonte: INE, <year>" attribution.
- **Cohort medians/sigmas** in `CohortEngine.swift` are mock values — replace with real GEP/Quadros de Pessoal tables (same shape).
- **futureSeed pension math** is a stub (2%/year heuristic) — needs the real Segurança Social formula.
- No localization yet (EN only; PT/EN auto-detect planned), no premium/IAP, no accessibility pass.
