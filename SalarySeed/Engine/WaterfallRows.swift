import Foundation

/// The waterfall's six figures as whole euros that ADD UP on the screen.
///
/// Found in review: rounded one by one, as `eur` rounds everything, the rows
/// failed to add up by a euro for about a quarter of salaries. At 1250 € gross
/// they read 1250 − 138 − 108 over a net of 1005. A list whose job is to show
/// where the money goes cannot be a euro out with itself.
///
/// So the whole screen is built from ONE set of whole euros, rounded so that
/// everything adds up, and measured rather than argued: `tools/waterfall_probe`
/// compiles this file with `TaxEngine.swift`, unmodified, and sweeps 255 000
/// waterfalls over regions, households, IRS Jovem, both schedules, all three
/// lenses, and salaries in cents as well as whole euros (a salary typed as NET
/// reaches the engine as a gross with cents).
/// - Gross and net are rounded on their own, because Home shows those exact
///   figures and Tax may not disagree with Home.
/// - Social Security and IRS share what is left, gross minus net as shown,
///   by largest remainder: both start rounded down, and the euro or two still
///   missing go to the larger fractions. Each stays one of its own two nearest
///   whole euros, which keeps "11% of gross" true of the euros beside it.
/// - The cost is gross plus the employer's Social Security as shown, so the
///   total is the total of its rows.
/// - The settlement card's "Withheld this year" IS the Year lens's IRS row
///   (`SettlementRows`), so the two cannot disagree, and its refund or amount
///   to pay is withheld minus real as shown, so the card adds up too.
///
/// The first version pinned IRS to its own rounding and let Social Security
/// take the rest. A Python sweep over whole-euro salaries passed it; the probe,
/// compiling the real thing over salaries in cents, found 2288 failures,
/// including one branch marked unreachable that was not. Rule 18, again.
///
/// Whole euros by half-to-even, which is what `NumberFormatter` does, so a
/// figure here is the same whole euro `eur` would have printed for it.
struct WaterfallRows {
    let cost, employerSS, gross, employeeSS, irs, net: Double

    init(_ b: SalaryBreakdown, factor: Double) {
        gross = Self.whole(b.grossMonthly * factor)
        net = Self.whole(b.netMonthly * factor)
        employerSS = Self.whole(b.employerSSMonthly * factor)
        cost = gross + employerSS
        (employeeSS, irs) = Self.split(b.employeeSSMonthly * factor,
                                       b.irsMonthly * factor,
                                       into: gross - net)
    }

    static func whole(_ x: Double) -> Double { x.rounded(.toNearestOrEven) }

    /// Two exact amounts as whole euros that sum to `total`, each rounded to
    /// one of its two nearest whole euros.
    ///
    /// `total` is gross minus net, each rounded on its own, so it sits within a
    /// euro either side of the exact sum and the gap above the rounded-down
    /// pair is 0, 1 or 2. Outside that (only when gross and net both land
    /// exactly halfway between two whole euros and round in opposite
    /// directions) no split can keep both true, and the difference goes to IRS,
    /// the one with no statutory rate printed beside it.
    static func split(_ ss: Double, _ irs: Double, into total: Double) -> (Double, Double) {
        let ss0 = ss.rounded(.down), irs0 = irs.rounded(.down)
        switch total - ss0 - irs0 {
        case 0:
            return (ss0, irs0)
        case 1:
            return ss - ss0 >= irs - irs0 ? (ss0 + 1, irs0) : (ss0, irs0 + 1)
        case 2:
            return (ss0 + 1, irs0 + 1)
        default:
            return (ss0, total - ss0)
        }
    }
}

/// The settlement card's three figures, on the same footing as the rows above.
///
/// "Withheld this year" is the Year lens's IRS row, so the card and the
/// waterfall show one figure for one amount. The real IRS is rounded on its
/// own, and the refund or amount to pay is withheld minus real AS SHOWN, so the
/// card's own sum holds. Before this the three were rounded one by one, so the
/// amount back could be a euro off the difference of the two figures printed
/// directly above it.
struct SettlementRows {
    let withheld, settled, balance: Double

    init(_ b: SalaryBreakdown) {
        withheld = WaterfallRows(b, factor: b.months).irs
        settled = WaterfallRows.whole(b.annualIRSSettled)
        balance = withheld - settled
    }
}
