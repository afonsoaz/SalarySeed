#!/usr/bin/env python3
"""Lift every line of app copy out of Localization.swift into docs/copy.md.

WHY THIS IS GENERATED. There are ~590 strings in two languages, and a document
that restates them by hand is wrong the first time somebody edits the source.
This reads the file that ships, so the review document cannot drift from it,
and `--verify` proves that by reading the document back and comparing.

WHAT IT COVERS. The `t(english, portuguese)` pairs inside `struct Strings`, which
is where the app's prose lives. Enum labels (`ProfileSignals`, `EuroDataset`,
`TaxEngine`, `AccentTheme`) and the 230 job titles in `JobTitles.swift` are
catalogue rather than copy and are deliberately out.

WHAT IT REFUSES TO HIDE. A handful of members build their string in code instead
of calling `t()` (the two ordinal helpers), and a handful are one value used in
both languages (`IRS`, the Eurostat attribution). Those cannot be shown as a pair
and they are listed anyway, with their line number, because a review document
that silently drops the strings it found awkward is a document that says the app
has less copy than it does.

    python3 tools/dump_copy.py              # write docs/copy.md
    python3 tools/dump_copy.py --verify     # check docs/copy.md matches the source
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "SalarySeed", "Models", "Localization.swift")
DOC = os.path.join(ROOT, "docs", "copy.md")

DECL = re.compile(r"^    (?:@\w+\s+)?(?:private\s+)?(?:var|func)\s+(\w+)")
# A call to `t`, and not the `private func t(...)` that declares it.
CALL = re.compile(r"(?<![A-Za-z0-9_.])(?<!func )t\(")
MARK = re.compile(r"^\s*// MARK:\s*(.+?)\s*$")


def read_string_literal(text, i):
    """Scan the Swift string literal starting at text[i] == '"'.

    Returns (literal_source, index_after_closing_quote). The literal comes back
    as written, so `\\(name)` and `\\n` survive into the document: a reviewer
    rewriting a sentence has to be able to see where a number gets dropped into
    it.
    """
    assert text[i] == '"'
    i += 1
    out = []
    while i < len(text):
        c = text[i]
        if c == "\\":
            nxt = text[i + 1]
            if nxt == "(":                      # interpolation, possibly nested
                depth, j = 0, i + 1
                while j < len(text):
                    if text[j] == '"':          # a string inside the expression
                        _, j = read_string_literal(text, j)
                        continue
                    if text[j] == "(":
                        depth += 1
                    elif text[j] == ")":
                        depth -= 1
                        if depth == 0:
                            j += 1
                            break
                    j += 1
                out.append(text[i:j])
                i = j
                continue
            out.append(text[i:i + 2])
            i += 2
            continue
        if c == '"':
            return "".join(out), i + 1
        out.append(c)
        i += 1
    raise ValueError("unterminated string literal")


def find_pairs(body):
    """Every t("en", "pt") in a chunk of source, in order."""
    pairs = []
    for m in CALL.finditer(body):
        i = m.end()
        try:
            while body[i] in " \n\t":
                i += 1
            if body[i] != '"':
                continue
            en, i = read_string_literal(body, i)
            while body[i] in " \n\t":
                i += 1
            if body[i] != ",":
                continue
            i += 1
            while body[i] in " \n\t":
                i += 1
            if body[i] != '"':
                continue
            pt, i = read_string_literal(body, i)
        except (IndexError, ValueError):
            continue
        pairs.append((en, pt))
    return pairs


def strip_comments(body):
    """Doc comments carry prose that is not copy. Drop them before scanning."""
    return "\n".join(l for l in body.split("\n") if not l.lstrip().startswith("//"))


def parse():
    """-> [(section, [(name, line, pairs, has_bare_literal)])] in source order."""
    lines = open(SOURCE, encoding="utf-8").read().split("\n")

    start = next(i for i, l in enumerate(lines) if l.startswith("struct Strings {"))
    end = next(i for i in range(start + 1, len(lines)) if lines[i] == "}")

    sections, section, members = [], "General", []
    name, first, buf = None, 0, []

    def flush():
        if name is None:
            return
        body = strip_comments("\n".join(buf))
        pairs = find_pairs(body)
        # A member with no pair but a literal of its own builds its string in
        # code. Recorded, not dropped. See the module docstring.
        bare = not pairs and '"' in body
        if pairs or bare:
            members.append((name, first + 1, pairs, bare))

    for i in range(start + 1, end):
        line = lines[i]
        m = MARK.match(line)
        if m:
            flush()
            name, buf = None, []
            if members:
                sections.append((section, members))
            section, members = m.group(1), []
            continue
        d = DECL.match(line)
        if d:
            flush()
            name, first, buf = d.group(1), i, [line]
            continue
        if name is not None:
            buf.append(line)

    flush()
    if members:
        sections.append((section, members))

    # EVERY `t(` IN THE STRUCT HAS TO HAVE BEEN LIFTED. A call this scanner
    # cannot read is the one shape of failure that would not show up anywhere:
    # the document would simply be shorter than the app, and nothing would say
    # so. `perPeriod` was exactly this, hiding its pair inside two ternaries.
    # If this ever fires, either the call is genuinely not a pair, in which case
    # rewrite it in the Swift so it is, or this scanner needs to learn the shape.
    struct_body = strip_comments("\n".join(lines[start + 1:end]))
    calls = len(CALL.findall(struct_body))
    lifted = sum(len(p) for _, ms in sections for _, _, p, _ in ms)
    if calls != lifted:
        raise SystemExit(
            "FAIL: %d `t(` calls in struct Strings, %d lifted into pairs. "
            "Something is being skipped silently." % (calls, lifted))

    return sections


def esc(text):
    """Put a string inside a markdown code span without it breaking out."""
    ticks = "`"
    while ticks in text:
        ticks += "`"
    pad = " " if text.startswith("`") or text.endswith("`") else ""
    return "%s%s%s%s%s" % (ticks, pad, text, pad, ticks)


def render(sections):
    n = sum(len(p) for _, ms in sections for _, _, p, _ in ms)
    out = [
        "# SalarySeed copy, both languages",
        "",
        "Every line of prose the app can show, in English and European Portuguese,",
        "grouped by the screen it belongs to.",
        "",
        "**Generated from `SalarySeed/Models/Localization.swift` by `tools/dump_copy.py`.**",
        "Editing this file changes nothing on its own; it is here to be read and marked up,",
        "and the edits get applied back to the Swift source afterwards.",
        "",
        "- **%d** string pairs." % n,
        "- `\\(name)` is a value dropped in at runtime. It has to survive a rewrite,",
        "  and it can move within the sentence.",
        "- `\\n` is a deliberate line break.",
        "- Portuguese is informal **tu**. No em dashes. Quote rates, not bare percentages.",
        "- A few entries say **built in code**: those are assembled in Swift rather than",
        "  written out as a pair, so they are listed with a line number instead of text.",
        "",
        "---",
        "",
    ]
    for section, members in sections:
        out.append("## %s" % section)
        out.append("")
        for name, line, pairs, bare in members:
            if bare:
                out.append("### `%s` — built in code" % name)
                out.append("")
                out.append("Assembled in Swift rather than written as a pair. "
                           "`Localization.swift:%d`." % line)
                out.append("")
                continue
            for idx, (en, pt) in enumerate(pairs):
                key = name if len(pairs) == 1 else "%s[%d]" % (name, idx)
                out.append("### `%s`" % key)
                out.append("")
                out.append("- **EN** %s" % esc(en))
                out.append("- **PT** %s" % esc(pt))
                out.append("")
        out.append("---")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


ENTRY = re.compile(r"^### `([^`]+)`(?: — built in code)?$")
SIDE = re.compile(r"^- \*\*(EN|PT)\*\* (`+)( ?)(.*?)\3\2$")


def read_back(path):
    """Pull (key, en, pt) back out of the rendered document."""
    found, key, side = [], None, {}
    for raw in open(path, encoding="utf-8").read().split("\n"):
        m = ENTRY.match(raw)
        if m:
            if key and len(side) == 2:
                found.append((key, side["EN"], side["PT"]))
            key, side = m.group(1), {}
            continue
        m = SIDE.match(raw)
        if m and key:
            side[m.group(1)] = m.group(4)
    if key and len(side) == 2:
        found.append((key, side["EN"], side["PT"]))
    return found


def verify(sections):
    if not os.path.exists(DOC):
        print("FAIL: %s does not exist. Run without --verify first." % DOC)
        return 1

    expected = []
    for _, members in sections:
        for name, _, pairs, bare in members:
            if bare:
                continue
            for idx, (en, pt) in enumerate(pairs):
                key = name if len(pairs) == 1 else "%s[%d]" % (name, idx)
                expected.append((key, en, pt))

    actual = read_back(DOC)
    if len(expected) != len(actual):
        print("FAIL: source has %d pairs, document has %d."
              % (len(expected), len(actual)))
        return 1

    bad = 0
    for (k1, e1, p1), (k2, e2, p2) in zip(expected, actual):
        if (k1, e1, p1) != (k2, e2, p2):
            bad += 1
            if bad <= 5:
                print("FAIL: %s\n  source EN %r\n    doc EN %r\n  source PT %r\n    doc PT %r"
                      % (k1, e1, e2, p1, p2))
    if bad:
        print("FAIL: %d of %d pairs differ." % (bad, len(expected)))
        return 1

    print("OK: %d pairs round-trip between %s and the document."
          % (len(expected), os.path.basename(SOURCE)))
    return 0


def main():
    sections = parse()
    if "--verify" in sys.argv:
        return verify(sections)
    os.makedirs(os.path.dirname(DOC), exist_ok=True)
    open(DOC, "w", encoding="utf-8").write(render(sections))
    n = sum(len(p) for _, ms in sections for _, _, p, _ in ms)
    code = sum(1 for _, ms in sections for _, _, _, b in ms if b)
    print("Wrote %s: %d pairs across %d sections, %d built in code."
          % (os.path.relpath(DOC, ROOT), n, len(sections), code))
    return 0


if __name__ == "__main__":
    sys.exit(main())
