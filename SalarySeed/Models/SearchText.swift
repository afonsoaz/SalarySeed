import Foundation

/// v0.9.1: the shared text-matching rules behind every searchable picker.
///
/// Extracted from JobTitleCatalog when the concelho picker needed exactly the
/// same behaviour. Two pickers with two slightly different notions of "matches"
/// is the kind of drift nobody notices until one of them stops finding things.
enum SearchText {

    /// Diacritic and case insensitive, so "eletrico" matches "elétrico",
    /// "SETUBAL" matches "Setúbal" and "braganca" matches "Bragança".
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "pt_PT"))
    }

    /// True when any word starts with the query. Splitting on slashes, commas,
    /// parentheses and hyphens matters here: "Programador / Engenheiro de
    /// software" has to be findable by "engenheiro", and "Vila Nova de Gaia" by
    /// "gaia".
    ///
    /// Word-prefix is checked before plain substring everywhere it is used,
    /// because substring alone lets "uber" match the "kubernetes" synonym and
    /// outrank the taxi driver.
    static func hasWordPrefix(_ haystack: String, _ query: String) -> Bool {
        haystack
            .split(whereSeparator: { $0 == " " || $0 == "/" || $0 == "," || $0 == "(" || $0 == "-" })
            .contains { $0.hasPrefix(query) }
    }
}
