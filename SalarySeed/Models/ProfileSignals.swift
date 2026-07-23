import Foundation

/// v0.2 — progressive profile signals (the "give to get" inputs behind compareSeed layers).
///
/// Raw values are STABLE IDs: they are persisted in UserDefaults and are designed to be
/// the exact keys that (a) the real GEP/MTSSS "Quadros de Pessoal" lookup tables and
/// (b) the future growthSeed advice engine (v0.3) will consume. Rename with care.

/// Age bands as published by GEP/INE.
enum AgeBand: String, CaseIterable, Identifiable {
    case under25 = "lt25"
    case band25to34 = "25_34"
    case band35to44 = "35_44"
    case band45to54 = "45_54"
    case band55to64 = "55_64"
    case over65 = "65p"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .under25: "<25"
        case .band25to34: "25–34"
        case .band35to44: "35–44"
        case .band45to54: "45–54"
        case .band55to64: "55–64"
        case .over65: "65+"
        }
    }
}

/// NUTS II regions of Portugal.
enum PTRegion: String, CaseIterable, Identifiable {
    case norte
    case centro
    case amLisboa = "aml"
    case alentejo
    case algarve
    case acores
    case madeira

    var id: String { rawValue }

    var label: String {
        switch self {
        case .norte: "Norte"
        case .centro: "Centro"
        case .amLisboa: "AM Lisboa"
        case .alentejo: "Alentejo"
        case .algarve: "Algarve"
        case .acores: "Açores"
        case .madeira: "Madeira"
        }
    }
}

/// Education levels, kept to a few meaningful bands (deliberate product choice).
enum EducationLevel: String, CaseIterable, Identifiable {
    case basic = "basic"
    case secondary = "sec"
    case postSecondary = "postsec"
    case higher = "higher"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .basic: "Básico (até 3º ciclo)"
        case .secondary: "Secundário"
        case .postSecondary: "Pós-secundário"
        case .higher: "Superior (licenciatura+)"
        }
    }
}

/// Broad occupation groups (CPP major-group flavor — deliberately coarse).
enum OccupationGroup: String, CaseIterable, Identifiable {
    case managers
    case specialists
    case technicians
    case administrative = "admin"
    case services
    case trades
    case operators
    case elementary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .managers: "Directors & Managers"
        case .specialists: "Specialists & Professionals"
        case .technicians: "Technicians"
        case .administrative: "Administrative"
        case .services: "Services & Sales"
        case .trades: "Skilled Trades"
        case .operators: "Machine Operators"
        case .elementary: "Elementary Occupations"
        }
    }
}
