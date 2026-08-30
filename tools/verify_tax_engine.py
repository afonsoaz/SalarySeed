#!/usr/bin/env python3
"""Verify SalarySeed's tax engine.

There is no test target in this project, so this script is what stands in for one
on the part of the app where being wrong matters most. It does four things:

  1. Parses the withholding tables straight out of TaxEngine.swift, so it checks
     the code that ships rather than a copy of it that can drift.
  2. Round-trips the Acores and Madeira tables against the AT workbooks in
     _archive/data-sources/. Every bracket, rate, parcela and formula.
  3. Replays the workbooks' own published "taxa efetiva no limite" column through
     the engine's formula, which tests the arithmetic and not just the numbers.
  4. Checks the invariants no source can give you: that net never falls as gross
     rises, that each region's minimum wage withholds nothing, that the annual
     escaloes' media rates agree with their normal rates, and that net -> gross
     inverts cleanly.

Continente cannot be round-tripped here: its table comes from Despacho 233-A/2026
and there is no workbook for it in the repo. Everything in (4) still covers it.

    python3 tools/verify_tax_engine.py

Exits non-zero if anything fails, so it can go in a pre-release check.
"""
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
SWIFT = ROOT / "SalarySeed" / "Engine" / "TaxEngine.swift"
WORKBOOKS = ROOT / "_archive" / "data-sources"
INF = float("inf")
NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"

failures = []


def fail(msg):
    failures.append(msg)
    print(f"  FAIL {msg}")


# ---------------------------------------------------------------- xlsx reading
from xml.etree import ElementTree as ET
NS = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'

def xlsx_load(path):
    z = zipfile.ZipFile(path)
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for si in root.findall(f'{NS}si'):
            shared.append(''.join(t.text or '' for t in si.iter(f'{NS}t')))
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    relmap = {r.get('Id'): r.get('Target') for r in rels}
    sheets = []
    for sh in wb.find(f'{NS}sheets'):
        rid = sh.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
        tgt = relmap[rid]
        if not tgt.startswith('xl/'): tgt = 'xl/' + tgt.lstrip('/')
        sheets.append((sh.get('name'), tgt))
    out = {}
    for name, tgt in sheets:
        root = ET.fromstring(z.read(tgt))
        grid = {}
        for c in root.iter(f'{NS}c'):
            ref = c.get('r'); t = c.get('t')
            v = c.find(f'{NS}v')
            isel = c.find(f'{NS}is')
            if t == 'inlineStr' and isel is not None:
                val = ''.join(x.text or '' for x in isel.iter(f'{NS}t'))
            elif v is None:
                continue
            elif t == 's':
                val = shared[int(v.text)]
            else:
                try: val = float(v.text)
                except (TypeError, ValueError): val = v.text
            m = re.match(r'([A-Z]+)(\d+)', ref)
            col, row = m.group(1), int(m.group(2))
            grid[(row, col)] = val
        out[name] = grid
    return out

def _colnum(c):
    n = 0
    for ch in c: n = n*26 + (ord(ch)-64)
    return n

def xlsx_rows(grid):
    if not grid: return []
    maxrow = max(r for r,_ in grid)
    res = []
    for r in range(1, maxrow+1):
        cells = {_colnum(c): v for (rr,c), v in grid.items() if rr == r}
        if cells:
            res.append((r, [cells.get(i) for i in range(1, max(cells)+1)]))
    return res


# ------------------------------------------------- reading the Swift as source
def parse_swift_tables():
    """Pull every `static let tableX: [Row] = [...]` out of TaxEngine.swift.

    Parsing the Swift rather than restating it is the whole point: a table
    retyped into this file would verify itself and nothing else.
    """
    src = SWIFT.read_text()
    tables = {}
    for m in re.finditer(r"static let (table\w+): \[Row\] = \[(.*?)\n    \]", src, re.S):
        name, body = m.group(1), m.group(2)
        rows = []
        for rm in re.finditer(r"Row\(upTo:\s*([^,]+),\s*rate:\s*([\d.]+),\s*abate:\s*\{([^}]*)\}\)", body):
            up, rate, abate = rm.group(1).strip(), float(rm.group(2)), rm.group(3).strip()
            upTo = INF if ".infinity" in up else float(up.replace("_", ""))
            fm = re.match(r"R in ([\d._]+) \* ([\d._]+) \* \(([\d._]+) - R\)", abate)
            if fm:
                spec = ("formula", *(float(g.replace("_", "")) for g in fm.groups()))
            else:
                cm = re.match(r"_ in ([\d._]+)", abate)
                if not cm:
                    fail(f"{name}: cannot read abate {abate!r}")
                    continue
                spec = ("const", float(cm.group(1).replace("_", "")))
            rows.append((upTo, rate, spec))
        tables[name] = rows
    return tables


def parse_swift_constants():
    src = SWIFT.read_text()
    out = {}
    for key, pat in (
        ("employeeSS", r"employeeSSRate = ([\d.]+)"),
        ("employerSS", r"employerSSRate = ([\d.]+)"),
        ("ias", r"static let ias = ([\d.]+)"),
        ("taxYear", r"static let taxYear = (\d+)"),
    ):
        m = re.search(pat, src)
        out[key] = float(m.group(1)) if m else None
    out["minWage"] = {r: float(v) for r, v in
                      re.findall(r"case \.(\w+): return (\d+)\n", src)[:3]} or None
    esc = [(INF if ".infinity" in u else float(u.replace("_", "")), float(n), float(md))
           for u, n, md in re.findall(
               r"Escalao\(upTo:\s*([^,]+),\s*normal:\s*([\d.]+),\s*media:\s*([\d.]+)\)", src)]
    out["escaloes"] = esc
    return out


def abate_at(spec, R):
    if spec[0] == "const":
        return spec[1]
    _, rate, mult, const = spec
    return rate * mult * (const - R)


def withholding(table, R, per_dep, dependents):
    for upTo, rate, spec in table:
        if R <= upTo:
            return max(0.0, R * rate - abate_at(spec, R) - dependents * per_dep)
    return 0.0


# --------------------------------------------------- (2) and (3): the workbooks
def workbook_tables(path):
    """Every 'Tabela N' block in the workbook's Categoria A sheet."""
    grid = xlsx_load(path)["Categoria A"]
    out, cur = {}, None
    for _, cells in xlsx_rows(grid):
        text = " ".join(str(c) for c in cells if isinstance(c, str))
        if "Tabela" in text and "Trabalho dependente" in text:
            cur = text.split("-")[0].strip()
            out[cur] = []
            continue
        if cur is None:
            continue
        # Find the 'Até' cell rather than assuming a column. These sheets have an
        # empty column A, which is the off-by-one that makes a hand-indexed
        # parser read zero rows and report a clean pass.
        idx = next((i for i, v in enumerate(cells)
                    if isinstance(v, str) and v.strip() in ("Até", "Superior a")), None)
        if idx is None:
            continue
        c = cells + [None] * (idx + 16 - len(cells))
        if not isinstance(c[idx + 1], float):
            continue
        upTo = INF if c[idx].strip() == "Superior a" else c[idx + 1]
        if isinstance(c[idx + 5], str) and c[idx + 5].strip() == "x":
            spec = ("formula", c[idx + 4], c[idx + 6], c[idx + 8])
        else:
            spec = ("const", c[idx + 4] or 0.0)
        out[cur].append(dict(upTo=upTo, rate=c[idx + 2], abate=spec,
                             per_dep=c[idx + 10], eff=c[idx + 13]))
    return out


def check_region(region, filename, swift_tables, pairs):
    print(f"\n-- {region}: tables vs {filename}")
    wb = workbook_tables(WORKBOOKS / filename)
    for tname, swift_name in pairs:
        if tname not in wb:
            fail(f"{region}: workbook has no {tname}")
            continue
        xl, sw = wb[tname], swift_tables[swift_name]
        if len(xl) != len(sw):
            fail(f"{region} {tname}: workbook {len(xl)} rows, Swift {len(sw)}")
            continue
        bad = False
        for i, (x, (su, sr, sspec)) in enumerate(zip(xl, sw), 1):
            if (x["upTo"] == INF) != (su == INF) or (su != INF and abs(x["upTo"] - su) > 1e-9):
                fail(f"{region} {tname} row {i}: upTo {x['upTo']} vs {su}"); bad = True
            if abs(x["rate"] - sr) > 1e-9:
                fail(f"{region} {tname} row {i}: rate {x['rate']} vs {sr}"); bad = True
            if x["abate"][0] != sspec[0]:
                fail(f"{region} {tname} row {i}: abate is {x['abate'][0]} in the "
                     f"workbook and {sspec[0]} in Swift"); bad = True
            else:
                probe = su - 10 if su != INF else 30000
                if abs(abate_at(x["abate"], probe) - abate_at(sspec, probe)) > 1e-6:
                    fail(f"{region} {tname} row {i}: abate differs at R={probe}"); bad = True
        if not bad:
            print(f"  ok   {tname}: {len(xl)} rows identical to the workbook")

        # (3) replay the workbook's own published effective rate through the formula
        pts = [(r["upTo"], r["eff"]) for r in xl
               if r["upTo"] != INF and isinstance(r["eff"], float)]
        off = [(l, e, withholding(sw, l, 0, 0) / l) for l, e in pts
               if abs(withholding(sw, l, 0, 0) / l - e) > 6e-4]
        if off:
            for l, e, g in off:
                fail(f"{region} {tname} @{l}: workbook effective {e:.4f}, engine {g:.4f}")
        else:
            print(f"  ok   {tname}: engine reproduces {len(pts)} published effective rates")


# ------------------------------------------- (4) the invariants no source gives
def check_invariants(t, k):
    escaloes = k["escaloes"]

    print("\n-- net never falls as gross rises")
    for region, single, married in (
            ("continente", t["tableSingle"], t["tableMarriedOne"]),
            ("acores", t["tableSingleAcores"], t["tableMarriedOneAcores"]),
            ("madeira", t["tableSingleMadeira"], t["tableMarriedOneMadeira"])):
        for label, table, per_dep in (("single/0", single, 21.43),
                                      ("single/2", single, 34.29),
                                      ("married1", married, 42.86)):
            deps = 2 if label == "single/2" else 0
            worst, prev, prev_g = None, -1.0, None
            g = 700.0
            while g <= 25000:
                net = g - g * k["employeeSS"] - withholding(table, g, per_dep, deps)
                if net < prev - 1e-9 and (worst is None or prev - net > worst[2]):
                    worst = (prev_g, g, prev - net)
                prev, prev_g = net, g
                g += 1.0
            if worst:
                fail(f"{region}/{label}: gross {worst[0]:.0f} -> {worst[1]:.0f} "
                     f"LOSES {worst[2]:.2f} of net")
            else:
                print(f"  ok   {region}/{label}")

    print("\n-- the minimum wage withholds nothing")
    for region, mw, tabs in (("continente", 920, ("tableSingle", "tableMarriedOne")),
                             ("acores", 966, ("tableSingleAcores", "tableMarriedOneAcores")),
                             ("madeira", 980, ("tableSingleMadeira", "tableMarriedOneMadeira"))):
        for tn in tabs:
            w = withholding(t[tn], mw, 21.43, 0)
            if abs(w) > 1e-9:
                fail(f"{region} {tn}: minimum wage {mw} withholds {w:.2f}")
        print(f"  ok   {region}: {mw} withholds 0.00 in both tables")

    print("\n-- annual escaloes: media agrees with normal")
    lower = 0.0
    for i, (upTo, normal, media) in enumerate(escaloes[:-1]):
        tax = upTo * normal if i == 0 else lower * escaloes[i - 1][2] + (upTo - lower) * normal
        implied = tax / upTo
        if abs(implied - media) > 1e-4:
            fail(f"escalao {i+1} (top {upTo:.0f}): media {media:.5f}, implied {implied:.5f}")
        lower = upTo
    print(f"  ok   all {len(escaloes)-1} finite brackets")

    print("\n-- degenerate inputs")
    for g in (0.0, 0.01):
        w = withholding(t["tableSingle"], g, 21.43, 0)
        if w < 0 or w > g:
            fail(f"gross {g}: withholding {w}")
    print("  ok   zero and near-zero gross withhold nothing negative")

    print("\n-- net -> gross inverts")
    def net_of(g):
        return g - g * k["employeeSS"] - withholding(t["tableSingle"], g, 21.43, 0)
    worst = 0.0
    for g in (800, 1100, 1500, 2000, 3000, 5000, 10000):
        target = net_of(g)
        lo, hi = target, target * 3 + 1000
        for _ in range(60):
            mid = (lo + hi) / 2
            if net_of(mid) < target: lo = mid
            else: hi = mid
        worst = max(worst, abs((lo + hi) / 2 - g))
    if worst > 0.01:
        fail(f"net->gross worst error {worst:.4f}")
    print(f"  ok   worst round-trip error {worst:.6f} EUR over 7 salaries")


def main():
    if not SWIFT.exists():
        print(f"cannot find {SWIFT}"); return 2
    tables = parse_swift_tables()
    consts = parse_swift_constants()
    print(f"TaxEngine.swift: {len(tables)} withholding tables, "
          f"{len(consts['escaloes'])} annual escaloes, fiscal year {consts['taxYear']:.0f}")
    print(f"SS: employee {consts['employeeSS']:.2%}, employer {consts['employerSS']:.2%}")

    missing = [f for f in ("Tabelas_RF_RA_Acores_2026.xlsx", "Tabelas_RF_2026_RAM.xlsx")
               if not (WORKBOOKS / f).exists()]
    if missing:
        print(f"\nSKIPPING the workbook round-trip: {', '.join(missing)} not in "
              f"{WORKBOOKS.relative_to(ROOT)} (it is gitignored, so a fresh clone "
              f"will not have it).")
    else:
        check_region("Acores", "Tabelas_RF_RA_Acores_2026.xlsx", tables,
                     [("Tabela I", "tableSingleAcores"), ("Tabela II", "tableSingleAcores"),
                      ("Tabela III", "tableMarriedOneAcores")])
        check_region("Madeira", "Tabelas_RF_2026_RAM.xlsx", tables,
                     [("Tabela I", "tableSingleMadeira"), ("Tabela II", "tableSingleMadeira"),
                      ("Tabela III", "tableMarriedOneMadeira")])

    check_invariants(tables, consts)

    print("\n" + "=" * 62)
    if failures:
        print(f"{len(failures)} FAILURE(S)")
        return 1
    print("everything checks out")
    return 0


if __name__ == "__main__":
    sys.exit(main())
