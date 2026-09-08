import Foundation

/// One piece of text with its place on the page.
///
/// v1.1: the PDF path and the photo path both produce these, which is the
/// single most useful decision in the reader. Row grouping, column detection,
/// classification and reconciliation are then one code path with one set of
/// bugs, and all of it is testable without a device, a camera or a payslip.
///
/// Coordinates are normalised 0...1 with the origin at the TOP LEFT and y
/// growing downwards, which is the opposite of both PDFKit and Vision. Both
/// extractors flip on the way in, once, so that nothing downstream has to
/// remember which framework a fragment came from.
struct PayslipFragment: Equatable {
    let text: String
    let x0: Double
    let x1: Double
    let y0: Double
    let y1: Double

    var width: Double { x1 - x0 }
    var height: Double { y1 - y0 }
    var xMid: Double { (x0 + x1) / 2 }
    var yMid: Double { (y0 + y1) / 2 }

    /// Rough width of one character, used for the adjacency test when deciding
    /// whether two fragments are halves of one number.
    var characterWidth: Double { text.isEmpty ? width : width / Double(text.count) }

    init(text: String, x0: Double, x1: Double, y0: Double, y1: Double) {
        self.text = text
        self.x0 = min(x0, x1)
        self.x1 = max(x0, x1)
        self.y0 = min(y0, y1)
        self.y1 = max(y0, y1)
    }
}

/// Fragments that sit on one printed line, left to right.
struct PayslipRow: Equatable {
    let fragments: [PayslipFragment]
    let yMid: Double

    var text: String { fragments.map(\.text).joined(separator: " ") }
}

/// v1.1: geometry only. Nothing here knows what a payslip is, what a euro is or
/// what any label means. It groups fragments into rows and finds the columns.
///
/// This layer exists because the iOS 26 table API cannot be trusted with the
/// numbers. Measured on a real payslip, `RecognizeDocumentsRequest` returned
/// 301,50 where the paper says 301,60, invented a 187,60 next to a correct
/// 187,90, and on a second real payslip found no tables at all. Plain text
/// recognition read every one of those correctly. So we take the text from the
/// recogniser and do the geometry ourselves.
enum PayslipLayout {

    /// A fragment joins the row being built when its vertical centre is within
    /// this many median line heights of the row's running centre.
    static let rowTolerance = 0.6

    /// Right edges within this fraction of the page width are the same column.
    static let columnTolerance = 0.02

    /// Two fragments are halves of one number when the gap between them is at
    /// most this many character widths.
    static let joinTolerance = 0.4

    // MARK: Rows

    /// Groups fragments into printed lines.
    ///
    /// Greedy on the y centre against a running mean rather than a fixed bucket
    /// size, because a photographed payslip still has a little rotation left in
    /// it after deskew, and a fixed grid cuts a slightly sloped line in half
    /// somewhere across the page.
    static func rows(from fragments: [PayslipFragment]) -> [PayslipRow] {
        guard !fragments.isEmpty else { return [] }
        let h = medianHeight(of: fragments)
        let limit = rowTolerance * h
        let sorted = fragments.sorted { $0.yMid < $1.yMid }

        var rows: [[PayslipFragment]] = []
        var current: [PayslipFragment] = [sorted[0]]
        var runningMean = sorted[0].yMid

        for fragment in sorted.dropFirst() {
            if abs(fragment.yMid - runningMean) <= limit {
                current.append(fragment)
                runningMean += (fragment.yMid - runningMean) / Double(current.count)
            } else {
                rows.append(current)
                current = [fragment]
                runningMean = fragment.yMid
            }
        }
        rows.append(current)

        return rows.map { group in
            let ordered = group.sorted { $0.x0 < $1.x0 }
            let mid = ordered.reduce(0.0) { $0 + $1.yMid } / Double(ordered.count)
            return PayslipRow(fragments: ordered, yMid: mid)
        }
    }

    static func medianHeight(of fragments: [PayslipFragment]) -> Double {
        let heights = fragments.map(\.height).sorted()
        guard !heights.isEmpty else { return 0 }
        let mid = heights[heights.count / 2]
        // A degenerate page (every box zero-height) would make every fragment
        // one row. Fall back to something that at least separates lines.
        return mid > 0 ? mid : 0.01
    }

    // MARK: Joining split numbers

    /// Rejoins numbers the recogniser split at the thousands separator.
    ///
    /// "2 741,86" very often arrives as "2" and "292,14". The test is narrow on
    /// purpose: the left half must be one to three digits and nothing else, the
    /// right half must begin with exactly three digits, and the two must be
    /// adjacent. That rejects joining a quantity to the amount beside it,
    /// because "1.450,00" begins with one digit, not three.
    static func joinSplitNumbers(in row: PayslipRow) -> PayslipRow {
        var out: [PayslipFragment] = []
        var index = 0
        let items = row.fragments
        while index < items.count {
            if index + 1 < items.count, let merged = join(items[index], items[index + 1]) {
                out.append(merged)
                index += 2
            } else {
                out.append(items[index])
                index += 1
            }
        }
        return PayslipRow(fragments: out, yMid: row.yMid)
    }

    private static func join(_ left: PayslipFragment, _ right: PayslipFragment) -> PayslipFragment? {
        let l = left.text.trimmingCharacters(in: .whitespaces)
        let r = right.text.trimmingCharacters(in: .whitespaces)
        guard (1...3).contains(l.count), l.allSatisfy(\.isNumber) else { return nil }
        guard leadingDigitRun(r) == 3 else { return nil }
        let gap = right.x0 - left.x1
        guard gap >= 0, gap <= joinTolerance * max(left.characterWidth, right.characterWidth) else { return nil }
        // Only worth it if the join is what makes it money.
        guard PayslipNumber.cents(from: l + " " + r) != nil else { return nil }
        return PayslipFragment(text: l + " " + r,
                               x0: left.x0, x1: right.x1,
                               y0: min(left.y0, right.y0), y1: max(left.y1, right.y1))
    }

    static func leadingDigitRun(_ text: String) -> Int {
        var count = 0
        for ch in text {
            if ch.isNumber { count += 1 } else { break }
        }
        return count
    }

    // MARK: Orphan rows

    /// Reattaches a label to the amount printed on the next line.
    ///
    /// A PDF's reading order is not its visual order. On the real
    /// Chrome-printed payslip, `page.string` returns the totals block as
    ///
    ///     Total Iliquido
    ///     2480.00
    ///     Total Descontos
    ///     611.52
    ///
    /// so the three figures that matter most arrive with no label and the three
    /// labels arrive with no figure. Merging a label-only row into the
    /// amount-only row that follows it recovers all six.
    ///
    /// Deliberately narrow: the first row must have text and no amount, the
    /// second must have an amount and no word carrying a letter. Two label-only
    /// rows in a row are left alone, which is what keeps a wrapped name
    /// ("Nome Maria Joana Ferreira dos" / "Santos") from swallowing the line
    /// below it.
    static func mergeOrphanRows(_ rows: [PayslipRow]) -> [PayslipRow] {
        var out: [PayslipRow] = []
        var index = 0
        while index < rows.count {
            let row = rows[index]
            let labelOnly = !row.fragments.isEmpty
                && row.fragments.allSatisfy { PayslipNumber.cents(from: $0.text) == nil }
                && row.fragments.contains { $0.text.contains(where: \.isLetter) }
            if labelOnly, index + 1 < rows.count {
                let next = rows[index + 1]
                let amountOnly = next.fragments.contains { PayslipNumber.cents(from: $0.text) != nil }
                    && !next.fragments.contains { $0.text.contains(where: \.isLetter) }
                if amountOnly {
                    out.append(PayslipRow(fragments: row.fragments + next.fragments,
                                          yMid: row.yMid))
                    index += 2
                    continue
                }
            }
            out.append(row)
            index += 1
        }
        return out
    }

    // MARK: Columns

    /// The right-edge positions of the money columns, left to right.
    ///
    /// Money is right-aligned on every payslip layout there is, so the right
    /// edge is the stable thing to cluster on. Left edges are useless here:
    /// "1 264,05" and "12,50" share a right edge and agree on nothing else.
    static func moneyColumns(in rows: [PayslipRow]) -> [Double] {
        let edges = rows
            .flatMap(\.fragments)
            .filter { PayslipNumber.cents(from: $0.text) != nil }
            .map(\.x1)
            .sorted()
        guard !edges.isEmpty else { return [] }

        var clusters: [[Double]] = []
        var current: [Double] = [edges[0]]
        var mean = edges[0]
        for edge in edges.dropFirst() {
            if abs(edge - mean) <= columnTolerance {
                current.append(edge)
                mean += (edge - mean) / Double(current.count)
            } else {
                clusters.append(current)
                current = [edge]
                mean = edge
            }
        }
        clusters.append(current)
        return clusters.map { $0.reduce(0, +) / Double($0.count) }
    }

    /// Which money column a fragment's right edge falls in, or nil when it
    /// falls in none of them.
    static func columnIndex(forRightEdge x: Double, in columns: [Double]) -> Int? {
        var best: (index: Int, distance: Double)?
        for (i, centre) in columns.enumerated() {
            let d = abs(centre - x)
            if d <= columnTolerance, best == nil || d < best!.distance {
                best = (i, d)
            }
        }
        return best?.index
    }

    /// The row's label: the words to the left of this row's first amount.
    ///
    /// Bounded per row, by that row's own leftmost money fragment, and not by
    /// the page's leftmost money column. Measured on both real payslips, the
    /// page's leftmost money column sits far to the left of the line-item
    /// table: one has a percentage column under Formas de Pagamento at x=0.14,
    /// the other a Valores Acumulados block. Bounding by that cut every
    /// description down to its tail, so "Subsidio" arrived as "ubsidio" and
    /// most rows had no label at all.
    ///
    /// A fragment also has to contain a letter to count as description.
    /// Without that, the quantity "30" joins the label, because a bare integer
    /// is deliberately not money and would otherwise pass the filter.
    static func label(of row: PayslipRow) -> String {
        let firstAmount = row.fragments
            .first { PayslipNumber.cents(from: $0.text) != nil }?
            .x0 ?? 1.0
        let words = row.fragments
            .filter { $0.x0 < firstAmount && $0.text.contains(where: \.isLetter) }
            .map(\.text)
        return words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
