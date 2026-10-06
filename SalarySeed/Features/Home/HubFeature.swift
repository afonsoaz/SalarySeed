import Foundation

/// One row on Home: a feature, what it is called, and where it goes.
///
/// Home is the only way around the app, and these are its ways in. The order
/// and the names are Afonso's, set as one list: understanding your pay
/// (Tax), putting it against other people (Portugal, Europe), checking a
/// document you hold (the payslip), trying what could come next (Grow), and
/// checking an offer, with everything else under Other tools. Each name says
/// what you DO there, so a row reads as an action rather than a section, and
/// the two that check something share the verb. The order is the declaration
/// order below, because Home draws `allCases`.
///
/// A new feature costs one case here, or one row in Other tools, rather than a
/// sixth tab nobody can fit.
///
/// The words are `Strings` members, never literals here, so `dump_copy.py` sees
/// every one of them and the copy review cannot be shorter than the app.
enum HubFeature: CaseIterable, Identifiable {
    case tax, comparePortugal, compareEurope, payslip, grow, offer, tools

    var id: Self { self }

    var route: HubRoute {
        switch self {
        case .tax: return .tax
        case .comparePortugal: return .comparePortugal
        case .compareEurope: return .compareEurope
        case .payslip: return .payslipCheck(.check)
        case .grow: return .grow
        case .offer: return .offer
        case .tools: return .tools
        }
    }

    /// Three of these were the tab bar's own symbols, kept so a returning
    /// reader finds the same picture beside the same feature.
    var glyph: String {
        switch self {
        case .tax: return "percent"
        case .comparePortugal: return "chart.bar.fill"
        case .compareEurope: return "globe.europe.africa.fill"
        case .payslip: return "doc.text.magnifyingglass"
        case .grow: return "chart.line.uptrend.xyaxis"
        case .offer: return "briefcase.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        }
    }

    /// Free, or part of the support payment, for the day it comes back.
    ///
    /// DORMANT, AND ON PURPOSE. While `AppConfig.monetisation` is `.free`,
    /// `SupporterStore.isSupporter` is forced true, so no row is ever drawn
    /// locked and nothing on Home changes. Turning payments back on is a legal
    /// decision, not a product one (see CLAUDE.md), and when it is made these
    /// two rows show a lock with no further work. The real gate stays where the
    /// paid thing lives, `SupportLock` on the screen itself, so a reader who
    /// taps a locked row still sees the real screen out of focus first.
    var tier: Tier {
        switch self {
        case .compareEurope, .grow: return .supporter
        default: return .free
        }
    }

    enum Tier {
        case free
        case supporter
    }

    /// The same name whatever state the feature is in. The offer row used to
    /// read "Your job offer" once one was kept; the names are a set now, and a
    /// row that renames itself would break it. Whether an offer is kept is
    /// still said, to VoiceOver, by the hint.
    func title(_ s: Strings) -> String {
        switch self {
        case .tax: return s.hubTaxTitle
        case .comparePortugal: return s.hubPortugalTitle
        case .compareEurope: return s.hubEuropeTitle
        case .payslip: return s.hubPayslipTitle
        case .grow: return s.hubGrowTitle
        case .offer: return s.hubOfferTitle
        case .tools: return s.toolsTitle
        }
    }

    /// What the row opens, in a sentence. Not drawn: Home's rows are a glyph
    /// and a name, and this is what VoiceOver says after the name.
    func hint(_ s: Strings, offerKept: Bool) -> String {
        switch self {
        case .tax: return s.hubTaxSub
        case .comparePortugal: return s.hubPortugalSub
        case .compareEurope: return s.euroTitle
        case .payslip: return s.hubPayslipSub
        case .grow: return s.growTitle
        case .offer: return offerKept ? s.offerNudgeKeptSub : s.hubOfferSub
        case .tools: return s.hubToolsSub
        }
    }
}
