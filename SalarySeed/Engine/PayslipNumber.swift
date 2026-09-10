import Foundation

/// v1.1: turning a token off a payslip into money. Integer cents, never Double.
///
/// Three real payslips disagreed about how to write a number, and two of them
/// disagreed with themselves:
///
///     2 741,86     space thousands, comma decimal
///     5.910,22     period thousands, comma decimal   (same page as the above)
///     4812.35      period decimal, no thousands      (different employer)
///
/// So the format is worked out per token and never per document. A reader that
/// sniffs one format from the header and applies it to the page gets the
/// Valores Acumulados block wrong on a payslip whose main table it got right.
///
/// The other rule that earns its place: **a money token has to show its
/// formatting.** Either it carries cents, or it carries a thousands separator.
/// A bare run of digits is not money. That is what stops the reader turning the
/// line code "D01", the quantity "30" or the day count "22" into 1 cent, 30
/// euros and 22 euros, and it costs nothing, because every money figure on
/// every Portuguese payslip is printed with its cents.
///
/// Everything is `Int` cents. A Double sum of the same figures printed
/// 3187.4000000000005 during the work that led to this file, against a stated
/// total of 3187,40, which is a reconciliation failure invented entirely by the
/// number type.
enum PayslipNumber {

    /// Which column a trailing marker claims the value belongs to. Some payroll
    /// software prints "D" or "C" after the figure instead of placing it.
    enum ColumnHint: String {
        case debit = "D"
        case credit = "C"
    }

    struct Parsed: Equatable {
        /// Signed, in cents.
        let cents: Int
        /// True when the token itself carried a sign, rather than the sign
        /// being inferred from the column it sits in.
        let explicitlySigned: Bool
        let columnHint: ColumnHint?
        /// True when a homoglyph substitution was needed to read it. The row
        /// this came from is downgraded in confidence, because a token that
        /// needed guessing is a token that could have been guessed wrong.
        let repaired: Bool
    }

    // MARK: Entry points

    /// Signed cents, or nil when the token is not money.
    static func cents(from token: String) -> Int? {
        parse(token)?.cents
    }

    /// The full reading, including whether it had to be repaired.
    static func parse(_ token: String) -> Parsed? {
        let cleaned = strip(token)
        guard !cleaned.body.isEmpty else { return nil }

        // Try it as it came. Only if that fails is a homoglyph guess allowed,
        // and only on a token that already looks like a number gone wrong.
        if let magnitude = magnitudeCents(cleaned.body) {
            return Parsed(cents: cleaned.negative ? -magnitude : magnitude,
                          explicitlySigned: cleaned.negative,
                          columnHint: cleaned.hint,
                          repaired: false)
        }
        guard PayslipText.digitShare(cleaned.body) >= 0.5 else { return nil }
        let repaired = PayslipText.deHomoglyph(cleaned.body)
        guard repaired != cleaned.body, let magnitude = magnitudeCents(repaired) else { return nil }
        return Parsed(cents: cleaned.negative ? -magnitude : magnitude,
                      explicitlySigned: cleaned.negative,
                      columnHint: cleaned.hint,
                      repaired: true)
    }

    /// A percentage as hundredths of a percent: "20,73" -> 2073, "11" -> 1100.
    ///
    /// Looser than money on purpose. Rates are printed with 0, 1 or 2 decimals
    /// ("11,0%", "7.4%", "23,75%") and never with a thousands separator, so the
    /// show-your-formatting rule would reject every one of them.
    static func rateHundredths(from token: String) -> Int? {
        let cleaned = strip(token).body
        guard !cleaned.isEmpty,
              cleaned.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) else { return nil }
        let parts = cleaned.split(separator: ",", omittingEmptySubsequences: false)
            .flatMap { $0.split(separator: ".", omittingEmptySubsequences: false) }
        guard parts.count <= 2, let whole = parts.first, !whole.isEmpty,
              whole.allSatisfy(\.isNumber), let w = Int(whole) else { return nil }
        guard parts.count == 2 else { return w * 100 }
        let frac = parts[1]
        guard frac.count <= 2, !frac.isEmpty, frac.allSatisfy(\.isNumber),
              let f = Int(frac) else { return nil }
        return w * 100 + (frac.count == 1 ? f * 10 : f)
    }

    /// Cents back to the Portuguese form, "1 234,56". Used by the round-trip
    /// invariant in the verification script and by nothing in the app, which
    /// formats through `Theme.eur`.
    static func format(cents: Int) -> String {
        let negative = cents < 0
        let magnitude = abs(cents)
        var whole = String(magnitude / 100)
        let frac = String(format: "%02d", magnitude % 100)
        var grouped = ""
        while whole.count > 3 {
            let cut = whole.index(whole.endIndex, offsetBy: -3)
            grouped = " " + whole[cut...] + grouped
            whole = String(whole[..<cut])
        }
        return (negative ? "-" : "") + whole + grouped + "," + frac
    }

    // MARK: Sign, currency and column markers

    private struct Stripped {
        let body: String
        let negative: Bool
        let hint: ColumnHint?
    }

    /// Peels the sign, the currency word and any trailing D/C marker off, so
    /// the parser proper only ever sees digits and separators.
    private static func strip(_ token: String) -> Stripped {
        var s = PayslipText.normalizeSeparators(token)
            .trimmingCharacters(in: .whitespaces)

        for word in ["EUR", "eur", "Eur"] where s.hasSuffix(word) {
            s = String(s.dropLast(word.count)).trimmingCharacters(in: .whitespaces)
            break
        }

        var negative = false
        if s.hasPrefix("(") && s.hasSuffix(")") && s.count > 2 {
            negative = true
            s = String(s.dropFirst().dropLast())
        }
        if s.hasPrefix("-") { negative = true; s = String(s.dropFirst()) }
        if s.hasSuffix("-") { negative = true; s = String(s.dropLast()) }
        s = s.trimmingCharacters(in: .whitespaces)

        // A trailing D or C is a column marker, not a sign and not a digit.
        // Only when a digit precedes it, so the label "C" is left alone.
        var hint: ColumnHint?
        if let last = s.last, last == "D" || last == "C",
           s.count > 1, s[s.index(s.endIndex, offsetBy: -2)].isNumber {
            hint = ColumnHint(rawValue: String(last))
            s = String(s.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        return Stripped(body: s, negative: negative, hint: hint)
    }

    // MARK: The parser proper

    /// Unsigned cents from a token containing only digits, spaces, "." and ",".
    private static func magnitudeCents(_ s: String) -> Int? {
        guard !s.isEmpty,
              s.allSatisfy({ $0.isNumber || $0 == " " || $0 == "." || $0 == "," }) else { return nil }
        guard s.contains(where: \.isNumber) else { return nil }

        let lastComma = s.lastIndex(of: ",")
        let lastDot = s.lastIndex(of: ".")

        // Which separator, if either, is the decimal point.
        //
        // Both present: the rightmost one is the decimal, the other is
        // thousands. Only one kind present: a group of exactly 3 digits after
        // it makes it a thousands separator, 1 or 2 digits make it a decimal.
        // That single rule resolves all three formats measured on real
        // payslips.
        var decimalIndex: String.Index?
        switch (lastComma, lastDot) {
        case (nil, nil):
            decimalIndex = nil
        case (let comma?, nil):
            decimalIndex = digitRun(after: comma, in: s) == 2 ? comma : nil
        case (nil, let dot?):
            decimalIndex = digitRun(after: dot, in: s) == 2 ? dot : nil
        case (let comma?, let dot?):
            let rightmost = comma > dot ? comma : dot
            decimalIndex = digitRun(after: rightmost, in: s) == 2 ? rightmost : nil
        }

        let integerText: String
        let fractionValue: Int
        if let decimalIndex {
            integerText = String(s[s.startIndex..<decimalIndex])
            let fraction = String(s[s.index(after: decimalIndex)...])
            guard fraction.count == 2, fraction.allSatisfy(\.isNumber),
                  let f = Int(fraction) else { return nil }
            fractionValue = f
        } else {
            integerText = s
            fractionValue = 0
        }

        guard let (whole, grouped) = wholeNumber(integerText) else { return nil }

        // Show your formatting: cents, or a thousands separator. A bare run of
        // digits is a code or a count, not money.
        guard decimalIndex != nil || grouped else { return nil }

        let (product, overflowA) = whole.multipliedReportingOverflow(by: 100)
        guard !overflowA else { return nil }
        let (total, overflowB) = product.addingReportingOverflow(fractionValue)
        guard !overflowB else { return nil }
        return total
    }

    /// The integer part, and whether it was written with thousands separators.
    ///
    /// Every group after the first must be exactly three digits, so "1.2.3" and
    /// "12,5" are rejected rather than guessed at.
    private static func wholeNumber(_ text: String) -> (value: Int, grouped: Bool)? {
        if text.isEmpty { return (0, false) }
        let separators: Set<Character> = [" ", ".", ","]
        guard text.contains(where: { separators.contains($0) }) else {
            guard text.allSatisfy(\.isNumber), let v = Int(text) else { return nil }
            return (v, false)
        }
        let groups = text.split(whereSeparator: { separators.contains($0) })
        guard groups.count >= 2, let first = groups.first,
              first.count >= 1, first.count <= 3 else { return nil }
        for group in groups.dropFirst() where group.count != 3 { return nil }
        guard groups.allSatisfy({ $0.allSatisfy(\.isNumber) }),
              let v = Int(groups.joined()) else { return nil }
        return (v, true)
    }

    /// How many digits immediately follow the character at `index`.
    private static func digitRun(after index: String.Index, in s: String) -> Int {
        var count = 0
        var i = s.index(after: index)
        while i < s.endIndex, s[i].isNumber {
            count += 1
            i = s.index(after: i)
        }
        // Anything non-digit after the run means this is not a decimal point.
        return i == s.endIndex ? count : -1
    }

    // MARK: Fixtures

    /// Parsing cases, as "token => signed cents" or "token => nil".
    ///
    /// Read by tools/verify_payslip_reader.py, which runs a Python
    /// implementation written from the rules rather than transliterated from
    /// this file, and fails on any disagreement.
    ///
    /// Rows marked real are token SHAPES that came off one of the three
    /// payslips this was built against: the separators, the homoglyph, the
    /// trailing sign. The digits inside them are stand-ins, because the
    /// originals were somebody's actual pay. Change a shape and you are
    /// changing the test; change the digits and you are not.
    static let parsingFixtures: [String] = [
        "2 741,86 => 274186",        // real
        "5.910,22 => 591022",        // real, same page as the line above
        "4812.35 => 481235",         // real, different employer
        "1 318,45 => 131845",        // real
        "22 311,80 => 2231180",      // real
        "0.00 => 0",                 // real
        "10.20 => 1020",             // real
        "611.52 => 61152",           // real
        "\u{0437} 187,40 => 318740", // real, Cyrillic ze for the digit 3
        "1.450,00 => 145000",
        "575,00 => 57500",
        "\u{20AC} 1 264,05 => 126405",
        "1 264,05 EUR => 126405",
        "-301,60 => -30160",
        "301,60- => -30160",
        "(45,00) => -4500",
        "1 234,56D => 123456",
        "1,500 => 150000",
        "12,5 => nil",
        "1.2.3 => nil",
        "30 => nil",
        "22 => nil",
        "D01 => nil",
        "R13 => nil",
        "001 => nil",
        "abc => nil",
        " => nil",
        "11,0% => nil",
    ]

    /// Rate cases, as "token => hundredths of a percent" or "token => nil".
    static let rateFixtures: [String] = [
        "20,73 => 2073",   // real
        "11,00 => 1100",   // real
        "13,50 => 1350",   // real
        "7.4 => 740",      // real
        "11.0 => 1100",    // real
        "23,75 => 2375",
        "11 => 1100",
        "1,234 => nil",
        "abc => nil",
    ]
}
