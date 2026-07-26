import Foundation

/// v0.11: the European layer of mapSeed. Eurostat Structure of Earnings Survey
/// 2022, `earn_ses22_24`: mean gross monthly earnings, NACE section, employees
/// in enterprises with 10 or more staff, both sexes. Reuse is free including
/// commercial; the attribution line is in `EuroDataset.sourceLine`.
///
/// WHY THIS IS A SEPARATE DATASET FROM EVERY OTHER NUMBER IN THE APP. GEP and
/// Eurostat measure different populations, in different years, with different
/// definitions, so their LEVELS are not comparable and must never be mixed. The
/// only thing that crosses the boundary is a RATIO computed entirely inside
/// Eurostat: country ÷ Portugal, both from this table. That ratio is then applied
/// to the user's own salary. No GEP figure ever enters the calculation.
///
/// SECTIONS, NOT DIVISIONS. SES publishes NACE sections only, so the app's three
/// trade sectors collapse into G, its three information sectors into J, and
/// health and social work into Q. Agriculture is outside the survey's scope
/// entirely (SES covers B to S) and public administration has no Portuguese
/// value, so those two sectors have no European comparison and say so.
enum EuroDataset {

    static let referenceYear = 2022
    static let sourceLine = "Fonte: Eurostat, Inquérito à Estrutura dos Ganhos 2022 (earn_ses22_24)"

    /// Mean gross monthly earnings in euros, per NACE section, per country.
    /// 455 of the 459 possible cells are populated. The four gaps are Cyprus and
    /// Malta in mining and in electricity and gas, which is structural rather
    /// than suppression: neither country has a sector there to measure.
    static let sectionMean: [EuroSection: [Country: Double]] = [
        .sB: [.finland: 4041, .denmark: 7936, .sweden: 4423, .estonia: 1890, .ireland: 4903, .netherlands: 6154, .germany: 4155, .poland: 1856, .latvia: 1628, .belgium: 4367, .luxembourg: 3944, .czechia: 1663, .slovakia: 1435, .lithuania: 1808, .france: 3168, .austria: 4159, .hungary: 1340, .romania: 1630, .portugal: 1640, .spain: 2820, .italy: 3140, .slovenia: 2733, .croatia: 1379, .bulgaria: 1228, .greece: 2209],
        .sC: [.finland: 4026, .denmark: 5808, .sweden: 3934, .estonia: 1701, .ireland: 4671, .netherlands: 3985, .germany: 4068, .poland: 1309, .latvia: 1432, .belgium: 4255, .luxembourg: 4290, .czechia: 1577, .slovakia: 1463, .lithuania: 1767, .france: 3161, .austria: 3731, .hungary: 1245, .romania: 1069, .portugal: 1265, .spain: 2337, .italy: 2701, .slovenia: 1994, .croatia: 1255, .bulgaria: 781, .malta: 1963, .greece: 1485, .cyprus: 1645],
        .sD: [.finland: 4971, .denmark: 6885, .sweden: 4568, .estonia: 2060, .ireland: 6267, .netherlands: 5068, .germany: 5048, .poland: 1776, .latvia: 1747, .belgium: 5916, .luxembourg: 6149, .czechia: 2130, .slovakia: 1973, .lithuania: 1980, .france: 4091, .austria: 4905, .hungary: 1705, .romania: 1752, .portugal: 2943, .spain: 3964, .italy: 3745, .slovenia: 2818, .croatia: 1789, .bulgaria: 1408, .greece: 2823],
        .sE: [.finland: 3780, .denmark: 5430, .sweden: 3844, .estonia: 1744, .ireland: 3924, .netherlands: 3905, .germany: 3657, .poland: 1184, .latvia: 1272, .belgium: 4109, .luxembourg: 4713, .czechia: 1419, .slovakia: 1285, .lithuania: 1587, .france: 2667, .austria: 3267, .hungary: 1097, .romania: 985, .portugal: 1256, .spain: 2265, .italy: 2425, .slovenia: 1920, .croatia: 1190, .bulgaria: 656, .malta: 2033, .greece: 1828, .cyprus: 1744],
        .sF: [.finland: 3937, .denmark: 5347, .sweden: 3947, .estonia: 1940, .ireland: 4219, .netherlands: 4165, .germany: 3329, .poland: 1342, .latvia: 1619, .belgium: 3584, .luxembourg: 3802, .czechia: 1525, .slovakia: 1378, .lithuania: 1698, .france: 2881, .austria: 3388, .hungary: 1021, .romania: 985, .portugal: 1217, .spain: 2081, .italy: 2418, .slovenia: 1742, .croatia: 1127, .bulgaria: 730, .malta: 1843, .greece: 1430, .cyprus: 1808],
        .sG: [.finland: 3306, .denmark: 4297, .sweden: 3701, .estonia: 1643, .ireland: 3370, .netherlands: 2812, .germany: 3199, .poland: 1280, .latvia: 1358, .belgium: 3704, .luxembourg: 3861, .czechia: 1573, .slovakia: 1440, .lithuania: 1661, .france: 2749, .austria: 3005, .hungary: 1133, .romania: 1097, .portugal: 1376, .spain: 1953, .italy: 2421, .slovenia: 1955, .croatia: 1261, .bulgaria: 795, .malta: 1758, .greece: 1412, .cyprus: 1560],
        .sH: [.finland: 3579, .denmark: 5410, .sweden: 3384, .estonia: 1627, .ireland: 3965, .netherlands: 3739, .germany: 2990, .poland: 1355, .latvia: 1456, .belgium: 3733, .luxembourg: 4763, .czechia: 1515, .slovakia: 1372, .lithuania: 1601, .france: 2712, .austria: 3310, .hungary: 1126, .romania: 1090, .portugal: 1524, .spain: 2238, .italy: 2387, .slovenia: 1873, .croatia: 1414, .bulgaria: 816, .malta: 2113, .greece: 1795, .cyprus: 2638],
        .sI: [.finland: 2629, .denmark: 3328, .sweden: 2802, .estonia: 1299, .ireland: 2578, .netherlands: 2229, .germany: 2164, .poland: 964, .latvia: 1028, .belgium: 2898, .luxembourg: 3225, .czechia: 1077, .slovakia: 1042, .lithuania: 1340, .france: 2444, .austria: 2215, .hungary: 789, .romania: 745, .portugal: 1067, .spain: 1699, .italy: 1962, .slovenia: 1584, .croatia: 1169, .bulgaria: 586, .malta: 1745, .greece: 1255, .cyprus: 1434],
        .sJ: [.finland: 4824, .denmark: 6495, .sweden: 4895, .estonia: 3078, .ireland: 7254, .netherlands: 4657, .germany: 5077, .poland: 2537, .latvia: 2492, .belgium: 4930, .luxembourg: 5943, .czechia: 2779, .slovakia: 2298, .lithuania: 3315, .france: 4357, .austria: 4568, .hungary: 1998, .romania: 2575, .portugal: 2234, .spain: 2869, .italy: 3168, .slovenia: 3023, .croatia: 2419, .bulgaria: 2141, .malta: 2749, .greece: 2011, .cyprus: 3405],
        .sK: [.finland: 4685, .denmark: 6858, .sweden: 5423, .estonia: 2650, .ireland: 6464, .netherlands: 5305, .germany: 5122, .poland: 2172, .latvia: 2368, .belgium: 5207, .luxembourg: 7460, .czechia: 2415, .slovakia: 2124, .lithuania: 2970, .france: 4268, .austria: 4597, .hungary: 1930, .romania: 1951, .portugal: 2412, .spain: 3383, .italy: 4225, .slovenia: 2841, .croatia: 1915, .bulgaria: 1159, .malta: 2781, .greece: 2719, .cyprus: 3101],
        .sL: [.finland: 3855, .denmark: 4786, .sweden: 4001, .estonia: 1524, .ireland: 3831, .netherlands: 4302, .germany: 3610, .poland: 1280, .latvia: 1203, .belgium: 4722, .luxembourg: 5494, .czechia: 1688, .slovakia: 1437, .lithuania: 1563, .france: 3019, .austria: 3747, .hungary: 1068, .romania: 1208, .portugal: 1948, .spain: 2819, .italy: 2676, .slovenia: 2239, .croatia: 1369, .bulgaria: 781, .malta: 2248, .greece: 1837, .cyprus: 1262],
        .sM: [.finland: 4334, .denmark: 6521, .sweden: 4616, .estonia: 2296, .ireland: 5160, .netherlands: 4596, .germany: 4614, .poland: 1978, .latvia: 2152, .belgium: 5441, .luxembourg: 6638, .czechia: 2207, .slovakia: 1959, .lithuania: 2504, .france: 4061, .austria: 4281, .hungary: 1778, .romania: 1717, .portugal: 1980, .spain: 2588, .italy: 3259, .slovenia: 2668, .croatia: 1886, .bulgaria: 1310, .malta: 2566, .greece: 1824, .cyprus: 2652],
        .sN: [.finland: 2811, .denmark: 4310, .sweden: 3181, .estonia: 1562, .ireland: 3533, .netherlands: 2786, .germany: 2691, .poland: 1105, .latvia: 1223, .belgium: 3346, .luxembourg: 3347, .czechia: 1175, .slovakia: 1236, .lithuania: 1385, .france: 2532, .austria: 2632, .hungary: 965, .romania: 982, .portugal: 1058, .spain: 1661, .italy: 1978, .slovenia: 1498, .croatia: 1036, .bulgaria: 773, .malta: 1641, .greece: 1225, .cyprus: 1742],
        .sP: [.finland: 3820, .denmark: 5088, .sweden: 3495, .estonia: 1541, .ireland: 4667, .netherlands: 4075, .germany: 4057, .poland: 1198, .latvia: 1150, .belgium: 4598, .luxembourg: 8580, .czechia: 1551, .slovakia: 1283, .lithuania: 1697, .france: 3317, .austria: 3631, .hungary: 1154, .romania: 1478, .portugal: 2257, .spain: 2621, .italy: 2365, .slovenia: 2135, .croatia: 1561, .bulgaria: 994, .malta: 2185, .greece: 1494, .cyprus: 3044],
        .sQ: [.finland: 3344, .denmark: 4331, .sweden: 3443, .estonia: 1987, .ireland: 4135, .netherlands: 3369, .germany: 3543, .poland: 1531, .latvia: 2057, .belgium: 3820, .luxembourg: 5927, .czechia: 1806, .slovakia: 1633, .lithuania: 2205, .france: 2784, .austria: 3329, .hungary: 1151, .romania: 1624, .portugal: 1388, .spain: 2509, .italy: 2742, .slovenia: 2284, .croatia: 1657, .bulgaria: 939, .malta: 2011, .greece: 1535, .cyprus: 2788],
        .sR: [.finland: 3144, .denmark: 3805, .sweden: 3098, .estonia: 1437, .ireland: 3521, .netherlands: 3005, .germany: 2863, .poland: 1176, .latvia: 1211, .belgium: 3683, .luxembourg: 5149, .czechia: 1396, .slovakia: 1302, .lithuania: 1510, .france: 3423, .austria: 3284, .hungary: 1259, .romania: 1120, .portugal: 1733, .spain: 2120, .italy: 3968, .slovenia: 2117, .croatia: 1285, .bulgaria: 742, .malta: 2446, .greece: 1233, .cyprus: 1744],
        .sS: [.finland: 3351, .denmark: 5324, .sweden: 3520, .estonia: 1560, .ireland: 3090, .netherlands: 3660, .germany: 3388, .poland: 1048, .latvia: 1426, .belgium: 3822, .luxembourg: 4942, .czechia: 1313, .slovakia: 1156, .lithuania: 1556, .france: 2802, .austria: 3201, .hungary: 1020, .romania: 1163, .portugal: 1306, .spain: 1853, .italy: 1992, .slovenia: 1829, .croatia: 1270, .bulgaria: 748, .malta: 1852, .greece: 1406, .cyprus: 1691],
    ]

    /// Country price level, EU27 = 1.00, derived as the euro figure divided by
    /// the purchasing-power-standard figure Eurostat publishes for the same cell.
    /// It is a pure country effect: computed from two different sectors and two
    /// different tenure bands it agrees to within 0.12%, which is rounding. So
    /// the app stores euros once and divides, rather than bundling a second grid.
    static let priceLevel: [Country: Double] = [
        .finland: 1.240, .denmark: 1.333, .sweden: 1.267,
        .estonia: 0.897, .ireland: 1.189, .netherlands: 1.171,
        .germany: 1.119, .poland: 0.614, .latvia: 0.801,
        .belgium: 1.119, .luxembourg: 1.306, .czechia: 0.806,
        .slovakia: 0.793, .lithuania: 0.752, .france: 1.086,
        .austria: 1.123, .hungary: 0.646, .romania: 0.559,
        .portugal: 0.843, .spain: 0.932, .italy: 0.960,
        .slovenia: 0.848, .croatia: 0.725, .bulgaria: 0.602,
        .malta: 0.892, .greece: 0.820, .cyprus: 0.934,
    ]

    /// The euro figure, or the same figure restated in what it buys.
    static func mean(section: EuroSection, country: Country, purchasingPower: Bool) -> Double? {
        guard let eur = sectionMean[section]?[country] else { return nil }
        guard purchasingPower, let pl = priceLevel[country], pl > 0 else { return eur }
        return eur / pl
    }
}

/// The NACE sections SES publishes. Raw values are the NACE letters, prefixed so
/// they are legal Swift identifiers; the letter itself is `code`.
enum EuroSection: String, CaseIterable, Identifiable {
    case sB, sC, sD, sE, sF, sG, sH, sI, sJ, sK, sL, sM, sN, sP, sQ, sR, sS

    var id: String { rawValue }
    var code: String { String(rawValue.dropFirst()) }

    func label(pt: Bool) -> String {
        switch self {
        case .sB: return pt ? "Indústrias extractivas" : "Mining and quarrying"
        case .sC: return pt ? "Indústria transformadora" : "Manufacturing"
        case .sD: return pt ? "Eletricidade e gás" : "Electricity and gas"
        case .sE: return pt ? "Água e saneamento" : "Water and waste"
        case .sF: return pt ? "Construção" : "Construction"
        case .sG: return pt ? "Comércio por grosso e a retalho" : "Wholesale and retail trade"
        case .sH: return pt ? "Transportes e armazenagem" : "Transport and storage"
        case .sI: return pt ? "Alojamento e restauração" : "Accommodation and food"
        case .sJ: return pt ? "Informação e comunicação" : "Information and communication"
        case .sK: return pt ? "Banca e seguros" : "Finance and insurance"
        case .sL: return pt ? "Atividades imobiliárias" : "Real estate"
        case .sM: return pt ? "Consultoria científica e técnica" : "Professional and technical"
        case .sN: return pt ? "Serviços administrativos e de apoio" : "Administrative and support"
        case .sP: return pt ? "Educação" : "Education"
        case .sQ: return pt ? "Saúde e apoio social" : "Health and social work"
        case .sR: return pt ? "Artes e recreação" : "Arts and recreation"
        case .sS: return pt ? "Outros serviços" : "Other services"
        }
    }
}

/// The 27 members of the European Union. Raw values are Eurostat geo codes,
/// which is what the source keys on, so they stay stable if a label changes.
/// Greece is `el` in Eurostat and GR everywhere else, so `code` differs from the
/// raw value for exactly one country.
enum Country: String, CaseIterable, Identifiable {
    case finland = "fi"
    case denmark = "dk"
    case sweden = "se"
    case estonia = "ee"
    case ireland = "ie"
    case netherlands = "nl"
    case germany = "de"
    case poland = "pl"
    case latvia = "lv"
    case belgium = "be"
    case luxembourg = "lu"
    case czechia = "cz"
    case slovakia = "sk"
    case lithuania = "lt"
    case france = "fr"
    case austria = "at"
    case hungary = "hu"
    case romania = "ro"
    case portugal = "pt"
    case spain = "es"
    case italy = "it"
    case slovenia = "si"
    case croatia = "hr"
    case bulgaria = "bg"
    case malta = "mt"
    case greece = "el"
    case cyprus = "cy"

    var id: String { rawValue }

    /// Two-letter code shown on the tile.
    var code: String {
        switch self {
        case .finland: return "FI"
        case .denmark: return "DK"
        case .sweden: return "SE"
        case .estonia: return "EE"
        case .ireland: return "IE"
        case .netherlands: return "NL"
        case .germany: return "DE"
        case .poland: return "PL"
        case .latvia: return "LV"
        case .belgium: return "BE"
        case .luxembourg: return "LU"
        case .czechia: return "CZ"
        case .slovakia: return "SK"
        case .lithuania: return "LT"
        case .france: return "FR"
        case .austria: return "AT"
        case .hungary: return "HU"
        case .romania: return "RO"
        case .portugal: return "PT"
        case .spain: return "ES"
        case .italy: return "IT"
        case .slovenia: return "SI"
        case .croatia: return "HR"
        case .bulgaria: return "BG"
        case .malta: return "MT"
        case .greece: return "GR"
        case .cyprus: return "CY"
        }
    }

    func label(pt: Bool) -> String {
        switch self {
        case .finland: return pt ? "Finlândia" : "Finland"
        case .denmark: return pt ? "Dinamarca" : "Denmark"
        case .sweden: return pt ? "Suécia" : "Sweden"
        case .estonia: return pt ? "Estónia" : "Estonia"
        case .ireland: return pt ? "Irlanda" : "Ireland"
        case .netherlands: return pt ? "Países Baixos" : "Netherlands"
        case .germany: return pt ? "Alemanha" : "Germany"
        case .poland: return pt ? "Polónia" : "Poland"
        case .latvia: return pt ? "Letónia" : "Latvia"
        case .belgium: return pt ? "Bélgica" : "Belgium"
        case .luxembourg: return pt ? "Luxemburgo" : "Luxembourg"
        case .czechia: return pt ? "Chéquia" : "Czechia"
        case .slovakia: return pt ? "Eslováquia" : "Slovakia"
        case .lithuania: return pt ? "Lituânia" : "Lithuania"
        case .france: return pt ? "França" : "France"
        case .austria: return pt ? "Áustria" : "Austria"
        case .hungary: return pt ? "Hungria" : "Hungary"
        case .romania: return pt ? "Roménia" : "Romania"
        case .portugal: return "Portugal"
        case .spain: return pt ? "Espanha" : "Spain"
        case .italy: return pt ? "Itália" : "Italy"
        case .slovenia: return pt ? "Eslovénia" : "Slovenia"
        case .croatia: return pt ? "Croácia" : "Croatia"
        case .bulgaria: return pt ? "Bulgária" : "Bulgaria"
        case .malta: return "Malta"
        case .greece: return pt ? "Grécia" : "Greece"
        case .cyprus: return pt ? "Chipre" : "Cyprus"
        }
    }

    /// Position on the tile grid, column then row. A tile cartogram rather than a
    /// real map: on a phone a true projection makes France and Sweden shout while
    /// Malta and Luxembourg become untappable specks, and every country here
    /// deserves the same weight because each one is a single number.
    var tile: (col: Int, row: Int) {
        switch self {
        case .finland: return (5, 0)
        case .denmark: return (3, 1)
        case .sweden: return (4, 1)
        case .estonia: return (5, 1)
        case .ireland: return (0, 2)
        case .netherlands: return (2, 2)
        case .germany: return (3, 2)
        case .poland: return (4, 2)
        case .latvia: return (5, 2)
        case .belgium: return (1, 3)
        case .luxembourg: return (2, 3)
        case .czechia: return (3, 3)
        case .slovakia: return (4, 3)
        case .lithuania: return (5, 3)
        case .france: return (1, 4)
        case .austria: return (3, 4)
        case .hungary: return (4, 4)
        case .romania: return (5, 4)
        case .portugal: return (0, 5)
        case .spain: return (1, 5)
        case .italy: return (2, 5)
        case .slovenia: return (3, 5)
        case .croatia: return (4, 5)
        case .bulgaria: return (5, 5)
        case .malta: return (2, 6)
        case .greece: return (4, 6)
        case .cyprus: return (5, 6)
        }
    }

    static let gridColumns = 6
    static let gridRows = 7
}

extension Sector {
    /// The NACE section this sector is compared as, or nil when there is no
    /// European comparison to make. Agriculture is outside the survey. Public
    /// administration has no Portuguese figure, so there is no denominator.
    var euroSection: EuroSection? {
        switch self {
        case .agriculture: return nil
        case .extractive: return .sB
        case .manufacturing: return .sC
        case .energy: return .sD
        case .water: return .sE
        case .construction: return .sF
        case .autoTrade: return .sG
        case .wholesale: return .sG
        case .retail: return .sG
        case .transport: return .sH
        case .hospitality: return .sI
        case .media: return .sJ
        case .telecom: return .sJ
        case .it: return .sJ
        case .finance: return .sK
        case .realEstate: return .sL
        case .consulting: return .sM
        case .admin: return .sN
        case .publicAdmin: return nil
        case .education: return .sP
        case .health: return .sQ
        case .socialWork: return .sQ
        case .arts: return .sR
        case .otherServices: return .sS
        }
    }
}
