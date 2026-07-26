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
    var tabGrow: String { t("Grow", "Crescer") }
    var tabCompare: String { t("Compare", "Comparar") }
    var tabMap: String { t("Map", "Mapa") }
    var tabProfile: String { t("Profile", "Perfil") }

    // MARK: Onboarding

    var welcomeTitle: String { t("Let's understand\nwhat you earn.", "Vamos compreender\nquanto ganhas.") }
    var welcomeSub: String { t("Type one number and see what you really earn, what you cost, and how you compare.", "Escreve um número e vê quanto ganhas na verdade, quanto custas e como te comparas.") }
    var welcomeAskName: String { t("What's your name?", "Como te chamas?") }
    var welcomeNamePlaceholder: String { t("Your first name", "O teu primeiro nome") }
    var welcomePrivacy: String { t("No account. No sign-up. Everything stays on your phone.", "Sem conta. Sem registo. Fica tudo no teu telemóvel.") }
    var welcomeButton: String { t("Let's grow", "Vamos a isso") }
    var welcomeSkip: String { t("Skip for now", "Agora não") }

    var salaryTitle: String { t("How much do\nyou make?", "Quanto é que\ntu ganhas?") }
    var salarySub: String { t("Just the monthly number. That's it.", "Só o valor mensal. Mais nada.") }
    func salarySubNamed(_ name: String) -> String { t("Nice to meet you, \(name). Just the monthly number.", "Prazer, \(name). Só o valor mensal.") }
    /// v0.8.2 combined salary step: greet by name and ask simply.
    func salaryQuestion(_ name: String?) -> String {
        if let name, !name.isEmpty { return t("\(name), how much do you make?", "\(name), quanto ganhas?") }
        return t("How much do you make?", "Quanto ganhas?")
    }
    var howYouGetPaid: String { t("How do you get paid?", "Como recebes?") }
    var entryModeHint: String { t("12x or 14x = payments a year. Yearly = the whole-year total.", "12x ou 14x = pagamentos por ano. Anual = o total do ano.") }
    var perMonthSuffix: String { t("/mo", "/mês") }
    var continueButton: String { t("Continue", "Continuar") }
    var okButton: String { t("OK", "OK") }

    var grossOrNet: String { t("Is that gross or net?", "Esse valor é bruto ou líquido?") }
    var howManyMonths: String { t("Paid over how many months?", "Recebes em quantos meses?") }
    var monthsHint: String { t("14 is the norm: holiday and Christmas pay come separately. With 12, those subsidies are split across every month (duodécimos).", "14 é o normal: os subsídios de férias e Natal vêm à parte. Com 12, esses subsídios vêm repartidos por todos os meses (duodécimos).") }
    var fiveSeconds: String { t("This takes 5 seconds. Your number stays on your phone.", "Demora 5 segundos. O número fica no teu telemóvel.") }
    var revealButton: String { t("Show my breakdown", "Mostrar as minhas contas") }
    var salaryNeeded: String { t("The salary is the one thing we need.", "O salário é a única coisa de que precisamos.") }

    // v0.5 onboarding: ajudas step + one-by-one profile questions
    var onbAjudasTitle: String { t("Meal allowance or\najudas de custo?", "Subsídio de alimentação\nou ajudas de custo?") }
    var onbAjudasSub: String { t("Amounts paid on top of the salary, straight to net, like the meal allowance (subsídio de alimentação) or ajudas de custo. You can change this later.", "Valores pagos à parte do salário, direto no líquido, como o subsídio de alimentação ou as ajudas de custo. Podes mudar isto mais tarde.") }
    var onbProfileWhy: String { t("This improves your comparison. You can skip it.", "Isto melhora a tua comparação. Podes saltar.") }
    var skipStep: String { t("Skip", "Saltar") }
    var skipQuestion: String { t("Skip, I'd rather not say", "Saltar, prefiro não dizer") }

    // v0.6 onboarding: marital situation + dependants (real IRS estimate)
    var onbMaritalTitle: String { t("What's your\nsituation?", "Qual é a tua\nsituação?") }
    var onbMaritalSub: String { t("This sets your real IRS. Married with one earner, or with children, changes how much is withheld.", "Isto define o teu IRS real. Ser casado com um só titular, ou ter filhos, muda quanto é retido.") }
    var onbDependentsTitle: String { t("Any dependants?", "Tens dependentes?") }
    var onbDependentsSub: String { t("Children or others in your care count for IRS. If none, leave it at zero.", "Filhos ou outros a teu cargo contam para o IRS. Se não tens, deixa a zero.") }
    func dependentsUnit(_ n: Int) -> String {
        if n == 1 { return t("dependant", "dependente") }
        return t("dependants", "dependentes")
    }

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
    // v0.8: three-way result view (monthly ÷12, monthly ÷14, annual)
    var grossWord: String { t("Gross", "Bruto") }
    var netWord: String { t("Net", "Líquido") }
    var resultM12: String { t("Mo ×12", "Mês ×12") }
    var resultM14: String { t("Mo ×14", "Mês ×14") }
    var resultYear: String { t("Year", "Ano") }
    func periodSuffix(_ mode: Int) -> String {
        // 0 = ÷12 monthly, 1 = ÷14 monthly, 2 = annual
        switch mode {
        case 2: return t("year", "ano")
        case 1: return t("month (×14)", "mês (×14)")
        default: return t("month (×12)", "mês (×12)")
        }
    }
    func resultCaption(_ mode: Int) -> String? {
        switch mode {
        case 0: return t("Your yearly pay spread evenly over 12 months.",
                         "O teu salário anual repartido por 12 meses.")
        case 1: return t("What lands in each of your 14 payments.",
                         "O que entra em cada um dos teus 14 pagamentos.")
        default: return nil
        }
    }
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
    var cardYourSS: String { t("Social Security (you)", "Segurança Social (tu)") }
    var cardIRS: String { t("IRS withheld", "IRS retido") }

    // v0.5 detail trees
    var treeCompanyTitle: String { t("Total cost for your company", "Custo total para a empresa") }
    var treeGross: String { t("Gross salary", "Salário bruto") }
    var treeEmployerSS: String { t("Social Security (employer)", "Segurança Social (empresa)") }
    var treeDeductionsTitle: String { t("Your total discounts", "Os teus descontos totais") }
    func ofGross(_ pct: String) -> String { t("\(pct) of gross", "\(pct) do bruto") }
    func ofCost(_ pct: String) -> String { t("\(pct) of cost", "\(pct) do custo") }

    // v0.6 annual settlement (withholding vs real IRS)
    var annualTitle: String { t("Withheld vs real IRS", "Retido vs IRS real") }
    var annualWithheld: String { t("Withheld this year", "Retido este ano") }
    var annualSettled: String { t("Estimated real IRS", "IRS real estimado") }
    func annualRefund(_ amount: String) -> String { t("About \(amount) back at settlement", "Cerca de \(amount) a receber no acerto") }
    func annualToPay(_ amount: String) -> String { t("About \(amount) left to pay at settlement", "Cerca de \(amount) a pagar no acerto") }
    var annualEven: String { t("Withholding lands about right", "A retenção fica quase certa") }
    // v0.8.1: no IRS at all (salary below the taxable threshold)
    var annualNoIRS: String { t("You pay no IRS this year", "Não pagas IRS este ano") }
    var annualNoIRSSub: String { t("Your salary is below the level where IRS starts.", "O teu salário fica abaixo do valor a partir do qual há IRS.") }
    func annualNoIRSRefund(_ amount: String) -> String {
        t("You get back the \(amount) withheld during the year.", "Recebes de volta os \(amount) retidos durante o ano.")
    }
    var annualNote: String {
        t("Estimate on the 2026 brackets. Your real deductions can shift it.",
          "Estimativa nos escalões de 2026. As tuas deduções reais podem mudar isto.")
    }

    // v0.9.4: the two assumptions behind the settlement, always stated.
    func annualJovemBoth(_ pct: Int) -> String {
        t("IRS Jovem (\(pct)% exempt) is already in both numbers: it lowers what's withheld every month and the real IRS at the end of the year.",
          "O IRS Jovem (\(pct)% isento) já está nos dois números: baixa o que te retêm todos os meses e também o IRS real no fim do ano.")
    }
    func annualCreditFull(_ assumed: String) -> String {
        t("Assumes \(assumed) of the usual deductions (health, education, invoices), and all of it is used here.",
          "Assume \(assumed) das deduções habituais (saúde, educação, faturas), e aqui são usados por inteiro.")
    }
    func annualCreditPartial(_ assumed: String, _ applied: String) -> String {
        t("Assumes \(assumed) of the usual deductions (health, education, invoices), but only \(applied) fits: a deduction never pushes your IRS below zero.",
          "Assume \(assumed) das deduções habituais (saúde, educação, faturas), mas só \(applied) cabem: uma dedução nunca faz o IRS descer abaixo de zero.")
    }
    func annualCreditUnused(_ assumed: String) -> String {
        t("Assumes \(assumed) of the usual deductions (health, education, invoices), but none of it is used here: there is no IRS left for it to reduce.",
          "Assume \(assumed) das deduções habituais (saúde, educação, faturas), mas aqui não são usados: já não há IRS para reduzir.")
    }

    // v0.5 ajudas de custo, always shown apart from the salary
    func heroAjudas(_ amount: String, total: String) -> String {
        t("+ \(amount) in ajudas de custo. Total in your pocket: \(total).",
          "+ \(amount) de ajudas de custo. Total no teu bolso: \(total).")
    }
    var ajudasCardTitle: String { t("Ajudas de custo", "Ajudas de custo") }
    func ajudasCardYearly(_ yearly: String) -> String { t("\(yearly) a year, paid over 12 months", "\(yearly) por ano, pago em 12 meses") }
    var ajudasCardBody: String {
        t("This goes straight to your net pay: no IRS, no Social Security. But it does not count as gross salary. Banks ignore it when rating you for loans, and it builds no pension or social protection.",
          "Este valor vai direto para o teu líquido: sem IRS, sem Segurança Social. Mas não conta como salário bruto. Os bancos ignoram este valor quando avaliam um crédito, e não conta para a reforma nem para a proteção social.")
    }
    var ajudasExcludedNote: String {
        t("Ajudas de custo not included: comparisons use the gross salary only.",
          "Ajudas de custo não incluídas: as comparações usam só o salário bruto.")
    }

    var standTitle: String { t("How you compare in Portugal", "Como te comparas em Portugal") }
    var earnMorePre: String { t("You earn more than", "Ganhas mais do que") }
    var earnMorePost: String { t("of workers", "dos trabalhadores") }
    var ineNote: String { t("Fontes: GEP-MTSSS e INE · 2024. See more in compareSeed.", "Fontes: GEP-MTSSS e INE · 2024. Vê mais no compareSeed.") }

    var whatIf: String { t("What if…", "E se…") }
    var raiseNudgeTitle: String { t("Simulate a raise", "Simula um aumento") }
    var raiseNudgeSub: String { t("What would a €100 net raise cost your employer?", "Quanto custaria à empresa dar-te mais €100 líquidos?") }
    var ajudasNudgeTitle: String { t("Paid partly in ajudas de custo?", "Recebes parte em ajudas de custo?") }
    var ajudasNudgeSub: String { t("See what it's costing your pension.", "Vê quanto isso custa à tua reforma.") }
    var homeDisclaimer: String { t("Estimates based on 2026 tax tables for mainland Portugal (Continente). Not official tax advice.", "Estimativas com base nas tabelas fiscais de 2026 para o Continente. Não é aconselhamento fiscal oficial.") }

    // MARK: Compare

    var compareTitle: String { t("Where you stand", "Como te comparas") }
    var allPortugal: String { t("All of Portugal", "Portugal inteiro") }
    var earnLessThanYou: String { t("of workers earn less than you", "dos trabalhadores ganham menos do que tu") }
    var grossVsGross: String { t("Gross vs gross · GEP-MTSSS e INE · 2024 · estimate", "Bruto vs bruto · GEP-MTSSS e INE · 2024 · estimativa") }
    var natDistribution: String { t("National distribution", "Distribuição nacional") }
    // v0.7 interactive distribution
    var dragToExplore: String { t("Drag to explore", "Arrasta para explorar") }
    var releaseToReset: String { t("Release to reset", "Larga para voltar") }
    func atLevel(_ amount: String) -> String { t("\(amount) / mo", "\(amount) / mês") }
    func bandShare(_ share: String, _ range: String) -> String {
        t("\(share) of workers earn \(range)", "\(share) dos trabalhadores ganham \(range)")
    }
    func bandUnder(_ hi: String) -> String { t("under \(hi)", "menos de \(hi)") }
    func bandOver(_ lo: String) -> String { t("over \(lo)", "mais de \(lo)") }
    // v0.8: percentile explorer (drag a percentile, see the salary there)
    var exploreByPercentile: String { t("Explore by percentile", "Explora por percentil") }
    var exploreHint: String { t("Drag the handle. Let go to return to you.", "Arrasta o cursor. Larga para voltar a ti.") }
    func percentileEarns(_ p: String) -> String { t("The \(p) percentile earns", "O percentil \(p) ganha") }
    var aboutPerMonth: String { t("about / month", "cerca de / mês") }
    func ordinalPercentile(_ n: Int) -> String {
        if pt { return "\(n)º" }
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
    var youMarker: String { t("You", "Tu") }
    var lowestEarners: String { t("Lowest", "Mais baixos") }
    var highestEarners: String { t("Highest", "Mais altos") }
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
        case "region": return t("Your município sets your region", "O teu concelho define a tua região")
        case "occupation": return t("Broad occupation groups", "Grandes grupos de profissões")
        default: return nil
        }
    }
    func dimAdd(_ id: String) -> String {
        switch id {
        case "age": t("Add your age", "Adiciona a tua idade")
        case "region": t("Add your município", "Adiciona o teu concelho")
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

    // MARK: v0.8.3 sector + tenure

    var sectorRowTitle: String { t("Your sector", "O teu setor") }
    var sectorSheetTitle: String { t("Which sector do you work in?", "Em que setor trabalhas?") }
    var sectorQuestion: String { t("Which sector do\nyou work in?", "Em que setor\ntrabalhas?") }
    var sectorNote: String { t("Economic activity (GEP CAE)", "Atividade económica (CAE, GEP)") }
    var sectorAdd: String { t("Add your sector", "Adiciona o teu setor") }
    var sectorAddHint: String { t("Compare with your sector and time at the company", "Compara com o teu setor e antiguidade na empresa") }
    var sectorKicker: String { t("Sector + time at the company", "Setor + antiguidade na empresa") }
    var tenureLabel: String { t("Years at this employer", "Anos nesta empresa") }
    var tenureQuestion: String { t("How many years at your current employer?", "Há quantos anos estás na empresa onde trabalhas?") }
    var tenureHint: String { t("Time at your current employer, not your whole career. That is how the official tables count it.", "Tempo na empresa onde estás agora, não a carreira toda. É assim que as tabelas oficiais contam.") }
    var tenureAddHint: String { t("Add your years to sharpen it", "Adiciona os anos para afinar") }
    func yearsText(_ n: Int) -> String {
        if n >= 40 { return t("40+ years", "40+ anos") }
        return n == 1 ? t("\(n) year", "\(n) ano") : t("\(n) years", "\(n) anos")
    }
    /// The cohort name for the sector card: "Retail · 5–9 years" style.
    func sectorCohort(_ sector: String, tenure: String?) -> String {
        if let tenure { return "\(sector) · \(tenure)" }
        return sector
    }

    // MARK: Picker sheet

    var sheetPrivacy: String { t("Stays on your phone. Used for your comparison.", "Fica no teu telemóvel. Serve para a tua comparação.") }
    var removeDetail: String { t("Remove", "Remover") }

    // MARK: Profile

    func profileTitle(_ name: String?) -> String {
        if let name { return t("\(name)'s profile", "Perfil de \(name)") }
        return t("Your profile", "O teu perfil")
    }
    // v0.9.3: the sprout drawing stays, the seed vocabulary does not.
    var profileProgressTitle: String { t("Your details", "Os teus dados") }
    var profileProgressSub: String { t("Each one you add sharpens your comparison.", "Cada um que adicionas afina a tua comparação.") }
    var profileDoneTitle: String { t("All done", "Está tudo") }
    var profileDoneSub: String {
        t("Nothing left to ask. Your comparison is as precise as this app can make it.",
          "Não falta nada. A tua comparação está tão precisa quanto a app consegue.")
    }
    func profileProgressCount(_ filled: Int, _ total: Int) -> String {
        t("\(filled) of \(total)", "\(filled) de \(total)")
    }
    var demographicsTitle: String { t("About you", "Sobre ti") }
    var yourSalary: String { t("Your salary", "O teu salário") }
    var nameLabel: String { t("Name", "Nome") }
    var namePlaceholder: String { t("Add your name", "O teu nome") }
    var appSection: String { "App" }
    var languageLabel: String { t("Language", "Idioma") }
    var premiumLabel: String { "Premium" }
    var premiumValue: String { t("Free version", "Versão gratuita") }
    var privacyLabel: String { t("Privacy", "Privacidade") }
    var privacyValue: String { t("All data stays on this phone", "Tudo fica neste telemóvel") }
    var sourcesLabel: String { t("Data sources", "Fontes de dados") }
    var sourcesValue: String { "INE / GEP-MTSSS · CC BY 4.0" }
    var profileFooter: String { t("SalarySeed v0.9.4. Estimates only, not official tax or financial advice.", "SalarySeed v0.9.4. Só estimativas, não aconselhamento fiscal ou financeiro oficial.") }

    // v0.6 tax details section (profileSeed)
    var taxSection: String { t("Tax details", "Dados fiscais") }
    var maritalLabel: String { t("Situation", "Situação") }
    var dependentsLabel: String { t("Dependants", "Dependentes") }
    var irsJovemTitle: String { t("IRS Jovem", "IRS Jovem") }
    var irsJovemSub: String {
        t("On IRS Jovem? Pick how much of your income is exempt this year. It lowers your IRS, not your Social Security.",
          "Estás no IRS Jovem? Escolhe quanto do teu rendimento está isento este ano. Baixa o IRS, não a Segurança Social.")
    }
    var irsJovemOff: String { t("Off", "Não") }
    var irsJovemNote: String {
        t("Steps: 100% (year 1), 75% (years 2 to 4), 50% (years 5 to 7), 25% (years 8 to 10). Up to 55 × IAS a year.",
          "Escalões: 100% (ano 1), 75% (anos 2 a 4), 50% (anos 5 a 7), 25% (anos 8 a 10). Até 55 × IAS por ano.")
    }

    // v0.8: IRS Jovem eligibility assessor
    var irsJovemCheck: String { t("Not sure? Check your eligibility", "Não sabes? Verifica se tens direito") }
    var irsJovemManual: String { t("Or set it by hand", "Ou define à mão") }
    var jovemAssessTitle: String { t("IRS Jovem", "IRS Jovem") }
    var jovemAssessIntro: String {
        t("A few questions to find out if you qualify this year, and for how much. Nothing leaves your phone.",
          "Umas perguntas para saber se tens direito este ano, e a quanto. Nada sai do teu telemóvel.")
    }
    var jovemAgeQ: String { t("How old are you?", "Que idade tens?") }
    var jovemAgeHint: String { t("Must be 35 or under at the end of the year.", "Tens de ter 35 ou menos no fim do ano.") }
    var jovemFirstYearQ: String { t("First year you filed IRS independently", "Primeiro ano com IRS declarado independentemente") }
    var jovemFirstYearHint: String {
        t("The first year you filed IRS on your own, no longer as a dependant. This sets which benefit year you're in.",
          "O primeiro ano em que entregaste o IRS por ti, já não como dependente. Define em que ano do benefício estás.")
    }
    var jovemDependentQ: String { t("Are you a dependant on someone else's IRS this year?", "Este ano és dependente no IRS de outra pessoa?") }
    var jovemRegimeQ: String { t("Have you used RNH, IFICI or Programa Regressar?", "Já usaste RNH, IFICI ou Programa Regressar?") }
    var yesWord: String { t("Yes", "Sim") }
    var noWord: String { t("No", "Não") }
    var jovemSeeResult: String { t("See my exemption", "Ver a minha isenção") }

    var jovemExemptThisYear: String { t("exemption on your IRS this year", "de isenção no teu IRS este ano") }
    func jovemBenefitYear(_ n: Int) -> String { t("You're in benefit year \(n) of 10.", "Estás no ano \(n) de 10 do benefício.") }
    func jovemCapLine(_ yearly: String, monthly: String) -> String {
        t("Exempt up to \(yearly) a year (about \(monthly) a month).",
          "Isento até \(yearly) por ano (cerca de \(monthly) por mês).")
    }
    var jovemNotEligible: String { t("You don't qualify this year", "Não tens direito este ano") }
    var jovemReasonTooOld: String { t("IRS Jovem is only for people 35 or under.", "O IRS Jovem é só para quem tem 35 anos ou menos.") }
    var jovemReasonDependent: String { t("While you're a dependant on someone else's IRS, the benefit doesn't apply.", "Enquanto fores dependente no IRS de outra pessoa, o benefício não se aplica.") }
    var jovemReasonRegime: String { t("IRS Jovem can't be combined with RNH, IFICI or Programa Regressar.", "O IRS Jovem não se junta com RNH, IFICI ou Programa Regressar.") }
    var jovemReasonExhausted: String { t("You've passed the 10 benefit years. The exemption has run out.", "Já passaste os 10 anos do benefício. A isenção terminou.") }
    var jovemReasonNotStarted: String { t("That first income year is in the future. Come back when it starts.", "Esse primeiro ano de rendimentos ainda está no futuro. Volta quando começar.") }
    var jovemApply: String { t("Use this in the app", "Usar isto na app") }
    var jovemApplied: String { t("Done. Your IRS now uses this exemption.", "Feito. O teu IRS passa a usar esta isenção.") }
    var jovemDisclaimer: String {
        t("A guide, not an official ruling. Non-consecutive years and dependant years can change the count. Confirm on the Portal das Finanças.",
          "Um guia, não uma decisão oficial. Anos não seguidos e anos como dependente podem mudar a contagem. Confirma no Portal das Finanças.")
    }

    // MARK: Salary editor

    var editorTitle: String { t("Your salary", "O teu salário") }
    var editorPlaceholder: String { t("Monthly amount", "Valor mensal") }
    // v0.8: monthly vs yearly input
    var editorPeriodLabel: String { t("Enter it as", "Escreve como") }
    var perYearSuffix: String { t("/yr", "/ano") }
    func editorYearlyNote(_ months: Int) -> String {
        t("Total for the year. We split it across your \(months) payments.",
          "Total do ano. Dividimos pelos teus \(months) pagamentos.")
    }
    var updateButton: String { t("Update", "Atualizar") }
    var updateSalaryButton: String { t("Update my salary", "Atualizar o meu salário") }
    var editorAjudasLabel: String { t("Meal allowance & ajudas de custo / month (optional)", "Subsídio de alimentação e ajudas de custo / mês (opcional)") }
    var editorAjudasNote: String {
        t("Amounts paid straight to net, like the meal allowance (subsídio de alimentação) or ajudas de custo. Not included in percentiles or comparisons, which use the gross salary.",
          "Valores pagos diretamente no líquido, como o subsídio de alimentação ou as ajudas de custo. Não entram nos percentis nem nas comparações, que usam o salário bruto.")
    }

    // MARK: raiseSeed

    var raiseTitle: String { t("Simulate a raise", "Simula um aumento") }
    var ifYouWant: String { t("If you want", "Se quiseres") }
    var netPerMonth: String { t("net / month", "líquidos / mês") }
    var costsEmployer: String { t("What it really costs your employer", "O que custa mesmo à empresa") }
    var extraPerMonth: String { t("Extra per month", "Extra por mês") }
    func extraPerYear(_ months: Int) -> String { t("Extra per year (\(months) months)", "Extra por ano (\(months) meses)") }
    var newGross: String { t("Your new gross / month", "O teu novo bruto / mês") }
    func raiseInfo(_ ratio: String) -> String { t("Every €1 extra in your pocket costs your employer about €\(ratio). Taxes and Social Security grow with it.", "Cada €1 extra no teu bolso custa à empresa cerca de €\(ratio). Impostos e Segurança Social crescem juntos.") }
    var raiseDisclaimer: String { t("Estimate using 2026 tax tables. Confirm before using it for real.", "Estimativa com as tabelas fiscais de 2026. Confirma antes de usares a sério.") }

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

    // MARK: v0.9 progressive enrichment

    var enrichKicker: String { t("One quick question", "Uma pergunta rápida") }
    var enrichSkip: String { t("Not now", "Agora não") }
    func enrichProgress(_ done: Int, _ total: Int) -> String {
        t("\(done) of \(total) answered", "\(done) de \(total) respondidas")
    }
    var enrichAllDone: String { t("You've answered everything. Nice.", "Já respondeste a tudo. Boa.") }

    func enrichQuestion(_ id: String) -> String {
        switch id {
        case "employerKind": return t("Who do you work for?", "Para quem trabalhas?")
        case "workSchedule": return t("Full-time or part-time?", "Tempo inteiro ou parcial?")
        case "jobTitle": return t("What do you actually do?", "O que fazes exatamente?")
        case "variablePay": return t("Any bonus on top of your salary?", "Recebes prémios além do salário?")
        case "gender": return t("One optional question", "Uma pergunta opcional")
        default: return ""
        }
    }

    /// The reason, always shown before the answer. No question without a why.
    func enrichWhy(_ id: String) -> String {
        switch id {
        case "employerKind":
            return t("The official tables only cover private-contract workers. If you're on a public-function contract, we need to tell you the comparison doesn't fit you.",
                     "As tabelas oficiais só cobrem quem tem contrato privado. Se estás em funções públicas, temos de te dizer que a comparação não serve para ti.")
        case "workSchedule":
            return t("Part-time pay mixed in with full-time pay drags every average down. Telling us keeps the numbers honest.",
                     "Salários a tempo parcial misturados com tempo inteiro puxam todas as médias para baixo. Dizeres-nos mantém as contas honestas.")
        case "jobTitle":
            return t("Your sector says where you work. Your job says what you do, and that's where the real difference in pay is. Nothing compares on it yet, it's being gathered.",
                     "O setor diz onde trabalhas. A profissão diz o que fazes, e é aí que está a diferença real nos salários. Ainda não compara nada, está a ser reunido.")
        case "variablePay":
            return t("Bonus and commission can be a big slice of the year. Kept apart from the salary so neither number lies.",
                     "Prémios e comissões podem ser uma fatia grande do ano. Ficam à parte do salário para nenhum dos números mentir.")
        case "gender":
            return t("Pay differs by gender in Portugal and measuring that is the whole point of the new pay transparency rules. Skip it freely, it changes nothing else in the app.",
                     "Os salários diferem entre homens e mulheres em Portugal e medir isso é o objetivo das novas regras de transparência salarial. Salta à vontade, não muda mais nada na app.")
        default: return ""
        }
    }

    // Employer kind
    var employerRowTitle: String { t("Employer", "Empregador") }
    var employerAddHint: String { t("Private, public or state-owned", "Privado, público ou empresa do Estado") }
    var employerSheetTitle: String { t("Who do you work for?", "Para quem trabalhas?") }
    var publicCaveatTitle: String { t("This comparison doesn't cover you", "Esta comparação não te cobre") }
    var publicCaveatBody: String {
        t("The Quadros de Pessoal leave out staff on public-function contracts, so these averages are private-sector pay. Your own pay scale isn't in here yet.",
          "Os Quadros de Pessoal deixam de fora quem tem contrato de trabalho em funções públicas, por isso estas médias são do privado. A tua tabela remuneratória ainda não está aqui.")
    }

    // Work schedule
    var scheduleRowTitle: String { t("Working time", "Tempo de trabalho") }
    var scheduleAddHint: String { t("Full-time or part-time", "Tempo inteiro ou parcial") }
    var hoursQuestion: String { t("Contracted hours a week", "Horas contratadas por semana") }
    func hoursText(_ n: Int) -> String { t("\(n) hours", "\(n) horas") }
    var partTimeNote: String {
        t("You're part-time, so comparing against the average means comparing against mostly full-time pay.",
          "Estás a tempo parcial, por isso comparar com a média é comparar com salários quase todos a tempo inteiro.")
    }

    // Job title
    var jobRowTitle: String { t("Your job", "A tua profissão") }
    var jobAddHint: String { t("The thing you'd say at a dinner table", "Aquilo que dirias num jantar") }
    var jobSheetTitle: String { t("What do you do?", "O que fazes?") }
    var jobSearchPlaceholder: String { t("Search your job", "Procura a tua profissão") }
    var jobNoResults: String { t("Nothing matched. Try a shorter word.", "Nada encontrado. Tenta uma palavra mais curta.") }
    var jobNotCompared: String {
        t("Not compared yet. Portugal's published tables stop at broad groups, so this one is being gathered first.",
          "Ainda não é comparada. As tabelas publicadas em Portugal ficam-se por grupos largos, por isso esta está primeiro a ser reunida.")
    }
    var jobBrowseAll: String { t("Browse all", "Ver todas") }

    // Variable pay
    var variableRowTitle: String { t("Bonus and commission", "Prémios e comissões") }
    var variableAddHint: String { t("Anything on top of the salary", "Tudo o que vem além do salário") }
    var variableSheetTitle: String { t("Bonus over a year", "Prémios ao longo do ano") }
    var variableFieldLabel: String { t("Total for the year", "Total do ano") }
    var variableNone: String { t("I don't get any", "Não recebo nada") }
    var variableTaxNote: String {
        t("Kept out of the monthly estimate on purpose. IRS on bonuses is withheld under different rules and we'd rather show nothing than show it wrong.",
          "Fica de fora da estimativa mensal de propósito. O IRS dos prémios é retido por outras regras e preferimos não mostrar a mostrar mal.")
    }
    func variableYearly(_ amount: String) -> String { t("\(amount) a year", "\(amount) por ano") }

    // Gender
    var genderRowTitle: String { t("Gender", "Género") }
    var genderAddHint: String { t("Optional", "Opcional") }
    var genderSheetTitle: String { t("Gender", "Género") }

    // Work details sheet (employer + schedule, edited together)
    var workSheetTitle: String { t("About your work", "Sobre o teu trabalho") }
    var workSectionTitle: String { t("Your work", "O teu trabalho") }
    var collectedNotComparedNote: String {
        t("Stays on your phone. Some of these aren't compared yet, they're being gathered so the comparison can get sharper later.",
          "Fica no teu telemóvel. Alguns destes ainda não são comparados, estão a ser reunidos para a comparação ficar melhor mais à frente.")
    }
    var saveButton: String { t("Save", "Guardar") }

    // MARK: v0.9.1 município

    var concelhoRowTitle: String { t("Your município", "O teu concelho") }
    var concelhoAddHint: String { t("Sets your region for the comparison", "Define a tua região para a comparação") }
    var concelhoSheetTitle: String { t("Which município do you work in?", "Em que concelho trabalhas?") }
    var concelhoQuestion: String { t("Which município\ndo you work in?", "Em que concelho\ntrabalhas?") }
    var concelhoSearchPlaceholder: String { t("Search your município", "Procura o teu concelho") }
    var concelhoNoResults: String { t("Nothing matched. Try a shorter word.", "Nada encontrado. Tenta uma palavra mais curta.") }
    /// Said before the question, not after. Districts and regions do not line up,
    /// so the município is the only answer that gets the region right.
    var concelhoWhy: String {
        t("Districts and statistical regions don't line up, so we ask for the município and work the region out from it. Mainland only for now.",
          "Os distritos e as regiões estatísticas não coincidem, por isso perguntamos o concelho e daí tiramos a região. Só continente, para já.")
    }
    func concelhoDerived(_ region: String) -> String {
        t("Your region: \(region)", "A tua região: \(region)")
    }

    // MARK: v0.9.2 mapSeed

    var mapTitle: String { t("What your sector pays,\nby district", "Quanto paga o teu setor,\npor distrito") }
    var mapAllSectors: String { t("All sectors together", "Todos os setores juntos") }
    var mapPickSector: String { t("Pick your sector to see it properly", "Escolhe o teu setor para veres a sério") }
    var mapSectorHint: String { t("Tap to change sector", "Toca para mudar de setor") }
    var mapVsNational: String { t("vs the country", "vs o país") }
    var mapVsHome: String { t("vs where I am", "vs onde estou") }
    var mapNeedConcelho: String { t("Add your município", "Adiciona o teu concelho") }
    var mapBaselineNationalName: String { t("the mainland average", "a média do continente") }
    var mapYouAreHere: String { t("You're here", "Estás aqui") }
    var mapHomeTag: String { t("You", "Tu") }
    var mapTapHint: String { t("Tap a district to see its numbers.", "Toca num distrito para veres os números.") }
    var mapAllDistricts: String { t("Every district", "Todos os distritos") }
    var mapLegendTop: String { t("+30% or more", "+30% ou mais") }
    var mapLegendBottom: String { t("-30% or less", "-30% ou menos") }
    var mapLegendSame: String { t("about the same", "mais ou menos igual") }
    var mapThinTag: String { t("few data", "poucos dados") }

    func mapBaselineLine(_ baseline: String) -> String {
        t("Monthly average for this sector, compared with \(baseline).",
          "Média mensal deste setor, comparada com \(baseline).")
    }
    func mapCellSize(_ n: Int) -> String {
        t("Based on \(n) employees.", "Com base em \(n) trabalhadores.")
    }
    func mapThinCell(_ n: Int) -> String {
        t("Only \(n) employees in this cell. A handful of people move this number, so treat it lightly.",
          "Só \(n) trabalhadores nesta célula. Um punhado de pessoas mexe com este número, por isso leva-o com calma.")
    }

    var mapNoTenureNote: String {
        t("Sector only. The official tables never cross district with time at the company, and adding the national tenure effect would shift every district by the same amount, so not a single colour or percentage here would change.",
          "Só por setor. As tabelas oficiais nunca cruzam distrito com antiguidade na empresa, e aplicar o efeito nacional da antiguidade mexeria em todos os distritos por igual, por isso nem uma cor nem uma percentagem aqui mudariam.")
    }
    var mapScopeNote: String {
        t("Mainland only, private-contract employees, October 2024. These are averages for everyone in the sector, not for your job.",
          "Só continente, trabalhadores com contrato privado, outubro de 2024. São médias de toda a gente do setor, não da tua profissão.")
    }
    var mapGeoCredit: String { "Fronteiras: CAOP, Direção-Geral do Território" }

    // MARK: v0.9.4 salary explorer

    /// The fork: recording a real change, or trying a number on. Same wording
    /// wherever the user taps to edit their salary.
    var salaryChangeTitle: String { t("Has your salary actually changed?", "O teu salário mudou mesmo?") }
    var salaryChangeMessage: String {
        t("Changing it here replaces the number the whole app works from.",
          "Mudar aqui substitui o número com que a app toda trabalha.")
    }
    var salaryChangeYes: String { t("Yes, update my salary", "Sim, atualizar o meu salário") }
    var salaryChangeNo: String { t("No, I'm just trying a number", "Não, só estou a experimentar um valor") }
    var cancelButton: String { t("Cancel", "Cancelar") }

    var explorerNudgeTitle: String { t("Try another salary", "Experimenta outro salário") }
    var explorerNudgeSub: String {
        t("See where a different number would put you, without changing yours.",
          "Vê onde é que outro valor te punha, sem mexer no teu.")
    }
    var explorerTitle: String { t("Try a salary", "Experimentar um salário") }
    var explorerSub: String {
        t("Uses your own tax situation. Nothing here changes your real salary.",
          "Usa a tua situação fiscal. Nada aqui muda o teu salário a sério.")
    }
    var explorerEmpty: String { t("Type an amount to see where it lands.", "Escreve um valor para veres onde fica.") }
    var explorerPercentileSuffix: String {
        t("of people in Portugal earn less than this", "das pessoas em Portugal ganham menos do que isto")
    }
    var explorerNet: String { t("Net / month", "Líquido / mês") }
    var explorerGross: String { t("Gross / month", "Bruto / mês") }
    var explorerVsYours: String { t("vs your salary", "vs o teu salário") }
    var explorerNoCohorts: String {
        t("Add your sector, age or município in your profile and they show up here too.",
          "Adiciona o setor, a idade ou o concelho no teu perfil e aparecem aqui também.")
    }
    func explorerPercentileShort(_ pct: Int) -> String {
        t("top \(100 - pct)%", "top \(100 - pct)%")
    }
    var explorerNotSaved: String {
        t("This is only a simulation. Your salary in the app has not moved.",
          "Isto é só uma simulação. O teu salário na app não mexeu.")
    }
    var explorerPromote: String { t("Actually, make this my salary", "Afinal, passar a ser o meu salário") }
    var explorerClose: String { t("Done exploring", "Já vi o que queria") }

    // MARK: v0.10 Grow

    var growNudgeTitle: String { t("Stay or move?", "Ficar ou mudar?") }
    var growNudgeSub: String {
        t("What your pay does over the next years, and what changing job would do to it.",
          "O que o teu salário faz nos próximos anos, e o que mudar de emprego lhe fazia.")
    }

    var growTitle: String { t("Grow", "Crescer") }
    func growSub(_ sector: String, years: Int) -> String {
        t("\(sector), \(years) \(years == 1 ? "year" : "years") at your employer.",
          "\(sector), \(years) \(years == 1 ? "ano" : "anos") na empresa.")
    }

    var growEmptyTitle: String { t("Two answers away", "Faltam duas respostas") }
    var growEmptySub: String {
        t("Your sector and how long you have been at your employer. Both come from the same table this screen is built on, so without them there is nothing honest to draw.",
          "O teu setor e há quanto tempo estás na empresa. Os dois vêm da mesma tabela em que este ecrã assenta, por isso sem eles não há nada de honesto para desenhar.")
    }
    var growEmptyButton: String { t("Answer them", "Responder") }

    var growBreakEvenTitle: String { t("A new job has to beat", "Um emprego novo tem de bater") }
    func growBreakEvenSuffix(_ years: Int) -> String {
        t("if you leave after \(years) \(years == 1 ? "year" : "years")",
          "se saíres aos \(years) \(years == 1 ? "ano" : "anos")")
    }
    func growBreakEvenBody(_ sector: String) -> String {
        t("That is the pay step people at that tenure have in \(sector.lowercased()), and you give it up the day you leave. Anything less than this and the move costs you money.",
          "É esse o degrau de quem tem essa antiguidade em \(sector.lowercased()), e perde-lo no dia em que sais. Menos do que isto e mudar fica-te caro.")
    }

    var growMetricNet: String { t("Net", "Líquido") }
    var growMetricGross: String { t("Gross", "Bruto") }
    var growMetricPercentile: String { t("Position", "Posição") }
    var growNominal: String { t("In euros", "Em euros") }
    var growReal: String { t("Today's money", "Dinheiro de hoje") }

    var growLegendStay: String { t("Staying", "Ficar") }
    var growLegendMove: String { t("Changing job", "Mudar de emprego") }

    var growToday: String { t("Today", "Hoje") }
    func growYears(_ n: Int) -> String {
        t("\(n) \(n == 1 ? "year" : "years")", "\(n) \(n == 1 ? "ano" : "anos")")
    }
    func growTenureAt(_ n: Int) -> String {
        t("\(n) \(n == 1 ? "year" : "years") at that employer", "\(n) \(n == 1 ? "ano" : "anos") nessa empresa")
    }

    var growScrubNet: String { t("Net / month", "Líquido / mês") }
    var growScrubGross: String { t("Gross / month", "Bruto / mês") }
    var growScrubEmployer: String { t("Costs the employer", "Custa à empresa") }
    func growScrubVsStay(_ amount: String) -> String {
        t("\(amount) a month against staying put.", "\(amount) por mês em relação a ficar.")
    }
    var growEditToday: String { t("Change the starting salary", "Mudar o salário de partida") }

    func growCumulativeTitle(_ years: Int) -> String {
        t("Over \(years) years, in total", "Ao fim de \(years) anos, no total")
    }
    var growCumulativeAhead: String { t("ahead by changing job", "a mais por mudares de emprego") }
    var growCumulativeBehind: String { t("behind by changing job", "a menos por mudares de emprego") }
    func growCrossover(_ year: Int) -> String {
        t("Changing job pulls ahead in total in year \(year).",
          "Mudar de emprego passa à frente no total no ano \(year).")
    }
    func growNoCrossover(_ years: Int) -> String {
        t("Changing job never pulls ahead in total inside \(years) years.",
          "Mudar de emprego nunca passa à frente no total dentro de \(years) anos.")
    }

    var growLeversButton: String { t("Change something", "Mudar alguma coisa") }
    var growLeversNone: String { t("Right now this is just you, staying where you are.", "Neste momento és só tu, a ficar onde estás.") }
    var growLeversTitle: String { t("Change something", "Mudar alguma coisa") }
    var growLeversSub: String {
        t("Nothing you do here is saved. Your real salary and profile stay exactly as they are.",
          "Nada do que fizeres aqui fica guardado. O teu salário e o teu perfil ficam na mesma.")
    }
    var growLeversDone: String { t("See the path", "Ver o percurso") }

    var growLeverHorizon: String { t("How far ahead", "Até quando") }
    var growLeverCadence: String { t("Changing employer", "Mudar de empresa") }
    var growCadenceNever: String { t("Never", "Nunca") }
    func growCadenceEvery(_ years: Int) -> String { t("Every \(years) yrs", "De \(years) em \(years) anos") }
    var growCadenceNote: String {
        t("After a move the model gives you the sector's own tenure shape from year zero. That is generous for anyone moving very often, which is why moving yearly is not offered.",
          "Depois de uma mudança o modelo dá-te a forma da antiguidade do próprio setor a partir do ano zero. Isso é generoso para quem muda muitas vezes, por isso mudar todos os anos não aparece aqui.")
    }

    var growLeverExpected: String { t("What you would negotiate", "O que ias negociar") }
    var growPerMonthGross: String { t("gross / month", "bruto / mês") }
    func growBreakEvenHint(_ pct: String, years: Int) -> String {
        t("At \(years) years, leaving gives up \(pct). Beat that and the move is worth something.",
          "Aos \(years) anos, sair abdica de \(pct). Passa disso e a mudança vale alguma coisa.")
    }
    func growExpectedImplied(_ pct: String) -> String {
        t("That is \(pct) against what staying would have paid you that year.",
          "Isso é \(pct) em relação ao que ficar te pagava nesse ano.")
    }
    var growExpectedEmpty: String {
        t("Empty means the model assumes you match your salary and nothing more, so the chart shows what leaving costs on its own.",
          "Vazio quer dizer que o modelo assume que igualas o teu salário e mais nada, por isso o gráfico mostra o que sair custa por si só.")
    }

    var growLeverSector: String { t("Sector", "Setor") }
    var growSameAsNow: String { t("Same as now", "O mesmo de agora") }
    var growSectorNote: String {
        t("Changing sector keeps your standing: the model puts you at the same distance from the average there as you are from the average here.",
          "Mudar de setor mantém a tua posição: o modelo põe-te à mesma distância da média de lá que estás da média daqui.")
    }
    var growLeverDistrict: String { t("District", "Distrito") }
    var growNoDistrict: String { t("Not set", "Por definir") }
    var growRegionNote: String {
        t("The district table is not crossed with tenure, so a district can only shift the whole path up or down. It cannot bend it.",
          "A tabela dos distritos não cruza com a antiguidade, por isso um distrito só consegue subir ou descer o percurso todo. Não o consegue dobrar.")
    }

    var growLeverFiscal: String { t("Tax and prices", "Impostos e preços") }
    var growBracketsTitle: String { t("Escalões follow prices", "Escalões acompanham os preços") }
    var growBracketsShort: String { t("indexed escalões", "escalões indexados") }
    var growBracketsHint: String {
        t("Off means the 2026 escalões stay frozen while pay rises, so a bigger slice of it is taxed each year.",
          "Desligado quer dizer que os escalões de 2026 ficam congelados enquanto o salário sobe, por isso uma fatia maior é tributada todos os anos.")
    }
    var growPayGrowth: String { t("Pay growth across the economy", "Subida geral dos salários") }
    var growPayGrowthHint: String {
        t("Zero by default, on purpose: at zero every euro on this screen is in today's money and the path shows the tenure effect and nothing else.",
          "Zero por omissão, de propósito: a zero todos os euros deste ecrã são dinheiro de hoje e o percurso mostra só o efeito da antiguidade.")
    }
    var growInflation: String { t("Inflation", "Inflação") }
    var growInflationHint: String {
        t("Used for the today's-money view and, when it is on, for the escalões.",
          "Serve para a vista em dinheiro de hoje e, quando está ligado, para os escalões.")
    }
    var growPerYearShort: String { t("yr", "ano") }

    func growWaterfallTitle(_ years: Int) -> String {
        t("Where the \(years) years came from", "De onde vêm os \(years) anos")
    }
    var growWaterfallStart: String { t("Today", "Hoje") }
    func growWaterfallLabel(_ id: String) -> String {
        switch id {
        case "tenure": return t("Tenure", "Antiguidade")
        case "sector": return t("New sector", "Setor novo")
        case "region": return t("New district", "Distrito novo")
        case "moving": return t("Changing job", "Mudar de emprego")
        case "growth": return t("Pay growth", "Subida geral")
        case "tax": return t("Tax and SS", "Impostos e SS")
        case "inflation": return t("Inflation", "Inflação")
        default: return id
        }
    }
    var growWaterfallNote: String {
        t("The pay-side steps are all multipliers, so the order they are applied in cannot change the total. Tax is not a multiplier and inflation is a change of unit, so those two always come last, in that order.",
          "Os passos do lado do salário são todos multiplicadores, por isso a ordem em que se aplicam não muda o total. O imposto não é multiplicador e a inflação é uma mudança de unidade, por isso esses dois vêm sempre no fim, por essa ordem.")
    }

    var growAssumptionsTitle: String { t("What this takes for granted", "O que isto dá como certo") }
    var growAssumptionCrossSection: String {
        t("This is a photograph of October 2024, not a career. The people in the 20+ tenure band are not the people in the first-year band twenty years later: they are the ones who stayed, in a different mix of jobs. So every point answers what people at that tenure earn today, never what you will earn then.",
          "Isto é uma fotografia de outubro de 2024, não uma carreira. Quem está no escalão dos 20+ anos não é quem está no primeiro ano vinte anos depois: são os que ficaram, noutra mistura de funções. Por isso cada ponto responde ao que ganha hoje quem tem essa antiguidade, nunca ao que tu vais ganhar.")
    }
    var growAssumptionAnchor: String {
        t("Your path starts on your real salary and keeps your distance from the average. That assumes the shape of the tenure steps is the same for everyone in your sector and only the level differs.",
          "O teu percurso começa no teu salário a sério e mantém a tua distância à média. Isso assume que a forma dos degraus da antiguidade é igual para toda a gente do teu setor e que só o nível é que muda.")
    }
    func growAssumptionEntrant(_ amount: String) -> String {
        t("First-year people in this sector average \(amount) a month. That is here as a reference only: it is full of people entering the labour market, so it is not where an experienced person lands after a move, and the model never puts you there.",
          "Quem está no primeiro ano neste setor ganha em média \(amount) por mês. Está aqui só como referência: é um escalão cheio de gente a entrar no mercado de trabalho, por isso não é onde alguém com experiência cai depois de mudar, e o modelo nunca te põe lá.")
    }
    var growAssumptionDip: String {
        t("In this sector pay does not rise across every tenure band. The dip you can see is what the survey found, and it is drawn rather than smoothed away.",
          "Neste setor o salário não sobe de escalão para escalão em todos eles. A descida que se vê é o que o inquérito encontrou, e está desenhada em vez de alisada.")
    }
    var growAssumptionDipMoving: String {
        t("Because pay in this sector does not climb with tenure, every move puts you back on the only part of the curve that rises, while staying drifts down. Over a long horizon that gap grows fast. It comes out of the assumption above, not out of anything the survey measured about people who change job.",
          "Como neste setor o salário não sobe com a antiguidade, cada mudança volta a pôr-te na única parte da curva que sobe, enquanto ficar vai descendo. Num horizonte longo essa diferença cresce depressa. Vem da suposição acima, não de algo que o inquérito tenha medido sobre quem muda de emprego.")
    }
    var growAssumptionRegion: String {
        t("The district figure comes from a table that has no tenure in it, so it moves the whole path by one ratio and cannot say whether tenure pays differently there.",
          "O valor do distrito vem de uma tabela sem antiguidade, por isso mexe no percurso todo por um só rácio e não consegue dizer se a antiguidade paga de forma diferente lá.")
    }
    var growAssumptionJovem: String {
        t("Your IRS Jovem step-down is applied year by year, which is why the net line can fall in a year the gross line rises. The app knows your percentage but not which benefit year produced it, so it assumes the first year of that step, which is the most generous reading.",
          "A descida do teu IRS Jovem é aplicada ano a ano, e é por isso que a linha do líquido pode cair num ano em que a do bruto sobe. A app sabe a tua percentagem mas não sabe que ano do benefício a produziu, por isso assume o primeiro ano desse degrau, que é a leitura mais generosa.")
    }
    var growAssumptionBracketsOn: String {
        t("The escalões and the IRS Jovem ceiling are being grown with prices, so bracket creep is switched off.",
          "Os escalões e o tecto do IRS Jovem estão a subir com os preços, por isso não há subida de escalão por inflação.")
    }
    var growAssumptionBracketsOff: String {
        t("The 2026 escalões and the IRS Jovem ceiling are held frozen, so any pay growth is taxed a little harder every year.",
          "Os escalões de 2026 e o tecto do IRS Jovem estão congelados, por isso qualquer subida de salário é tributada um pouco mais cada ano.")
    }
    var growAssumptionNothingSaved: String {
        t("Nothing on this screen is saved. Your salary and your profile are untouched.",
          "Nada deste ecrã fica guardado. O teu salário e o teu perfil ficam intactos.")
    }
}
