import Foundation

/// v0.9: the curated job-title catalogue.
///
/// WHY THIS EXISTS. GEP's open workbook only publishes occupation at 2-digit CPP
/// (~43 sub-major groups: "Professores", "Pessoal de apoio a clientes"). That is
/// too coarse to be worth showing, which is why v0.8.3 dropped occupation and
/// went with sector instead. This catalogue is deliberately NOT backed by a
/// published table: nothing in the app compares against it yet. It exists so the
/// signal is being banked from day one, because a job title cannot be collected
/// retroactively. The moment there are enough real answers in a cell, this is the
/// axis that makes the comparison worth more than anything GEP publishes.
///
/// DESIGN RULES.
/// - Stable string IDs, persisted in UserDefaults. Never rename an id; add a new
///   one and leave the old one resolvable.
/// - Curated list, not free text. "consultor IT" / "IT consultant" / "consultora
///   informática" are one cell, not three, and free text would fragment them.
/// - `family` is for browsing only. `cppMajor` is the CPP/2010 grande grupo
///   (0 to 9), which is safe to assert; 4-digit CPP codes are deliberately absent
///   because guessing them wrong would be worse than not having them. The mapping
///   to 4-digit happens when GEP microdata or a custom tabulation is licensed.
/// - Search is diacritic and case insensitive, and matches synonyms too, so
///   "programador" finds the software developer entry.

struct JobTitle: Identifiable, Hashable {
    let id: String
    let family: JobFamily
    /// CPP/2010 grande grupo, 0 to 9.
    let cppMajor: Int
    let pt: String
    let en: String
    /// Extra search terms (informal names, English/Portuguese synonyms, acronyms).
    let alt: String

    func label(pt isPT: Bool) -> String { isPT ? pt : en }
}

enum JobFamily: String, CaseIterable, Identifiable {
    case management, it, engineering, health, education, business, science
    case creative, technicians, admin, sales, services, hospitality
    case transport, construction, industry, agriculture, publicSafety, other

    var id: String { rawValue }

    func label(pt: Bool) -> String {
        switch self {
        case .management:   return pt ? "Direção e gestão" : "Management"
        case .it:           return pt ? "Informática e dados" : "IT & data"
        case .engineering:  return pt ? "Engenharia e arquitetura" : "Engineering & architecture"
        case .health:       return pt ? "Saúde" : "Health"
        case .education:    return pt ? "Ensino e formação" : "Education & training"
        case .business:     return pt ? "Finanças, jurídico e RH" : "Finance, legal & HR"
        case .science:      return pt ? "Ciências e investigação" : "Science & research"
        case .creative:     return pt ? "Criativos e media" : "Creative & media"
        case .technicians:  return pt ? "Técnicos" : "Technicians"
        case .admin:        return pt ? "Administrativo" : "Administrative"
        case .sales:        return pt ? "Comércio e vendas" : "Retail & sales"
        case .services:     return pt ? "Serviços pessoais" : "Personal services"
        case .hospitality:  return pt ? "Hotelaria e restauração" : "Hospitality & food"
        case .transport:    return pt ? "Transportes e logística" : "Transport & logistics"
        case .construction: return pt ? "Construção" : "Construction"
        case .industry:     return pt ? "Indústria e produção" : "Industry & production"
        case .agriculture:  return pt ? "Agricultura, pescas e floresta" : "Agriculture, fishing & forestry"
        case .publicSafety: return pt ? "Forças armadas e segurança" : "Armed forces & security"
        case .other:        return pt ? "Outras" : "Other"
        }
    }

    var icon: String {
        switch self {
        case .management:   return "briefcase"
        case .it:           return "laptopcomputer"
        case .engineering:  return "compass.drawing"
        case .health:       return "cross.case"
        case .education:    return "graduationcap"
        case .business:     return "chart.line.uptrend.xyaxis"
        case .science:      return "atom"
        case .creative:     return "paintbrush"
        case .technicians:  return "wrench.and.screwdriver"
        case .admin:        return "tray.full"
        case .sales:        return "cart"
        case .services:     return "hands.sparkles"
        case .hospitality:  return "fork.knife"
        case .transport:    return "truck.box"
        case .construction: return "hammer"
        case .industry:     return "gearshape.2"
        case .agriculture:  return "leaf"
        case .publicSafety: return "shield"
        case .other:        return "ellipsis.circle"
        }
    }
}

/// Small builder so the literals below stay readable and the Swift type checker
/// stays linear (the arrays are split per family for the same reason).
private func j(_ id: String, _ f: JobFamily, _ g: Int, _ pt: String, _ en: String, _ alt: String = "") -> JobTitle {
    JobTitle(id: id, family: f, cppMajor: g, pt: pt, en: en, alt: alt)
}

enum JobTitleCatalog {

    // MARK: Families

    private static let management: [JobTitle] = [
        j("ceo", .management, 1, "Diretor-geral / CEO", "CEO / Managing director", "administrador ceo gestor topo"),
        j("dir_financeiro", .management, 1, "Diretor financeiro", "Finance director (CFO)", "cfo financas"),
        j("dir_rh", .management, 1, "Diretor de recursos humanos", "HR director", "chro pessoas"),
        j("dir_comercial", .management, 1, "Diretor comercial", "Sales director", "vendas cso"),
        j("dir_marketing", .management, 1, "Diretor de marketing", "Marketing director", "cmo"),
        j("dir_operacoes", .management, 1, "Diretor de operações", "Operations director", "coo"),
        j("dir_ti", .management, 1, "Diretor de sistemas de informação", "IT director (CIO/CTO)", "cto cio informatica"),
        j("dir_producao", .management, 1, "Diretor de produção", "Production director", "fabrica industrial"),
        j("dir_logistica", .management, 1, "Diretor de logística", "Logistics director", "supply chain cadeia"),
        j("gestor_projeto", .management, 1, "Gestor de projeto", "Project manager", "pm project manager"),
        j("gestor_produto", .management, 1, "Gestor de produto", "Product manager", "product owner po"),
        j("gerente_loja", .management, 1, "Gerente de loja", "Store manager", "encarregado loja retalho"),
        j("gerente_restaurante", .management, 1, "Gerente de restaurante", "Restaurant manager", "encarregado restauracao"),
        j("dir_hotel", .management, 1, "Diretor de hotel", "Hotel manager", "hotelaria"),
        j("dir_escolar", .management, 1, "Diretor escolar", "School principal", "diretor agrupamento escola"),
        j("dir_clinico", .management, 1, "Diretor clínico", "Clinical director", "hospital saude"),
        j("socio_gerente", .management, 1, "Sócio-gerente", "Owner-manager", "empresario dono patrao"),
    ]

    private static let it: [JobTitle] = [
        j("dev_software", .it, 2, "Programador / Engenheiro de software", "Software developer", "developer programador engenheiro informatico coder dev"),
        j("dev_frontend", .it, 2, "Programador front-end", "Front-end developer", "react angular vue web"),
        j("dev_backend", .it, 2, "Programador back-end", "Back-end developer", "java python api servidor"),
        j("dev_mobile", .it, 2, "Programador mobile", "Mobile developer", "ios android swift kotlin"),
        j("eng_dados", .it, 2, "Engenheiro de dados", "Data engineer", "etl pipelines big data"),
        j("cientista_dados", .it, 2, "Cientista de dados", "Data scientist", "machine learning ia ai modelos"),
        j("analista_dados", .it, 2, "Analista de dados / BI", "Data / BI analyst", "business intelligence powerbi sql"),
        j("consultor_it", .it, 2, "Consultor de IT", "IT consultant", "consultoria informatica sap tecnologia"),
        j("arquiteto_software", .it, 2, "Arquiteto de software", "Software architect", "arquitetura sistemas cloud"),
        j("devops", .it, 2, "Engenheiro DevOps / SRE", "DevOps / SRE engineer", "infraestrutura kubernetes cloud aws"),
        j("admin_sistemas", .it, 3, "Administrador de sistemas", "Systems administrator", "sysadmin servidores windows linux"),
        j("admin_redes", .it, 3, "Administrador de redes", "Network administrator", "redes cisco networking"),
        j("admin_bd", .it, 2, "Administrador de bases de dados", "Database administrator", "dba sql oracle"),
        j("ciberseguranca", .it, 2, "Especialista de cibersegurança", "Cybersecurity specialist", "seguranca informatica infosec soc"),
        j("qa_tester", .it, 3, "Engenheiro de testes / QA", "QA engineer", "tester qualidade software testes"),
        j("suporte_it", .it, 3, "Técnico de suporte informático", "IT support technician", "helpdesk suporte tecnico informatica"),
        j("ux_designer", .it, 2, "Designer UX/UI", "UX/UI designer", "ux ui produto interface figma"),
        j("scrum_master", .it, 2, "Scrum master / Agile coach", "Scrum master / Agile coach", "agile agilidade"),
    ]

    private static let engineering: [JobTitle] = [
        j("eng_civil", .engineering, 2, "Engenheiro civil", "Civil engineer", "obras estruturas"),
        j("eng_mecanico", .engineering, 2, "Engenheiro mecânico", "Mechanical engineer", "mecanica"),
        j("eng_eletrotecnico", .engineering, 2, "Engenheiro eletrotécnico", "Electrical engineer", "eletricidade energia"),
        j("eng_eletronico", .engineering, 2, "Engenheiro eletrónico", "Electronics engineer", "eletronica hardware"),
        j("eng_quimico", .engineering, 2, "Engenheiro químico", "Chemical engineer", "quimica processos"),
        j("eng_industrial", .engineering, 2, "Engenheiro industrial / de produção", "Industrial engineer", "producao processos lean"),
        j("eng_ambiente", .engineering, 2, "Engenheiro do ambiente", "Environmental engineer", "ambiente sustentabilidade"),
        j("eng_energia", .engineering, 2, "Engenheiro de energia", "Energy engineer", "renovaveis solar eolica"),
        j("eng_agronomo", .engineering, 2, "Engenheiro agrónomo", "Agricultural engineer", "agronomia agricultura"),
        j("eng_alimentar", .engineering, 2, "Engenheiro alimentar", "Food engineer", "alimentar industria"),
        j("arquiteto", .engineering, 2, "Arquiteto", "Architect", "arquitetura projeto"),
        j("arquiteto_paisagista", .engineering, 2, "Arquiteto paisagista", "Landscape architect", "paisagismo"),
        j("topografo", .engineering, 3, "Topógrafo", "Surveyor", "topografia medicao"),
        j("eng_qualidade", .engineering, 2, "Engenheiro da qualidade", "Quality engineer", "qualidade iso"),
        j("tec_sup_seguranca", .engineering, 2, "Técnico superior de segurança no trabalho", "Health & safety engineer", "shst seguranca trabalho"),
    ]

    private static let health: [JobTitle] = [
        j("medico_familia", .health, 2, "Médico de família", "GP / family doctor", "clinica geral medico centro saude"),
        j("medico_especialista", .health, 2, "Médico especialista (hospitalar)", "Hospital specialist doctor", "medico hospital especialidade"),
        j("medico_interno", .health, 2, "Médico interno", "Resident doctor", "internato medico jovem"),
        j("cirurgiao", .health, 2, "Cirurgião", "Surgeon", "cirurgia bloco"),
        j("enfermeiro", .health, 2, "Enfermeiro", "Nurse", "enfermagem"),
        j("enfermeiro_especialista", .health, 2, "Enfermeiro especialista", "Specialist nurse", "enfermagem especialidade"),
        j("farmaceutico", .health, 2, "Farmacêutico", "Pharmacist", "farmacia"),
        j("tecnico_farmacia", .health, 3, "Técnico de farmácia", "Pharmacy technician", "farmacia balcao"),
        j("dentista", .health, 2, "Médico dentista", "Dentist", "dentaria estomatologia"),
        j("higienista_oral", .health, 3, "Higienista oral", "Dental hygienist", "dentaria higiene"),
        j("fisioterapeuta", .health, 2, "Fisioterapeuta", "Physiotherapist", "fisioterapia reabilitacao"),
        j("terapeuta_fala", .health, 2, "Terapeuta da fala", "Speech therapist", "terapia fala"),
        j("terapeuta_ocupacional", .health, 2, "Terapeuta ocupacional", "Occupational therapist", "terapia ocupacional"),
        j("psicologo", .health, 2, "Psicólogo", "Psychologist", "psicologia clinica"),
        j("nutricionista", .health, 2, "Nutricionista", "Dietitian / nutritionist", "nutricao dietista"),
        j("tecnico_analises", .health, 3, "Técnico de análises clínicas", "Clinical lab technician", "laboratorio analises"),
        j("tecnico_radiologia", .health, 3, "Técnico de radiologia", "Radiographer", "imagiologia raio x"),
        j("veterinario", .health, 2, "Médico veterinário", "Veterinarian", "veterinaria animais"),
        j("aux_saude", .health, 5, "Assistente operacional de saúde", "Healthcare assistant", "auxiliar acao medica hospital"),
        j("tecnico_emergencia", .health, 3, "Técnico de emergência pré-hospitalar", "Paramedic", "inem ambulancia socorro"),
        j("optometrista", .health, 2, "Optometrista", "Optometrist", "optica visao"),
        j("podologista", .health, 3, "Podologista", "Podiatrist", "pes podologia"),
    ]

    private static let education: [JobTitle] = [
        j("prof_universitario", .education, 2, "Professor universitário", "University lecturer / professor", "docente universidade politecnico ensino superior"),
        j("investigador", .education, 2, "Investigador", "Researcher", "investigacao ciencia i&d"),
        j("prof_secundario", .education, 2, "Professor do ensino secundário", "Secondary school teacher", "professor escola liceu 3 ciclo"),
        j("prof_basico", .education, 2, "Professor do ensino básico", "Primary school teacher", "professor primaria 1 ciclo escola"),
        j("educador_infancia", .education, 2, "Educador de infância", "Kindergarten teacher", "infantario creche pre escolar"),
        j("prof_especial", .education, 2, "Professor de educação especial", "Special education teacher", "necessidades educativas"),
        j("formador", .education, 2, "Formador profissional", "Corporate trainer", "formacao cursos"),
        j("prof_linguas", .education, 2, "Professor de línguas", "Language teacher", "ingles frances aleman idiomas"),
        j("prof_musica", .education, 2, "Professor de música", "Music teacher", "conservatorio musica"),
        j("explicador", .education, 2, "Explicador", "Private tutor", "explicacoes centro estudos"),
        j("aux_educativo", .education, 5, "Assistente operacional (escola)", "Teaching assistant", "auxiliar educacao escola"),
    ]

    private static let business: [JobTitle] = [
        j("contabilista", .business, 2, "Contabilista certificado", "Certified accountant", "toc coc contabilidade roc"),
        j("tecnico_contabilidade", .business, 3, "Técnico de contabilidade", "Bookkeeper", "contabilidade escrita"),
        j("auditor", .business, 2, "Auditor", "Auditor", "auditoria big four"),
        j("analista_financeiro", .business, 2, "Analista financeiro", "Financial analyst", "financas analise investimento"),
        j("controller", .business, 2, "Controller de gestão", "Financial controller", "controlo gestao"),
        j("consultor_gestao", .business, 2, "Consultor de gestão", "Management consultant", "consultoria estrategia"),
        j("gestor_cliente_banca", .business, 3, "Gestor de cliente (banca)", "Bank relationship manager", "banco gestor conta"),
        j("bancario", .business, 4, "Bancário / Caixa de banco", "Bank clerk", "banco balcao agencia"),
        j("mediador_seguros", .business, 3, "Mediador de seguros", "Insurance broker", "seguros corretor"),
        j("advogado", .business, 2, "Advogado", "Lawyer", "advocacia direito juridico"),
        j("solicitador", .business, 2, "Solicitador", "Solicitor", "solicitadoria execucao"),
        j("jurista", .business, 2, "Jurista de empresa", "In-house legal counsel", "juridico legal direito"),
        j("notario", .business, 2, "Notário", "Notary", "notariado cartorio"),
        j("tecnico_rh", .business, 3, "Técnico de recursos humanos", "HR officer", "rh recursos humanos pessoal"),
        j("recrutador", .business, 2, "Recrutador", "Recruiter", "recrutamento talent headhunter"),
        j("tecnico_marketing", .business, 2, "Técnico de marketing", "Marketing specialist", "marketing digital seo"),
        j("gestor_redes_sociais", .business, 2, "Gestor de redes sociais", "Social media manager", "social media community"),
        j("comunicacao_pr", .business, 2, "Técnico de comunicação / RP", "Communications / PR officer", "comunicacao relacoes publicas imprensa"),
        j("economista", .business, 2, "Economista", "Economist", "economia"),
        j("tecnico_compras", .business, 3, "Técnico de compras", "Procurement officer", "compras procurement fornecedores"),
        j("analista_negocio", .business, 2, "Analista de negócio", "Business analyst", "business analyst processos"),
    ]

    private static let science: [JobTitle] = [
        j("biologo", .science, 2, "Biólogo", "Biologist", "biologia"),
        j("quimico", .science, 2, "Químico", "Chemist", "quimica"),
        j("fisico", .science, 2, "Físico", "Physicist", "fisica"),
        j("geologo", .science, 2, "Geólogo", "Geologist", "geologia"),
        j("matematico", .science, 2, "Matemático / Estatístico", "Mathematician / statistician", "matematica estatistica atuario"),
        j("tecnico_laboratorio", .science, 3, "Técnico de laboratório", "Laboratory technician", "laboratorio ensaios"),
        j("bolseiro", .science, 2, "Bolseiro de investigação", "Research fellow", "bolsa doutoramento fct"),
        j("arqueologo", .science, 2, "Arqueólogo", "Archaeologist", "arqueologia patrimonio"),
    ]

    private static let creative: [JobTitle] = [
        j("designer_grafico", .creative, 2, "Designer gráfico", "Graphic designer", "design grafico artes"),
        j("designer_produto", .creative, 2, "Designer de produto", "Product designer", "design industrial"),
        j("designer_interiores", .creative, 2, "Designer de interiores", "Interior designer", "decoracao interiores"),
        j("jornalista", .creative, 2, "Jornalista", "Journalist", "jornalismo imprensa reporter"),
        j("editor", .creative, 2, "Editor / Revisor", "Editor / proofreader", "edicao revisao texto"),
        j("tradutor", .creative, 2, "Tradutor / Intérprete", "Translator / interpreter", "traducao interpretacao"),
        j("fotografo", .creative, 3, "Fotógrafo", "Photographer", "fotografia"),
        j("video", .creative, 3, "Operador de câmara / Editor de vídeo", "Camera operator / video editor", "video camara montagem audiovisual"),
        j("tecnico_som", .creative, 3, "Técnico de som", "Sound technician", "som audio"),
        j("musico", .creative, 2, "Músico", "Musician", "musica banda orquestra"),
        j("ator_bailarino", .creative, 2, "Ator / Bailarino", "Actor / dancer", "teatro danca artes performativas"),
        j("copywriter", .creative, 2, "Copywriter / Redator", "Copywriter", "redacao conteudos content"),
        j("animador_3d", .creative, 2, "Animador / Artista 3D", "Animator / 3D artist", "animacao 3d motion vfx"),
    ]

    private static let technicians: [JobTitle] = [
        j("desenhador_cad", .technicians, 3, "Desenhador / Projetista (CAD)", "Draughtsperson (CAD)", "cad autocad desenho projetista"),
        j("tecnico_manutencao", .technicians, 3, "Técnico de manutenção", "Maintenance technician", "manutencao industrial"),
        j("tecnico_eletronica", .technicians, 3, "Técnico de eletrónica", "Electronics technician", "eletronica reparacao"),
        j("tecnico_telecom", .technicians, 3, "Técnico de telecomunicações", "Telecoms technician", "telecomunicacoes fibra redes"),
        j("tecnico_ambiente", .technicians, 3, "Técnico de ambiente", "Environmental technician", "ambiente residuos"),
        j("tecnico_qualidade", .technicians, 3, "Técnico de qualidade", "Quality technician", "qualidade controlo"),
        j("tecnico_shst", .technicians, 3, "Técnico de segurança e higiene no trabalho", "Health & safety technician", "shst seguranca higiene"),
        j("inspetor", .technicians, 3, "Inspetor / Fiscal", "Inspector", "fiscalizacao inspecao"),
        j("agente_imobiliario", .technicians, 3, "Agente imobiliário", "Estate agent", "imobiliaria mediacao casas"),
        j("agente_viagens", .technicians, 4, "Agente de viagens", "Travel agent", "viagens turismo"),
        j("despachante", .technicians, 3, "Despachante oficial", "Customs broker", "alfandega despacho"),
        j("tecnico_apoio_social", .technicians, 3, "Técnico de apoio social", "Social work technician", "apoio social ipss"),
        j("assistente_social", .technicians, 2, "Assistente social", "Social worker", "servico social"),
    ]

    private static let admin: [JobTitle] = [
        j("assistente_administrativo", .admin, 4, "Assistente administrativo", "Administrative assistant", "administrativo escritorio backoffice"),
        j("secretario", .admin, 4, "Secretário / Assistente de direção", "Secretary / executive assistant", "secretariado assistente direcao"),
        j("rececionista", .admin, 4, "Rececionista", "Receptionist", "rececao atendimento"),
        j("callcenter", .admin, 4, "Operador de call center", "Call centre operator", "call center telefonista contact"),
        j("apoio_cliente", .admin, 4, "Assistente de apoio ao cliente", "Customer support agent", "apoio cliente suporte customer"),
        j("escriturario", .admin, 4, "Escriturário", "Clerk", "escritorio administrativo"),
        j("tesoureiro", .admin, 4, "Tesoureiro / Caixa", "Cashier / treasurer", "caixa tesouraria"),
        j("assistente_tecnico_ap", .admin, 4, "Assistente técnico (função pública)", "Public administration officer", "funcao publica camara estado"),
        j("tecnico_superior_ap", .admin, 2, "Técnico superior (função pública)", "Public administration senior officer", "funcao publica tecnico superior estado"),
        j("fiel_armazem", .admin, 4, "Fiel de armazém", "Warehouse clerk", "armazem stocks inventario"),
        j("rececionista_hotel", .admin, 4, "Rececionista de hotel", "Hotel receptionist", "hotel rececao front office"),
    ]

    private static let sales: [JobTitle] = [
        j("vendedor_loja", .sales, 5, "Empregado de loja / Vendedor", "Shop assistant", "loja retalho balcao vendedor"),
        j("operador_caixa", .sales, 5, "Operador de caixa", "Checkout operator", "caixa supermercado"),
        j("comercial", .sales, 3, "Comercial / Vendedor externo", "Sales representative", "vendas comercial account"),
        j("key_account", .sales, 2, "Gestor de conta / Key account", "Account manager", "key account gestor cliente vendas"),
        j("promotor", .sales, 5, "Promotor de vendas", "Sales promoter", "promotor merchandising"),
        j("repositor", .sales, 9, "Repositor", "Shelf stacker", "reposicao supermercado"),
        j("ecommerce", .sales, 2, "Gestor de e-commerce", "E-commerce manager", "ecommerce loja online"),
    ]

    private static let services: [JobTitle] = [
        j("cabeleireiro", .services, 5, "Cabeleireiro", "Hairdresser", "cabelo salao barbeiro"),
        j("esteticista", .services, 5, "Esteticista", "Beautician", "estetica beleza unhas"),
        j("massagista", .services, 5, "Massagista", "Massage therapist", "massagem spa"),
        j("ama", .services, 5, "Ama / Babysitter", "Childminder", "ama criancas babysitter"),
        j("cuidador", .services, 5, "Cuidador de idosos", "Care worker", "lar idosos cuidados apoio domiciliario"),
        j("empregado_domestico", .services, 9, "Empregado doméstico", "Domestic worker", "domestica limpeza casa"),
        j("personal_trainer", .services, 3, "Personal trainer", "Personal trainer", "ginasio fitness treino"),
        j("treinador", .services, 3, "Treinador desportivo", "Sports coach", "desporto futebol treinador"),
        j("agente_funerario", .services, 5, "Agente funerário", "Funeral director", "funeraria"),
    ]

    private static let hospitality: [JobTitle] = [
        j("cozinheiro", .hospitality, 5, "Cozinheiro", "Cook", "cozinha restaurante"),
        j("chef", .hospitality, 3, "Chef de cozinha", "Head chef", "chefe cozinha restaurante"),
        j("ajudante_cozinha", .hospitality, 9, "Ajudante de cozinha", "Kitchen assistant", "copa cozinha auxiliar"),
        j("empregado_mesa", .hospitality, 5, "Empregado de mesa", "Waiter", "mesa restaurante servico"),
        j("barman", .hospitality, 5, "Barman", "Bartender", "bar bebidas"),
        j("barista", .hospitality, 5, "Barista", "Barista", "cafe cafetaria"),
        j("pasteleiro", .hospitality, 7, "Pasteleiro", "Pastry chef", "pastelaria doces"),
        j("padeiro", .hospitality, 7, "Padeiro", "Baker", "padaria pao"),
        j("governanta", .hospitality, 5, "Governanta / Camareira", "Housekeeper", "hotel limpeza quartos andares"),
        j("guia_turistico", .hospitality, 5, "Guia turístico", "Tour guide", "turismo guia"),
    ]

    private static let transport: [JobTitle] = [
        j("motorista_pesados", .transport, 8, "Motorista de pesados", "HGV driver", "camiao tir pesados motorista"),
        j("motorista_ligeiros", .transport, 8, "Motorista de ligeiros", "Van / car driver", "carrinha distribuicao motorista"),
        j("motorista_tvde", .transport, 8, "Motorista TVDE / Táxi", "Ride-hailing / taxi driver", "uber bolt taxi tvde"),
        j("motorista_autocarro", .transport, 8, "Motorista de autocarro", "Bus driver", "autocarro carris stcp"),
        j("estafeta", .transport, 9, "Estafeta", "Courier", "entregas glovo uber eats estafeta"),
        j("piloto", .transport, 3, "Piloto de aviação", "Airline pilot", "aviacao piloto"),
        j("tripulante_cabine", .transport, 5, "Tripulante de cabine", "Cabin crew", "hospedeira comissario aviao"),
        j("maquinista", .transport, 8, "Maquinista", "Train driver", "comboio cp metro"),
        j("marinheiro", .transport, 8, "Marinheiro / Oficial de marinha", "Seafarer", "navio marinha mercante"),
        j("operador_logistica", .transport, 4, "Operador de logística", "Logistics operator", "logistica armazem expedicao"),
        j("empilhador", .transport, 8, "Operador de empilhador", "Forklift operator", "empilhador armazem"),
        j("controlador_aereo", .transport, 3, "Controlador de tráfego aéreo", "Air traffic controller", "nav trafego aereo"),
    ]

    private static let construction: [JobTitle] = [
        j("pedreiro", .construction, 7, "Pedreiro", "Bricklayer / mason", "obra construcao alvenaria"),
        j("carpinteiro", .construction, 7, "Carpinteiro", "Carpenter", "madeira cofragem"),
        j("eletricista", .construction, 7, "Eletricista", "Electrician", "eletricidade instalacoes"),
        j("canalizador", .construction, 7, "Canalizador", "Plumber", "picheleiro aguas canalizacao"),
        j("pintor_construcao", .construction, 7, "Pintor de construção", "Painter & decorator", "pintura obra"),
        j("serralheiro", .construction, 7, "Serralheiro", "Metalworker / fabricator", "serralharia metal aluminio"),
        j("soldador", .construction, 7, "Soldador", "Welder", "soldadura"),
        j("ladrilhador", .construction, 7, "Ladrilhador / Azulejador", "Tiler", "azulejo ceramica"),
        j("estucador", .construction, 7, "Estucador", "Plasterer", "estuque gesso"),
        j("encarregado_obra", .construction, 3, "Encarregado de obra", "Site foreman", "obra encarregado chefe equipa"),
        j("orcamentista", .construction, 3, "Medidor orçamentista", "Quantity surveyor", "orcamentos medicoes"),
        j("manobrador", .construction, 8, "Manobrador de máquinas", "Heavy machinery operator", "giratoria escavadora maquinas obra"),
        j("andaimes", .construction, 7, "Montador de andaimes", "Scaffolder", "andaimes"),
    ]

    private static let industry: [JobTitle] = [
        j("operador_producao", .industry, 8, "Operador de produção / fabril", "Production operator", "fabrica producao linha operario"),
        j("operador_maquinas", .industry, 8, "Operador de máquinas", "Machine operator", "maquinas industria"),
        j("cnc", .industry, 7, "Operador CNC / Fresador", "CNC machinist", "cnc torno fresa maquinacao"),
        j("mecanico_auto", .industry, 7, "Mecânico automóvel", "Car mechanic", "oficina carros mecanica auto"),
        j("eletromecanico", .industry, 7, "Eletromecânico", "Electromechanical technician", "eletromecanica manutencao"),
        j("costureira", .industry, 7, "Costureiro / Modista", "Sewing machinist", "costura textil confecao"),
        j("sapateiro", .industry, 7, "Sapateiro", "Shoemaker", "calcado sapatos"),
        j("marceneiro", .industry, 7, "Marceneiro", "Cabinetmaker", "madeira moveis"),
        j("tecnico_avac", .industry, 7, "Técnico de refrigeração e AVAC", "HVAC technician", "avac frio ar condicionado"),
        j("controlador_qualidade", .industry, 3, "Controlador de qualidade", "Quality inspector", "qualidade inspecao linha"),
        j("encarregado_producao", .industry, 3, "Encarregado de produção", "Production supervisor", "chefe linha encarregado fabrica"),
        j("impressor", .industry, 8, "Operador gráfico / Impressor", "Print operator", "grafica impressao artes graficas"),
    ]

    private static let agriculture: [JobTitle] = [
        j("agricultor", .agriculture, 6, "Agricultor", "Farmer", "agricultura campo lavrador"),
        j("trabalhador_agricola", .agriculture, 9, "Trabalhador agrícola", "Farm worker", "apanha campo agricola"),
        j("viticultor", .agriculture, 6, "Viticultor", "Viticulturist", "vinha uvas"),
        j("enologo", .agriculture, 2, "Enólogo", "Winemaker", "vinho adega enologia"),
        j("pescador", .agriculture, 6, "Pescador", "Fisher", "pesca mar barco"),
        j("criador_animais", .agriculture, 6, "Criador de animais", "Livestock farmer", "gado pecuaria animais"),
        j("jardineiro", .agriculture, 6, "Jardineiro", "Gardener", "jardins espacos verdes"),
        j("sapador_florestal", .agriculture, 6, "Sapador florestal", "Forestry worker", "floresta mato limpeza"),
    ]

    private static let publicSafety: [JobTitle] = [
        j("policia", .publicSafety, 5, "Polícia (PSP / GNR)", "Police officer", "psp gnr policia agente"),
        j("militar", .publicSafety, 0, "Militar", "Armed forces", "exercito marinha forca aerea tropa"),
        j("bombeiro", .publicSafety, 5, "Bombeiro", "Firefighter", "bombeiros socorro"),
        j("seguranca", .publicSafety, 5, "Segurança privado / Vigilante", "Security guard", "vigilante seguranca porteiro"),
        j("guarda_prisional", .publicSafety, 5, "Guarda prisional", "Prison officer", "prisao guarda"),
    ]

    private static let other: [JobTitle] = [
        j("limpeza", .other, 9, "Empregado de limpeza", "Cleaner", "limpeza higiene faxina"),
        j("ajudante_armazem", .other, 9, "Ajudante de armazém", "Warehouse operative", "armazem carga descarga"),
        j("servente", .other, 9, "Servente de construção", "Construction labourer", "servente obra ajudante"),
        j("porteiro", .other, 5, "Porteiro", "Doorman / concierge", "portaria condominio"),
        j("outra", .other, 9, "Outra profissão", "Other occupation", "outro outra nao listada"),
    ]

    // MARK: Catalogue

    static let all: [JobTitle] =
        management + it + engineering + health + education + business + science
        + creative + technicians + admin + sales + services + hospitality
        + transport + construction + industry + agriculture + publicSafety + other

    private static let byID: [String: JobTitle] = Dictionary(
        all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    static func title(_ id: String?) -> JobTitle? {
        guard let id else { return nil }
        return byID[id]
    }

    static func titles(in family: JobFamily) -> [JobTitle] {
        all.filter { $0.family == family }
    }

    /// True when any whitespace-separated or slash-separated word starts with
    /// the query. Slashes matter here: "Programador / Engenheiro de software"
    /// has to be findable by "engenheiro".
    static func hasWordPrefix(_ haystack: String, _ q: String) -> Bool {
        haystack
            .split(whereSeparator: { $0 == " " || $0 == "/" || $0 == "," || $0 == "(" })
            .contains { $0.hasPrefix(q) }
    }

    /// Diacritic and case insensitive, so "eletrico" matches "elétrico" and
    /// "PROGRAMADOR" matches "Programador".
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "pt_PT"))
    }

    /// Ranked search across both languages plus the synonym list. Prefix matches
    /// rank above contained matches so typing "enf" puts "Enfermeiro" first.
    static func search(_ query: String, pt: Bool) -> [JobTitle] {
        let q = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !q.isEmpty else { return [] }
        var scored: [(JobTitle, Int)] = []
        for t in all {
            let primary = fold(t.label(pt: pt))
            let secondary = fold(t.label(pt: !pt))
            let alt = fold(t.alt)
            // Word-prefix before raw substring, otherwise "uber" matches the
            // "kubernetes" synonym on the DevOps entry and outranks the taxi driver.
            var score = -1
            if primary.hasPrefix(q) { score = 0 }
            else if Self.hasWordPrefix(primary, q) { score = 1 }
            else if Self.hasWordPrefix(secondary, q) { score = 2 }
            else if Self.hasWordPrefix(alt, q) { score = 3 }
            else if primary.contains(q) { score = 4 }
            else if secondary.contains(q) { score = 5 }
            if score >= 0 { scored.append((t, score)) }
        }
        return scored
            .sorted { a, b in
                a.1 == b.1 ? a.0.label(pt: pt) < b.0.label(pt: pt) : a.1 < b.1
            }
            .map { $0.0 }
    }
}
