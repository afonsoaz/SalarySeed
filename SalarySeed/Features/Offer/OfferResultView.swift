import SwiftUI

/// v1.5: the offer, side by side with the job the reader has.
///
/// Five blocks, in the order of the questions people arrive with: what reaches
/// me, where the difference goes, where each sits against other people, what
/// staying would pay instead, and what none of this counts.
///
/// THE COMPARISON IS RECOMPUTED ON EVERY DRAW AND NEVER STORED. Only the terms
/// are kept, so a change to the reader's own salary, household or sector shows
/// up here immediately, with nothing stale to reconcile.
///
/// It writes nothing. Changing and removing the offer are handed back to
/// `OfferView`, which owns the one write.
struct OfferResultView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    let terms: OfferTerms
    let onEdit: () -> Void
    let onRemove: () -> Void

    @State private var period: ResultPeriod = .m14
    @State private var pickedInitial = false
    @State private var askingRemove = false
    @State private var showSectorTenure = false

    private var s: Strings { store.s }
    private var per: String { s.periodSuffix(period.modeIndex) }

    var body: some View {
        let r = store.offerComparison(terms)
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                summary
                reaches(r)
                tax(r)
                peers(r)
                staying(r)
                leavesOut
                actions
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .onAppear {
            // As Home does: open on the reader's own schedule, then leave the
            // choice alone.
            if !pickedInitial {
                period = store.schedule == .twelve ? .m12 : .m14
                pickedInitial = true
            }
        }
        .sheet(isPresented: $showSectorTenure) { SectorTenureSheet() }
    }

    // MARK: Header and the offer itself

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("offerSeed")
                .appFont(12)
                .foregroundStyle(Theme.accent)
            Text(s.offerResultTitle)
                .appFont(22, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var summaryLine: String {
        let shown = terms.inputYearly ? terms.amount * terms.schedule.months : terms.amount
        return s.offerSummary(eur(shown), payments: Int(terms.schedule.months),
                              gross: terms.kind == .gross, yearly: terms.inputYearly)
    }

    private var placeAndSector: String {
        let place = terms.concelho?.name ?? s.offerPlaceNone
        guard let sector = terms.sector else { return place }
        return "\(place) · \(sector.label(pt: s.pt))"
    }

    private var summary: some View {
        Button(action: onEdit) {
            SignalRow(icon: "briefcase", iconTint: Theme.accent,
                      title: summaryLine, subtitle: placeAndSector) {
                EditGlyph()
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(s.offerEdit)
    }

    // MARK: a. What reaches you

    private func reaches(_ r: OfferComparison.Result) -> some View {
        // Whole euros first, so the difference above is the difference of the
        // two figures under it. Each column is rounded the way Home rounds it,
        // so "now" is still Home's figure; rounded one by one, the hero and its
        // columns could disagree by a euro.
        let now = WaterfallRows.whole(r.now.pocket(in: period))
        let offer = WaterfallRows.whole(r.offer.pocket(in: period))
        let delta = offer - now
        let same = delta == 0
        let grossDelta = (r.offer.grossMonthly * period.factor(months: r.offer.months))
            - (r.now.grossMonthly * period.factor(months: r.now.months))
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(s.offerReachesTitle)
            // The same quiet lens Home and Tax use, because it is the same lens:
            // ×12, ×14 or a year, read the way Home reads it.
            PeriodSwitch(selection: $period)

            VStack(alignment: .leading, spacing: 2) {
                Text(eur(abs(delta)))
                    .appFont(44, weight: .medium)
                    .foregroundStyle(same ? Theme.textPrimary : (delta > 0 ? Theme.accent : Theme.danger))
                    .contentTransition(.numericText())
                Text(same ? s.offerHeroSame(per) : s.offerHeroCaption(per, more: delta > 0))
                    .appFont(13)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(same
                ? s.offerHeroSame(s.periodVoice(period.modeIndex))
                : s.offerHeroVoice(eur(abs(delta)), per: s.periodVoice(period.modeIndex), more: delta > 0))

            sideBySide(
                column(s.offerNowLabel, value: now, allowance: r.now.allowance(in: period), accent: false),
                column(s.offerOfferLabel, value: offer, allowance: r.offer.allowance(in: period), accent: true)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(s.offerGrossLine(signedEur(grossDelta), per: per))
                    .appFont(12)
                    .foregroundStyle(Theme.textSecondary)
                if let caption = s.offerPeriodCaption(period.modeIndex) {
                    Text(caption)
                        .appFont(11)
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func column(_ title: String, value: Double, allowance: Double, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)
            Text(eur(value))
                .appFont(24, weight: .medium)
                .foregroundStyle(accent ? Theme.accent : Theme.textPrimary)
                .contentTransition(.numericText())
            Text(allowance > 0 ? s.offerColumnWithAllowance(eur(allowance)) : s.offerColumnNet)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    /// Two cards across, or one above the other once they stop fitting.
    /// Reflow, do not shrink.
    @ViewBuilder
    private func sideBySide<A: View, B: View>(_ a: A, _ b: B) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 10) { a; b }
        } else {
            HStack(alignment: .top, spacing: 10) { a; b }
        }
    }

    // MARK: b. Where the difference goes

    private func tax(_ r: OfferComparison.Result) -> some View {
        let now = r.nowYear.shown
        let offer = r.offerYear.shown
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(s.offerTaxTitle) { SectionHint(s.offerTaxHint) }

            VStack(spacing: 10) {
                if !typeSize.isAccessibilitySize {
                    PairRow(label: "", now: s.offerNowLabel, offer: s.offerOfferLabel,
                            nowWord: s.offerNowLabel, offerWord: s.offerOfferLabel, faint: true)
                        .accessibilityHidden(true)
                }
                pair(s.grossWord, now.gross, offer.gross)
                pair(s.offerSSLabel, now.socialSecurity, offer.socialSecurity)
                pair(s.offerIRSLabel, now.irs, offer.irs)
                Divider().overlay(Theme.cardBorder)
                pair(s.offerAfterTaxLabel, now.afterTax, offer.afterTax, strong: true)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            if let keep = r.keepRate {
                keepLine(keep, grossDelta: offer.gross - now.gross, afterTaxDelta: offer.afterTax - now.afterTax)
            }

            VStack(spacing: 10) {
                pair(s.offerEmployerLabel, now.employerCost, offer.employerCost)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                if !r.sameTaxTable {
                    note(s.offerTablesDiffer(now: s.payslipRegionName(r.nowJob.taxRegion),
                                             offer: s.payslipRegionName(r.offerJob.taxRegion)))
                }
                if terms.taxRegionAssumed {
                    note(s.offerPlaceAssumed)
                }
                note(s.offerTaxNote)
            }

            allowances(r)
        }
    }

    private func pair(_ label: String, _ now: Double, _ offer: Double, strong: Bool = false) -> some View {
        PairRow(label: label, now: eur(now), offer: eur(offer),
                nowWord: s.offerNowLabel, offerWord: s.offerOfferLabel, strong: strong)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(s.offerPairVoice(label, now: eur(now), offer: eur(offer)))
    }

    private func keepLine(_ keep: Double, grossDelta: Double, afterTaxDelta: Double) -> some View {
        let cents = Int((keep * 100).rounded())
        let text = grossDelta > 0
            ? s.offerKeep(eur(grossDelta), kept: eur(afterTaxDelta), cents: cents)
            : s.offerKeepLess(eur(-grossDelta), felt: eur(-afterTaxDelta), cents: cents)
        return Text(text)
            .appFont(14, weight: .medium)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The app's own question, asked of an offer: how much of this is paid in a
    /// form that builds nothing for later. The contribution figure is exact; no
    /// pension figure, because the only pension model in the app calls itself a
    /// placeholder.
    @ViewBuilder
    private func allowances(_ r: OfferComparison.Result) -> some View {
        let rate = TaxEngine.employeeSSRate + TaxEngine.employerSSRate
        let offerAllowance = r.offerJob.ajudasMonthly
        let nowAllowance = r.nowJob.ajudasMonthly
        if offerAllowance > 0 || nowAllowance > 0 {
            VStack(alignment: .leading, spacing: 8) {
                if offerAllowance > 0 {
                    Text(s.offerAllowanceOffer(eur(offerAllowance), contributions: eur(offerAllowance * 12 * rate)))
                }
                if nowAllowance > 0 {
                    Text(s.offerAllowanceNow(eur(nowAllowance), contributions: eur(nowAllowance * 12 * rate)))
                }
            }
            .appFont(12.5)
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
        }
        if offerAllowance == 0 {
            note(s.offerNoAllowanceCounted)
        }
    }

    // MARK: c. Against other people

    private func peers(_ r: OfferComparison.Result) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(s.offerPeersTitle) { SectionHint(s.offerPeersHint) }

            standingRow(icon: "globe.europe.africa", title: s.allPortugal, subtitle: s.offerRowNationalSub,
                        now: PercentileEngine.shown(r.national.now), offer: PercentileEngine.shown(r.national.offer))

            if let st = r.sector {
                standingRow(icon: "building.2", title: s.offerRowSectorTitle, subtitle: sectorSubtitle(r),
                            now: st.now?.percentile, offer: st.offer?.percentile)
            }
            if let st = r.region {
                standingRow(icon: "map", title: s.offerRowRegionTitle, subtitle: regionSubtitle(r),
                            now: st.now?.percentile, offer: st.offer?.percentile)
            }
            if let st = r.age, let band = store.ageBand {
                standingRow(icon: "person.crop.circle.badge.clock", title: s.offerRowAgeTitle,
                            subtitle: s.offerRowSameGroupSub(band.label),
                            now: st.now?.percentile, offer: st.offer?.percentile)
            }
            if let st = r.education, let level = store.education {
                standingRow(icon: "graduationcap", title: s.offerRowEducationTitle,
                            subtitle: s.offerRowSameGroupSub(level.label(pt: s.pt)),
                            now: st.now?.percentile, offer: st.offer?.percentile)
            }

            VStack(alignment: .leading, spacing: 6) {
                if r.sector != nil { note(s.offerSectorWhy) }
                if [r.sector, r.region, r.age, r.education].contains(where: { $0?.thin == true }) {
                    note(s.thinChip)
                }
                if r.schedulesDiffer { note(s.offerSchedulesDiffer) }
                if r.nowJob.taxRegion != .continente || r.offerJob.taxRegion != .continente {
                    note(s.offerIslandNote)
                }
                if store.outsideGEPScope { note(s.publicCaveatBody) }
                if store.workSchedule == .partTime { note(s.partTimeNote) }
                note(s.grossVsGross)
            }
        }
    }

    private func sectorSubtitle(_ r: OfferComparison.Result) -> String {
        switch (r.nowJob.sector, r.offerJob.sector) {
        case let (now?, offer?) where now != offer:
            return s.offerRowSectorSubTwo(now: now.label(pt: s.pt), offer: offer.label(pt: s.pt))
        case let (now?, _):
            return s.offerRowSectorSub(now.label(pt: s.pt))
        case let (nil, offer?):
            return s.offerRowSectorSub(offer.label(pt: s.pt))
        case (nil, nil):
            return ""
        }
    }

    private func regionSubtitle(_ r: OfferComparison.Result) -> String {
        switch (r.nowJob.region, r.offerJob.region) {
        case let (now?, offer?) where now != offer:
            return s.offerRowRegionSubTwo(now: now.label, offer: offer.label)
        case let (now?, _):
            return now.label
        case let (nil, offer?):
            return offer.label
        case (nil, nil):
            return ""
        }
    }

    private func standingRow(icon: String, title: String, subtitle: String, now: Int?, offer: Int?) -> some View {
        SignalRow(icon: icon, title: title, subtitle: subtitle) {
            HStack(spacing: 5) {
                if let now {
                    Text("\(now)")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    missing
                }
                Image(systemName: "arrow.right")
                    .appFont(10, weight: .semibold)
                    .foregroundStyle(Theme.textFaint)
                if let offer {
                    Text("\(offer)")
                        .foregroundStyle(Theme.accent)
                } else {
                    missing
                }
            }
            .appFont(16, weight: .medium)
            .lineLimit(1)
            .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(standingVoice(title, now: now, offer: offer))
    }

    /// The side with no cohort, said in words rather than left blank.
    private var missing: some View {
        Text(s.offerNoFigure)
            .appFont(11)
            .foregroundStyle(Theme.textFaint)
    }

    private func standingVoice(_ title: String, now: Int?, offer: Int?) -> String {
        switch (now, offer) {
        case let (n?, o?): return s.offerRowVoice(title, now: "\(n)", offer: "\(o)")
        case let (n?, nil): return s.offerRowVoiceOne(title, value: "\(n)", isOffer: false)
        case let (nil, o?): return s.offerRowVoiceOne(title, value: "\(o)", isOffer: true)
        case (nil, nil): return title
        }
    }

    // MARK: d. If you stay instead

    private func staying(_ r: OfferComparison.Result) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // The unit hint only means something above figures, so the empty
            // state goes without it.
            SectionHeader(s.offerStayTitle) {
                if r.staying != nil { SectionHint(s.offerStayHint(per)) }
            }
            if let st = r.staying {
                stayingRows(st)
            } else {
                stayingEmpty
            }
        }
    }

    @ViewBuilder
    private func stayingRows(_ st: OfferComparison.Staying) -> some View {
        let nowFactor = period.factor(months: st.nowMonths)
        let offerFactor = period.factor(months: st.offerMonths)
        let offerShown = eur(st.offerGross * offerFactor)
        let top = Int(GrowthEngine.bandStarts.last ?? 20)
        let last = OfferComparison.horizons.max() ?? 20

        note(s.offerStayIntro)

        if !st.offerAhead {
            let same = abs(st.offerGross * st.offerMonths - st.todayGross * st.nowMonths) <= 1
            Text(same ? s.offerPaysSame : s.offerPaysLess)
                .appFont(13, weight: .medium)
                .foregroundStyle(same ? Theme.textPrimary : Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }

        stayRow(when: s.offerStayToday, staying: eur(st.todayGross * nowFactor), offer: offerShown, total: nil)

        ForEach(st.rows) { row in
            stayRow(when: s.offerStayIn(row.years),
                    staying: eur(row.stayingGross * nowFactor),
                    offer: offerShown,
                    total: s.offerStayTotal(eur(abs(row.totalDelta)), years: row.years,
                                            offerAhead: row.totalDelta >= 0))
        }

        VStack(alignment: .leading, spacing: 6) {
            if st.offerAhead {
                Text(st.catchUpYear.map { s.offerCatchUp($0) } ?? s.offerNoCatchUp(last))
                    .appFont(13, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let from = st.flatFrom {
                note(from == 0 ? s.offerFlatNow(top) : s.offerFlatFrom(from, top: top))
            }
            if st.falls { note(s.offerStayFalls) }
            note(s.offerStayAssumptions)
        }
    }

    private func stayRow(when: String, staying: String, offer: String, total: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(when)
                .appFont(13, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            PairRow(label: "", now: staying, offer: offer,
                    nowWord: s.offerStayingLabel, offerWord: s.offerOfferLabel, labelled: true)
            if let total {
                Text(total)
                    .appFont(11.5)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(s.offerStayRowVoice(when, staying: staying, offer: offer) + (total.map { " " + $0 } ?? ""))
    }

    private var stayingEmpty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.growEmptyTitle)
                .appFont(15, weight: .medium)
                .foregroundStyle(Theme.textPrimary)
            Text(s.offerStayEmptySub)
                .appFont(12)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { showSectorTenure = true } label: {
                Text(s.growEmptyButton)
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: e. What this leaves out

    private var leavesOut: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(s.offerLeavesOutTitle)
            if let bonus = terms.bonusAnnual {
                bullet(s.offerBonusShown(eur(bonus)))
            }
            ForEach(s.offerLeavesOutItems(year: TaxEngine.taxYear), id: \.self) { item in
                bullet(item)
            }
            Text(s.offerDisclaimer(TaxEngine.taxYear))
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 4)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .appFont(9)
                .foregroundStyle(Theme.textFaint)
                .frame(width: Theme.scaled(12, typeSize))
                .accessibilityHidden(true)
            Text(text)
                .appFont(11)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Changing and removing

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onEdit) {
                Text(s.offerEdit)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accentBorder))
            }
            Button { askingRemove = true } label: {
                Text(s.offerRemove)
                    .appFont(13)
                    .foregroundStyle(Theme.danger)
                    .underline()
                    .frame(maxWidth: .infinity)
            }
            // On the link and not on the screen: iOS 26 draws this as a popover,
            // and it should point at the thing that was tapped.
            .confirmationDialog(s.offerRemoveConfirm, isPresented: $askingRemove, titleVisibility: .visible) {
                Button(s.offerRemoveYes, role: .destructive) { onRemove() }
                Button(s.cancelButton, role: .cancel) {}
            }
            Text(s.offerKeptNote)
                .appFont(10)
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Helpers

    private func note(_ text: String) -> some View {
        Text(text)
            .appFont(11)
            .foregroundStyle(Theme.textFaint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A label with a "now" and an "offer" figure. Two right-aligned columns while
/// they fit; past `isAccessibilitySize`, the label on its own line and each
/// figure named, because a column header three rows up is no use once the
/// columns are gone.
private struct PairRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let label: String
    let now: String
    let offer: String
    let nowWord: String
    let offerWord: String
    var strong = false
    /// The column headers row, drawn in the faint style.
    var faint = false
    /// Name each figure even in the wide layout, for rows with no header row.
    var labelled = false

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                if !label.isEmpty {
                    Text(label)
                        .appFont(12, weight: strong ? .semibold : .regular)
                        .foregroundStyle(Theme.textSecondary)
                }
                named(nowWord, now, accent: false)
                named(offerWord, offer, accent: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if labelled {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                named(nowWord, now, accent: false)
                named(offerWord, offer, accent: true)
                Spacer(minLength: 0)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .appFont(12, weight: strong ? .semibold : .regular)
                    .foregroundStyle(faint ? Theme.textFaint : Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                figure(now, accent: false)
                figure(offer, accent: true)
            }
        }
    }

    private func figure(_ text: String, accent: Bool) -> some View {
        Text(text)
            .appFont(faint ? 11 : 14, weight: strong ? .semibold : .medium)
            .foregroundStyle(faint ? Theme.textFaint : (accent ? Theme.accent : Theme.textPrimary))
            .lineLimit(1)
            .frame(minWidth: Theme.scaled(88, typeSize), alignment: .trailing)
    }

    private func named(_ word: String, _ value: String, accent: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(word)
                .appFont(11)
                .foregroundStyle(Theme.textFaint)
            Text(value)
                .appFont(15, weight: strong ? .semibold : .medium)
                .foregroundStyle(accent ? Theme.accent : Theme.textPrimary)
        }
    }
}
