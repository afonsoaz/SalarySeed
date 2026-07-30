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

    /// v0.8.2 combined salary step: greet by name and ask simply.
    func salaryQuestion(_ name: String?) -> String {
        if let name, !name.isEmpty { return t("\(name), how much do you make?", "\(name), quanto ganhas?") }
        return t("How much do you make?", "Quanto ganhas?")
    }
    var perMonthSuffix: String { t("/mo", "/mês") }
    var okButton: String { t("OK", "OK") }

    var monthsHint: String { t("14 is the norm: holiday and Christmas pay come separately. With 12, those subsidies are split across every month (duodécimos).", "14 é o normal: os subsídios de férias e Natal vêm à parte. Com 12, esses subsídios vêm repartidos por todos os meses (duodécimos).") }
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

    var theDetails: String { t("Details", "Detalhe") }
    func perPeriod(yearly: Bool) -> String { t(yearly ? "per year" : "per month", yearly ? "por ano" : "por mês") }
    var cardYourSS: String { t("Social Security (employee)", "Segurança Social (trabalhador)") }
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


    var whatIf: String { t("What if…", "E se…") }
    // v0.10.1: the Home percentile card and the Grow nudge card are gone, and
    // their copy went with them rather than sitting here unreferenced. The
    // percentile has a whole tab; Grow has a tinted tab item.
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
    var releaseToReset: String { t("Release to reset", "Larga para voltar") }
    // v0.8: percentile explorer (drag a percentile, see the salary there)
    var exploreByPercentile: String { t("Explore by percentile", "Explora por percentil") }
    var exploreHint: String { t("Drag the handle. Let go to return to you.", "Arrasta o cursor. Larga para voltar a ti.") }
    func percentileEarns(_ p: String) -> String { t("The \(p) percentile earns", "O percentil \(p) ganha") }
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
    func medianCaption(median: String, diff: Double, diffText: String) -> String {
        if abs(diff) < 40 { return t("Median: \(median) gross. You're right at the median.", "Mediana: \(median) brutos. Estás mesmo na mediana.") }
        if diff > 0 { return t("Median: \(median) gross. You're \(diffText) above.", "Mediana: \(median) brutos. Estás \(diffText) acima.") }
        return t("Median: \(median) gross. You're \(diffText) below.", "Mediana: \(median) brutos. Estás \(diffText) abaixo.")
    }
    var thinChip: String { t("Rough estimate, small sample", "Estimativa aproximada, amostra pequena") }
    var edgeChip: String { t("Few data points at this level", "Poucos dados neste nível") }
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
    var sectorAddHint: String { t("Compare with your sector and time at the company", "Compara com o teu setor e antiguidade na empresa") }
    var sectorKicker: String { t("Sector + time at the company", "Setor + antiguidade na empresa") }
    var tenureQuestion: String { t("How many years at your current employer?", "Há quantos anos estás na empresa onde trabalhas?") }
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

    /// v0.12: what the green button DOES, for the two signals that open a sheet.
    /// It used to carry the destination's title, so the job card asked "What do
    /// you actually do?" and offered a button reading "What do you do?".
    func enrichOpenLabel(_ id: String) -> String {
        switch id {
        case "jobTitle": return t("Select job", "Escolher profissão")
        case "variablePay": return t("Add bonus", "Adicionar prémios")
        default: return t("Answer", "Responder")
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
    // v0.12 removed the paragraph explaining why the app asks for the município
    // rather than the district. Nobody decides whether to answer on the strength
    // of how NUTS boundaries work, and the derived region shown right under the
    // picker already makes the point in three words.
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
    // v0.12: the two ways out, both starting with "Ok" and both saying what they
    // do to the stored salary, so neither is the button you press by accident.
    var explorerKeep: String { t("Ok, keep my salary", "Ok, manter salário atual") }
    var explorerChange: String { t("Ok, change my salary", "Ok, alterar salário") }

    // MARK: v0.10 Grow


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
    var growPerYearOfTenure: String { t("a year, if you stay", "por ano, se ficares") }
    func growBreakEvenBody(_ total: String, years: Int) -> String {
        t("That is what time at one employer is worth in your sector. Over \(years) years the tenure step adds up to \(total), and you hand all of it back the day you leave, so a new job has to beat that yearly rate just to keep you level.",
          "É isso que o tempo na mesma empresa vale no teu setor. Ao fim de \(years) anos o degrau da antiguidade soma \(total), e devolves tudo no dia em que sais, por isso um emprego novo tem de bater essa taxa anual só para ficares na mesma.")
    }
    func growBreakEvenFlat(_ sector: String) -> String {
        t("In \(sector.lowercased()) pay does not climb with time at one employer, so staying is not buying you anything and leaving costs you nothing.",
          "Em \(sector.lowercased()) o salário não sobe com o tempo na mesma empresa, por isso ficar não te está a comprar nada e sair não te custa nada.")
    }
    var growBreakEvenNote: String {
        t("Leaving resets your time at the company to zero, so the whole step goes, not just the last year of it.",
          "Sair põe o teu tempo na empresa a zero, por isso vai o degrau todo, não só o último ano dele.")
    }

    // v0.10.1: the chart plots one quantity, gross, so the metric picker went.
    var growChartTitle: String { t("Gross per month", "Bruto por mês") }
    var growNominal: String { t("In euros", "Em euros") }
    var growReal: String { t("Today's money", "Dinheiro de hoje") }

    func growInYearsStaying(_ years: Int) -> String {
        t("In \(years) years, staying put", "Daqui a \(years) anos, se ficares")
    }
    func growVsToday(_ amount: String, _ pct: String) -> String {
        t("\(amount) a month against today (\(pct))", "\(amount) por mês em relação a hoje (\(pct))")
    }
    var growWithYourChanges: String { t("With your changes", "Com as tuas mudanças") }
    func growVsStaying(_ amount: String) -> String {
        t("\(amount) against staying put", "\(amount) em relação a ficar")
    }
    func growProjectionUnit(_ todaysMoney: Bool) -> String {
        if todaysMoney {
            return t("Gross per paid month, in today's money.", "Bruto por mês pago, em dinheiro de hoje.")
        }
        return t("Gross per paid month. GEP publishes gross pay, so that is what the whole projection is made of.",
                 "Bruto por mês pago. O GEP publica o ganho bruto, e é disso que a projeção toda é feita.")
    }

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

    var growLeversButton: String { t("Change parameters", "Alterar parâmetros") }
    var growLeversNone: String { t("Right now this is just you, staying where you are.", "Neste momento és só tu, a ficar onde estás.") }
    var growLeversTitle: String { t("Change parameters", "Alterar parâmetros") }
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
    /// v0.12: this now follows a euro amount, so it says WHICH change that amount
    /// belongs to. Deliberately short, and without the year in it: the list right
    /// underneath gives every change its own year and its own figure, and a long
    /// suffix beside a 30pt number wraps to three lines on a small phone.
    var growPerMoveSuffix: String {
        t("a month, at the first change", "por mês, na primeira mudança")
    }
    /// One change of employer: the salary before it and the salary after it.
    func growStepArrow(_ from: String, _ to: String) -> String { "\(from) → \(to)" }
    var growMoreTitle: String { t("Change more", "Alterar mais") }
    var growRateMoving: String { t("Changing job is worth, per year", "Mudar de emprego vale, por ano") }
    var growRateStaying: String { t("Staying is worth, per year", "Ficar vale, por ano") }
    func growMoveBeats(_ points: String) -> String {
        t("That beats staying by \(points) points a year.",
          "Isso bate ficar em \(points) pontos por ano.")
    }
    func growMoveLoses(_ points: String) -> String {
        t("That is \(points) points a year short of what staying is worth, so these moves cost you.",
          "Isso fica \(points) pontos por ano abaixo do que ficar vale, por isso estas mudanças saem-te caras.")
    }
    func growPremiumNote(_ years: Int) -> String {
        t("The same raise is taken at every change, measured against what you were earning the year before. Both rates above are what each path actually compounds to over \(years) years, so they always match the chart.",
          "O mesmo aumento é levado em cada mudança, medido contra o que ganhavas no ano anterior. As duas taxas acima são o que cada percurso rende de facto ao longo de \(years) anos, por isso batem sempre certo com o gráfico.")
    }
    func growCadenceEveryAt(_ years: Int, _ premium: String) -> String {
        t("\(premium) every \(years) yrs", "\(premium) de \(years) em \(years) anos")
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
    var growAssumptionGross: String {
        t("Everything on the path is gross, because that is what GEP publishes. Net appears only when you hold a single year, where it is worked out with your own tax situation.",
          "Tudo no percurso é bruto, porque é isso que o GEP publica. O líquido só aparece quando seguras um ano, e aí é calculado com a tua situação fiscal.")
    }
    func growAssumptionEntrant(_ amount: String) -> String {
        t("First-year people in this sector average \(amount) a month. That is here as a reference only: it is full of people entering the labour market, so it is not where an experienced person lands after a move, and the model never puts you there.",
          "Quem está no primeiro ano neste setor ganha em média \(amount) por mês. Está aqui só como referência: é um escalão cheio de gente a entrar no mercado de trabalho, por isso não é onde alguém com experiência cai depois de mudar, e o modelo nunca te põe lá.")
    }
    var growAssumptionDip: String {
        t("In this sector pay does not rise across every tenure band. The dip you can see is what the survey found, and it is drawn rather than smoothed away.",
          "Neste setor o salário não sobe de escalão para escalão em todos eles. A descida que se vê é o que o inquérito encontrou, e está desenhada em vez de alisada.")
    }
    var growAssumptionMoverFrozen: String {
        t("After your first change of employer, your pay only moves when you negotiate. The survey measures what time at ONE company is worth, and says nothing about what someone experienced is paid on arrival, so the model does not hand a mover a tenure raise it never measured.",
          "Depois da tua primeira mudança de empresa, o teu salário só mexe quando negoceias. O inquérito mede o que vale o tempo numa SÓ empresa, e não diz nada sobre quanto se paga a alguém com experiência que acaba de chegar, por isso o modelo não dá a quem muda um aumento de antiguidade que nunca mediu.")
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
    // MARK: v0.11 mapSeed, the European half

    var mapScopePortugal: String { t("Portugal", "Portugal") }
    var mapScopeEurope: String { t("Europe", "Europa") }
    var euroTitle: String { t("Your sector across the EU", "O teu setor pela UE") }
    var euroDash: String { "–" }

    var euroUnitEuros: String { t("Absolute salary (€)", "Salário absoluto (€)") }
    var euroUnitPower: String { t("PPP salary (€)", "Salário PPP (€)") }
    /// Shown only under the PPP chip, because it is the only one that needs it.
    var euroPppExplainer: String {
        t("PPP means purchasing power parity: each salary is adjusted for what things cost in that country, so €2,000 in Lisbon and €2,000 in Dublin buy the same amount. Use it to compare living standards, and the absolute figure to compare what lands in the bank.",
          "PPP quer dizer paridade de poder de compra: cada salário é ajustado ao que as coisas custam nesse país, por isso 2.000 € em Lisboa e 2.000 € em Dublin compram o mesmo. Usa isto para comparar nível de vida, e o valor absoluto para comparar o que entra na conta.")
    }

    func euroSectionLine(_ section: String) -> String {
        t("Compared as \"\(section)\", the closest activity Eurostat publishes.",
          "Comparado como \"\(section)\", a atividade mais próxima que o Eurostat publica.")
    }
    func euroCollapsed(_ sectors: String) -> String {
        t("Eurostat groups these together, so this number covers all of them: \(sectors).",
          "O Eurostat junta estes todos, por isso este número cobre-os a todos: \(sectors).")
    }

    var euroTapHint: String {
        t("Tap any country to compare it with Portugal.", "Toca num país para o comparares com Portugal.")
    }
    var euroPortugalShort: String { t("Portugal", "Portugal") }
    /// The magnitude arrives WITHOUT a sign, because "more" and "less" already
    /// carry it. "+127% more" reads as a mistake.
    func euroDirectChange(_ country: String, _ pct: String, _ amount: String, higher: Bool) -> String {
        if higher {
            return t("\(country) pays \(pct) more than Portugal in this activity, a difference of \(amount) a month.",
                     "\(country) paga mais \(pct) do que Portugal nesta atividade, uma diferença de \(amount) por mês.")
        }
        return t("\(country) pays \(pct) less than Portugal in this activity, a difference of \(amount) a month.",
                 "\(country) paga menos \(pct) do que Portugal nesta atividade, uma diferença de \(amount) por mês.")
    }
    var euroReferenceTag: String { t("reference", "referência") }
    var euroPortugalBody: String {
        t("Every percentage on this screen is measured against Portugal, so Portugal itself sits at zero.",
          "Todas as percentagens deste ecrã são medidas contra Portugal, por isso Portugal fica a zero.")
    }
    func euroYourSalaryLine(_ amount: String, purchasingPower: Bool) -> String {
        if purchasingPower {
            return t("Apply that gap to your salary and you get \(amount) a month of what money buys here.",
                     "Aplica essa diferença ao teu salário e dá \(amount) por mês do que o dinheiro compra cá.")
        }
        return t("Apply that gap to your salary and you get \(amount) a month.",
                 "Aplica essa diferença ao teu salário e dá \(amount) por mês.")
    }
    var euroNotAJob: String {
        t("This is the average across a whole activity, not a job. The same number covers a first-year assistant and a department head.",
          "Isto é a média de uma atividade inteira, não de uma função. O mesmo número cobre um assistente no primeiro ano e um diretor de departamento.")
    }
    func euroNoDataBody(_ country: String) -> String {
        t("Eurostat publishes no figure for this activity in \(country). Usually that means there is almost nothing of it there to measure.",
          "O Eurostat não publica valor para esta atividade em \(country). Normalmente é porque quase não existe lá nada para medir.")
    }
    /// English needs 1st / 2nd / 3rd / 21st, not a blanket "th". Portuguese takes
    /// "º" for every number, so only one side of this needs the rule.
    func ordinal(_ n: Int) -> String {
        guard !pt else { return "\(n).º" }
        let suffix: String
        switch (n % 100, n % 10) {
        case (11, _), (12, _), (13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    func euroRank(_ place: Int, of total: Int, purchasingPower: Bool) -> String {
        let nth = ordinal(place)
        if purchasingPower {
            return t("For what the money buys, Portugal is \(nth) of \(total) in this activity.",
                     "Pelo que o dinheiro compra, Portugal é o \(nth) de \(total) nesta atividade.")
        }
        return t("In euros, Portugal is \(nth) of \(total) in this activity.",
                 "Em euros, Portugal é o \(nth) de \(total) nesta atividade.")
    }

    var euroAllCountries: String { t("Every country", "Todos os países") }

    var euroLegendBelow: String { t("below Portugal", "abaixo de Portugal") }
    var euroLegendSame: String { t("about the same", "quase igual") }
    var euroLegendAbove: String { t("above Portugal", "acima de Portugal") }
    var euroLegendNoData: String { t("no figure published", "sem valor publicado") }

    var euroPickSector: String { t("Which sector?", "Que setor?") }
    var euroPickSectorBody: String {
        t("The comparison is per activity, so it needs to know yours first.",
          "A comparação é por atividade, por isso precisa de saber a tua primeiro.")
    }
    var euroPickSectorButton: String { t("Pick my sector", "Escolher o meu setor") }
    var euroNoSection: String { t("No European comparison here", "Sem comparação europeia aqui") }
    func euroNoSectionBody(_ sector: String) -> String {
        t("The European survey does not cover \(sector.lowercased()), so there is nothing to compare against. Agriculture sits outside the survey entirely, and public administration has no published Portuguese figure, which leaves no starting point.",
          "O inquérito europeu não cobre \(sector.lowercased()), por isso não há com o que comparar. A agricultura fica fora do inquérito, e a administração pública não tem valor publicado para Portugal, o que deixa a comparação sem ponto de partida.")
    }

    var euroFootnoteMethod: String {
        t("The percentages come entirely from the European survey, one country divided by Portugal. Your own salary is then moved by that ratio. The Portuguese and European figures are never added together or placed side by side, because they are different surveys of different people in different years.",
          "As percentagens vêm todas do inquérito europeu, um país a dividir por Portugal. O teu salário é depois movido por esse rácio. Os valores portugueses e europeus nunca são somados nem postos lado a lado, porque são inquéritos diferentes, de pessoas diferentes, em anos diferentes.")
    }
    var euroFootnoteVintage: String {
        t("The European survey is from 2022 and runs every four years, so this half of the map is two years older than the Portuguese half.",
          "O inquérito europeu é de 2022 e acontece de quatro em quatro anos, por isso esta metade do mapa é dois anos mais antiga do que a metade portuguesa.")
    }
    var euroFootnoteScope: String {
        t("Employees in companies with 10 or more people. Gross pay, before tax and before Social Security.",
          "Trabalhadores por conta de outrem em empresas com 10 ou mais pessoas. Valor bruto, antes de impostos e de Segurança Social.")
    }
    var euroFootnoteGaps: String {
        t("Cyprus and Malta have no figure for mining or for electricity and gas. Length of service is in the source but is not on this screen yet.",
          "Chipre e Malta não têm valor para as indústrias extractivas nem para a eletricidade e gás. A antiguidade existe na fonte mas ainda não está neste ecrã.")
    }

    var growAssumptionNothingSaved: String {
        t("Nothing on this screen is saved. Your salary and your profile are untouched.",
          "Nada deste ecrã fica guardado. O teu salário e o teu perfil ficam intactos.")
    }

    // MARK: v0.12 consent
    //
    // Written to be true first and inviting second, in that order. Every claim
    // here is one the app can actually keep: no name, no email, no device id,
    // aggregate only, withdrawable in the profile, and the app works the same
    // either way. The reason to say yes is stated as what it produces, which is
    // the comparison itself getting better, rather than as a favour to us.

    var consentTitle: String {
        t("Want your numbers to count?", "Queres que os teus números contem?")
    }
    var consentBody: String {
        t("The official tables are a photograph of 2024 and they stop at broad sectors. What is missing is what people actually earn, by job, now. If you agree, your answers join everyone else's and are only ever shown as totals and averages, never on their own.",
          "As tabelas oficiais são uma fotografia de 2024 e ficam-se por setores largos. O que falta é o que as pessoas ganham mesmo, por profissão, agora. Se concordares, as tuas respostas juntam-se às das outras pessoas e só aparecem em totais e médias, nunca sozinhas.")
    }
    var consentPointShared: String {
        t("Shared: your salary and the profile answers you gave, as anonymous data in a pool.",
          "Partilhado: o teu salário e as respostas do perfil, como dados anónimos num conjunto.")
    }
    var consentPointNotShared: String {
        t("Not shared: your name, your email, your contacts, anything that identifies you or your phone.",
          "Não partilhado: o teu nome, o teu email, os teus contactos, nada que te identifique a ti ou ao telemóvel.")
    }
    var consentPointWithdraw: String {
        t("You can change your mind whenever you want, in the profile tab.",
          "Podes mudar de ideias quando quiseres, no separador do perfil.")
    }
    var consentAccept: String { t("Ok, I agree", "Ok, eu concordo") }
    var consentDecline: String { t("No, thanks", "Não, obrigado") }
    var consentEitherWay: String {
        t("The app works exactly the same either way.",
          "A app funciona exatamente na mesma de qualquer das formas.")
    }

    var consentRowTitle: String { t("Share my data anonymously", "Partilhar os meus dados anonimamente") }
    var consentRowHint: String {
        t("Your salary and profile answers join the pool, shown only as totals and averages. Never your name, your email or anything that identifies you. Off is fine, nothing in the app changes.",
          "O teu salário e as respostas do perfil juntam-se ao conjunto, mostrados só em totais e médias. Nunca o teu nome, o teu email ou o que quer que te identifique. Desligado não faz mal, nada muda na app.")
    }
}
