#!/usr/bin/env python3
"""
SalarySeed v0.4 dataset derivation (national curve).

NOTE (v0.4.1): cohort cells (age, region, education, occupation) now come
directly from the QP 2024 workbook via parse_qp2024.py. The education
rescaling at the bottom of this script is superseded and kept only as a
record of the v0.4 estimate. The national-curve derivation here is current.

Sources (all official, CC BY 4.0 or Eurostat open reuse policy):
  [SES]  INE, Inquerito a Estrutura dos Ganhos 2022 (Structure of Earnings
         Survey), via Eurostat earn_ses_monthly / earn_ses22_23, geo=PT,
         nace B-S excl O. Firms with 10+ employees. Monthly earnings, Oct 2022.
         FT: D1=814, MED=1099, D9=2612, MEAN=1483. All worktime MED=1069.
         Education means (all sizeclas GE10): ED0-2=1044, ED3_4=1197, ED5-8=2234,
         TOTAL=1479.
  [QP]   GEP-MTSSS, Quadros de Pessoal, October 2024 (ganho medio mensal =
         base + regular subsidies + overtime; private-sector employees).
         National mean 1582.74 (GEP QP2024 sintese). Occupation means from the
         same series (via Pordata, series 3808, values cross-checked against
         GEP sintese total 1582.7).
  [DMR]  INE, remuneracao bruta mensal media por trabalhador (Social Security
         DMR + CGA), annual: 2022 total=1412, 2024 total=1604, 2025 total=1694.
         (File: Quadros_Destaque_Remuneracoes_Dezembro 2025.xlsx, Quadro 1a.)

Model:
  National curve: two-piece log-normal anchored at the national median.
    sigma_low  from SES D1/MED, sigma_high from SES D9/MED (shape from SES 2022,
    assumed stable over 2 years).
    Median level at QP concept, Oct 2024: QP mean * SES med/mean ratio.
  Cohort cells: median = published mean * exp(-sigma^2/2)  (log-normal identity,
    self-consistent with the app's percentile model).
  SES-sourced education means are rescaled to QP Oct-2024 level with the ratio
    QP_mean_2024 / SES_mean_2022 (corrects vintage + firm-coverage in one step).
"""
import math

PHI = lambda z: 0.5 * math.erfc(-z / math.sqrt(2))
Z90 = 1.2815515655446004  # z for the 90th percentile

# --- anchors ---
SES = dict(d1=814.0, med=1099.0, d9=2612.0, mean=1483.0, mean_allsize_ge10=1479.0)
QP_MEAN_2024 = 1582.74
DMR = {2022: 1412.0, 2023: 1507.0, 2024: 1604.0, 2025: 1694.0}

sigma_low = math.log(SES['med'] / SES['d1']) / Z90
sigma_high = math.log(SES['d9'] / SES['med']) / Z90
med_over_mean = SES['med'] / SES['mean']
national_median = QP_MEAN_2024 * med_over_mean

print(f"sigma_low  = {sigma_low:.4f}")
print(f"sigma_high = {sigma_high:.4f}")
print(f"national median (QP concept, Oct 2024) = {national_median:.0f}")

def pct(g, med=None):
    med = med or national_median
    if g <= 0: return 0.0
    s = sigma_low if g < med else sigma_high
    return 100 * PHI(math.log(g / med) / s)

print("\nsanity percentiles:")
for g in [760, 820, 870, 1000, 1100, 1173, 1330, 1500, 1750, 2000, 2500, 3000, 4000, 5000, 7500, 10000]:
    print(f"  {g:>6} -> p{pct(g):.1f}")

# check implied D1/D9 at 2024 level
d1_2024 = national_median * math.exp(-Z90 * sigma_low)
d9_2024 = national_median * math.exp(Z90 * sigma_high)
print(f"\nimplied 2024 D1={d1_2024:.0f}  D9={d9_2024:.0f} (SES 2022: 814 / 2612)")

# --- distribution bars for the compare chart (log-normal density on log grid) ---
bars_gross = [600, 760, 870, 1000, 1150, 1330, 1500, 1700, 2000, 2300, 2700, 3200, 4000, 5000, 7000, 10000]
def density(g, med):
    # chart-only continuous variant: side-dependent sigma inside the kernel,
    # common normalisation, so the curve has no jump at the median
    s = sigma_low if g < med else sigma_high
    x = math.log(g / med) / s
    return math.exp(-0.5 * x * x)
dens = [density(g, national_median) for g in bars_gross]
mx = max(dens)
print("\ndistribution bars:")
print("  gross:", bars_gross)
print("  norm :", [round(d / mx, 3) for d in dens])

# --- cohort cells ---
def cell_from_mean(mean, sigma, scale=1.0):
    m = mean * scale
    return m, m * math.exp(-sigma * sigma / 2)

print("\n-- occupation (QP Oct 2024 means, sigma 0.60) --")
occ = dict(managers=3295.9, specialists=2400.0, technicians=1947.3,
           administrative=1391.2, services=1162.7, trades=1246.4,
           operators=1342.0, elementary=1058.5)
for k, v in occ.items():
    m, med = cell_from_mean(v, 0.60)
    print(f"  {k:<15} mean {m:7.1f} -> median {med:6.0f}")

print("\n-- education (SES 2022 means rescaled to QP Oct 2024, sigma 0.55) --")
scale = QP_MEAN_2024 / SES['mean_allsize_ge10']
print(f"  scale = {scale:.4f}")
edu = dict(basic=1044.0, secondary=1197.0, higher=2234.0)
for k, v in edu.items():
    m, med = cell_from_mean(v, 0.55, scale)
    print(f"  {k:<10} scaled mean {m:7.1f} -> median {med:6.0f}")
