#!/usr/bin/env python3
"""Verify SalarySeed's payslip reader.

There is no test target in this project, so this script is what stands in for
one on the layer that turns a photograph into an accusation. It does six things,
reported as seven lines because the label check prints its two halves separately:

  1. Reimplements the money parser from the rules, in Python, and runs it over
     the fixtures parsed out of PayslipNumber.swift. A table retyped into this
     file would verify itself and nothing else, so the tokens come from the
     shipping source.
  2. Checks the homoglyph table cannot corrupt good input: every value is a
     digit, no key is already a digit or a separator, and applying it twice is
     the same as applying it once.
  3. Checks every lexicon pattern normalises to itself. A pattern carrying an
     accent, a capital or an abbreviation could never match anything, and no
     compiler would say so.
  4. Round-trips integer cents: format then reparse returns the same number.
  5. Checks the tolerance constants are ordered so a one-cent difference can
     never become an accusation. Two constants in the wrong order is the bug
     that makes the app tell people their employer stole from them over
     rounding, and nothing else would catch it.
  6. Checks the reader reads its rates from TaxEngine rather than retyping
     them, so a change to the engine cannot leave the checker behind.

What it does NOT do: run the Swift. Everything above is a rule restated in
Python and compared, which works because a rule has a source to compare against.
Four files resisted that completely: PayslipLayout, PayslipDocument,
PayslipClassifier and PayslipReconciler do not restate a table, they make a
judgement about a page, and a Python twin of a judgement is a second opinion
rather than a check.

Those are covered by tools/payslip_probe instead, which compiles the shipping
Engine sources into a command line tool and prints what they decide about a real
payslip. It is a dump rather than a pass/fail, because there is no answer key for
a payslip; its value is the diff across a change. It is not run here and does not
gate a release, because it needs a real payslip and those are somebody's actual
pay: payslip_examples/ is gitignored and a fresh clone has nothing to point it
at. This script is what has to pass.

Still open: replaying the reconciler over SYNTHETIC payslips built from
TaxEngine's own output. The probe makes it possible, since it already compiles
the engine, and nothing automated exercises the classifier or the reconciler
until it exists. PayslipLexicon.matchFixtures is also still read by nothing, so
check 3 verifies that patterns normalise to themselves and never that a label
picks the right concept.

    python3 tools/verify_payslip_reader.py

Exits non-zero if anything fails, so it can go in a pre-release check.
"""
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE = ROOT / "SalarySeed" / "Engine"

failures = []


def fail(msg):
    failures.append(msg)
    print(f"  FAIL {msg}")


def source(name):
    return (ENGINE / name).read_text(encoding="utf-8")


def unescape(text):
    """Swift's \\u{XXXX} to the character it means."""
    return re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m.group(1), 16)), text)


# ------------------------------------------------------------------ the tables

def parse_char_map(swift, name):
    block = re.search(rf"static let {name}: \[Character: Character\] = \[(.*?)\n    \]",
                      swift, re.S)
    if not block:
        fail(f"could not find {name}")
        return {}
    out = {}
    for k, v in re.findall(r'"((?:\\u\{[0-9A-Fa-f]+\})|[^"])"\s*:\s*"([^"])"', block.group(1)):
        out[unescape(k)] = v
    return out


def parse_char_set(swift, name):
    # Non-greedy to the FIRST closing bracket, not to a newline-indented one.
    # currencyLikes is written on a single line, and anchoring on "\n    ]"
    # ran past it into the next eighty lines of code, collecting every quoted
    # character in them: " ", "-" and "h" among others. Those were then deleted
    # from every input, which broke sixty-nine checks at once and looked for a
    # moment like the Swift was wrong.
    block = re.search(rf"static let {name}: Set<Character> = \[(.*?)\]", swift, re.S)
    if not block:
        fail(f"could not find {name}")
        return set()
    return {unescape(c) for c in re.findall(r'"((?:\\u\{[0-9A-Fa-f]+\})|[^"])"', block.group(1))}


def parse_string_array(swift, name):
    block = re.search(rf"static let {name}: \[String\] = \[(.*?)\n    \]", swift, re.S)
    if not block:
        fail(f"could not find {name}")
        return []
    return [unescape(s) for s in re.findall(r'"((?:[^"\\]|\\.)*)"', block.group(1))]


def parse_abbreviations(swift):
    block = re.search(r"static let abbreviations: \[String: String\] = \[(.*?)\n    \]",
                      swift, re.S)
    if not block:
        fail("could not find abbreviations")
        return {}
    return dict(re.findall(r'"([a-z]+)"\s*:\s*"([a-z ]+)"', block.group(1)))


def parse_patterns(swift):
    block = re.search(r"static let patterns: \[PayslipConcept: \[String\]\] = \[(.*?)\n    \]\n",
                      swift, re.S)
    if not block:
        fail("could not find lexicon patterns")
        return {}
    out = {}
    for concept, body in re.findall(r"\.(\w+): \[(.*?)\n        \]", block.group(1), re.S):
        out[concept] = re.findall(r'"([^"]*)"', body)
    return out


TEXT = source("PayslipText.swift")
NUMBER = source("PayslipNumber.swift")
LEXICON = source("PayslipLexicon.swift")
FINDING = source("PayslipFinding.swift")
CLASSIFIER = source("PayslipClassifier.swift")

HOMOGLYPHS = parse_char_map(TEXT, "homoglyphs")
SPACES = parse_char_set(TEXT, "spaceLikes")
DASHES = parse_char_set(TEXT, "dashLikes")
APOSTROPHES = parse_char_set(TEXT, "apostropheLikes")
CURRENCY = parse_char_set(TEXT, "currencyLikes")
ABBREV = parse_abbreviations(TEXT)
PATTERNS = parse_patterns(LEXICON)
STOPWORDS = set(re.findall(r'"(\w+)"', re.search(
    r"static let stopwords: Set<String> = \[(.*?)\n    \]", LEXICON, re.S).group(1)))


# ------------------------------------------- the parser, written from the rules

def normalize_separators(text):
    out = []
    for ch in text:
        if ch in SPACES:
            out.append(" ")
        elif ch in DASHES:
            out.append("-")
        elif ch in APOSTROPHES or ch in CURRENCY:
            continue
        else:
            out.append(ch)
    return "".join(out)


def digit_share(text):
    if not text:
        return 0.0
    return sum(1 for c in text if c.isdigit()) / len(text)


def dehomoglyph(text):
    return "".join(HOMOGLYPHS.get(c, c) for c in text)


def digit_run_after(s, i):
    j, n = i + 1, 0
    while j < len(s) and s[j].isdigit():
        n += 1
        j += 1
    return n if j == len(s) else -1


def whole_number(text):
    if text == "":
        return 0, False
    seps = " .,"
    if not any(c in seps for c in text):
        return (int(text), False) if text.isdigit() else None
    groups = [g for g in re.split(r"[ .,]", text) if g]
    if len(groups) < 2 or not (1 <= len(groups[0]) <= 3):
        return None
    if any(len(g) != 3 for g in groups[1:]):
        return None
    if not all(g.isdigit() for g in groups):
        return None
    return int("".join(groups)), True


def magnitude(s):
    if not s:
        return None
    if not all(c.isdigit() or c in " .," for c in s):
        return None
    if not any(c.isdigit() for c in s):
        return None
    last_comma, last_dot = s.rfind(","), s.rfind(".")
    dec = -1
    if last_comma == -1 and last_dot == -1:
        dec = -1
    elif last_dot == -1:
        dec = last_comma if digit_run_after(s, last_comma) == 2 else -1
    elif last_comma == -1:
        dec = last_dot if digit_run_after(s, last_dot) == 2 else -1
    else:
        right = max(last_comma, last_dot)
        dec = right if digit_run_after(s, right) == 2 else -1

    if dec >= 0:
        integer_text, fraction = s[:dec], s[dec + 1:]
        if len(fraction) != 2 or not fraction.isdigit():
            return None
        fraction_value = int(fraction)
    else:
        integer_text, fraction_value = s, 0

    w = whole_number(integer_text)
    if w is None:
        return None
    value, grouped = w
    if dec < 0 and not grouped:
        return None
    return value * 100 + fraction_value


def strip_token(token):
    s = normalize_separators(token).strip()
    for word in ("EUR", "eur", "Eur"):
        if s.endswith(word):
            s = s[: -len(word)].strip()
            break
    negative = False
    if s.startswith("(") and s.endswith(")") and len(s) > 2:
        negative, s = True, s[1:-1]
    if s.startswith("-"):
        negative, s = True, s[1:]
    if s.endswith("-"):
        negative, s = True, s[:-1]
    s = s.strip()
    if len(s) > 1 and s[-1] in "DC" and s[-2].isdigit():
        s = s[:-1].strip()
    return s, negative


def cents(token):
    body, negative = strip_token(token)
    if not body:
        return None
    value = magnitude(body)
    if value is None:
        if digit_share(body) < 0.5:
            return None
        repaired = dehomoglyph(body)
        if repaired == body:
            return None
        value = magnitude(repaired)
        if value is None:
            return None
    return -value if negative else value


def rate_hundredths(token):
    body, _ = strip_token(token)
    if not body or not all(c.isdigit() or c in ".," for c in body):
        return None
    parts = re.split(r"[.,]", body)
    if len(parts) > 2 or not parts[0] or not parts[0].isdigit():
        return None
    whole = int(parts[0])
    if len(parts) == 1:
        return whole * 100
    frac = parts[1]
    if not frac or len(frac) > 2 or not frac.isdigit():
        return None
    return whole * 100 + (int(frac) * 10 if len(frac) == 1 else int(frac))


def format_cents(value):
    negative = value < 0
    magnitude_value = abs(value)
    whole, frac = str(magnitude_value // 100), f"{magnitude_value % 100:02d}"
    grouped = ""
    while len(whole) > 3:
        grouped = " " + whole[-3:] + grouped
        whole = whole[:-3]
    return ("-" if negative else "") + whole + grouped + "," + frac


def fold(text):
    stripped = "".join(c for c in unicodedata.normalize("NFD", text)
                       if not unicodedata.combining(c))
    return stripped.lower()


def normalize_label(text):
    folded = fold(normalize_separators(text))
    rough = "".join(c if (c.isalpha() or c.isdigit()) else " " for c in folded)
    out = []
    for token in rough.split():
        out.extend(ABBREV.get(token, token).split())
    return " ".join(out)


# ------------------------------------------------------------------- the checks

def split_fixture(row):
    head, _, tail = row.partition(" => ")
    return head, tail


def check_number_fixtures():
    print("number parsing, two independent implementations")
    for row in parse_string_array(NUMBER, "parsingFixtures"):
        token, expected = split_fixture(row)
        got = cents(token)
        text = "nil" if got is None else str(got)
        if text != expected:
            fail(f'cents("{token}") = {text}, fixture says {expected}')
    for row in parse_string_array(NUMBER, "rateFixtures"):
        token, expected = split_fixture(row)
        got = rate_hundredths(token)
        text = "nil" if got is None else str(got)
        if text != expected:
            fail(f'rate("{token}") = {text}, fixture says {expected}')


def check_homoglyphs():
    print("homoglyph table cannot corrupt good input")
    if chr(0x0437) not in HOMOGLYPHS:
        fail("homoglyphs is missing CYRILLIC SMALL ZE, the one measured on a real payslip")
    for key, value in HOMOGLYPHS.items():
        if not value.isdigit():
            fail(f"homoglyph {key!r} maps to {value!r}, which is not a digit")
        if key.isdigit() or key in " .,":
            fail(f"homoglyph key {key!r} is already a digit or a separator")
    for key in HOMOGLYPHS.values():
        if key in HOMOGLYPHS:
            fail(f"homoglyph output {key!r} is itself a key, so the map is not idempotent")
    for row in parse_string_array(TEXT, "homoglyphFixtures"):
        raw, expected = split_fixture(row)
        got = dehomoglyph(raw)
        if got != expected:
            fail(f'deHomoglyph("{raw}") = "{got}", fixture says "{expected}"')


def check_labels():
    print("every lexicon pattern normalises to itself")
    seen = {}
    for concept, forms in PATTERNS.items():
        for form in forms:
            if normalize_label(form) != form:
                fail(f'{concept} pattern "{form}" normalises to "{normalize_label(form)}"')
            for word in form.split():
                if word in STOPWORDS:
                    fail(f'{concept} pattern "{form}" contains the stopword "{word}"')
            if form in seen and seen[form] != concept:
                fail(f'pattern "{form}" is claimed by {seen[form]} and {concept}')
            seen[form] = concept
    print("label normalisation fixtures")
    for row in parse_string_array(TEXT, "labelFixtures"):
        raw, expected = split_fixture(row)
        got = normalize_label(raw)
        if got != expected:
            fail(f'normalizeLabel("{raw}") = "{got}", fixture says "{expected}"')


def check_round_trip():
    print("integer cents round-trip")
    for value in [0, 1, 5, 99, 100, 999, 1000, 12345, 100000, 591022, 2231180,
                  -30160, 99999999]:
        text = format_cents(value)
        back = cents(text)
        if back != value:
            fail(f"{value} formats to \"{text}\" and reparses as {back}")


def check_tolerances():
    print("tolerances ordered so rounding cannot become an accusation")
    got = {}
    for name in ("roundingCents", "materialCents", "materialPerMille"):
        m = re.search(rf"static let {name} = (\d+)", FINDING)
        if not m:
            fail(f"could not find {name}")
            return
        got[name] = int(m.group(1))
    if not got["materialCents"] > got["roundingCents"] > 0:
        fail(f"materialCents ({got['materialCents']}) must exceed "
             f"roundingCents ({got['roundingCents']}), which must exceed 0")
    if got["materialPerMille"] <= 0:
        fail("materialPerMille must be positive")

    def tier(delta, confidence, base):
        if delta == 0:
            return "correct"
        if confidence == "low":
            return "mention"
        if abs(delta) <= got["roundingCents"]:
            return "mention"
        if abs(delta) < got["materialCents"]:
            return "mention"
        if base and abs(delta) * 1000 < got["materialPerMille"] * abs(base):
            return "mention"
        return "wrong"

    for delta in (1, 2, -1, -2):
        for confidence in ("low", "medium", "high"):
            if tier(delta, confidence, 500000) == "wrong":
                fail(f"a {delta} cent difference reached 'wrong' at {confidence} confidence")
    for confidence in ("medium", "high"):
        if tier(100000, confidence, 500000) != "wrong":
            fail("a 1000 euro difference on a 5000 euro base did not reach 'wrong'")
    if tier(100000, "low", 500000) != "mention":
        fail("a low-confidence figure was allowed to accuse somebody")


def check_rates_come_from_the_engine():
    print("rates are read from TaxEngine, not retyped")
    if "TaxEngine.employeeSSRate" not in CLASSIFIER:
        fail("PayslipClassifier does not read TaxEngine.employeeSSRate")
    for literal in ("0.11", "0.2375"):
        if literal in CLASSIFIER:
            fail(f"PayslipClassifier hardcodes {literal} instead of reading the engine")


def main():
    print("Verifying the payslip reader\n")
    check_number_fixtures()
    check_homoglyphs()
    check_labels()
    check_round_trip()
    check_tolerances()
    check_rates_come_from_the_engine()
    print()
    if failures:
        print(f"{len(failures)} failure{'s' if len(failures) != 1 else ''}")
        return 1
    print("everything checks out")
    return 0


if __name__ == "__main__":
    sys.exit(main())
