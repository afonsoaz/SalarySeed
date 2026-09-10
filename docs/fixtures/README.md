# A payslip you can actually run the checker on

`exemplo-recibo.pdf` is fictional. Nobody's pay is in it. The figures come from
the app's own `TaxEngine`, computed for a €2 400,00 monthly gross on Continente,
single, no dependants, 14 months:

| | |
|---|---|
| Vencimento base | 2.400,00 |
| Segurança Social, 11% | 264,00 |
| IRS retido | 436,41 |
| Total descontos | 700,41 |
| Líquido | 1.699,59 |

It exists because real payslips carry a name, an employer, a tax number and a
salary, so they are gitignored and a fresh clone has nothing to point the probe
at. This gives you something.

`exemplo-recibo.html` is the source. Regenerate the PDF with:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --no-pdf-header-footer --print-to-pdf=docs/fixtures/exemplo-recibo.pdf \
  file://$PWD/docs/fixtures/exemplo-recibo.html
```

`exemplo-recibo.probe.txt` is what the reader currently decides about it. That is
the baseline to diff against, per the rule about capturing what a heuristic
decides before changing it.

**What it currently produces: four checks correct, six not run.** The net
identity is confirmed, and Social Security is found by the 11% relation rather
than by its label. The six that skip do so because no `irs` figure is extracted,
and that in turn is because this payslip has a single money column, so nothing
separates the deductions run geometrically. A real payslip usually has two. Do
not treat the six skips as the target to optimise away: a synthetic fixture is
not evidence about real payslips, and the honest reading of one is worth more
than a tuned reading of the other.
