// One emitter per layout family.
//
// HTML printed by Chrome, because that is what the one existing fixture is and
// the command is already documented in `docs/fixtures/README.md`. It is also
// the corpus's biggest limitation and it is worth naming here rather than in a
// footnote: Chrome is the one PDF generator nobody's payroll department uses.
// Primavera, Sage, PHC, Cegid and Segurança Social Direta each write their own
// content streams, and `PayslipPDF`'s whole strategy was chosen from how a
// single Chrome-printed file behaved. Demo payslips from those vendors would
// close the gap and need no real pay to do it.

import Foundation

func escaped(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
}

/// Shared page furniture. Deliberately plain: a payslip is a table on white
/// paper and the reader has no opinion about typography.
let sharedCSS = """
  @page { size: A4; margin: 18mm 16mm; }
  body { font-family: Helvetica, Arial, sans-serif; font-size: 10pt; color:#111; }
  .co { font-size: 13pt; font-weight: bold; }
  .sub { font-size: 8pt; color:#444; margin-top:2px; }
  h1 { font-size: 11pt; margin: 18px 0 6px; letter-spacing:.5px; }
  hr { border:0; border-top:1px solid #999; margin:6px 0 12px; }
  table { width:100%; border-collapse:collapse; }
  td { padding:3px 0; vertical-align:top; }
  td.v { text-align:right; white-space:nowrap; width:110px; }
  td.q { text-align:right; white-space:nowrap; width:70px; color:#333; }
  .k { color:#444; font-size:8.5pt; width:130px; }
  .band { font-weight:bold; font-size:9pt; letter-spacing:.5px;
          border-bottom:1px solid #bbb; padding-top:14px; }
  .tot td { font-weight:bold; border-top:1px solid #bbb; }
  .net td { font-weight:bold; font-size:12pt; border-top:2px solid #333; padding-top:8px; }
  .half { width:49%; vertical-align:top; }
  .note { margin-top:26px; font-size:7.5pt; color:#666; line-height:1.5; }
"""

/// The fictional-document notice. Every page in the corpus carries one, in
/// Portuguese, so a printed copy that ends up on a desk cannot be mistaken for
/// somebody's pay.
func noticeHTML() -> String {
    """
    <div class="note">Documento fictício, gerado para testar o leitor de recibos do
    SalarySeed. Os valores vêm do motor fiscal da própria aplicação e não correspondem
    a ninguém.</div>
    """
}

func headerHTML(_ f: Fixture) -> String {
    """
    <div class="co">\(escaped(f.employer))</div>
    <div class="sub">\(escaped(f.employerAddress)) &nbsp;&nbsp; NIPC \(f.nipc)</div>
    <h1>RECIBO DE VENCIMENTO &nbsp; \(escaped(f.period))</h1>
    <hr>

    <table>
      <tr><td class="k">Nome</td><td>\(escaped(f.employee))</td>
          <td class="k">NIF</td><td class="v">\(f.nif)</td></tr>
      <tr><td class="k">Categoria</td><td>\(escaped(f.category))</td>
          <td class="k">Dias</td><td class="v">\(f.days)</td></tr>
    </table>
    """
}

/// A money cell, or an empty one.
func cell(_ cents: Int?, _ style: MoneyStyle) -> String {
    guard let cents else { return "<td class=\"v\"></td>" }
    return "<td class=\"v\">\(printedMoney(cents, style))</td>"
}

func labelCell(_ line: FixtureLine) -> String {
    let code = line.code.map { "\($0) " } ?? ""
    return "<td>\(escaped(code + line.label))</td>"
}

/// Rows for one block, label then value, optionally a quantity column.
func rowsHTML(_ lines: [FixtureLine], _ style: MoneyStyle, columns: Int) -> String {
    lines.map { line -> String in
        let klass = line.concept?.side == .total ? " class=\"tot\"" : ""
        var cells = labelCell(line)
        if columns >= 3 {
            cells += "<td class=\"q\">\(escaped(line.quantity ?? ""))</td>"
        }
        if let rate = line.ratePermyriad {
            cells += "<td class=\"q\">\(printedRate(rate))</td>"
        } else if columns >= 3 {
            cells += "<td class=\"q\"></td>"
        }
        if let base = line.baseCents {
            cells += cell(base, style)
        }
        cells += cell(line.cents, style)
        if let accumulated = line.accumulatedCents {
            cells += cell(accumulated, style)
        }
        return "  <tr\(klass)>\(cells)</tr>"
    }.joined(separator: "\n")
}

func bandHTML(_ title: String, span: Int) -> String {
    "  <tr><td class=\"band\" colspan=\"\(span)\">\(title)</td></tr>"
}

// MARK: The families

/// Labels left, ONE money column, earnings block above deductions block.
///
/// This is the shape of the repo's original hand-written fixture, kept as the
/// baseline. With a single money column there is nothing for the geometry to
/// separate the two sides by, so it is also the shape that shows what the
/// reader can do on labels and arithmetic alone.
func oneColumnHTML(_ f: Fixture) -> String {
    let s = f.style
    var body = headerHTML(f)
    body += "\n\n<table>\n"
    body += bandHTML("ABONOS", span: 2) + "\n"
    body += rowsHTML(f.lines(in: .earnings), s, columns: 2) + "\n"
    body += bandHTML("DESCONTOS", span: 2) + "\n"
    body += rowsHTML(f.lines(in: .deductions), s, columns: 2) + "\n"
    for line in f.lines(in: .net) {
        body += "  <tr class=\"net\">\(labelCell(line))\(cell(line.cents, s))</tr>\n"
    }
    let extra = f.lines(in: .extra)
    if !extra.isEmpty {
        body += "  <tr><td style=\"padding-top:20px\">&nbsp;</td><td></td></tr>\n"
        body += rowsHTML(extra, s, columns: 2) + "\n"
    }
    body += "</table>\n\n"
    body += accumulatedHTML(f)
    body += noticeHTML()
    return body
}

/// One description column and TWO money columns, ABONOS and DESCONTOS, with
/// the blocks stacked in one table.
///
/// This is the most common Portuguese payslip shape and the important one for
/// the whole question: it is the only stacked layout where the two money
/// columns genuinely distinguish the two sides, so it is what shows whether the
/// six checks that skip on a one-column page come back when the geometry can
/// separate earnings from deductions. The totals print on ONE row carrying both
/// figures, which is also how a real one does it.
func twoColumnSplitHTML(_ f: Fixture) -> String {
    let s = f.style
    var body = headerHTML(f)
    body += "\n\n<table>\n"
    body += "  <tr><td class=\"band\">DESCRIÇÃO</td>"
    body += "<td class=\"band\" style=\"text-align:right\">ABONOS</td>"
    body += "<td class=\"band\" style=\"text-align:right\">DESCONTOS</td></tr>\n"

    for line in f.lines(in: .earnings) where line.concept?.side != .total {
        body += "  <tr>\(labelCell(line))\(cell(line.cents, s))<td class=\"v\"></td></tr>\n"
    }
    for line in f.lines(in: .deductions) where line.concept?.side != .total {
        body += "  <tr>\(labelCell(line))<td class=\"v\"></td>\(cell(line.cents, s))</tr>\n"
    }

    let earningsTotal = f.lines.first { $0.concept == .totalEarnings }
    let deductionsTotal = f.lines.first { $0.concept == .totalDeductions }
    if earningsTotal != nil || deductionsTotal != nil {
        body += "  <tr class=\"tot\"><td>Totais</td>"
        body += cell(earningsTotal?.cents, s) + cell(deductionsTotal?.cents, s) + "</tr>\n"
    }
    for line in f.lines(in: .net) {
        body += "  <tr class=\"net\">\(labelCell(line))<td class=\"v\"></td>\(cell(line.cents, s))</tr>\n"
    }
    let extra = f.lines(in: .extra)
    if !extra.isEmpty {
        body += "  <tr><td style=\"padding-top:20px\">&nbsp;</td><td></td><td></td></tr>\n"
        for line in extra {
            body += "  <tr>\(labelCell(line))<td class=\"v\"></td>\(cell(line.cents, s))</tr>\n"
        }
    }
    body += "</table>\n\n"
    body += accumulatedHTML(f)
    body += noticeHTML()
    return body
}

/// A "Valores Acumulados" year-to-date block, when the fixture has one.
///
/// Its own three figures satisfy earnings minus deductions equals net, which is
/// the trap: the page then carries TWO valid net identities and only one of
/// them is this month. On a real payslip this is what sent the reader into the
/// annual block, and the "a total has to be a total of something" rule is what
/// pulled it back out.
func accumulatedHTML(_ f: Fixture) -> String {
    let block = f.lines(in: .accumulated)
    guard !block.isEmpty else { return "" }
    var out = "<table>\n"
    out += bandHTML("VALORES ACUMULADOS", span: 2) + "\n"
    out += rowsHTML(block, f.style, columns: 2) + "\n"
    out += "</table>\n\n"
    return out
}

/// Earnings and deductions in two tables side by side, each with its own money
/// column at its own right edge.
///
/// The layout the column detection was written for, and the one where the two
/// money columns genuinely distinguish the two sides.
func twoColumnSideBySideHTML(_ f: Fixture) -> String {
    let s = f.style
    var body = headerHTML(f)
    body += "\n\n<table><tr>\n"
    body += "<td class=\"half\"><table>\n"
    body += bandHTML("ABONOS", span: 2) + "\n"
    body += rowsHTML(f.lines(in: .earnings), s, columns: 2) + "\n"
    body += "</table></td>\n<td style=\"width:2%\"></td>\n"
    body += "<td class=\"half\"><table>\n"
    body += bandHTML("DESCONTOS", span: 2) + "\n"
    body += rowsHTML(f.lines(in: .deductions), s, columns: 2) + "\n"
    body += "</table></td>\n</tr></table>\n\n<table>\n"
    for line in f.lines(in: .net) {
        body += "  <tr class=\"net\">\(labelCell(line))\(cell(line.cents, s))</tr>\n"
    }
    body += rowsHTML(f.lines(in: .extra), s, columns: 2) + "\n"
    body += "</table>\n\n"
    body += accumulatedHTML(f)
    body += noticeHTML()
    return body
}

/// Quantity and unit-value columns before the value, which is the shape most
/// payroll software prints. The value is the LAST amount on the line and
/// everything before it is not the figure that counts.
func threeColumnHTML(_ f: Fixture) -> String {
    let s = f.style
    var body = headerHTML(f)
    body += "\n\n<table>\n"
    body += "  <tr><td class=\"band\">DESCRIÇÃO</td><td class=\"band\" style=\"text-align:right\">QTD</td>"
    body += "<td class=\"band\" style=\"text-align:right\">%</td>"
    body += "<td class=\"band\" style=\"text-align:right\">BASE</td>"
    body += "<td class=\"band\" style=\"text-align:right\">VALOR</td></tr>\n"
    body += rowsHTML(f.lines(in: .earnings), s, columns: 3) + "\n"
    body += rowsHTML(f.lines(in: .deductions), s, columns: 3) + "\n"
    for line in f.lines(in: .net) {
        body += "  <tr class=\"net\">\(labelCell(line))<td></td><td></td><td></td>\(cell(line.cents, s))</tr>\n"
    }
    body += rowsHTML(f.lines(in: .extra), s, columns: 3) + "\n"
    body += "</table>\n\n"
    body += accumulatedHTML(f)
    body += noticeHTML()
    return body
}

/// A page that is not a payslip. The negative fixtures.
func notAPayslipHTML(_ f: Fixture) -> String {
    let s = f.style
    var body = """
    <div class="co">\(escaped(f.employer))</div>
    <div class="sub">\(escaped(f.employerAddress)) &nbsp;&nbsp; NIPC \(f.nipc)</div>
    <h1>\(escaped(f.category)) &nbsp; \(escaped(f.period))</h1>
    <hr>

    """
    body += "<table>\n"
    body += rowsHTML(f.lines(in: .earnings) + f.lines(in: .deductions)
                     + f.lines(in: .net) + f.lines(in: .extra), s, columns: 2) + "\n"
    body += "</table>\n\n"
    body += noticeHTML()
    return body
}

func html(for f: Fixture) -> String {
    let body: String
    switch f.family {
    case "oneColumn":           body = oneColumnHTML(f)
    case "twoColumnSplit":      body = twoColumnSplitHTML(f)
    case "twoColumnSideBySide": body = twoColumnSideBySideHTML(f)
    case "threeColumn":         body = threeColumnHTML(f)
    case "notAPayslip":         body = notAPayslipHTML(f)
    default:                    body = oneColumnHTML(f)
    }
    return """
    <!doctype html><html lang="pt"><head><meta charset="utf-8">
    <style>
    \(sharedCSS)
    </style></head><body>

    \(body)
    </body></html>
    """
}
