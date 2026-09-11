import Foundation

/// Where a reading came from. Carried all the way to the results screen,
/// because it is the honest answer to "how sure are you".
///
/// v1.1: `pdfLines` is the good case and not a fallback. Measured on a real
/// Chrome-printed payslip, `page.string` was exact to all 1172 characters while
/// `characterBounds(at:)` desynchronised from its own indices and produced
/// fragments like "ubsidio d e f erias" that classified nothing. Text with
/// synthetic geometry beat real geometry with the same text.
enum PayslipSource {
    /// Exact characters from the PDF, laid out from the printed line structure.
    case pdfLines
    /// Exact characters from the PDF, laid out from per-character bounds.
    case pdfBounds
    /// Recognised from an image. Every amount is a guess until it reconciles.
    case ocr

    /// True when the characters are the file's own and not a recogniser's
    /// opinion of them. Nothing may treat this as "correct", only as "not
    /// misread": a PDF can still say something wrong.
    var isExactText: Bool { self != .ocr }

    /// True when the coordinates were INVENTED from the text rather than
    /// measured off the page.
    ///
    /// `.pdfLines` lays fragments out from the character offset within each
    /// extracted line, which is perfectly good for rows and left-to-right
    /// order and is not a measurement of anything. Distances on that path are
    /// whole characters and mean something different from distances on the
    /// other two, so any tolerance expressed as a fraction of a glyph has to
    /// know which it is looking at.
    var hasSyntheticGeometry: Bool { self == .pdfLines }
}

/// One amount found on the page, with where it sat.
struct PayslipAmount: Equatable {
    let cents: Int
    let lineIndex: Int
    /// Index into `PayslipReading.moneyColumns`, or nil when the amount's right
    /// edge did not fall in any column.
    let columnIndex: Int?
    /// True when a homoglyph substitution was needed to read it. Everything
    /// downstream treats a repaired amount as low confidence, because a token
    /// that had to be guessed is a token that could have been guessed wrong.
    let repaired: Bool
}

/// One printed line, as read.
struct PayslipLine: Equatable {
    let index: Int
    /// The description exactly as printed, for showing back to the reader.
    let rawLabel: String
    /// The same thing folded, expanded and reduced to words, for matching.
    let label: String
    /// A percentage printed inside the label, in hundredths of a percent.
    /// "IRS (Venc. 20,73%)" leaves 2073 here and "IRS" in the label.
    let statedRate: Int?
    let amounts: [PayslipAmount]
    /// True when something on this line looked like money and could not be
    /// read. The line is still kept: a line we half read is a line the reader
    /// should be asked about, not one to pretend we never saw.
    let hasUnreadableToken: Bool
}

/// Why a file could not be read as a payslip.
enum PayslipUnreadable: String, CaseIterable, Error {
    case unsupportedFile
    case encryptedPDF
    case noTextFound
    case tooFewNumbers
    case notAPayslip
}

/// A payslip as read off the page, before anything is classified or checked.
struct PayslipReading {
    let source: PayslipSource
    let lines: [PayslipLine]
    /// Right-edge positions of the money columns, left to right.
    let moneyColumns: [Double]
    /// Tokens that looked like money and did not parse. These are shown to the
    /// reader as empty fields to fill in, and every check that needed one is
    /// reported as not checked rather than guessed.
    let unreadableTokens: [String]

    var amounts: [PayslipAmount] { lines.flatMap(\.amounts) }

    /// Whether to stop and ask the reader before showing a verdict.
    ///
    /// A PDF that carried its own text, read cleanly and agreed with itself has
    /// nothing to confirm: every figure came from the file rather than from a
    /// recogniser's opinion of it, and asking the reader to check figures the
    /// file supplied is ceremony. Anything recognised from pixels, anything we
    /// could not read, and anything whose label fought its arithmetic does stop,
    /// because those are the cases where a wrong figure would otherwise become a
    /// wrong accusation.
    ///
    /// This lives here, in the Foundation-only layer, rather than on the view
    /// model that asks it, because it is the whole difference between a figure
    /// the reader saw before it counted and one they never did. That makes it
    /// the load-bearing rule for anything that promotes a read figure into
    /// stored state, and `tools/payslip_probe` has to be able to report it.
    /// A `@MainActor` view model cannot be compiled into that tool, and
    /// restating the rule in Python would be a second opinion rather than a
    /// check.
    func needsReview(facts: PayslipFacts) -> Bool {
        if source == .ocr { return true }
        if !unreadableTokens.isEmpty { return true }
        if !facts.disputed.isEmpty { return true }
        return false
    }

    /// A copy with the reader's corrections applied, keyed by line.
    ///
    /// The value replaces the last amount on its line, which is the one the
    /// classifier treats as the figure that counts. A nil value removes it, so
    /// a figure the reader could not make out either takes the checks that need
    /// it out of the verdict rather than poisoning them with a guess.
    ///
    /// Corrections go in HERE and the whole reading is classified again, rather
    /// than being patched onto the verdict afterwards. A corrected figure has to
    /// be able to change which lines the arithmetic identifies, and a patch
    /// applied downstream could not do that.
    func applying(_ edits: [Int: Int?]) -> PayslipReading {
        guard !edits.isEmpty else { return self }
        let corrected = lines.map { line -> PayslipLine in
            guard let edit = edits[line.index] else { return line }
            var amounts = line.amounts
            if let cents = edit {
                if amounts.isEmpty {
                    amounts = [PayslipAmount(cents: cents, lineIndex: line.index,
                                             columnIndex: nil, repaired: false)]
                } else {
                    let last = amounts[amounts.count - 1]
                    amounts[amounts.count - 1] = PayslipAmount(
                        cents: cents, lineIndex: last.lineIndex,
                        columnIndex: last.columnIndex, repaired: false)
                }
            } else if !amounts.isEmpty {
                amounts.removeLast()
            }
            return PayslipLine(index: line.index, rawLabel: line.rawLabel, label: line.label,
                               statedRate: line.statedRate, amounts: amounts,
                               hasUnreadableToken: false)
        }
        return PayslipReading(source: source, lines: corrected,
                              moneyColumns: moneyColumns, unreadableTokens: unreadableTokens)
    }

    // MARK: Building

    /// Turns fragments into a reading, or says why it could not.
    ///
    /// The gate at the end is what stops the app confidently reconciling a
    /// restaurant bill. It is deliberately cheap and deliberately not clever:
    /// a payslip has several amounts and says something about pay. A file that
    /// fails it gets a screen explaining what was looked for, which is more
    /// use than a wrong answer delivered with confidence.
    static func read(fragments: [PayslipFragment], source: PayslipSource) -> Result<PayslipReading, PayslipUnreadable> {
        guard !fragments.isEmpty else { return .failure(.noTextFound) }

        let joinTolerance = source.hasSyntheticGeometry
            ? PayslipLayout.syntheticJoinTolerance
            : PayslipLayout.joinTolerance
        let grouped = PayslipLayout.rows(from: fragments)
            .map { PayslipLayout.joinSplitNumbers(in: $0, tolerance: joinTolerance) }
        let rows = PayslipLayout.mergeOrphanRows(grouped)
        let columns = PayslipLayout.moneyColumns(in: rows)

        var lines: [PayslipLine] = []
        var unreadable: [String] = []

        for (index, row) in rows.enumerated() {
            var amounts: [PayslipAmount] = []
            var rowUnreadable = false

            var columnRate: Int?
            for fragment in row.fragments {
                if let rate = standaloneRate(fragment.text) {
                    columnRate = columnRate ?? rate
                } else if let parsed = PayslipNumber.parse(fragment.text) {
                    amounts.append(PayslipAmount(
                        cents: parsed.cents,
                        lineIndex: index,
                        columnIndex: PayslipLayout.columnIndex(forRightEdge: fragment.x1, in: columns),
                        repaired: parsed.repaired))
                } else if looksLikeBrokenMoney(fragment.text) {
                    rowUnreadable = true
                    unreadable.append(fragment.text)
                }
            }

            let rawLabel = PayslipLayout.label(of: row)
            let (stripped, rateToken) = PayslipText.splitStatedRate(rawLabel)
            lines.append(PayslipLine(
                index: index,
                rawLabel: rawLabel,
                label: PayslipText.normalizeLabel(stripped),
                statedRate: rateToken.flatMap { PayslipNumber.rateHundredths(from: $0) } ?? columnRate,
                amounts: amounts,
                hasUnreadableToken: rowUnreadable))
        }

        let reading = PayslipReading(source: source, lines: lines,
                                     moneyColumns: columns, unreadableTokens: unreadable)

        guard reading.amounts.count >= minimumAmounts else { return .failure(.tooFewNumbers) }
        guard reading.namesSomethingAboutPay else { return .failure(.notAPayslip) }
        return .success(reading)
    }

    /// A payslip carries at least this many amounts. Below it, there is nothing
    /// to reconcile even if the file is a payslip.
    static let minimumAmounts = 3

    /// True when at least one line names a payroll concept.
    ///
    /// Label evidence only, on purpose. The arithmetic identities are stronger
    /// but they are also happy to find 11% relationships in a phone bill, so
    /// they are not the right gate for "is this a payslip at all".
    var namesSomethingAboutPay: Bool {
        lines.contains { PayslipLexicon.best(for: $0.label) != nil }
    }

    /// A token that was probably money and could not be read.
    ///
    /// Requires a decimal separator, so a line code ("D01"), a quantity ("30")
    /// and a date ("31-10-2025") are not reported to the reader as damage.
    /// Percentages are excluded too: "11.0%" is a rate printed beside its own
    /// line and is read perfectly well, and calling it damage told the reader
    /// a clean payslip was torn.
    static func looksLikeBrokenMoney(_ text: String) -> Bool {
        guard !text.contains("%") else { return false }
        guard text.contains(",") || text.contains(".") else { return false }
        guard PayslipText.digitShare(text) >= 0.5 else { return false }
        return PayslipNumber.cents(from: text) == nil
    }

    /// A standalone percentage printed in its own column, as hundredths of a
    /// percent.
    ///
    /// Payslips put the rate either inside the description ("IRS (Venc.
    /// 20,73%)"), which `PayslipText.splitStatedRate` handles, or in a column
    /// of its own ("Seg. social empregado | 11.0% | 4812.35 | 529.36"), which
    /// this handles. Both end up on the same field.
    static func standaloneRate(_ text: String) -> Int? {
        guard text.hasSuffix("%") else { return nil }
        return PayslipNumber.rateHundredths(from: String(text.dropLast()))
    }
}
