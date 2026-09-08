import Foundation

/// v1.1: text normalisation for the payslip reader. Nothing here parses a number
/// or understands a label. It only makes strings comparable.
///
/// Both rules in this file exist because of something measured on a real
/// payslip, not because it seemed prudent:
///
///  - Vision returned "з 187,40" where the paper says "3 187,40". That first
///    character is Cyrillic ze (U+0437), not the digit 3, and it arrived with
///    the recogniser set to pt-BR. It was the Total Pago, the single most
///    important number on the page. A reader that assumes OCR output contains
///    only Latin characters drops it silently, or worse, strips it and reports
///    004,12.
///  - Three real payslips called the meal allowance "Vale de Refeicao",
///    "Subsidio Alimentacao - Generos" and "Subs. Alim.". No two of those share
///    a substring. Labels are therefore compared as sets of expanded tokens,
///    never with `contains`.
///
/// The homoglyph table is deliberately never applied on its own. See
/// `PayslipNumber.cents(from:)`: a substitution is made only when it turns a
/// token that does not parse into one that does. Rewriting good input is a
/// silent corruption no compiler and no reviewer would catch.
enum PayslipText {

    // MARK: Homoglyphs

    /// Characters OCR returns where a digit belongs, keyed by code point.
    ///
    /// Written as escapes on purpose. As literals, half of this table would be
    /// visually identical to the digits it maps to, and a reader could not tell
    /// the Cyrillic "о" from the Latin "o" from the digit "0" on the screen.
    /// The trailing comment on each row is the only thing that makes it
    /// reviewable.
    ///
    /// Rows marked "measured" were produced by Vision on one of the three real
    /// payslips this reader was built against.
    static let homoglyphs: [Character: Character] = [
        "\u{0437}": "3",   // CYRILLIC SMALL ZE          measured: "з 187,40" for "3 187,40"
        "\u{0417}": "3",   // CYRILLIC CAPITAL ZE
        "\u{043E}": "0",   // CYRILLIC SMALL O
        "\u{041E}": "0",   // CYRILLIC CAPITAL O
        "\u{0455}": "5",   // CYRILLIC SMALL DZE
        "\u{0405}": "5",   // CYRILLIC CAPITAL DZE
        "\u{0431}": "6",   // CYRILLIC SMALL BE
        "\u{03BF}": "0",   // GREEK SMALL OMICRON
        "\u{039F}": "0",   // GREEK CAPITAL OMICRON
        "O": "0",          // LATIN CAPITAL O            measured: "DOS" for "D05"
        "o": "0",          // LATIN SMALL O
        "l": "1",          // LATIN SMALL L
        "I": "1",          // LATIN CAPITAL I
        "|": "1",          // VERTICAL LINE
        "Z": "2",          // LATIN CAPITAL Z
        "S": "5",          // LATIN CAPITAL S            measured: "113335645SS" for "11333564655"
        "s": "5",          // LATIN SMALL S
        "G": "6",          // LATIN CAPITAL G            measured: "R1G" for "R16"
        "B": "8",          // LATIN CAPITAL B
    ]

    /// Spaces that are not U+0020. Payroll software uses these as thousands
    /// separators far more often than a plain space.
    static let spaceLikes: Set<Character> = [
        "\u{00A0}",  // NO-BREAK SPACE
        "\u{2007}",  // FIGURE SPACE
        "\u{2008}",  // PUNCTUATION SPACE
        "\u{2009}",  // THIN SPACE
        "\u{202F}",  // NARROW NO-BREAK SPACE
        "\u{2002}",  // EN SPACE
        "\u{2003}",  // EM SPACE
        "\u{2060}",  // WORD JOINER
    ]

    /// Dashes that are not U+002D. A minus sign in front of a deduction is
    /// commonly U+2212, which no `Int` initialiser accepts.
    static let dashLikes: Set<Character> = [
        "\u{2010}",  // HYPHEN
        "\u{2011}",  // NON-BREAKING HYPHEN
        "\u{2012}",  // FIGURE DASH
        "\u{2013}",  // EN DASH
        "\u{2014}",  // EM DASH
        "\u{2212}",  // MINUS SIGN
    ]

    /// Apostrophe-family thousands marks, dropped outright inside a number.
    static let apostropheLikes: Set<Character> = [
        "'",         // APOSTROPHE
        "\u{2019}",  // RIGHT SINGLE QUOTATION MARK
        "\u{02BC}",  // MODIFIER LETTER APOSTROPHE
    ]

    /// Currency marks, dropped outright inside a number.
    static let currencyLikes: Set<Character> = ["\u{20AC}", "$", "\u{00A3}"]

    // MARK: Character-level normalisation

    /// Collapses the space, dash, apostrophe and currency families onto their
    /// plain ASCII forms. Applied to every fragment before anything reads it,
    /// so no rule downstream has to know these variants exist.
    static func normalizeSeparators(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            if spaceLikes.contains(ch) { out.append(" ") }
            else if dashLikes.contains(ch) { out.append("-") }
            else if apostropheLikes.contains(ch) || currencyLikes.contains(ch) { continue }
            else { out.append(ch) }
        }
        return out
    }

    /// Substitutes every known homoglyph for its digit. Unconditional: the
    /// caller decides whether the result is an improvement. `PayslipNumber` is
    /// the only caller, and it keeps the substitution only when the token
    /// parses afterwards and did not before.
    static func deHomoglyph(_ text: String) -> String {
        String(text.map { homoglyphs[$0] ?? $0 })
    }

    /// The share of a token that is already digits, 0...1. Empty is 0.
    ///
    /// The homoglyph pass is gated on this so a word like "Social" is never
    /// rewritten to "50cia1". A token has to look like a number that went wrong
    /// before we are willing to guess at it.
    static func digitShare(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        let digits = text.reduce(into: 0) { $0 += $1.isNumber ? 1 : 0 }
        return Double(digits) / Double(text.count)
    }

    // MARK: Labels

    /// Abbreviations seen on real payslips, expanded before matching.
    ///
    /// The value may be several words: "ss" becomes "seguranca social", and the
    /// expansion is re-split afterwards, so a pattern never has to know which
    /// form it will meet.
    static let abbreviations: [String: String] = [
        "subs": "subsidio", "sub": "subsidio", "subsid": "subsidio",
        "alim": "alimentacao", "alimen": "alimentacao", "alimentac": "alimentacao",
        "ref": "refeicao", "refeic": "refeicao",
        "seg": "seguranca", "segur": "seguranca", "ss": "seguranca social",
        "soc": "social",
        "venc": "vencimento", "vcto": "vencimento", "vencim": "vencimento",
        "remun": "remuneracao", "rem": "remuneracao", "remuner": "remuneracao",
        "desc": "desconto", "descto": "desconto", "desct": "desconto",
        "liq": "liquido", "iliq": "iliquido",
        "qt": "quantidade", "qtd": "quantidade", "qtde": "quantidade",
        "tx": "taxa",
        "ret": "retencao",
        "grat": "gratificacao", "gratif": "gratificacao",
        "dep": "dependente", "deps": "dependentes",
        "sind": "sindical",
        "esp": "especie",
        "vlr": "valor", "val": "valor",
        "tot": "total",
        "emp": "empregado",
        "trab": "trabalhador",
        "abon": "abono", "abonos": "abono",
        "compl": "complemento",
        "ext": "extraordinario",
        "hs": "horas", "hrs": "horas", "h": "horas",
        "nat": "natal",
        "fer": "ferias",
        "irs": "irs", "iva": "iva",
    ]

    /// A label reduced to lowercase, unaccented, punctuation-free, abbreviation-
    /// expanded words separated by single spaces.
    ///
    /// This is the only form the lexicon ever matches against, which is why the
    /// verification script checks that every pattern in the lexicon normalises
    /// to itself. A pattern written with an accent or a capital could never
    /// match anything, and nothing in the compiler would say so.
    static func normalizeLabel(_ text: String) -> String {
        tokens(text).joined(separator: " ")
    }

    /// `normalizeLabel` without the join.
    static func tokens(_ text: String) -> [String] {
        let folded = SearchText.fold(normalizeSeparators(text))
        let rough = folded.map { ch -> Character in
            (ch.isLetter || ch.isNumber) ? ch : " "
        }
        return String(rough)
            .split(separator: " ")
            .flatMap { expand(String($0)) }
    }

    /// One token, expanded. Splits on the result so a multi-word expansion
    /// arrives as separate tokens.
    private static func expand(_ token: String) -> [String] {
        guard let full = abbreviations[token] else { return [token] }
        return full.split(separator: " ").map(String.init)
    }

    // MARK: Stated rates

    /// Splits a trailing or embedded percentage off a label.
    ///
    /// "IRS (Venc. 20,73%)" carries a token that parses perfectly well as money
    /// and must never become that line's value. Pulled out here, the 20,73
    /// becomes a stated rate the reconciler can check against the line it sits
    /// on, which turns a parsing hazard into an extra piece of evidence.
    ///
    /// Returns the label with the percentage removed, and the raw rate token
    /// for `PayslipNumber` to parse. The rate is left as text because parsing
    /// belongs in one place.
    static func splitStatedRate(_ text: String) -> (label: String, rate: String?) {
        let normalized = normalizeSeparators(text)
        guard let percent = normalized.firstIndex(of: "%") else { return (text, nil) }
        var start = percent
        var seenDigit = false
        while start > normalized.startIndex {
            let prev = normalized.index(before: start)
            let ch = normalized[prev]
            if ch.isNumber { seenDigit = true; start = prev; continue }
            if (ch == "," || ch == "." || ch == " ") && !seenDigit { start = prev; continue }
            if (ch == "," || ch == ".") && seenDigit { start = prev; continue }
            break
        }
        guard seenDigit else { return (text, nil) }
        let rate = String(normalized[start..<percent]).trimmingCharacters(in: .whitespaces)
        var stripped = normalized
        stripped.removeSubrange(start...percent)
        return (stripped, rate.isEmpty ? nil : rate)
    }

    // MARK: Fixtures

    /// Label normalisation cases, as "input => expected".
    ///
    /// Read by tools/verify_payslip_reader.py, which runs an independently
    /// written Python implementation over the same inputs. A table retyped into
    /// that script would verify itself and nothing else, so the inputs live
    /// here, next to the code that ships.
    ///
    /// Every row beginning with a real payslip label is marked; those are the
    /// ones that came off paper rather than out of somebody's imagination.
    static let labelFixtures: [String] = [
        "Subs. Alim. (isento) => subsidio alimentacao isento",          // real
        "Subsidio Alimentacao - Generos => subsidio alimentacao generos", // real
        "Vale de Refeicao => vale de refeicao",                          // real
        "Seg. social empregado => seguranca social empregado",           // real
        "Seguranca Social (11%) => seguranca social 11",                 // real
        "Imposto sobre o rendimento => imposto sobre o rendimento",      // real
        "Vencimento base => vencimento base",                            // real
        "Sub. Ferias - duodecimo => subsidio ferias duodecimo",          // real
        "Gratificacao Balanco => gratificacao balanco",                  // real
        "Ajudas de Custo => ajudas de custo",                            // real
        "Quota Sindical => quota sindical",                              // real
        "Desconto Especie => desconto especie",                          // real
        "SUBSIDIO DE NATAL => subsidio de natal",
        "Retencao IRS => retencao irs",
        "Total Iliquido => total iliquido",
        "  spaced   out  => spaced out",
        " => ",
    ]

    /// Homoglyph cases, as "input => expected". Same contract as
    /// `labelFixtures`: the script re-implements the rule and compares.
    static let homoglyphFixtures: [String] = [
        "\u{0437} 187,40 => 3 187,40",   // real, the Total Pago on a photographed payslip
        "1133356465\u{0405} => 11333564655",
        "R1G => R16",
        "S57,00 => 557,00",
        "Social => 50cia1",              // why the digitShare gate exists: never called on this
    ]
}
