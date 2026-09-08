import Foundation

/// What a line on a payslip is, independent of what it is called.
///
/// v1.1: `side` is what the reconciler needs and the label often cannot give.
/// A line's own text is frequently ambiguous ("Desconto Espécie" is a
/// deduction, "Subsídio Alimentação - Géneros" is the payment it reverses, and
/// on one real payslip they were the same figure), so the side is confirmed by
/// which column the amount sits in and by which total it sums into.
enum PayslipConcept: String, CaseIterable {
    case baseSalary
    case mealAllowance
    case overtime
    case holidaySubsidy
    case christmasSubsidy
    case seniorityBonus
    case bonus
    case ajudas
    case irs
    case employeeSS
    case unionDues
    case inKindDeduction
    case otherDeduction
    case otherEarning
    case totalEarnings
    case totalDeductions
    case netPay
    case employerSS
    case taxBase
    case ssBase

    enum Side { case earning, deduction, total, base }

    var side: Side {
        switch self {
        case .baseSalary, .mealAllowance, .overtime, .holidaySubsidy,
             .christmasSubsidy, .seniorityBonus, .bonus, .ajudas, .otherEarning:
            .earning
        case .irs, .employeeSS, .unionDues, .inKindDeduction, .otherDeduction:
            .deduction
        case .totalEarnings, .totalDeductions, .netPay, .employerSS:
            .total
        case .taxBase, .ssBase:
            .base
        }
    }

    /// How distinctive this concept's names are, used only to break a tie.
    ///
    /// The real label "IRS (Venc. 20,73%)" contains both "irs" and, once the
    /// rate is split off, "vencimento". Both are one-word matches and score
    /// identically, and without this the tie fell to alphabetical order, which
    /// made it base salary. "irs" names exactly one thing; "vencimento" appears
    /// on half the lines of a payslip.
    ///
    /// This is a tiebreak of last resort. Where the amount's column is known,
    /// the classifier filters by side first and never reaches this.
    var matchPriority: Int {
        switch self {
        case .baseSalary, .bonus, .overtime, .seniorityBonus,
             .otherDeduction, .otherEarning: 1
        default: 2
        }
    }

}

/// v1.1: labels to concepts, by expanded token set rather than by substring.
///
/// Substring matching cannot do this job. Three real payslips called the meal
/// allowance "Vale de Refeição", "Subsídio Alimentação - Géneros" and
/// "Subs. Alim.", and no two of those share a substring. Income tax was
/// "IRS (Venc. 20,73%)" on one and "Imposto sobre o rendimento" on another.
///
/// So a label is folded, expanded and reduced to a set of words, and a pattern
/// matches when every one of its words is present. Order is irrelevant, extra
/// words in the label are tolerated (payslips print a line code in the
/// description column), and a longer pattern always beats a shorter one.
///
/// Every pattern here must already be in normalised form. A pattern written
/// with an accent, a capital or an abbreviation could never match anything, and
/// nothing in the compiler would say so, which is why
/// tools/verify_payslip_reader.py asserts that each one normalises to itself.
enum PayslipLexicon {

    /// Words carried by both labels and patterns that say nothing about which
    /// concept a line is. Removed from both sides before matching, so
    /// "vale de refeicao" and "vale refeicao" are the same question.
    static let stopwords: Set<String> = [
        "de", "da", "do", "das", "dos", "e", "a", "o", "as", "os",
        "em", "no", "na", "por", "para", "com", "sobre", "ao",
    ]

    /// Patterns per concept, space separated, already normalised.
    ///
    /// Rows marked real were read off one of the three payslips this was built
    /// against. The rest are the forms the same payroll systems produce for
    /// other employers, and they should be treated as unverified until a real
    /// payslip carrying them turns up.
    static let patterns: [PayslipConcept: [String]] = [
        .baseSalary: [
            "vencimento base",          // real
            "vencimento mensal",
            "remuneracao base",
            "salario base",
            "vencimento",               // real
        ],
        .mealAllowance: [
            "subsidio alimentacao",     // real
            "vale refeicao",            // real
            "subsidio refeicao",
            "abono falhas alimentacao",
        ],
        .overtime: [
            "trabalho suplementar",
            "horas extraordinario",
            "trabalho extraordinario",
            "horas suplementar",
        ],
        .holidaySubsidy: [
            "subsidio ferias",          // real
        ],
        .christmasSubsidy: [
            "subsidio natal",           // real
        ],
        .seniorityBonus: [
            "diuturnidades",
            "premio antiguidade",
        ],
        .bonus: [
            "gratificacao balanco",     // real
            "premio assiduidade",
            "premio produtividade",
            "gratificacao",
            "premio",
            "bonus",
        ],
        .ajudas: [
            "ajudas custo",             // real
            "deslocacao ajudas",
            "abono falhas",
        ],
        .irs: [
            "irs",                      // real
            "retencao irs",
            "imposto rendimento",       // real
            "imposto rendimento singulares",
        ],
        .employeeSS: [
            "seguranca social",         // real
            "seguranca social empregado",   // real
            "seguranca social trabalhador",
            "contribuicao seguranca social",
        ],
        .unionDues: [
            "quota sindical",           // real
            "quotizacao sindical",
            "sindicato",
        ],
        .inKindDeduction: [
            "desconto especie",         // real
            "reembolso especie",
        ],
        .totalEarnings: [
            "total iliquido",           // real
            "total remuneracoes",
            "total abono",
            "total vencimentos",
        ],
        .totalDeductions: [
            "total descontos",          // real
            "total deducoes",
        ],
        .netPay: [
            "total pago",               // real
            "total receber",            // real
            "liquido receber",
            "valor liquido",
            "liquido pagar",
        ],
        .employerSS: [
            "seguranca social entidade",
            "encargos entidade patronal",
            "taxa social unica entidade",
        ],
        .taxBase: [
            "incidencia irs",
            "base incidencia irs",
            "remuneracao sujeita irs",
        ],
        .ssBase: [
            "incidencia seguranca social",
            "base incidencia seguranca social",
        ],
    ]

    // MARK: Matching

    /// Concepts a label could be, best first.
    ///
    /// Score is `10 * matched words` plus the fraction of the label the pattern
    /// accounts for. Specificity dominates, so "seguranca social empregado"
    /// outranks "seguranca social" on a label carrying both, and the fraction
    /// only separates ties. Extra words in the label cost almost nothing, which
    /// is deliberate: the description column often carries a line code, and a
    /// payslip should not become unreadable because it numbers its own rows.
    static func candidates(for label: String) -> [(concept: PayslipConcept, score: Double)] {
        let words = meaningfulWords(in: label)
        guard !words.isEmpty else { return [] }

        var out: [(PayslipConcept, Double)] = []
        for (concept, forms) in patterns {
            var best = 0.0
            for form in forms {
                let needed = form.split(separator: " ").map(String.init)
                    .filter { !stopwords.contains($0) }
                guard !needed.isEmpty, needed.allSatisfy({ contains(words, $0) }) else { continue }
                let score = 10 * Double(needed.count)
                    + Double(needed.count) / Double(words.count)
                best = max(best, score)
            }
            if best > 0 { out.append((concept, best)) }
        }
        // A deduction or a total outranks an earning whenever both match.
        //
        // Four real lines on one payslip made this necessary:
        //
        //     Seg. Social Sub. Natal      446,43   49,11
        //     Seg. Social Sub. Ferias     446,43   49,11
        //     IRS Sub. Natal              275,37   20,00
        //     IRS Sub. Ferias             275,37   20,00
        //
        // Each names a deduction AND the earning it was charged on, and the
        // earning half is the longer match, so scoring alone called the IRS on
        // the holiday subsidy a holiday subsidy. A deduction's name is the
        // line's identity; an earning's name inside a deduction line is only
        // saying which earning it was charged on.
        //
        // Advisory, and it does get reached. v1.1a: this used to claim the
        // classifier had already filtered by side so this ranking never ran
        // where a column was known. It runs: the classifier narrows the
        // candidates by the column's side and falls back to the unfiltered
        // best when that leaves nothing, so this order is what breaks the tie
        // on exactly the lines the column could not speak for.
        func rank(_ c: PayslipConcept) -> Int {
            switch c.side {
            case .deduction, .total: 1
            case .earning, .base: 0
            }
        }
        return out
            .sorted { a, b in
                if rank(a.0) != rank(b.0) { return rank(a.0) > rank(b.0) }
                if a.1 != b.1 { return a.1 > b.1 }
                if a.0.matchPriority != b.0.matchPriority {
                    return a.0.matchPriority > b.0.matchPriority
                }
                return a.0.rawValue < b.0.rawValue
            }
            .map { (concept: $0.0, score: $0.1) }
    }

    static func best(for label: String) -> PayslipConcept? {
        candidates(for: label).first?.concept
    }

    static func meaningfulWords(in label: String) -> [String] {
        PayslipText.tokens(label).filter { !stopwords.contains($0) && $0.count > 1 }
    }

    /// Whole-word membership, allowing one typo in a word long enough for one
    /// typo not to turn it into a different word. "alimentacan" still lands on
    /// "alimentacao"; "natal" and "total" stay apart because they are five
    /// characters and differ by two.
    ///
    /// The first two characters have to agree. Without that, "iliquido" is one
    /// edit from "liquido" and the gross total matches a pattern for the net,
    /// which is the one pair on a payslip where being one letter out inverts
    /// the meaning. OCR errors are rarely in the first letter, and where they
    /// are, missing the line is the better failure.
    private static func contains(_ words: [String], _ needle: String) -> Bool {
        if words.contains(needle) { return true }
        guard needle.count >= 6 else { return false }
        return words.contains { word in
            abs(word.count - needle.count) <= 1
                && word.prefix(2) == needle.prefix(2)
                && editDistance(word, needle) <= 1
        }
    }

    /// Levenshtein, two rows.
    static func editDistance(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            current[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[y.count]
    }

    // MARK: Fixtures

    /// Label to concept, as "label => concept raw value" or "label => nil".
    ///
    /// Rows marked real are the exact strings that came off the three payslips.
    /// They are the reason this file is a token matcher and not a `contains`.
    static let matchFixtures: [String] = [
        "Vencimento base => baseSalary",                       // real
        "Vencimento => baseSalary",                            // real
        "Subs. Alim. (isento) => mealAllowance",               // real
        "Subsidio Alimentacao - Generos => mealAllowance",     // real
        "Vale de Refeicao => mealAllowance",                   // real
        "Sub. Ferias - duodecimo => holidaySubsidy",           // real
        "Subsidio de Natal => christmasSubsidy",               // real
        "Ajudas de Custo => ajudas",                           // real
        "Gratificacao Balanco => bonus",                       // real
        "Premio Assiduidade => bonus",                         // real
        "Seg. Social - 11,00% => employeeSS",                  // real
        "Seguranca Social (11%) => employeeSS",                // real
        "Seg. social empregado => employeeSS",                 // real
        "IRS - Tx. 13,50% => irs",                             // real
        "IRS (Venc. 20,73%) => irs",                           // real, the tie matchPriority exists for
        "Seg. Social Sub. Natal => employeeSS",                // real, compound: deduction wins
        "Seg. Social Sub. Ferias => employeeSS",               // real
        "IRS Sub. Natal => irs",                               // real
        "IRS Sub. Ferias => irs",                              // real
        "Imposto sobre o rendimento => irs",                   // real
        "Quota Sindical => unionDues",                         // real
        "Desconto Especie => inKindDeduction",                 // real
        "Total Iliquido => totalEarnings",                     // real
        "Total Descontos => totalDeductions",                  // real
        "Total a Receber => netPay",                           // real
        "Total Pago => netPay",                                // real
        "R13 Subsidio Alimentacao => mealAllowance",
        "Trabalho suplementar => overtime",
        "Nome do trabalhador => nil",
        "Periodo => nil",
        "12345 => nil",
        "X => nil",
        " => nil",
    ]
}
