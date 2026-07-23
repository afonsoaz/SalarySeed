import Foundation

/// One computed salary picture. All monthly values are per paid month.
struct SalaryBreakdown {
    let grossMonthly: Double
    let netMonthly: Double
    let irsMonthly: Double
    let employeeSSMonthly: Double
    let employerSSMonthly: Double
    let months: Double

    var employerCostMonthly: Double { grossMonthly + employerSSMonthly }
    var grossYearly: Double { grossMonthly * months }
    var netYearly: Double { netMonthly * months }
    var employerCostYearly: Double { employerCostMonthly * months }

    /// Of every €1 the employer spends, how much reaches the pocket.
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

    static func breakdown(grossMonthly: Double, months: Double) -> SalaryBreakdown {
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
            months: months
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
