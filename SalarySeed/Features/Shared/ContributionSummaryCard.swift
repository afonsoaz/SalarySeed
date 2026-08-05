import SwiftUI

/// v0.14: the row that would be sent, in words, shown on the consent screen
/// itself rather than one tap away.
///
/// WHY IT DECODES THE ROW INSTEAD OF READING THE STORE. This is the whole
/// integrity property. If it read `store.concelho` it would happily print the
/// município, which the payload does not contain, and the screen would be
/// describing a row that does not exist. Reading `Contribution` back means the
/// card cannot show a field the payload lacks, and cannot hide one it has: if
/// the coarsening drops something to a band, the card shows the band.
///
/// It also means adding a field to `Contribution` and forgetting it here is a
/// visible omission rather than a silent one, which the verification kit checks
/// by making sure every `CodingKey` name appears in `summaryFields` below.
struct ContributionSummaryCard: View {
    let row: Contribution
    let s: Strings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(row.summaryFields(s).enumerated()), id: \.offset) { index, field in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.cardBorder.opacity(0.5))
                        .frame(height: 1)
                }
                HStack(alignment: .top, spacing: 10) {
                    Text(field.label)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 104, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(field.value)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(field.answered ? Theme.textPrimary : Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
    }
}

/// One line of the card.
struct ContributionField {
    let label: String
    let value: String
    /// False when the payload carries a null here, so an unanswered question
    /// reads as unanswered rather than as an empty row.
    let answered: Bool
}

extension Contribution {

    /// Every field of the payload, decoded back into the words the app uses
    /// elsewhere. `schema` is the only key deliberately left out: it is a number
    /// about the format, not about the person, and printing it would be noise.
    ///
    /// Fields are grouped where the grouping is what a person would read as one
    /// fact (pay and its schedule; working time and its hours). Every CodingKey
    /// still appears somewhere in here, which is what the kit checks.
    func summaryFields(_ s: Strings) -> [ContributionField] {
        var out: [ContributionField] = [
            ContributionField(label: s.contribRowCode,
                              value: ContributionToken.short(token), answered: true),
            ContributionField(label: s.contribRowYear,
                              value: String(year), answered: true),
            ContributionField(label: s.contribRowPay,
                              value: payLine(s), answered: true),
        ]
        if let netEntered {
            out.append(ContributionField(label: s.contribRowNetTyped,
                                         value: eur(Double(netEntered)), answered: true))
        }
        out.append(band(s.contribRowAjudas, ajudasBand, s))
        out.append(band(s.contribRowVariable, variableBand, s))
        out.append(text(s.contribRowSector, Sector(rawValue: sector ?? "")?.label(pt: s.pt), s))
        out.append(text(s.contribRowJob, JobTitleCatalog.title(jobTitleID)?.label(pt: s.pt), s))
        out.append(text(s.contribRowTenure, TenureBand(rawValue: tenureBand ?? "")?.label(pt: s.pt), s))
        out.append(text(s.contribRowEmployer, EmployerKind(rawValue: employerKind ?? "")?.label(pt: s.pt), s))
        out.append(text(s.contribRowHours, hoursLine(s), s))
        out.append(text(s.contribRowRegion, PTRegion(rawValue: region ?? "")?.label, s))
        out.append(text(s.contribRowAge, AgeBand(rawValue: ageBand ?? "")?.label, s))
        out.append(text(s.contribRowEducation, EducationLevel(rawValue: education ?? "")?.label(pt: s.pt), s))
        out.append(text(s.contribRowGender, Gender(rawValue: gender ?? "")?.label(pt: s.pt), s))
        return out
    }

    /// gross_monthly, kind_entered and pay_schedule read as one fact.
    private func payLine(_ s: Strings) -> String {
        let kind = kindEntered == AmountKind.net.rawValue
            ? AmountKind.net.label(pt: s.pt)
            : AmountKind.gross.label(pt: s.pt)
        return "\(eur(Double(grossMonthly))) · \(kind.lowercased()) · \(paySchedule)x"
    }

    /// work_schedule and hours_band, likewise.
    private func hoursLine(_ s: Strings) -> String? {
        let schedule = WorkSchedule(rawValue: workSchedule ?? "")?.label(pt: s.pt)
        let hours = hoursBand.map { s.contribBandLabel($0) }
        switch (schedule, hours) {
        case let (schedule?, hours?): return "\(schedule) · \(hours)"
        case let (schedule?, nil): return schedule
        case let (nil, hours?): return hours
        default: return nil
        }
    }

    private func band(_ label: String, _ raw: String?, _ s: Strings) -> ContributionField {
        text(label, raw.map { s.contribBandLabel($0) }, s)
    }

    private func text(_ label: String, _ value: String?, _ s: Strings) -> ContributionField {
        ContributionField(label: label,
                          value: value ?? s.contribNotAnswered,
                          answered: value != nil)
    }
}
