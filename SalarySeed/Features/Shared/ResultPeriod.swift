import Foundation

/// v0.8: three ways to read the result. Two are monthly (the yearly pay spread
/// over 12, or over the 14 real payments) and one is the yearly total.
///
/// v1.5 moved this out of `HomeView`, where it was nested. The offer screen
/// reads two salaries through the same picker, and it has to read them exactly
/// the way Home reads one, or the "now" figure there would stop matching the
/// figure on Home the first time either was touched.
enum ResultPeriod: String, CaseIterable, Identifiable {
    case m12, m14, year
    var id: String { rawValue }
    /// 0 = monthly ÷12, 1 = monthly ÷14, 2 = annual. Drives the copy helpers.
    var modeIndex: Int { self == .m12 ? 0 : (self == .m14 ? 1 : 2) }
    var isAnnual: Bool { self == .year }
    func label(_ s: Strings) -> String {
        switch self {
        case .m12: return s.resultM12
        case .m14: return s.resultM14
        case .year: return s.resultYear
        }
    }
    /// Multiplier on a per-payment monthly value to reach this view.
    func factor(months: Double) -> Double {
        switch self {
        case .m12: return months / 12
        case .m14: return months / 14
        case .year: return months
        }
    }
}

extension SalaryBreakdown {
    /// The allowance as this view shows it: the year's total in the yearly view,
    /// and what is paid in a calendar month in both monthly ones.
    func allowance(in period: ResultPeriod) -> Double {
        period.isAnnual ? ajudasYearly : ajudasMonthly
    }

    /// What reaches the reader in this view: the net from the salary, plus the
    /// allowance paid on top of it.
    ///
    /// v1.5 lifted this out of Home's hero footnote so the offer screen's "now"
    /// is Home's figure by construction rather than by coincidence. One reading
    /// is inherited on purpose: the monthly views add the allowance as it is
    /// paid, once a calendar month, while the salary is spread over 12 or 14.
    /// Home has always read it that way, and if that ever changes it changes
    /// here, once, for both screens.
    func pocket(in period: ResultPeriod) -> Double {
        netMonthly * period.factor(months: months) + allowance(in: period)
    }
}
