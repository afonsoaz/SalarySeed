# A corpus of payslips with an answer key

24 fictional payslips. Nobody's pay is in any of them, and every figure on every
page was computed by the app's own `TaxEngine` rather than typed in here.

That last part is the whole point. A real payslip has no answer key: you can
look at what the reader decided and you cannot check it, which is why
`tools/payslip_probe` is a dump rather than a pass or a fail. A generated one
has an answer key by construction, so the reading can be scored.

```bash
tools/payslip_corpus/build.sh
.build/payslip_corpus list
.build/payslip_corpus generate --out docs/fixtures/corpus   # html, pdf, truth
.build/payslip_corpus photos   --out docs/fixtures/corpus   # degraded jpegs
python3 tools/score_payslip_corpus.py --corpus docs/fixtures/corpus
python3 tools/score_payslip_corpus.py --corpus docs/fixtures/corpus --photos
```

Committed: the HTML, the PDF and a `.truth.json` per fixture, plus `manifest.json`.
A fresh clone can therefore run the harness without Chrome installed.

Not committed: `photos/`, the 144 degraded images. They are regenerable exactly,
because the noise is seeded rather than random, and 45MB of JPEG that rebuilds in
a minute does not belong in the history.

The PDFs' hashes are deliberately not in the manifest. Chrome stamps a creation
date into every file it prints, so the same HTML gives a different PDF on every
run. The HTML and truth hashes pin the content; the PDF is derived from it.

## What is in it

Layouts: one money column with the blocks stacked, which is the shape the repo's
original `exemplo-recibo.pdf` has; one description column with separate ABONOS
and DESCONTOS money columns, which is the commonest Portuguese shape and the only
stacked one whose geometry can tell the two sides apart; the two blocks as
separate tables side by side; and a quantity / rate / base / value layout.

Vocabulary: every label marked `lexicon` in a truth file is verbatim in
`PayslipLexicon.matchFixtures`, accents aside. The ones marked `attested` are off
real payslips but are not in that list. The ones marked `unknown` are deliberately
outside it.

Payroll shapes: ajudas de custo and a meal allowance beside the salary, which sit
outside the Social Security base and are the reason `onboarding.monthlyGrossCents`
is stated separately from `concepts.totalEarnings`; the holiday and Christmas
subsidies as duodécimos, with three Social Security lines and three IRS lines; the
minimum wage; all three fiscal regions; 12 and 14 month schedules; IRS Jovem; and
five money styles, every one of which is in `PayslipNumber.parsingFixtures` marked
as coming off a real document.

Traps: a "Valores Acumulados" year to date block whose own three figures satisfy
the net identity, printed larger than the month's own and with the real totals
labelled only "Total", so neither magnitude nor label can choose between the two
triples. A baited invoice carrying a "Total a pagar" and an amount that is exactly
11% of another, which must never produce a verdict. And four fixtures where one
figure was moved by a known amount after truth was computed, so detection can be
measured as well as correctness.

## What it cannot tell you

Stated here rather than in a footnote, because a corpus that oversells itself is
worse than none.

**Nothing about whether the 2026 tax tables are right.** The pages are computed
from `TaxEngine` and three of the checks compare against `TaxEngine`, so those
three are tautological here. `tools/verify_tax_engine.py` is what tests the
tables, against the AT workbooks. The shared engine is what makes the corpus
clean for its actual job: a `wrong` finding on a page generated to be correct
cannot be a disagreement about tax, so it can only be the reader accusing a
correct payslip.

**Nothing about real PDF generators.** Every page here is Chrome printed HTML,
and Chrome is the one generator nobody's payroll department uses. Primavera,
Sage, PHC, Cegid and Segurança Social Direta each write their own content
streams, and `PayslipPDF`'s entire strategy was chosen from how one Chrome file
behaved. Demo payslips from those vendors would close this and need no real pay
to do it. It is the biggest gap and the cheapest to close.

**It overstates label coverage, by construction.** The vocabulary comes from the
lexicon's own fixture list, so a corpus built this way cannot discover a label the
lexicon has never seen, which is the reader's likeliest real failure. The
generator prints how much of its vocabulary it borrowed for exactly this reason.

**The degraded images are not photographs.** An iPhone does its own sharpening,
tone mapping and JPEG, and Vision was trained on the output of pipelines like it.
Simulated blur and grain are a lower bound on realism. Crumple and paper texture
are absent rather than badly faked. No printed page has been photographed and
measured, by choice.

And one rule about using it at all: **no heuristic gets tuned on this corpus
alone.** `CLAUDE.md` warns against tuning the triple selection heuristic on one
observation. 24 fixtures generated by one program are 24 observations of that
program's habits.
