import Foundation

/// One computed salary picture. All monthly values are per paid month.
///
/// v0.5: ajudas de custo ride along, always kept separate from the salary.
/// They go straight to net (no IRS, no SS), are paid 12 times a year
/// regardless of the 12/14 schedule, and NEVER enter gross-based numbers
/// (percentiles, employer cost, efficiency). The UI must always show them
/// as their own thing.
struct SalaryBreakdown {
    let grossMonthly: Double
    let netMonthly: Double
    let irsMonthly: Double
    let employeeSSMonthly: Double
    let employerSSMonthly: Double
    let months: Double
    /// Ajudas de custo (or similar) per month, straight to net. 12 payments a year.
    var ajudasMonthly: Double = 0

    var employerCostMonthly: Double { grossMonthly + employerSSMonthly }
    var grossYearly: Double { grossMonthly * months }
    var netYearly: Double { netMonthly * months }
    var employerCostYearly: Double { employerCostMonthly * months }

    var ajudasYearly: Double { ajudasMonthly * 12 }
    /// What actually lands in the pocket in a normal month: salary net plus ajudas.
    var pocketMonthly: Double { netMonthly + ajudasMonthly }
    var pocketYearly: Double { netYearly + ajudasYearly }

    var deductionsMonthly: Double { irsMonthly + employeeSSMonthly }
    /// Effective rates on the gross salary (0 when gross is 0).
    var irsRate: Double { grossMonthly > 0 ? irsMonthly / grossMonthly : 0 }
    var employeeSSEffRate: Double { grossMonthly > 0 ? employeeSSMonthly / grossMonthly : 0 }
    var deductionsRate: Double { grossMonthly > 0 ? deductionsMonthly / grossMonthly : 0 }

    /// Of every €1 the employer spends on the salary, how much reaches the pocket.
    /// Salary only: ajudas de custo stay out on both sides.
    var efficiency: Double {
        employerCostMonthly > 0 ? netMonthly / employerCostMonthly : 0
    }
}

/// ⚠️ SKELETON TAX ENGINE — ALL RATES ARE PLACEHOLDERS.
///
/// The IRS withholding below is a simplified progressive approximation,
/// NOT the official "tabelas de retenção na fonte". Before any release:
/// - Encode the official withholding tables for the current year (versioned).
/// - Handle marital status, dependents, region (Continente/Açores/Madeira).
/// - Verify Social Security rates against Segurança Social.
enum TaxEngine {
    static let employeeSSRate = 0.11    // TODO: verify (Segurança Social, trabalhador)
    static let employerSSRate = 0.2375  // TODO: verify (entidade patronal)

    /// Simplified progressive IRS withholding approximation (per paid month).
    /// PLACEHOLDER — replace with official yearly-versioned tables.
    static func irsWithholding(grossMonthly g: Double) -> Double {
        let brackets: [(upTo: Double, rate: Double)] = [
            (870, 0.00),
            (1_100, 0.10),
            (1_600, 0.16),
            (2_100, 0.22),
            (3_000, 0.28),
            (5_000, 0.34),
            (.infinity, 0.40),
        ]
        var tax = 0.0
        var lower = 0.0
        for b in brackets {
            let slice = min(g, b.upTo) - lower
            if slice <= 0 { break }
            tax += slice * b.rate
            lower = b.upTo
        }
        return tax
    }

    static func breakdown(grossMonthly: Double, months: Double, ajudasMonthly: Double = 0) -> SalaryBreakdown {
        let gross = max(0, grossMonthly)
        let ss = gross * employeeSSRate
        let irs = irsWithholding(grossMonthly: gross)
        let net = gross - ss - irs
        return SalaryBreakdown(
            grossMonthly: gross,
            netMonthly: net,
            irsMonthly: irs,
            employeeSSMonthly: ss,
            employerSSMonthly: gross * employerSSRate,
            months: months,
            ajudasMonthly: max(0, ajudasMonthly)
        )
    }

    /// Invert net → gross by bisection (net is monotonic in gross).
    static func grossFromNet(_ net: Double) -> Double {
        guard net > 0 else { return 0 }
        var lo = net, hi = net * 3 + 1_000
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            let midNet = breakdown(grossMonthly: mid, months: 14).netMonthly
            if midNet < net { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }
}
