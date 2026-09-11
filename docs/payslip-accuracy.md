# How accurately the payslip reader reads a payslip

Measured September 2026, against `tools/payslip_corpus`: 24 generated payslips,
three extraction paths, and 144 degraded images. Two things are scored: what the
reader decides about a payslip, and what `PayslipSalary` would propose as a salary
from it. Rerun both with

```bash
tools/payslip_probe/build.sh && tools/payslip_corpus/build.sh
.build/payslip_corpus generate --out docs/fixtures/corpus
.build/payslip_corpus photos   --out docs/fixtures/corpus
python3 tools/score_payslip_corpus.py --corpus docs/fixtures/corpus
python3 tools/score_payslip_corpus.py --corpus docs/fixtures/corpus --photos
```

Until now the reader had never been measured. It was built against two real
payslips, both since deleted from this machine on purpose, and the four files
that make a judgement about a page had no automated coverage at all.
`verify_payslip_reader.py` says so itself: it can check anything expressible as a
rule restated in Python, and a judgement is not one of those things.

The question this was built to answer is whether the reader is accurate enough to
move the payslip from a card on Home to the way into the app, filling in a salary
instead of typing one.

## The four things that had to be true

All four hold, on every fixture, every extraction path and every image quality.
`tools/score_payslip_corpus.py` exits non-zero on any of them and on nothing else.

| | |
|---|---|
| False accusations | **0** |
| Verdicts on things that are not payslips | **0** |
| Grosses that were wrong and silently accepted | **0** |
| Wrong salaries proposed | **0** |

The first is the strongest result here, and the corpus's shared tax engine is
what makes it clean rather than what weakens it: because the payslip and the
reconciler are computed from the same `TaxEngine`, a `wrong` finding on a page
generated to be correct cannot be a disagreement about tax. It can only be the
reader accusing a correct payslip. It never did.

The third and fourth are the ones the promotion decision actually turns on. The
third needs its own paragraph; the fourth has its own section, further down.

## Why silent-wrong is the metric and percent-correct is not

A typed salary has one property a read one cannot: the reader knows what they
typed. Every figure the app draws is a pure function of that single number, so a
gross wrong by ten percent is wrong on Home, on Compare, on the map, in Grow and
in the ajudas comparison, for ever, with no error and no crash, and nobody has any
reason to doubt it because they never saw a number to check.

So the outcomes are not right and wrong. They are:

- **right, and never asked about**: the figure is correct and the reader was not
  stopped
- **right, after review**: correct, and shown for confirmation first. One tap
- **wrong, but visible**: wrong or missing, and the reader was going to see it
  anyway. Costs a correction
- **wrong, and silent**: wrong, accepted, never shown. The only unacceptable one

## The gross, which is the figure onboarding needs

Out of 19 payslips generated to be correct:

| input | right, unasked | right, reviewed | wrong, visible | wrong, silent |
|---|---|---|---|---|
| PDF text layer | 5 | 14 | 0 | 0 |
| PDF, rasterised to Vision | 0 | 19 | 0 | 0 |
| clean render | 0 | 19 | 0 | 0 |
| flatbed scan | 0 | 19 | 0 | 0 |
| good photo | 0 | 18 | 1 | 0 |
| ordinary photo | 0 | 18 | 1 | 0 |
| poor photo | 0 | 19 | 0 | 0 |
| barely legible photo | 0 | 0 | 19 | 0 |
| PDF per character bounds | 0 | 10 | 9 | 0 |

The gross survives degradation better than anything else on the page, and the
reason is structural rather than lucky. It is recovered from the 11% Social
Security identity, which is arithmetic, and not from reading a label. Its score
is identical from a clean render down to a poor photo: 17 exact, 2 where a
defensible alternative reading was taken, 2 declined. It holds up even on images
where the row pairing collapsed and every other figure was lost, because finding
two amounts in an 11% relation does not depend on which label they sit beside.

When the page finally becomes unreadable, at the barely legible profile, the
reader reports nothing rather than something wrong. That is the behaviour the
whole design is for.

The one payslip that loses its gross on a photograph is the duodécimos fixture,
where the gross is genuinely ambiguous: the Social Security base is the salary
plus both subsidy twelfths, and the reader finds the salary. That is the case a
payslip should be refused for rather than read, and it is refused.

Everything else on the page degrades much harder. IRS and the printed totals are
frequently lost or misread on photographs. That costs checks. It never cost a
wrong answer.

## A bug this found, and fixed

**Thousands separated by a space were being dropped from every figure on the PDF
text path.** `2 400,00` was read as `400,00` and `1 699,59` as `699,59`.

`PayslipLayout.join` rejoins a thousands group to its remainder if the gap
between them is at most `joinTolerance` character widths, and `joinTolerance` is
0.4. That number was measured against real per word extents from Vision, where a
thousands space is genuinely narrower than a digit. But
`PayslipPDF.fragments(fromLinesOf:)` synthesises its x coordinates from the
character offset within the extracted line, so on that path a single space is
always exactly 1.0 character widths, and 1.0 is never under 0.4. The join could
not fire, ever.

Portuguese payslips commonly print `1 234,56`, so on the app's primary path every
figure over a thousand lost its leading digit. It failed safe, which is why it
was invisible: the reading stopped adding up, so all ten checks declined and
nothing was accused. But the feature would have been close to useless on those
payslips. The repo's only fixture used `2.400,00`, with a dot, which is why
neither real payslip nor any existing test could have shown it.

Fixed with a path aware tolerance, `syntheticJoinTolerance = 1.05`, selected by a
new `PayslipSource.hasSyntheticGeometry`. Just over one character is deliberate:
consecutive spaces each advance the offset, so a single space is a thousands
separator and anything wider is a column gap that must not be joined across. What
it weakens is documented at the constant.

Per the rule about capturing what a heuristic decides before changing it, all 73
probe dumps were captured before and diffed after. **Exactly two moved**, both of
them the broken fixtures, and 71 were untouched, including the committed
`exemplo-recibo` baseline, the entire per character bounds path and all 24 OCR
readings. The two that moved went from nothing reconciling to a confirmed net
identity, both runs closing at zero, and `deductionsSum` correct.

## Other findings, not acted on

These are recorded rather than fixed. Nothing here gets tuned on a synthetic
corpus alone.

**Two labels the lexicon reads wrongly.** "Base de incidência Segurança Social"
resolves to `employeeSS` rather than `ssBase`, and "Encargo da entidade
empregadora" resolves to nothing at all. Neither is in
`PayslipLexicon.matchFixtures`, which is why neither was known. In the full
pipeline the arithmetic overrides the first, so it does no visible harm today; it
is one heuristic away from doing some. This is also the first time anything has
read `matchFixtures`, which `CLAUDE.md` had listed as unread since v1.1.

**Detection is not monotonic in the size of the error.** A 0,30 euro and a 30,00
euro Social Security error were both caught by `deductionsSum`. A 500,00 euro IRS
error was missed. The large error is what destroys the arithmetic that identifies
the deductions total, and without that total the check that would have caught it
declines to run. An error can be big enough to hide itself.

**The engine checks almost never run.** `irsWithholding`, `netMonthly`,
`regionTable` and `jovemApplied` skip on 22 of 23 payslips, and `statedRate` on
all 23. Five of the ten checks do the work. This is the open thread `CLAUDE.md`
already records, that the engine models a month as gross times a schedule and
real payslips are not shaped like that, now with a number against it.

**The per character bounds path is much worse than either of the others**, 0
exact on every total across 23 fixtures. It is only ever reached when the line
path fails, so this costs nothing today, and it confirms the comment that put it
second.

## The salary it would propose

v1.2 lets the checker hand its figure back: the results screen ends by asking
whether the monthly gross it read should become your salary, and onboarding offers
to read a payslip instead of asking you to type a number. `PayslipSalary.propose`
is the only route across, and the probe prints what it decides in a `PROPOSAL`
block so it is measured rather than argued about.

Out of 19 payslips generated to be correct, 18 can be proposed from at all. The
nineteenth is the duodécimos fixture and it is refused on purpose, because the
Social Security base there is the salary plus both subsidy twelfths and storing
that as a monthly salary on a 14 month schedule would be 16.7% high in the
flattering direction, silently, for ever.

| input | proposed correctly | proposed wrongly | refused |
|---|---|---|---|
| PDF text layer | 18 | **0** | 1 |
| PDF, rasterised to Vision | 18 | **0** | 1 |
| clean render | 18 | **0** | 1 |
| flatbed scan | 18 | **0** | 1 |
| good photo | 18 | **0** | 1 |
| ordinary photo | 18 | **0** | 1 |
| poor photo | 18 | **0** | 1 |
| barely legible photo | 0 | **0** | 0 |

Not one wrong salary was proposed, on any input, at any image quality. The figure
is right on every proposable payslip from a clean render down to a poor
photograph, and the table is flat across that whole range for the same structural
reason the gross itself is: it comes from the 11% Social Security identity, which
is arithmetic and does not care which label sits beside the numbers.

The last row is the honest failure. At the barely legible profile the reading fails
outright, before any facts exist, so the reader gets the unreadable screen and is
never offered a figure at all. Nothing is proposed, nothing is refused, because the
question never arises.

The corroboration gate never produced a false refusal. On every one of these the
earnings total, minus the meal allowance and ajudas de custo, equalled the gross
found by the 11% identity to the cent. Two independent readings of the page, one
by an arithmetic identity and one by a printed total its own lines add up to,
agreeing 18 times out of 18. The two fixtures where the Social Security figure was
deliberately perturbed refuse with `noGrossFigure` rather than inventing a gross
without it, which is the design working rather than a refusal rate.

The ajudas fixtures are the ones worth looking at by hand. They print earnings of
2 675,40, and what is proposed is 2 400,00, with the 275,40 carried separately as
the meal allowance and ajudas de custo. Folding those into a gross would hide the
exact thing this app exists to show.

## What onboarding sees

At the salary step the reader has not said where they live, whether they are
married or how many dependants they have, so `PayslipReconciler.check` is called
with no context at all. Four of the ten checks still run and keep identical
figures: earnings and deductions each summing to their own printed total, the net
identity, and the Social Security rate, which reads a constant rather than a table.

The other six say so. Five skip with `profileIncomplete`, a reason that already
existed and had one user, and the sixth skips for whatever reason it would have
anyway. The screen names them and says the checker on the home screen will run them
once the profile is filled in.

`PayslipSalary` never reads the context, so the proposal is identical in onboarding
and on Home. The table above holds in both places.

```
  ---- VERDICT (no profile yet, as at onboarding) ----------------------
    correct  deductionsSum    expected=700,41   actual=700,41   delta=0,00
    correct  earningsSum      expected=2400,00  actual=2400,00  delta=0,00
    correct  netIdentity      expected=1699,59  actual=1699,59  delta=0,00
    correct  ssRate           expected=264,00   actual=264,00   delta=0,00

    skipped  irsWithholding   profileIncomplete
    skipped  jovemApplied     profileIncomplete
    skipped  minWage          profileIncomplete
    skipped  netMonthly       profileIncomplete
    skipped  regionTable      profileIncomplete
    skipped  statedRate       missingFigure
```

Reproduce it with `--no-context` on any fixture.

## What this does not tell you

The corpus's own limits are in `docs/fixtures/corpus/README.md` and they are
real: nothing about whether the tax tables are right, nothing about PDF
generators that are not Chrome, and label coverage overstated by construction
because the vocabulary came from the lexicon's own word list.

**The refusal rate above is not the refusal rate in the wild.** Eighteen out of
eighteen corroborated because these pages are internally perfect: every printed
total equals its own lines, because the generator refuses to emit one that does
not. A real payslip carries lines this reader has never seen a name for, and every
one of those that lands in the earnings total and not in the gross will trip
`earningsDisagree` and refuse. That is the intended trade, since a false refusal
costs one tap and a false proposal costs every figure in the app, but it means the
honest expectation for real payslips is "refuses more often than this", not
"proposes correctly 95% of the time". Nothing here measures how much more often.

One more belongs here rather than there. **No printed payslip has been
photographed and measured.** The degraded images are simulations: seeded grain,
a gaussian blur, a keystone, a shadow gradient. An iPhone does its own
sharpening, tone mapping and JPEG, and Vision was trained on the output of
pipelines like it. Every photograph number above is a lower bound on realism and
not a measurement of the camera path. Closing that needs a printer and ten
minutes and has not been done.

Two corrections worth recording, because both were believed for a while during
the measurement itself. Vision appeared to beat the PDF text layer outright; it
did not, the text layer had the space separator bug, and with it fixed the two
are level and the text path is slightly ahead on totals. And the first version of
the perspective simulation pulled two opposite corners inward, which shears a
page rather than keystoning it, so every amount on the right drifted a row
against its label on the left and a gentle profile scored worse than a rough one.
A simulator can be wrong in exactly the way it is meant to detect.

Finally, the six image profiles vary seven axes at once. They are six scenarios,
not a quality ladder, and should not be read as one. Single axis sweeps are what
would give a slope and they have not been run.
