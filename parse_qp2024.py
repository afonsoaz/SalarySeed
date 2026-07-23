#!/usr/bin/env python3
"""
SalarySeed v0.4.1: extract cohort cells from GEP-MTSSS Quadros de Pessoal 2024.

Input: ../qp2024pub.xlsx (the Excel edition of the QP 2024 publication,
downloaded from gep.mtsss.gov.pt). Reference: October 2024, Continente,
private-sector employees. Ganho medio mensal = base + regular subsidies
+ overtime.

Tables used:
  Quadro 138  ganho medio by grupo etario (Continente TOTAL row)
  Quadro 114  ganho medio by NUTS II 2024 (Continente)
  Quadro 105  ganho medio by nivel de habilitacao (TOTAL row)
  Quadro 113  ganho medio by profissao, CPP major groups
  Quadro 39   worker counts by grupo etario x habilitacao (weights)

Aggregations (worker-count weighted):
  under25      = <18 + 18-24
  basic        = inferior ao 1.o ciclo + 1.o + 2.o + 3.o ciclo
  postSecondary= pos-secundario nao superior + CTeSP        (thin: <1% of workers)
  higher       = bacharelato + licenciatura + mestrado + doutoramento

Every printed value goes verbatim into Engine/SalaryDataset.swift.
"""
import openpyxl

wb = openpyxl.load_workbook('../qp2024pub.xlsx', read_only=True, data_only=True)

def rows(sheet):
    return list(wb[sheet].iter_rows(values_only=True))

# --- Quadro 39: counts ---------------------------------------------------
q39 = rows('Quadro 39')
counts_by_age = {}
for r in q39:
    label = str(r[0]).strip() if r[0] else ''
    if label in ('MENOS DE 18 ANOS', '18 A 24 ANOS', '25 A 34 ANOS', '35 A 44 ANOS',
                 '45 A 54 ANOS', '55 A 64 ANOS', '65 E + ANOS'):
        counts_by_age[label] = float(r[2])
total_row = next(r for r in q39 if r[1] and str(r[1]).strip() == 'TOTAL')
# columns: 2 TOTAL, 3 inf 1c, 4 1c, 5 2c, 6 3c, 7 sec, 8 pos-sec, 9 CTeSP,
#          10 bach, 11 lic, 12 mest, 13 dout
cnt = [float(total_row[i]) for i in range(2, 14)]
total_workers = cnt[0]

# --- Quadro 138: ganho by age (Continente TOTAL row) ---------------------
q138 = rows('Quadro 138')
age_row = next(r for r in q138 if r[0] and str(r[0]).strip() == 'TOTAL')
# columns: 1 TOTAL, 2 <18, 3 18-24, 4 25-34, 5 35-44, 6 45-54, 7 55-64, 8 65+
g = [float(age_row[i]) for i in range(1, 9)]
assert abs(g[0] - 1582.74) < 0.01, g[0]

u25 = (counts_by_age['MENOS DE 18 ANOS'] * g[1] + counts_by_age['18 A 24 ANOS'] * g[2]) \
      / (counts_by_age['MENOS DE 18 ANOS'] + counts_by_age['18 A 24 ANOS'])
print('age cells (ganho mean, Oct 2024):')
print(f'  under25    {u25:8.2f}   (weighted <18 + 18-24)')
for name, v in zip(['25-34', '35-44', '45-54', '55-64', '65+'], g[3:]):
    share = ''
    key = {'25-34': '25 A 34 ANOS', '35-44': '35 A 44 ANOS', '45-54': '45 A 54 ANOS',
           '55-64': '55 A 64 ANOS', '65+': '65 E + ANOS'}[name]
    share = f'{100 * counts_by_age[key] / total_workers:.1f}% of workers'
    print(f'  {name:<10} {v:8.2f}   ({share})')

# --- Quadro 114: ganho by NUTS II 2024 -----------------------------------
q114 = rows('Quadro 114')
print('\nregion cells (ganho mean, Oct 2024, NUTS 2024):')
region_names = ['Norte', 'Centro', 'Oeste e Vale do Tejo', 'Grande Lisboa',
                'Península de Setúbal', 'Alentejo', 'Algarve']
for r in q114:
    label = str(r[0]).strip() if r[0] else ''
    if label in region_names:
        print(f'  {label:<22} {float(r[5]):8.2f}')

# --- Quadro 105: ganho by habilitacao (TOTAL row) ------------------------
q105 = rows('Quadro 105')
edu_row = next(r for r in q105 if r[0] and str(r[0]).strip() == 'TOTAL')
e = [float(edu_row[i]) for i in range(1, 13)]
# e: 0 TOTAL, 1 inf 1c, 2 1c, 3 2c, 4 3c, 5 sec, 6 pos-sec, 7 CTeSP,
#    8 bach, 9 lic, 10 mest, 11 dout
assert abs(e[0] - 1582.74) < 0.01

def wavg(values, weights):
    return sum(v * w for v, w in zip(values, weights)) / sum(weights)

basic = wavg(e[1:5], cnt[1:5])
post = wavg(e[6:8], cnt[6:8])
higher = wavg(e[8:12], cnt[8:12])
print('\neducation cells (ganho mean, Oct 2024):')
print(f'  basic         {basic:8.2f}   ({100 * sum(cnt[1:5]) / total_workers:.1f}% of workers)')
print(f'  secondary     {e[5]:8.2f}   ({100 * cnt[5] / total_workers:.1f}%)')
print(f'  postSecondary {post:8.2f}   ({100 * sum(cnt[6:8]) / total_workers:.2f}%, thin)')
print(f'  higher        {higher:8.2f}   ({100 * sum(cnt[8:12]) / total_workers:.1f}%)')

# cross-check: count-weighted mean over all education levels vs national mean.
# ~2% low is expected: ganho tables cover full-time workers with complete pay,
# Quadro 39 counts all employees. Weights are shares, so this is fine for
# aggregating adjacent levels; it would not be fine for deriving levels.
chk = wavg(e[1:12], cnt[1:12])
assert abs(chk - 1582.74) < 50, chk
print(f'  [check] weighted mean over all levels = {chk:.2f} (published total 1582.74, gap = FT coverage)')

# --- Quadro 113: ganho by CPP major group --------------------------------
q113 = rows('Quadro 113')
print('\noccupation cells (ganho mean, Oct 2024):')
names = {1: 'managers', 2: 'specialists', 3: 'technicians', 4: 'administrative',
         5: 'services', 6: '(agriculture, unused)', 7: 'trades', 8: 'operators',
         9: 'elementary'}
for r in q113:
    a = str(r[0]).strip() if r[0] is not None else ''
    if a in '123456789' and len(a) == 1:
        print(f'  {names[int(a)]:<22} {float(r[5]):8.2f}')
