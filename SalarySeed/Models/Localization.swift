import Foundation

/// v0.3: in-app localization, English + European Portuguese (informal "tu").
///
/// The app follows the device language by default and lets the user override it
/// in the profile tab. A tiny custom layer (instead of system localization)
/// because the app must switch language at runtime, without a restart.
/// All user-facing copy lives here, in plain, direct language.

enum AppLanguage: String, CaseIterable, Identifiable {
    case auto
    case english = "en"
    case portuguese = "pt"

    var id: String { rawValue }

    func label(pt: Bool) -> String {
        switch self {
        case .auto: "Auto"
        case .english: "English"
        case .portuguese: "Português"
        }
    }
}

enum ResolvedLanguage {
    case en, pt

    /// The device language, mapped to what the app supports.
    static var device: ResolvedLanguage {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("pt") ? .pt : .en
    }
}

/// The full string table. Views read this through `store.s`.
struct Strings {
    let pt: Bool

    init(_ lang: ResolvedLanguage) { pt = lang == .pt }

    private func t(_ en: String, _ ptText: String) -> String { pt ? ptText : en }

    // MARK: Tabs

    var tabHome: String { t("Home", "Início") }
    var tabCompare: String { t("Compare", "Comparar") }
    var tabProfile: String { t("Profile", "Perfil") }

    // MARK: Onboarding

    var welcomeTitle: String { t("Let's plant\nyour seed.", "Vamos plantar\na tua semente.") }
    var welcomeSub: String { t("Type one number and see what you really earn, what you cost, and how you compare.", "Escreve um número e vê quanto ganhas na verdade, quanto custas e como te comparas.") }
    var welcomeAskName: String { t("What's your name?", "Como te chamas?") }
    var welcomeNamePlaceholder: String { t("Your first name", "O teu primeiro nome") }
    var welcomePrivacy: String { t("No account. No sign-up. Everything stays on your phone.", "Sem conta. Sem registo. Fica tudo no teu telemóvel.") }
    var welcomeButton: String { t("Let's grow", "Vamos a isso") }
    var welcomeSkip: String { t("Skip for now", "Agora não") }

    var salaryTitle: String { t("How much do\nyou make?", "Quanto é que\ntu ganhas?") }
    var salarySub: String { t("Just the monthly number. That's it.", "Só o valor mensal. Mais nada.") }
    func salarySubNamed(_ name: String) -> String { t("Nice to meet you, \(name). Just the monthly number.", "Prazer, \(name). Só o valor mensal.") }
    var perMonthSuffix: String { t("/mo", "/mês") }
    var continueButton: String { t("Continue", "Continuar") }

    var grossOrNet: String { t("Is that gross or net?", "Esse valor é bruto ou líquido?") }
    var howManyMonths: String { t("Paid over how many months?", "Recebes em quantos meses?") }
    var monthsHint: String { t("In Portugal most people get 14, with holiday and Christmas pay.", "Em Portugal o normal são 14, com subsídio de férias e de Natal.") }
    var fiveSeconds: String { t("This takes 5 seconds. Your number stays on your phone.", "Demora 5 segundos. O número fica no teu telemóvel.") }
    var revealButton: String { t("Show my breakdown", "Mostrar as minhas contas") }

    // MARK: Home

    func hey(_ name: String?) -> String {
        if let name { return t("Hey \(name)", "Olá, \(name)") }
        return t("Hey there", "Olá")
    }
    var greetSub: String { t("here's what your salary really means.", "isto é o que o teu salário significa na prática.") }
    var monthly: String { t("Monthly", "Mensal") }
    var yearly: String { t("Yearly", "Anual") }
    func grossLabel(yearly: Bool) -> String { t("Gross / \(yearly ? "year" : "month")", "Bruto / \(yearly ? "ano" : "mês")") }
    func netLabel(yearly: Bool) -> String { t("Net / \(yearly ? "year" : "month")", "Líquido / \(yearly ? "ano" : "mês")") }
    var effLine1: String { t("Of every €100 your company spends,", "Por cada €100 que a tua empresa gasta,") }
    var effLine2: String { t("reaches your pocket", "chegam ao teu bolso") }

    var whereMoneyGoes: String { t("Where the money goes", "Para onde vai o dinheiro") }
    var legendNet: String { t("Net", "Líquido") }
    var legendIRS: String { "IRS" }
    var legendYourSS: String { t("Your SS", "A tua SS") }
    var legendEmployerSS: String { t("Employer SS", "SS da empresa") }
    var shareOfCost: String { t("Share of total cost to your company", "Parte do custo total para a tua empresa") }

    var theDetails: String { t("The details", "Em detalhe") }
    func perPeriod(yearly: Bool) -> String { t(yearly ? "per year" : "per month", yearly ? "por ano" : "por mês") }
    var cardEmployerCost: String { t("Costs your company", "Custo para a empresa") }
    var cardEmployerTop: String { t("Employer pays on top", "Extra pago pela empresa") }
    var cardYourSS: String { t("Social Security (you)", "Segurança Social (tu)") }
    var cardIRS: String { t("IRS withheld", "IRS retido") }
    var cardDeductions: String { t("Your deductions", "Os teus descontos") }
    var cardRate: String { t("Tax + SS rate", "Taxa IRS + SS") }

    var standTitle: String { t("How you compare in Portugal", "Como te comparas em Portugal") }
    var earnMorePre: String { t("You earn more than", "Ganhas mais do que") }
    var earnMorePost: String { t("of workers", "dos trabalhadores") }
    var ineNote: String { t("Fontes: GEP-MTSSS e INE · 2024. See more in compareSeed.", "Fontes: GEP-MTSSS e INE · 2024. Vê mais no compareSeed.") }

    var whatIf: String { t("What if…", "E se…") }
    var raiseNudgeTitle: String { t("Simulate a raise", "Simula um aumento") }
    var raiseNudgeSub: String { t("What would a €100 net raise cost your employer?", "Quanto custaria à empresa dar-te mais €100 líquidos?") }
    var ajudasNudgeTitle: String { t("Paid partly in ajudas de custo?", "Recebes parte em ajudas de custo?") }
    var ajudasNudgeSub: String { t("See what it's costing your pension.", "Vê quanto isso custa à tua reforma.") }
    var growthTitle: String { t("Steps to improve your salary", "Passos para melhorar o teu salário") }
    var growthSub: String { t("Simple ideas to earn more, based on your profile.", "Ideias simples para ganhares mais, com base no teu perfil.") }
    var growthSoon: String { t("growthSeed · coming soon", "growthSeed · em breve") }
    var homeDisclaimer: String { t("These are estimates, not official tax advice. Rates not verified yet.", "Isto são estimativas, não aconselhamento fiscal oficial. Taxas ainda por verificar.") }

    // MARK: Compare

    var compareTitle: String { t("Where you stand", "Como te comparas") }
    func planted(_ n: Int, of total: Int) -> String { t("\(n) of \(total) planted", "\(n) de \(total) plantados") }
    var allPortugal: String { t("All of Portugal", "Portugal inteiro") }
    var earnLessThanYou: String { t("of workers earn less than you", "dos trabalhadores ganham menos do que tu") }
    var grossVsGross: String { t("Gross vs gross · GEP-MTSSS e INE · 2024 · estimate", "Bruto vs bruto · GEP-MTSSS e INE · 2024 · estimativa") }
    var natDistribution: String { t("National distribution", "Distribuição nacional") }
    var peopleLikeYou: String { t("People like you", "Pessoas como tu") }
    var earnLess: String { t("earn less", "ganham menos") }
    var medianWord: String { t("median", "mediana") }
    var earnMore: String { t("earn more", "ganham mais") }
    func medianCaption(median: String, diff: Double, diffText: String) -> String {
        if abs(diff) < 40 { return t("Median: \(median) gross. You're right at the median.", "Mediana: \(median) brutos. Estás mesmo na mediana.") }
        if diff > 0 { return t("Median: \(median) gross. You're \(diffText) above.", "Mediana: \(median) brutos. Estás \(diffText) acima.") }
        return t("Median: \(median) gross. You're \(diffText) below.", "Mediana: \(median) brutos. Estás \(diffText) abaixo.")
    }
    var thinChip: String { t("Rough estimate, small sample", "Estimativa aproximada, amostra pequena") }
    var edgeChip: String { t("Few data points at this level", "Poucos dados neste nível") }
    var offerTitle: String { t("Compare job offers", "Compara propostas de emprego") }
    var offerUnlock: String { "Premium · offerSeed" }
    var addPill: String { t("+ Add", "+ Adicionar") }
    var compareSourceNote: String { t("Group medians from official data: GEP-MTSSS, Quadros de Pessoal, Oct 2024, and INE, Estrutura dos Ganhos 2022. Employees only. Estimates, not official advice.", "Medianas dos grupos com base em dados oficiais: GEP-MTSSS, Quadros de Pessoal, out. 2024, e INE, Estrutura dos Ganhos 2022. Só trabalhadores por conta de outrem. Estimativas, não aconselhamento oficial.") }

    // MARK: Dimensions (keyed by CompareDimension.id)

    func dimRowTitle(_ id: String) -> String {
        switch id {
        case "age": t("People your age", "Pessoas da tua idade")
        case "region": t("Your region", "A tua região")
        case "education": t("Your education level", "A tua escolaridade")
        default: t("Your profession", "A tua profissão")
        }
    }
    func dimShort(_ id: String) -> String {
        switch id {
        case "age": t("Age", "Idade")
        case "region": t("Region", "Região")
        case "education": t("Education", "Escolaridade")
        default: t("Profession", "Profissão")
        }
    }
    func dimSheetTitle(_ id: String) -> String {
        switch id {
        case "age": t("How old are you?", "Que idade tens?")
        case "region": t("Where do you work?", "Onde trabalhas?")
        case "education": t("What's your education level?", "Qual é a tua escolaridade?")
        default: t("What kind of work do you do?", "Que tipo de trabalho fazes?")
        }
    }
    func dimSheetNote(_ id: String) -> String? {
        switch id {
        case "region": return t("NUTS II regions", "Regiões NUTS II")
        case "occupation": return t("Broad occupation groups", "Grandes grupos de profissões")
        default: return nil
        }
    }
    func dimAdd(_ id: String) -> String {
        switch id {
        case "age": t("Add your age", "Adiciona a tua idade")
        case "region": t("Add your region", "Adiciona a tua região")
        case "education": t("Add your education", "Adiciona a tua escolaridade")
        default: t("Add your profession", "Adiciona a tua profissão")
        }
    }
    func dimProfileHint(_ id: String) -> String {
        switch id {
        case "age": t("Compare with people your age", "Compara com pessoas da tua idade")
        case "region": t("Compare with your region", "Compara com a tua região")
        case "education": t("Compare by education level", "Compara pela escolaridade")
        default: t("Compare with your profession", "Compara com a tua profissão")
        }
    }
    func cohortWord(_ id: String, _ label: String) -> String {
        id == "age" ? t("\(label) year olds", "\(label) anos") : label
    }

    // MARK: Picker sheet

    var sheetPrivacy: String { t("Stays on your phone. Used for your comparison and, later, for growthSeed tips.", "Fica no teu telemóvel. Serve para a tua comparação e, mais tarde, para as dicas do growthSeed.") }
    var removeDetail: String { t("Remove", "Remover") }

    // MARK: Profile

    func profileTitle(_ name: String?) -> String {
        if let name { return t("\(name)'s profile", "Perfil de \(name)") }
        return t("Your profile", "O teu perfil")
    }
    var yourSeed: String { t("Your seed", "A tua semente") }
    var seedSub: String { t("Each detail you add improves your comparison.", "Cada detalhe que adicionas melhora a tua comparação.") }
    var yourSalary: String { t("Your salary", "O teu salário") }
    var nameLabel: String { t("Name", "Nome") }
    var namePlaceholder: String { t("Add your name", "O teu nome") }
    var addMore: String { t("Add more, unlock more", "Adiciona mais, vê mais") }
    var maritalTitle: String { t("Marital status / dependents", "Estado civil / dependentes") }
    var maritalHint: String { t("Later: better IRS estimate", "Mais tarde: IRS mais preciso") }
    var cvTitle: String { t("CV upload", "Carregar o CV") }
    var cvHint: String { t("Later: better comparisons and tips", "Mais tarde: melhores comparações e dicas") }
    var appSection: String { "App" }
    var languageLabel: String { t("Language", "Idioma") }
    var premiumLabel: String { "Premium" }
    var premiumValue: String { t("Free version", "Versão gratuita") }
    var privacyLabel: String { t("Privacy", "Privacidade") }
    var privacyValue: String { t("All data stays on this phone", "Tudo fica neste telemóvel") }
    var sourcesLabel: String { t("Data sources", "Fontes de dados") }
    var sourcesValue: String { "INE / GEP-MTSSS · CC BY 4.0" }
    var profileFooter: String { t("SalarySeed v0.3. Estimates only, not official tax or financial advice.", "SalarySeed v0.3. Só estimativas, não aconselhamento fiscal ou financeiro oficial.") }

    // MARK: Salary editor

    var editorTitle: String { t("Your salary", "O teu salário") }
    var editorPlaceholder: String { t("Monthly amount", "Valor mensal") }
    var updateButton: String { t("Update", "Atualizar") }

    // MARK: raiseSeed

    var raiseTitle: String { t("Simulate a raise", "Simula um aumento") }
    var ifYouWant: String { t("If you want", "Se quiseres") }
    var netPerMonth: String { t("net / month", "líquidos / mês") }
    var costsEmployer: String { t("What it really costs your employer", "O que custa mesmo à empresa") }
    var extraPerMonth: String { t("Extra per month", "Extra por mês") }
    func extraPerYear(_ months: Int) -> String { t("Extra per year (\(months) months)", "Extra por ano (\(months) meses)") }
    var newGross: String { t("Your new gross / month", "O teu novo bruto / mês") }
    func raiseInfo(_ ratio: String) -> String { t("Every €1 extra in your pocket costs your employer about €\(ratio). Taxes and Social Security grow with it.", "Cada €1 extra no teu bolso custa à empresa cerca de €\(ratio). Impostos e Segurança Social crescem juntos.") }
    var raiseDisclaimer: String { t("Estimate with test rates. Confirm before using it for real.", "Estimativa com taxas de teste. Confirma antes de usares a sério.") }

    // MARK: futureSeed

    var futureTitle: String { t("The hidden cost", "O custo escondido") }
    var futureQuestion: String { t("How much of your pay comes as ajudas de custo or off the books?", "Quanto do teu salário vem em ajudas de custo ou por fora?") }
    var perMonthShort: String { t("/ month", "/ mês") }
    var todaysGain: String { t("What you gain today", "O que ganhas hoje") }
    var extraPocketNow: String { t("Extra in your pocket now (untaxed)", "Extra no bolso agora (sem impostos)") }
    var tomorrowsLoss: String { t("What you lose later (rough estimate)", "O que perdes depois (estimativa aproximada)") }
    var ssNotPaid: String { t("Monthly SS contributions not paid", "Descontos mensais para a SS que não fazes") }
    var pensionLost: String { t("Monthly pension lost (40-year career)", "Pensão mensal perdida (carreira de 40 anos)") }
    var alsoReduced: String { t("Also reduced", "Também diminui") }
    var alsoReducedValue: String { t("Sick leave · unemployment · parental pay", "Baixa · desemprego · licença parental") }
    var tradeOffTitle: String { t("What this means", "O que isto significa") }
    func tradeOffBody(_ amount: String) -> String { t("You gain \(amount) a month today. But your declared pay shrinks, so your pension and safety net shrink too. Nobody shows you this number.", "Ganhas \(amount) por mês hoje. Mas o teu salário declarado encolhe, e a tua reforma e a tua proteção social encolhem também. Ninguém te mostra este número.") }
    var futureDisclaimer: String { t("Very rough estimate with a test pension model. Not advice.", "Estimativa muito aproximada com um modelo de pensão de teste. Não é aconselhamento.") }
}
