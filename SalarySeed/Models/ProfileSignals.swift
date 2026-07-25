import Foundation

/// v0.2: progressive profile signals (the "give to get" inputs behind compareSeed layers).
///
/// Raw values are STABLE IDs: they are persisted in UserDefaults and are designed to be
/// the exact keys that (a) the real GEP/MTSSS "Quadros de Pessoal" lookup tables and
/// (b) the future growthSeed advice engine (v0.3+) will consume. Rename with care.
/// v0.3: labels are bilingual where the languages differ (age bands and regions are
/// proper names or numbers, so they read the same in both).

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

/// NUTS II regions of Portugal, 2024 edition (the one GEP/INE publish on).
/// v0.4.1: replaces the old 7-region list. "AM Lisboa" split into Grande
/// Lisboa and Península de Setúbal; Oeste e Vale do Tejo is new. A stored
/// "aml" from older builds simply no longer resolves and the user re-picks.
enum PTRegion: String, CaseIterable, Identifiable {
    case norte
    case centro
    case oesteValeTejo = "ovt"
    case grandeLisboa = "glx"
    case penSetubal = "psetubal"
    case alentejo
    case algarve
    case acores
    case madeira

    var id: String { rawValue }

    var label: String {
        switch self {
        case .norte: "Norte"
        case .centro: "Centro"
        case .oesteValeTejo: "Oeste e Vale do Tejo"
        case .grandeLisboa: "Grande Lisboa"
        case .penSetubal: "Península de Setúbal"
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

    func label(pt: Bool) -> String {
        switch self {
        case .basic: pt ? "Básico (até ao 3º ciclo)" : "Basic (up to 9th grade)"
        case .secondary: pt ? "Secundário" : "Secondary"
        case .postSecondary: pt ? "Pós-secundário" : "Post-secondary"
        case .higher: pt ? "Superior (licenciatura ou mais)" : "Higher (degree or more)"
        }
    }
}

/// Economic sector (GEP CAE-Rev.3). v0.8.3 replaces the old occupation groups:
/// people know their sector far better than an ISCO occupation major group. The
/// list is a curated, non-overlapping cut of Quadro 104 — sections, plus the key
/// divisions people actually recognise (retail vs wholesale, health vs social
/// work, IT vs the rest of "information & communication"). Raw values are STABLE
/// IDs (persisted); they key the GEP sector tables in SalaryDataset.
enum Sector: String, CaseIterable, Identifiable {
    case agriculture, extractive, manufacturing, energy, water, construction
    case autoTrade, wholesale, retail, transport, hospitality
    case media, telecom, it, finance, realEstate, consulting
    case admin, publicAdmin, education, health, socialWork, arts, otherServices

    var id: String { rawValue }

    func label(pt: Bool) -> String {
        switch self {
        case .agriculture:   return pt ? "Agricultura e pescas" : "Agriculture & fishing"
        case .extractive:    return pt ? "Indústrias extractivas" : "Mining & quarrying"
        case .manufacturing: return pt ? "Indústria transformadora" : "Manufacturing"
        case .energy:        return pt ? "Eletricidade e gás" : "Electricity & gas"
        case .water:         return pt ? "Água e saneamento" : "Water & waste"
        case .construction:  return pt ? "Construção" : "Construction"
        case .autoTrade:     return pt ? "Comércio e reparação de veículos" : "Vehicle sales & repair"
        case .wholesale:     return pt ? "Comércio por grosso" : "Wholesale trade"
        case .retail:        return pt ? "Comércio a retalho" : "Retail"
        case .transport:     return pt ? "Transportes e armazenagem" : "Transport & storage"
        case .hospitality:   return pt ? "Alojamento e restauração" : "Hospitality & food"
        case .media:         return pt ? "Edição, media e audiovisual" : "Publishing & media"
        case .telecom:       return pt ? "Telecomunicações" : "Telecommunications"
        case .it:            return pt ? "Informática e serviços de informação" : "IT & information services"
        case .finance:       return pt ? "Banca e seguros" : "Banking & insurance"
        case .realEstate:    return pt ? "Atividades imobiliárias" : "Real estate"
        case .consulting:    return pt ? "Consultoria científica e técnica" : "Consulting, science & technical"
        case .admin:         return pt ? "Serviços administrativos e de apoio" : "Administrative & support"
        case .publicAdmin:   return pt ? "Administração pública e defesa" : "Public administration & defence"
        case .education:     return pt ? "Educação" : "Education"
        case .health:        return pt ? "Saúde" : "Healthcare"
        case .socialWork:    return pt ? "Apoio social" : "Social work"
        case .arts:          return pt ? "Artes, cultura e desporto" : "Arts, culture & sport"
        case .otherServices: return pt ? "Outros serviços" : "Other services"
        }
    }
}

/// Seniority as tenure AT THE CURRENT EMPLOYER, banded exactly as GEP's
/// "escalão de antiguidade na empresa" (Quadro 104).
///
/// v0.9 correctness fix: v0.8.3 asked for "years in the sector" and fed that
/// straight into these bands. Quadro 104 is titled "GANHO MÉDIO, POR ACTIVIDADE
/// ECONÓMICA, SEGUNDO O ESCALÃO DE ANTIGUIDADE NA EMPRESA", and the Relatório
/// Único introductory note lists the worker variable as "antiguidade na
/// empresa". Someone who had spent 8 years in IT across three employers was
/// being placed in the 5-9 cell when GEP would have them in 1-4. The question
/// now asks for years at the current employer; career total is a separate,
/// collect-only signal (see SalaryStore.careerYears).
enum TenureBand: String, CaseIterable, Identifiable {
    case lt1, y1to4, y5to9, y10to14, y15to19, y20plus

    var id: String { rawValue }

    /// 0-based index into SalaryDataset.sectorTenureMean arrays.
    var index: Int {
        switch self {
        case .lt1: return 0
        case .y1to4: return 1
        case .y5to9: return 2
        case .y10to14: return 3
        case .y15to19: return 4
        case .y20plus: return 5
        }
    }

    static func from(years: Int) -> TenureBand {
        switch years {
        case ..<1: return .lt1
        case 1...4: return .y1to4
        case 5...9: return .y5to9
        case 10...14: return .y10to14
        case 15...19: return .y15to19
        default: return .y20plus
        }
    }

    func label(pt: Bool) -> String {
        switch self {
        case .lt1: return pt ? "menos de 1 ano" : "under 1 year"
        case .y1to4: return pt ? "1 a 4 anos" : "1–4 years"
        case .y5to9: return pt ? "5 a 9 anos" : "5–9 years"
        case .y10to14: return pt ? "10 a 14 anos" : "10–14 years"
        case .y15to19: return pt ? "15 a 19 anos" : "15–19 years"
        case .y20plus: return pt ? "20+ anos" : "20+ years"
        }
    }
}

// MARK: - v0.9 signals

/// Whether the employer pays under the Código do Trabalho (essentially all
/// private employers, plus public companies and EPEs) or under the Regime do
/// Contrato de Trabalho em Funções Públicas.
///
/// WHY THIS MATTERS MORE THAN IT LOOKS. The Relatório Único introductory note is
/// explicit: employers are obliged to report "ficando excluídos desta obrigação
/// os serviços e órgãos que apenas tenham trabalhadores abrangidos pelo Regime
/// do Contrato de Trabalho em Funções Públicas". So GEP's tables do NOT cover
/// staff on public-function contracts: direct public administration, state
/// school teachers, most of the SNS career staff. The CAE O / P / Q rows exist,
/// but they describe the Código do Trabalho slice of those activities, not the
/// people most users would picture. Without this flag the app silently compares
/// a funcionário público against a population he is not in.
enum EmployerKind: String, CaseIterable, Identifiable {
    case privateSector = "private"
    case publicSector = "public"
    case stateOwned = "stateowned"

    var id: String { rawValue }

    func label(pt: Bool) -> String {
        switch self {
        case .privateSector: return pt ? "Privado" : "Private"
        case .publicSector:  return pt ? "Função pública" : "Public administration"
        case .stateOwned:    return pt ? "Empresa pública / EPE" : "State-owned company / EPE"
        }
    }

    func hint(pt: Bool) -> String {
        switch self {
        case .privateSector:
            return pt ? "Empresa privada, IPSS, associação" : "Private company, non-profit, association"
        case .publicSector:
            return pt ? "Contrato de trabalho em funções públicas: Estado, câmara, escola pública, SNS"
                      : "Public-function contract: state, council, state school, national health service"
        case .stateOwned:
            return pt ? "Empresa do Estado com contrato individual de trabalho" : "State-owned employer on a normal employment contract"
        }
    }

    /// GEP's Quadros de Pessoal do not cover public-function contracts, so any
    /// comparison shown to these users has to carry a caveat.
    var outsideGEP: Bool { self == .publicSector }
}

/// Full-time or part-time, with the contracted weekly hours.
///
/// This is the cheapest data-quality field in the app. Published cell means mix
/// full-timers and part-timers together, and a crowd database that does not
/// record it will quietly pull every median down without anyone being able to
/// see why.
enum WorkSchedule: String, CaseIterable, Identifiable {
    case fullTime = "ft"
    case partTime = "pt"

    var id: String { rawValue }

    func label(pt isPT: Bool) -> String {
        switch self {
        case .fullTime: return isPT ? "Tempo inteiro" : "Full-time"
        case .partTime: return isPT ? "Tempo parcial" : "Part-time"
        }
    }

    /// The default weekly hours offered when this option is picked.
    var defaultHours: Int { self == .fullTime ? 40 : 20 }
}

/// Optional and always skippable.
///
/// Collected for two reasons, both stated to the user before they answer: it is
/// a real pay determinant in Portugal, and it is the axis the EU pay
/// transparency directive is built around. Nothing in the app compares on it
/// yet. `preferNot` is stored as an explicit answer rather than as nil, so a
/// deliberate refusal can be told apart from a question never reached.
enum Gender: String, CaseIterable, Identifiable {
    case female = "f"
    case male = "m"
    case other = "o"
    case preferNot = "na"

    var id: String { rawValue }

    func label(pt: Bool) -> String {
        switch self {
        case .female:    return pt ? "Feminino" : "Female"
        case .male:      return pt ? "Masculino" : "Male"
        case .other:     return pt ? "Outro" : "Other"
        case .preferNot: return pt ? "Prefiro não dizer" : "Prefer not to say"
        }
    }

    /// Only answers that carry information count towards the seed.
    var informative: Bool { self != .preferNot }
}
