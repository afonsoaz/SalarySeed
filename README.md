# SalarySeed — v0.5

Preliminary iOS build of the SalarySeed concept (`../app-concept.md`). Everything works end-to-end. As of v0.4 the percentile and cohort comparisons run on real published data (GEP-MTSSS and INE); tax rates are still placeholders.

## Run it

1. Open `SalarySeed.xcodeproj` in Xcode 16 or newer (uses folder-synchronized groups, so new files added to the `SalarySeed/` folder appear in Xcode automatically).
2. Pick an iPhone simulator, press Run.

No dependencies, no backend, no account. Everything on-device.

## What's new in v0.5

- **Ajudas de custo as a first-class input.** A monthly amount that goes straight to net (no IRS, no SS), paid 12 times a year regardless of the 12/14 salary schedule. Stored in `SalaryStore.ajudasMonthly` and carried through `SalaryBreakdown` (`pocketMonthly`, `pocketYearly`, `ajudasYearly`). It never enters gross-based numbers: percentiles, cohort comparisons, employer cost and the efficiency card stay salary-only, and the UI says so wherever those numbers appear (red note on the Home percentile card and the compareSeed hero).
- **"In detail" redesigned as branching trees** (`Features/Home/DetailTree.swift`). Total cost for the company branches into gross salary and employer SS (each with its share of cost); total employee discounts branch into IRS and employee SS, each with its effective rate on gross. When ajudas exist, a red highlight card shows the amount and reminds the user that it is invisible to banks rating loans, to the future pension, and to social protection.
- **Update-salary button right on the Home screen**, opening the editor. The editor also takes the ajudas amount, with the not-in-percentiles note.
- **Onboarding asks for everything one by one**: name (skippable), salary (the only mandatory answer; continue stays disabled until a value is entered), gross/net + months, ajudas de custo (skippable), then age, region, education and profession as single-question screens with chip answers, each skippable. Answers commit at the end.
- **"Compare job offers" (offerSeed) teaser hidden** until the feature is implemented. The strings and the LockedRow component stay for its return.
- **futureSeed starts from the stored ajudas amount** when one exists.

## What's new in v0.4.1

- **All four cohort dimensions now run on real Quadros de Pessoal Oct 2024 data**, parsed straight from the publication workbook (`../qp2024pub.xlsx`) by `parse_qp2024.py`. Age cells from Quadro 138 (under-25 is a worker-count-weighted aggregate), region cells from Quadro 114, education upgraded from the SES 2022 estimate to direct QP figures from Quadro 105 (four real levels, including pós-secundário), occupation from Quadro 113. The national mean (€1,582.74) is consistent across every table used.
- **Regions moved to NUTS 2024**: Norte, Centro, Oeste e Vale do Tejo, Grande Lisboa, Península de Setúbal, Alentejo, Algarve, plus Açores and Madeira. The old "AM Lisboa" no longer exists in official statistics; a previously stored selection simply asks the user to re-pick. Açores and Madeira have no published cells yet (the QP publication covers Continente) and stay hidden in the pickers until their data lands.

## What's new in v0.4

- **Real salary data.** All percentile math now runs on official published figures, gathered from GEP-MTSSS (Quadros de Pessoal, October 2024), INE (Estrutura dos Ganhos 2022, via Eurostat; and the monthly remuneration series from Social Security data). Everything lives in one new file, `Engine/SalaryDataset.swift`, with full provenance comments.
- **National percentile is a two-piece log-normal.** Shape (dispersion below and above the median) from the Estrutura dos Ganhos 2022 deciles (D1 €814, median €1,099, D9 €2,612, full-time); level anchored to the Quadros de Pessoal Oct 2024 national mean ganho (€1,582.74), giving a derived national median of €1,173. Below-median and above-median tails have different spreads, which matches the Portuguese distribution (compressed at the bottom by the minimum wage, long tail at the top).
- **Cohort cells store the published mean** and derive their model median with the log-normal identity `median = mean × exp(-sigma²/2)`, using the same sigma as the percentile model. One assumption instead of two.
- **Git-managed from v0.2 onward.** This version was committed and tagged in the repo (`v0.4`), not copied into a sibling folder.

## Data sources (v0.4)

| Cut | Source | Reference |
| --- | --- | --- |
| National distribution shape | INE, Estrutura dos Ganhos 2022 (Eurostat `earn_ses_monthly`, PT, full-time) | Oct 2022 |
| National level | GEP-MTSSS, Quadros de Pessoal, national mean ganho | Oct 2024 |
| Occupation (8 CPP groups) | GEP-MTSSS, Quadros de Pessoal, Quadro 113 | Oct 2024 |
| Education (4 levels) | GEP-MTSSS, Quadros de Pessoal, Quadro 105 (weighted via Quadro 39) | Oct 2024 |
| Age bands (6) | GEP-MTSSS, Quadros de Pessoal, Quadro 138 | Oct 2024 |
| Region (NUTS II 2024, Continente) | GEP-MTSSS, Quadros de Pessoal, Quadro 114 | Oct 2024 |
| Level checks / growth | INE, remuneração bruta mensal média (DMR/Segurança Social + CGA) | 2015–2025 |

All sources are open data; commercial use is OK with attribution ("Fonte: GEP-MTSSS / INE" plus year), which the UI shows wherever data appears. Coverage: employees only (Quadros de Pessoal covers the private sector; the Estrutura dos Ganhos covers firms with 10 or more employees). Values are anchored to October 2024, the latest Quadros de Pessoal wave; national salaries grew about 5.6% during 2025 (DMR), so percentiles read slightly generous. `derive_dataset.py` in the repo root reproduces every derived constant from the published anchors.

## What's in the app (v0.1–v0.3)

- **Onboarding** with a welcome screen that asks for a name (skippable), then salary, then gross/net and 12/14 months. Seed-dot progress.
- **Home (netSeed)**: greeting, gross/net heroes with count-up and a leaf unfurl, cost-to-employer, where-the-money-goes bar, detail cards, national percentile, what-if nudges, locked growthSeed teaser ("Steps to improve your salary", coming in a later version).
- **compareSeed**: national percentile plus one comparison layer per filled profile signal (age band, NUTS II region, education, occupation group), each with a percentile bar, median caption, thin-sample and edge caveats, and source lines. Signals are added via chip picker sheets.
- **profileSeed**: "Your seed" sprout hero (profile completeness = growth stage), salary and name editing, add/edit rows for the four signals, language switch, privacy and source notes.
- **raiseSeed** and **futureSeed** sheets from Home.
- **Two languages** (English + European Portuguese, informal "tu"), runtime-switchable in profileSeed.

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
│   ├── SalaryDataset.swift  all real data + provenance (v0.4)
│   ├── PercentileEngine.swift  national two-piece log-normal percentile
│   └── CohortEngine.swift   cohort model + dimension descriptors
└── Features/
    ├── Shared/              SproutKit (sprout, seed dots, leaf, count-up), picker sheet
    ├── Onboarding/ Home/ Compare/ Raise/ Future/ Profile/
```

## Known limitations (v0.4)

- **IRS withholding** is a simplified progressive approximation. Replace with the official *tabelas de retenção na fonte*, versioned by year, with marital status/dependents/region.
- **SS rates** (11% / 23.75%) unverified.
- **Açores and Madeira** have no cohort cells yet (the QP publication covers Continente only) and are hidden in the region picker. They need the INE regional series or SREA/DREM tables.
- **Cohort sigmas** (0.50–0.60) are modeling assumptions, not published values. The national curve's sigmas are derived from published deciles.
- **The ganho tables cover full-time workers**; count weights used for aggregation cover all employees, which is fine for shares but explains a ~2% gap in the full cross-check (documented in `parse_qp2024.py`).
- **futureSeed pension math** is a stub (2%/year heuristic). Needs the real Segurança Social formula.
- No premium/IAP yet, no full accessibility pass. PT translations are informal ("tu") by design.
