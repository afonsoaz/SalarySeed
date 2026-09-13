#!/usr/bin/env python3
"""Two layout mistakes the compiler cannot see and a screenshot only shows late.

Both of these shipped. Neither produces a warning, an error, or anything visible
at the default text size, which is why they survived several releases.

1. TEXT IN A BUTTON LABEL WITH NO ALIGNMENT.
   SwiftUI centres the text inside a Button's label unless it is told otherwise.
   A one-line title never reveals it. A subtitle that wraps does: the second line
   sits centred under a left-aligned first line, which is what Afonso saw on the
   Profile rows ("Compara com pessoas da / tua idade").

2. A SCALING GLYPH IN A FIXED-WIDTH BOX.
   `.appFont(18)` grows with Dynamic Type; `.frame(width: 28)` does not. `frame`
   does not clip, so past the accessibility threshold the glyph draws straight
   out of its box and over the text beside it. This one has now been found three
   times in three different files, which is why `SignalRow` exists.

Neither check is clever. Both are greps with enough structure to know what they
are looking at, and both are advisory: a centred Button label is sometimes right,
and a fixed box around a glyph is fine when the glyph is fixed too.

    python3 tools/audit_layout.py
"""

import glob
import re
import sys

SRC = "SalarySeed/**/*.swift"


def button_labels(src):
    """(line, body) for every Button { ... } label: { ... }."""
    out = []
    for m in re.finditer(r"\bButton\s*[{(]", src):
        j, depth, started = m.start(), 0, False
        while j < len(src):
            if src[j] == "{":
                depth += 1
                started = True
            elif src[j] == "}":
                depth -= 1
                if started and depth == 0:
                    break
            j += 1
        tail = src[j + 1:j + 200]
        if re.match(r"\s*label:\s*\{", tail):
            j2 = j + 1 + tail.index("{")
            depth = 0
            while j2 < len(src):
                if src[j2] == "{":
                    depth += 1
                elif src[j2] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j2 += 1
            j = j2
        out.append((src[:m.start()].count("\n") + 1, src[m.start():j + 1]))
    return out


def unaligned_button_text(path, src):
    hits = []
    for line, body in button_labels(src):
        if "multilineTextAlignment" in body:
            continue
        texts = re.findall(r"Text\(", body)
        # One Text is a plain button title and centring it is usually right.
        # Two stacked in a VStack is a title over a subtitle, and the subtitle
        # is the one that wraps.
        if len(texts) >= 2 and "VStack" in body:
            hits.append((line, "%d Text in a Button label, no alignment" % len(texts)))
    return hits


GLYPH = re.compile(
    r"\.appFont\((\d+(?:\.\d+)?)[^\n]*\)(?:\s*\n[^\n]*?)*?\n[^\n]*?\.frame\(width: (\d+)",
)


def unscaled_glyph_box(path, src):
    hits = []
    lines = src.split("\n")
    for i, line in enumerate(lines):
        m = re.search(r"\.appFont\((\d+(?:\.\d+)?)", line)
        if not m:
            continue
        for k in range(i + 1, min(i + 5, len(lines))):
            f = re.search(r"\.frame\(width: (\d+(?:\.\d+)?)[,)]", lines[k])
            if not f:
                continue
            size, width = float(m.group(1)), float(f.group(1))
            # A box within about twice the glyph's design size is a box FOR the
            # glyph. Anything wider is a column, and a column holds text whose
            # own wrapping is a different question.
            if width <= size * 2:
                hits.append((i + 1, "appFont(%g) inside frame(width: %g)" % (size, width)))
            break
    return hits


def main():
    total = 0
    for path in sorted(glob.glob(SRC, recursive=True)):
        src = open(path, encoding="utf-8").read()
        for line, why in unaligned_button_text(path, src) + unscaled_glyph_box(path, src):
            print("%s:%d  %s" % (path, line, why))
            total += 1
    print("\n%d place%s to look at." % (total, "" if total == 1 else "s"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
