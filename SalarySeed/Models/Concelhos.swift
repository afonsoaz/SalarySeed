import Foundation

/// v0.9.1: the 278 mainland municipalities, and the crosswalk that turns one of
/// them into both a district and a NUTS 2024 region.
///
/// WHY CONCELHO AND NOT DISTRICT. Districts and NUTS regions are different
/// geographies that cross-cut each other, so a district cannot be converted into
/// a NUTS II region without guessing. Six of the eighteen straddle two regions,
/// and the population split is not always lopsided:
///
///     Aveiro    Centro 55.9% / Norte 44.1%
///     Leiria    Centro 62.0% / Oeste e Vale do Tejo 38.0%
///     Viseu     Centro 73.3% / Norte 26.7%
///     Lisboa    Grande Lisboa 90.3% / Oeste e Vale do Tejo 9.7%
///     Setúbal   Península de Setúbal 92.4% / Alentejo 7.6%
///     Guarda    Centro 95.5% / Norte 4.5%
///
/// Picking the dominant region would put roughly two in five Aveiro users in the
/// wrong cell, and would quietly tell someone in Torres Vedras they are in Grande
/// Lisboa, where the average is about 44% higher. The concelho is the atomic unit
/// both geographies are built from, so asking for it derives both exactly and
/// leaves nothing to guess.
///
/// NUTS 2024 (EU Regulation 2023/674), not NUTS 2013. Three things changed and
/// most tables online still show the old coding:
///  - Área Metropolitana de Lisboa split into Grande Lisboa and Península de Setúbal.
///  - Oeste e Vale do Tejo was created from Oeste, Lezíria do Tejo and Médio Tejo.
///  - Sertã and Vila de Rei moved from Médio Tejo to Beira Baixa, which is what
///    makes Castelo Branco district map cleanly to Centro.
///
/// v0.15 ADDED AÇORES AND MADEIRA, and they do not fit the mainland shape.
/// The islands have no districts: the old Angra, Horta, Ponta Delgada and Funchal
/// districts were abolished in 1976 and the GEP district table has 18 rows, all
/// mainland. So `district` became optional rather than being faked, and the
/// picker browses the two regions as their own sections.
///
/// They are here now because TAX made them necessary, not because the comparison
/// data arrived. Both regions apply their own IRS and an islander computed on the
/// Continente tables is told they owe more than they do. The comparison figures
/// are still Continente-only, which the screens say out loud.
///
/// Stable slug ids, persisted in UserDefaults. Never rename one.

/// The 18 mainland districts. Not used for any comparison yet: this is what the
/// v0.9.2 map will be drawn from, and it is derived, never asked for.
enum District: String, CaseIterable, Identifiable {
    case aveiro
    case beja
    case braga
    case braganca
    case casteloBranco
    case coimbra
    case evora
    case faro
    case guarda
    case leiria
    case lisboa
    case portalegre
    case porto
    case santarem
    case setubal
    case vianaCastelo
    case vilaReal
    case viseu

    var id: String { rawValue }

    /// District names are proper nouns, identical in both languages.
    var label: String {
        switch self {
        case .aveiro: return "Aveiro"
        case .beja: return "Beja"
        case .braga: return "Braga"
        case .braganca: return "Bragança"
        case .casteloBranco: return "Castelo Branco"
        case .coimbra: return "Coimbra"
        case .evora: return "Évora"
        case .faro: return "Faro"
        case .guarda: return "Guarda"
        case .leiria: return "Leiria"
        case .lisboa: return "Lisboa"
        case .portalegre: return "Portalegre"
        case .porto: return "Porto"
        case .santarem: return "Santarém"
        case .setubal: return "Setúbal"
        case .vianaCastelo: return "Viana do Castelo"
        case .vilaReal: return "Vila Real"
        case .viseu: return "Viseu"
        }
    }
}

struct Concelho: Identifiable, Hashable {
    let id: String
    let name: String
    /// nil for Açores and Madeira, which have no districts. Everything downstream
    /// already treated the user's district as optional, so nothing had to bend to
    /// accommodate this.
    let district: District?
    /// NUTS 2024 NUTS II. This is what every existing cohort comparison keys on.
    let region: PTRegion
}

private func c(_ id: String, _ name: String, _ d: District, _ r: PTRegion) -> Concelho {
    Concelho(id: id, name: name, district: d, region: r)
}

/// An island concelho: no district, region stated directly.
private func i(_ id: String, _ name: String, _ r: PTRegion) -> Concelho {
    Concelho(id: id, name: name, district: nil, region: r)
}

/// How the picker offers the country: eighteen mainland districts, then the two
/// autonomous regions as sections of their own.
enum ConcelhoGroup: Identifiable, Hashable {
    case district(District)
    case island(PTRegion)

    var id: String {
        switch self {
        case .district(let d): return "d_" + d.rawValue
        case .island(let r): return "i_" + r.rawValue
        }
    }
    var label: String {
        switch self {
        case .district(let d): return d.label
        case .island(let r): return r.label
        }
    }
}

enum ConcelhoCatalog {

    private static let aveiro: [Concelho] = [
        c("agueda", "Águeda", .aveiro, .centro),
        c("albergaria_a_velha", "Albergaria-a-Velha", .aveiro, .centro),
        c("anadia", "Anadia", .aveiro, .centro),
        c("arouca", "Arouca", .aveiro, .norte),
        c("aveiro", "Aveiro", .aveiro, .centro),
        c("castelo_de_paiva", "Castelo de Paiva", .aveiro, .norte),
        c("espinho", "Espinho", .aveiro, .norte),
        c("estarreja", "Estarreja", .aveiro, .centro),
        c("ilhavo", "Ílhavo", .aveiro, .centro),
        c("mealhada", "Mealhada", .aveiro, .centro),
        c("murtosa", "Murtosa", .aveiro, .centro),
        c("oliveira_de_azemeis", "Oliveira de Azeméis", .aveiro, .norte),
        c("oliveira_do_bairro", "Oliveira do Bairro", .aveiro, .centro),
        c("ovar", "Ovar", .aveiro, .centro),
        c("santa_maria_da_feira", "Santa Maria da Feira", .aveiro, .norte),
        c("sao_joao_da_madeira", "São João da Madeira", .aveiro, .norte),
        c("sever_do_vouga", "Sever do Vouga", .aveiro, .centro),
        c("vagos", "Vagos", .aveiro, .centro),
        c("vale_de_cambra", "Vale de Cambra", .aveiro, .norte),
    ]

    private static let beja: [Concelho] = [
        c("aljustrel", "Aljustrel", .beja, .alentejo),
        c("almodovar", "Almodôvar", .beja, .alentejo),
        c("alvito", "Alvito", .beja, .alentejo),
        c("barrancos", "Barrancos", .beja, .alentejo),
        c("beja", "Beja", .beja, .alentejo),
        c("castro_verde", "Castro Verde", .beja, .alentejo),
        c("cuba", "Cuba", .beja, .alentejo),
        c("ferreira_do_alentejo", "Ferreira do Alentejo", .beja, .alentejo),
        c("mertola", "Mértola", .beja, .alentejo),
        c("moura", "Moura", .beja, .alentejo),
        c("odemira", "Odemira", .beja, .alentejo),
        c("ourique", "Ourique", .beja, .alentejo),
        c("serpa", "Serpa", .beja, .alentejo),
        c("vidigueira", "Vidigueira", .beja, .alentejo),
    ]

    private static let braga: [Concelho] = [
        c("amares", "Amares", .braga, .norte),
        c("barcelos", "Barcelos", .braga, .norte),
        c("braga", "Braga", .braga, .norte),
        c("cabeceiras_de_basto", "Cabeceiras de Basto", .braga, .norte),
        c("celorico_de_basto", "Celorico de Basto", .braga, .norte),
        c("esposende", "Esposende", .braga, .norte),
        c("fafe", "Fafe", .braga, .norte),
        c("guimaraes", "Guimarães", .braga, .norte),
        c("povoa_de_lanhoso", "Póvoa de Lanhoso", .braga, .norte),
        c("terras_de_bouro", "Terras de Bouro", .braga, .norte),
        c("vieira_do_minho", "Vieira do Minho", .braga, .norte),
        c("vila_nova_de_famalicao", "Vila Nova de Famalicão", .braga, .norte),
        c("vila_verde", "Vila Verde", .braga, .norte),
        c("vizela", "Vizela", .braga, .norte),
    ]

    private static let braganca: [Concelho] = [
        c("alfandega_da_fe", "Alfândega da Fé", .braganca, .norte),
        c("braganca", "Bragança", .braganca, .norte),
        c("carrazeda_de_ansiaes", "Carrazeda de Ansiães", .braganca, .norte),
        c("freixo_de_espada_a_cinta", "Freixo de Espada à Cinta", .braganca, .norte),
        c("macedo_de_cavaleiros", "Macedo de Cavaleiros", .braganca, .norte),
        c("miranda_do_douro", "Miranda do Douro", .braganca, .norte),
        c("mirandela", "Mirandela", .braganca, .norte),
        c("mogadouro", "Mogadouro", .braganca, .norte),
        c("torre_de_moncorvo", "Torre de Moncorvo", .braganca, .norte),
        c("vila_flor", "Vila Flor", .braganca, .norte),
        c("vimioso", "Vimioso", .braganca, .norte),
        c("vinhais", "Vinhais", .braganca, .norte),
    ]

    private static let casteloBranco: [Concelho] = [
        c("belmonte", "Belmonte", .casteloBranco, .centro),
        c("castelo_branco", "Castelo Branco", .casteloBranco, .centro),
        c("covilha", "Covilhã", .casteloBranco, .centro),
        c("fundao", "Fundão", .casteloBranco, .centro),
        c("idanha_a_nova", "Idanha-a-Nova", .casteloBranco, .centro),
        c("oleiros", "Oleiros", .casteloBranco, .centro),
        c("penamacor", "Penamacor", .casteloBranco, .centro),
        c("proenca_a_nova", "Proença-a-Nova", .casteloBranco, .centro),
        c("serta", "Sertã", .casteloBranco, .centro),
        c("vila_de_rei", "Vila de Rei", .casteloBranco, .centro),
        c("vila_velha_de_rodao", "Vila Velha de Ródão", .casteloBranco, .centro),
    ]

    private static let coimbra: [Concelho] = [
        c("arganil", "Arganil", .coimbra, .centro),
        c("cantanhede", "Cantanhede", .coimbra, .centro),
        c("coimbra", "Coimbra", .coimbra, .centro),
        c("condeixa_a_nova", "Condeixa-a-Nova", .coimbra, .centro),
        c("figueira_da_foz", "Figueira da Foz", .coimbra, .centro),
        c("gois", "Góis", .coimbra, .centro),
        c("lousa", "Lousã", .coimbra, .centro),
        c("mira", "Mira", .coimbra, .centro),
        c("miranda_do_corvo", "Miranda do Corvo", .coimbra, .centro),
        c("montemor_o_velho", "Montemor-o-Velho", .coimbra, .centro),
        c("oliveira_do_hospital", "Oliveira do Hospital", .coimbra, .centro),
        c("pampilhosa_da_serra", "Pampilhosa da Serra", .coimbra, .centro),
        c("penacova", "Penacova", .coimbra, .centro),
        c("penela", "Penela", .coimbra, .centro),
        c("soure", "Soure", .coimbra, .centro),
        c("tabua", "Tábua", .coimbra, .centro),
        c("vila_nova_de_poiares", "Vila Nova de Poiares", .coimbra, .centro),
    ]

    private static let evora: [Concelho] = [
        c("alandroal", "Alandroal", .evora, .alentejo),
        c("arraiolos", "Arraiolos", .evora, .alentejo),
        c("borba", "Borba", .evora, .alentejo),
        c("estremoz", "Estremoz", .evora, .alentejo),
        c("evora", "Évora", .evora, .alentejo),
        c("montemor_o_novo", "Montemor-o-Novo", .evora, .alentejo),
        c("mora", "Mora", .evora, .alentejo),
        c("mourao", "Mourão", .evora, .alentejo),
        c("portel", "Portel", .evora, .alentejo),
        c("redondo", "Redondo", .evora, .alentejo),
        c("reguengos_de_monsaraz", "Reguengos de Monsaraz", .evora, .alentejo),
        c("vendas_novas", "Vendas Novas", .evora, .alentejo),
        c("viana_do_alentejo", "Viana do Alentejo", .evora, .alentejo),
        c("vila_vicosa", "Vila Viçosa", .evora, .alentejo),
    ]

    private static let faro: [Concelho] = [
        c("albufeira", "Albufeira", .faro, .algarve),
        c("alcoutim", "Alcoutim", .faro, .algarve),
        c("aljezur", "Aljezur", .faro, .algarve),
        c("castro_marim", "Castro Marim", .faro, .algarve),
        c("faro", "Faro", .faro, .algarve),
        c("lagoa", "Lagoa", .faro, .algarve),
        c("lagos", "Lagos", .faro, .algarve),
        c("loule", "Loulé", .faro, .algarve),
        c("monchique", "Monchique", .faro, .algarve),
        c("olhao", "Olhão", .faro, .algarve),
        c("portimao", "Portimão", .faro, .algarve),
        c("sao_bras_de_alportel", "São Brás de Alportel", .faro, .algarve),
        c("silves", "Silves", .faro, .algarve),
        c("tavira", "Tavira", .faro, .algarve),
        c("vila_do_bispo", "Vila do Bispo", .faro, .algarve),
        c("vila_real_de_santo_antonio", "Vila Real de Santo António", .faro, .algarve),
    ]

    private static let guarda: [Concelho] = [
        c("aguiar_da_beira", "Aguiar da Beira", .guarda, .centro),
        c("almeida", "Almeida", .guarda, .centro),
        c("celorico_da_beira", "Celorico da Beira", .guarda, .centro),
        c("figueira_de_castelo_rodrigo", "Figueira de Castelo Rodrigo", .guarda, .centro),
        c("fornos_de_algodres", "Fornos de Algodres", .guarda, .centro),
        c("gouveia", "Gouveia", .guarda, .centro),
        c("guarda", "Guarda", .guarda, .centro),
        c("manteigas", "Manteigas", .guarda, .centro),
        c("meda", "Mêda", .guarda, .centro),
        c("pinhel", "Pinhel", .guarda, .centro),
        c("sabugal", "Sabugal", .guarda, .centro),
        c("seia", "Seia", .guarda, .centro),
        c("trancoso", "Trancoso", .guarda, .centro),
        c("vila_nova_de_foz_coa", "Vila Nova de Foz Côa", .guarda, .norte),
    ]

    private static let leiria: [Concelho] = [
        c("alcobaca", "Alcobaça", .leiria, .oesteValeTejo),
        c("alvaiazere", "Alvaiázere", .leiria, .centro),
        c("ansiao", "Ansião", .leiria, .centro),
        c("batalha", "Batalha", .leiria, .centro),
        c("bombarral", "Bombarral", .leiria, .oesteValeTejo),
        c("caldas_da_rainha", "Caldas da Rainha", .leiria, .oesteValeTejo),
        c("castanheira_de_pera", "Castanheira de Pera", .leiria, .centro),
        c("figueiro_dos_vinhos", "Figueiró dos Vinhos", .leiria, .centro),
        c("leiria", "Leiria", .leiria, .centro),
        c("marinha_grande", "Marinha Grande", .leiria, .centro),
        c("nazare", "Nazaré", .leiria, .oesteValeTejo),
        c("obidos", "Óbidos", .leiria, .oesteValeTejo),
        c("pedrogao_grande", "Pedrógão Grande", .leiria, .centro),
        c("peniche", "Peniche", .leiria, .oesteValeTejo),
        c("pombal", "Pombal", .leiria, .centro),
        c("porto_de_mos", "Porto de Mós", .leiria, .centro),
    ]

    private static let lisboa: [Concelho] = [
        c("alenquer", "Alenquer", .lisboa, .oesteValeTejo),
        c("amadora", "Amadora", .lisboa, .grandeLisboa),
        c("arruda_dos_vinhos", "Arruda dos Vinhos", .lisboa, .oesteValeTejo),
        c("azambuja", "Azambuja", .lisboa, .oesteValeTejo),
        c("cadaval", "Cadaval", .lisboa, .oesteValeTejo),
        c("cascais", "Cascais", .lisboa, .grandeLisboa),
        c("lisboa", "Lisboa", .lisboa, .grandeLisboa),
        c("loures", "Loures", .lisboa, .grandeLisboa),
        c("lourinha", "Lourinhã", .lisboa, .oesteValeTejo),
        c("mafra", "Mafra", .lisboa, .grandeLisboa),
        c("odivelas", "Odivelas", .lisboa, .grandeLisboa),
        c("oeiras", "Oeiras", .lisboa, .grandeLisboa),
        c("sintra", "Sintra", .lisboa, .grandeLisboa),
        c("sobral_de_monte_agraco", "Sobral de Monte Agraço", .lisboa, .oesteValeTejo),
        c("torres_vedras", "Torres Vedras", .lisboa, .oesteValeTejo),
        c("vila_franca_de_xira", "Vila Franca de Xira", .lisboa, .grandeLisboa),
    ]

    private static let portalegre: [Concelho] = [
        c("alter_do_chao", "Alter do Chão", .portalegre, .alentejo),
        c("arronches", "Arronches", .portalegre, .alentejo),
        c("avis", "Avis", .portalegre, .alentejo),
        c("campo_maior", "Campo Maior", .portalegre, .alentejo),
        c("castelo_de_vide", "Castelo de Vide", .portalegre, .alentejo),
        c("crato", "Crato", .portalegre, .alentejo),
        c("elvas", "Elvas", .portalegre, .alentejo),
        c("fronteira", "Fronteira", .portalegre, .alentejo),
        c("gaviao", "Gavião", .portalegre, .alentejo),
        c("marvao", "Marvão", .portalegre, .alentejo),
        c("monforte", "Monforte", .portalegre, .alentejo),
        c("nisa", "Nisa", .portalegre, .alentejo),
        c("ponte_de_sor", "Ponte de Sor", .portalegre, .alentejo),
        c("portalegre", "Portalegre", .portalegre, .alentejo),
        c("sousel", "Sousel", .portalegre, .alentejo),
    ]

    private static let porto: [Concelho] = [
        c("amarante", "Amarante", .porto, .norte),
        c("baiao", "Baião", .porto, .norte),
        c("felgueiras", "Felgueiras", .porto, .norte),
        c("gondomar", "Gondomar", .porto, .norte),
        c("lousada", "Lousada", .porto, .norte),
        c("maia", "Maia", .porto, .norte),
        c("marco_de_canaveses", "Marco de Canaveses", .porto, .norte),
        c("matosinhos", "Matosinhos", .porto, .norte),
        c("pacos_de_ferreira", "Paços de Ferreira", .porto, .norte),
        c("paredes", "Paredes", .porto, .norte),
        c("penafiel", "Penafiel", .porto, .norte),
        c("porto", "Porto", .porto, .norte),
        c("povoa_de_varzim", "Póvoa de Varzim", .porto, .norte),
        c("santo_tirso", "Santo Tirso", .porto, .norte),
        c("trofa", "Trofa", .porto, .norte),
        c("valongo", "Valongo", .porto, .norte),
        c("vila_do_conde", "Vila do Conde", .porto, .norte),
        c("vila_nova_de_gaia", "Vila Nova de Gaia", .porto, .norte),
    ]

    private static let santarem: [Concelho] = [
        c("abrantes", "Abrantes", .santarem, .oesteValeTejo),
        c("alcanena", "Alcanena", .santarem, .oesteValeTejo),
        c("almeirim", "Almeirim", .santarem, .oesteValeTejo),
        c("alpiarca", "Alpiarça", .santarem, .oesteValeTejo),
        c("benavente", "Benavente", .santarem, .oesteValeTejo),
        c("cartaxo", "Cartaxo", .santarem, .oesteValeTejo),
        c("chamusca", "Chamusca", .santarem, .oesteValeTejo),
        c("constancia", "Constância", .santarem, .oesteValeTejo),
        c("coruche", "Coruche", .santarem, .oesteValeTejo),
        c("entroncamento", "Entroncamento", .santarem, .oesteValeTejo),
        c("ferreira_do_zezere", "Ferreira do Zêzere", .santarem, .oesteValeTejo),
        c("golega", "Golegã", .santarem, .oesteValeTejo),
        c("macao", "Mação", .santarem, .oesteValeTejo),
        c("ourem", "Ourém", .santarem, .oesteValeTejo),
        c("rio_maior", "Rio Maior", .santarem, .oesteValeTejo),
        c("salvaterra_de_magos", "Salvaterra de Magos", .santarem, .oesteValeTejo),
        c("santarem", "Santarém", .santarem, .oesteValeTejo),
        c("sardoal", "Sardoal", .santarem, .oesteValeTejo),
        c("tomar", "Tomar", .santarem, .oesteValeTejo),
        c("torres_novas", "Torres Novas", .santarem, .oesteValeTejo),
        c("vila_nova_da_barquinha", "Vila Nova da Barquinha", .santarem, .oesteValeTejo),
    ]

    private static let setubal: [Concelho] = [
        c("alcacer_do_sal", "Alcácer do Sal", .setubal, .alentejo),
        c("alcochete", "Alcochete", .setubal, .penSetubal),
        c("almada", "Almada", .setubal, .penSetubal),
        c("barreiro", "Barreiro", .setubal, .penSetubal),
        c("grandola", "Grândola", .setubal, .alentejo),
        c("moita", "Moita", .setubal, .penSetubal),
        c("montijo", "Montijo", .setubal, .penSetubal),
        c("palmela", "Palmela", .setubal, .penSetubal),
        c("santiago_do_cacem", "Santiago do Cacém", .setubal, .alentejo),
        c("seixal", "Seixal", .setubal, .penSetubal),
        c("sesimbra", "Sesimbra", .setubal, .penSetubal),
        c("setubal", "Setúbal", .setubal, .penSetubal),
        c("sines", "Sines", .setubal, .alentejo),
    ]

    private static let vianaCastelo: [Concelho] = [
        c("arcos_de_valdevez", "Arcos de Valdevez", .vianaCastelo, .norte),
        c("caminha", "Caminha", .vianaCastelo, .norte),
        c("melgaco", "Melgaço", .vianaCastelo, .norte),
        c("moncao", "Monção", .vianaCastelo, .norte),
        c("paredes_de_coura", "Paredes de Coura", .vianaCastelo, .norte),
        c("ponte_da_barca", "Ponte da Barca", .vianaCastelo, .norte),
        c("ponte_de_lima", "Ponte de Lima", .vianaCastelo, .norte),
        c("valenca", "Valença", .vianaCastelo, .norte),
        c("viana_do_castelo", "Viana do Castelo", .vianaCastelo, .norte),
        c("vila_nova_de_cerveira", "Vila Nova de Cerveira", .vianaCastelo, .norte),
    ]

    private static let vilaReal: [Concelho] = [
        c("alijo", "Alijó", .vilaReal, .norte),
        c("boticas", "Boticas", .vilaReal, .norte),
        c("chaves", "Chaves", .vilaReal, .norte),
        c("mesao_frio", "Mesão Frio", .vilaReal, .norte),
        c("mondim_de_basto", "Mondim de Basto", .vilaReal, .norte),
        c("montalegre", "Montalegre", .vilaReal, .norte),
        c("murca", "Murça", .vilaReal, .norte),
        c("peso_da_regua", "Peso da Régua", .vilaReal, .norte),
        c("ribeira_de_pena", "Ribeira de Pena", .vilaReal, .norte),
        c("sabrosa", "Sabrosa", .vilaReal, .norte),
        c("santa_marta_de_penaguiao", "Santa Marta de Penaguião", .vilaReal, .norte),
        c("valpacos", "Valpaços", .vilaReal, .norte),
        c("vila_pouca_de_aguiar", "Vila Pouca de Aguiar", .vilaReal, .norte),
        c("vila_real", "Vila Real", .vilaReal, .norte),
    ]

    private static let viseu: [Concelho] = [
        c("armamar", "Armamar", .viseu, .norte),
        c("carregal_do_sal", "Carregal do Sal", .viseu, .centro),
        c("castro_daire", "Castro Daire", .viseu, .centro),
        c("cinfaes", "Cinfães", .viseu, .norte),
        c("lamego", "Lamego", .viseu, .norte),
        c("mangualde", "Mangualde", .viseu, .centro),
        c("moimenta_da_beira", "Moimenta da Beira", .viseu, .norte),
        c("mortagua", "Mortágua", .viseu, .centro),
        c("nelas", "Nelas", .viseu, .centro),
        c("oliveira_de_frades", "Oliveira de Frades", .viseu, .centro),
        c("penalva_do_castelo", "Penalva do Castelo", .viseu, .centro),
        c("penedono", "Penedono", .viseu, .norte),
        c("resende", "Resende", .viseu, .norte),
        c("santa_comba_dao", "Santa Comba Dão", .viseu, .centro),
        c("sao_joao_da_pesqueira", "São João da Pesqueira", .viseu, .norte),
        c("sao_pedro_do_sul", "São Pedro do Sul", .viseu, .centro),
        c("satao", "Sátão", .viseu, .centro),
        c("sernancelhe", "Sernancelhe", .viseu, .norte),
        c("tabuaco", "Tabuaço", .viseu, .norte),
        c("tarouca", "Tarouca", .viseu, .norte),
        c("tondela", "Tondela", .viseu, .centro),
        c("vila_nova_de_paiva", "Vila Nova de Paiva", .viseu, .centro),
        c("viseu", "Viseu", .viseu, .centro),
        c("vouzela", "Vouzela", .viseu, .centro),
    ]

    /// 278 mainland municipalities. Split per district so the Swift type
    /// checker stays linear.

    /// The 19 concelhos of the Região Autónoma dos Açores, across the nine islands.
    private static let acores: [Concelho] = [
        // Santa Maria
        i("vila_do_porto", "Vila do Porto", .acores),
        // São Miguel
        i("lagoa_acores", "Lagoa (Açores)", .acores),
        i("nordeste", "Nordeste", .acores),
        i("ponta_delgada", "Ponta Delgada", .acores),
        i("povoacao", "Povoação", .acores),
        i("ribeira_grande", "Ribeira Grande", .acores),
        i("vila_franca_do_campo", "Vila Franca do Campo", .acores),
        // Terceira
        i("angra_do_heroismo", "Angra do Heroísmo", .acores),
        i("praia_da_vitoria", "Praia da Vitória", .acores),
        // Graciosa
        i("santa_cruz_da_graciosa", "Santa Cruz da Graciosa", .acores),
        // São Jorge
        i("calheta_sao_jorge", "Calheta (São Jorge)", .acores),
        i("velas", "Velas", .acores),
        // Pico
        i("lajes_do_pico", "Lajes do Pico", .acores),
        i("madalena", "Madalena", .acores),
        i("sao_roque_do_pico", "São Roque do Pico", .acores),
        // Faial
        i("horta", "Horta", .acores),
        // Flores
        i("lajes_das_flores", "Lajes das Flores", .acores),
        i("santa_cruz_das_flores", "Santa Cruz das Flores", .acores),
        // Corvo
        i("corvo", "Corvo", .acores),
    ]

    /// The 11 concelhos of the Região Autónoma da Madeira, including Porto Santo.
    private static let madeira: [Concelho] = [
        i("calheta_madeira", "Calheta (Madeira)", .madeira),
        i("camara_de_lobos", "Câmara de Lobos", .madeira),
        i("funchal", "Funchal", .madeira),
        i("machico", "Machico", .madeira),
        i("ponta_do_sol", "Ponta do Sol", .madeira),
        i("porto_moniz", "Porto Moniz", .madeira),
        i("porto_santo", "Porto Santo", .madeira),
        i("ribeira_brava", "Ribeira Brava", .madeira),
        i("santa_cruz", "Santa Cruz", .madeira),
        i("santana", "Santana", .madeira),
        i("sao_vicente", "São Vicente", .madeira),
    ]

    static let all: [Concelho] =
        aveiro + beja + braga + braganca + casteloBranco
        + coimbra + evora + faro + guarda + leiria
        + lisboa + portalegre + porto + santarem + setubal
        + vianaCastelo + vilaReal + viseu
        + acores + madeira

    private static let byID: [String: Concelho] = Dictionary(
        all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    static func concelho(_ id: String?) -> Concelho? {
        guard let id else { return nil }
        return byID[id]
    }

    static func concelhos(in district: District) -> [Concelho] {
        all.filter { $0.district == district }
    }

    /// Eighteen districts and then the two regions, in the order the picker shows
    /// them. Built from the data rather than hard-coded, so a region with no
    /// concelhos could never appear as an empty section.
    static let groups: [ConcelhoGroup] =
        District.allCases.map { ConcelhoGroup.district($0) }
        + [PTRegion.acores, .madeira]
            .filter { r in all.contains { $0.district == nil && $0.region == r } }
            .map { ConcelhoGroup.island($0) }

    static func concelhos(in group: ConcelhoGroup) -> [Concelho] {
        switch group {
        case .district(let d): return concelhos(in: d)
        case .island(let r): return all.filter { $0.district == nil && $0.region == r }
        }
    }

    /// Ranked, diacritic and case insensitive. Typing a district name finds every
    /// municipality in it, so "setubal" surfaces Almada and Sines too.
    ///
    /// v0.15: island concelhos have no district, so the REGION plays that part.
    /// Typing "madeira" surfaces Funchal for exactly the reason typing "setubal"
    /// surfaces Almada, and the one search behaviour the doc comment promises
    /// stays true for all 308 rather than only the mainland 278.
    static func search(_ query: String) -> [Concelho] {
        let q = SearchText.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !q.isEmpty else { return [] }
        var scored: [(Concelho, Int)] = []
        for item in all {
            let name = SearchText.fold(item.name)
            let area = SearchText.fold(item.district?.label ?? item.region.label)
            var score = -1
            if name.hasPrefix(q) { score = 0 }
            else if SearchText.hasWordPrefix(name, q) { score = 1 }
            else if name.contains(q) { score = 2 }
            else if SearchText.hasWordPrefix(area, q) { score = 3 }
            if score >= 0 { scored.append((item, score)) }
        }
        return scored
            .sorted { a, b in a.1 == b.1 ? a.0.name < b.0.name : a.1 < b.1 }
            .map { $0.0 }
    }
}
