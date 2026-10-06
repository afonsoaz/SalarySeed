import SwiftUI

/// "People like you": the reader against each group they belong to, one line
/// per group, under the national figure and never instead of it. Thin groups
/// and results at the edge of the model are flagged, and the sources are named
/// once, at the foot of the screen.
///
/// Phase two (Afonso) made it one list. It was four cards, about half a screen
/// each, every one carrying its own slider, its own median sentence and the
/// same source line, so four percentages took two screens to read. A line now
/// says the group and where you sit in it. Tapping one opens it in place: the
/// median, that group's explorer, and the way to change the answer. One line
/// is open at a time, so the list stays a list.
///
/// A line has three states, because the reader is owed the difference
/// (rule 21): answered, with a figure; answered, with no figure in the source;
/// and not answered yet. The middle one used to fall into the third. Açores
/// and Madeira have no regional cell, so an islander who had given their
/// município was asked to "Add your município" again.
struct PeopleLikeYou: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The open line: "sector", or a `CompareDimension.id`.
    @State private var open: String?
    @State private var activeDimension: CompareDimension?
    @State private var showSectorSheet = false
    // v0.9.1: the region is answered by picking a município.
    @State private var showConcelhoSheet = false
    /// The quick question, asked in its own sheet.
    @State private var question: EnrichmentSignal?
    /// The sheet a question hands over to, opened once the question's own
    /// sheet has gone. Presenting it while that one is still on its way down is
    /// the moment SwiftUI handles worst.
    @State private var handOver: SignalSheet?
    @State private var activeSignalSheet: SignalSheet?

    private var s: Strings { store.s }
    private var gross: Double { store.breakdown.grossMonthly }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(s.peopleLikeYou)
            scopeCaveat
            LineCard {
                sectorLine
                ForEach(CompareDimension.all) { dim in
                    GlyphLineDivider()
                    dimensionLine(dim)
                }
            }
            partTimeCaveat
            islandCaveat
            quickQuestion
        }
        .sheet(isPresented: $showSectorSheet) { SectorTenureSheet() }
        .sheet(isPresented: $showConcelhoSheet) { ConcelhoSheet() }
        .sheet(item: $activeDimension) { ProfilePickerSheet(dimension: $0) }
        .sheet(item: $question, onDismiss: {
            guard let next = handOver else { return }
            handOver = nil
            activeSignalSheet = next
        }) { signal in
            QuickQuestionSheet(
                signal: signal,
                onHandOver: { handOver = SignalSheet.from($0) },
                onSkip: { _ = store.compareSnoozed.insert(signal.rawValue) }
            )
        }
        .sheet(item: $activeSignalSheet) { SignalSheetView(sheet: $0) }
    }

    // MARK: The lines

    /// Sector crossed with time at the company leads: it is the closest thing
    /// to "people like you" the published tables have.
    @ViewBuilder
    private var sectorLine: some View {
        if let sector = store.sector, let cell = store.sectorCell {
            let result = CohortEngine.result(grossMonthly: gross, cell: cell)
            // Without the years the group is the whole sector. The line says so
            // while closed, as the sector card always did: the years are also
            // what Grow is built on, so this is not a prompt to tuck away.
            GroupLine(glyph: "building.2",
                      name: s.sectorCohort(sector.label(pt: s.pt),
                                           tenure: store.tenureYears.map { s.yearsText($0) }),
                      note: store.tenureYears == nil ? s.tenureAddHint : nil,
                      kind: s.sectorKicker,
                      result: result,
                      isOpen: open == "sector",
                      toggle: { toggle("sector") }) {
                GroupDetail(result: result, cell: cell, userGross: gross,
                            changeTitle: store.tenureYears == nil ? s.tenureAddHint : s.groupChange("sector")) {
                    showSectorSheet = true
                }
            }
        } else {
            AddLine(glyph: "building.2", title: s.sectorAdd, hint: s.sectorAddHint) {
                close("sector")
                showSectorSheet = true
            }
        }
    }

    @ViewBuilder
    private func dimensionLine(_ dim: CompareDimension) -> some View {
        if let option = dim.selectedOption(in: store, pt: s.pt) {
            if let cell = dim.cell(option.id) {
                let result = CohortEngine.result(grossMonthly: gross, cell: cell)
                GroupLine(glyph: dim.icon,
                          name: s.cohortWord(dim.id, option.label),
                          kind: s.dimRowTitle(dim.id),
                          result: result,
                          isOpen: open == dim.id,
                          toggle: { toggle(dim.id) }) {
                    GroupDetail(result: result, cell: cell, userGross: gross,
                                changeTitle: s.groupChange(dim.id)) { edit(dim) }
                }
            } else {
                NoFigureLine(glyph: dim.icon, name: option.label, kind: s.dimRowTitle(dim.id),
                             hint: s.groupChange(dim.id)) {
                    close(dim.id)
                    edit(dim)
                }
            }
        } else {
            AddLine(glyph: dim.icon, title: s.dimAdd(dim.id), hint: s.dimProfileHint(dim.id)) {
                close(dim.id)
                edit(dim)
            }
        }
    }

    private func toggle(_ id: String) {
        let flip = { open = open == id ? nil : id }
        if reduceMotion { flip() } else { withAnimation(.snappy(duration: 0.3)) { flip() } }
    }

    /// A line that has lost its figure (its answer removed, or moved to an
    /// island with no regional cell) forgets that it was open, so that it does
    /// not come back already open when it gets a figure again.
    private func close(_ id: String) {
        if open == id { open = nil }
    }

    /// Region opens the município search; everything else opens its chip picker.
    private func edit(_ dim: CompareDimension) {
        if dim.usesConcelhoPicker { showConcelhoSheet = true } else { activeDimension = dim }
    }

    // MARK: Caveats

    /// Shown whenever the user is on a public-function contract: the Quadros de
    /// Pessoal exclude that population, so every group below describes
    /// somebody else. Above the list, because it changes how all of it reads.
    @ViewBuilder
    private var scopeCaveat: some View {
        if store.outsideGEPScope {
            VStack(alignment: .leading, spacing: 3) {
                Text(s.publicCaveatTitle)
                    .appFont(12, weight: .medium)
                    .foregroundStyle(Theme.danger)
                Text(s.publicCaveatBody)
                    .appFont(11)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.dangerSoft, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.dangerBorder, lineWidth: 1)
            )
        }
    }

    /// v0.15: the islands have no cells in the Quadros de Pessoal, so an islander
    /// gets sector and tenure figures that are mainland ones and no regional
    /// comparison at all. The region line says "no figure"; this says why.
    @ViewBuilder
    private var islandCaveat: some View {
        if let region = store.region, region == .acores || region == .madeira {
            Text(s.islandNoCohortNote)
                .appFont(11)
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Shown when the user works part-time: the published averages are mostly
    /// full-time pay, so the comparison is not like for like.
    @ViewBuilder
    private var partTimeCaveat: some View {
        if store.workSchedule == .partTime {
            // v0.12: red, not faint. This is not a footnote, it is the reason
            // every percentile on the screen reads lower than it should, and a
            // caveat that changes how you read the whole page cannot be the
            // quietest text on it.
            Text(s.partTimeNote)
                .appFont(11)
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The quick question

    /// v0.9: one unanswered question, under the comparison the reader just
    /// read, because the app asks only once it has given something. Phase two
    /// made it one line that opens the question in a sheet; it was a card as
    /// tall as the groups above it. "Not now" still means not this session.
    @ViewBuilder
    private var quickQuestion: some View {
        if let next = store.nextEnrichment(skipping: store.compareSnoozed) {
            QuickQuestionRow(signal: next) { question = next }
                .padding(.top, 6)
        }
    }
}

// MARK: - One group

/// A group the reader belongs to, with a figure: its glyph, its name and the
/// share of it that earns less than the reader. Tapping it opens `detail`.
private struct GroupLine<Detail: View>: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.dynamicTypeSize) private var typeSize

    let glyph: String
    let name: String
    /// A line under the name while the line is closed, for something the
    /// reader should not have to open it to learn.
    var note: String? = nil
    /// What kind of group it is, said to VoiceOver before the name, since on
    /// screen the glyph says it.
    let kind: String
    let result: CohortResult
    let isOpen: Bool
    let toggle: () -> Void
    @ViewBuilder let detail: () -> Detail

    private var s: Strings { store.s }
    private var shown: String { percent(Double(result.percentile) / 100, decimals: 0) }
    private var flag: String? {
        result.thin ? s.thinChip : (result.edge ? s.edgeChip : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                GlyphLine(glyph: glyph, accessory: "chevron.right", accessoryTurned: isOpen) {
                    VStack(alignment: .leading, spacing: 2) {
                        nameText
                        if let note {
                            Text(note)
                                .appFont(12)
                                .foregroundStyle(Theme.accent)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } trailing: {
                    figure
                }
            }
            .buttonStyle(RowPressStyle())
            .accessibilityLabel("\(kind): \(name)")
            .accessibilityValue(voiceValue)

            if isOpen {
                // Little padding underneath: the detail ends in a 44 point
                // button whose own frame is most of the gap.
                detail()
                    .padding(.leading, detailInset)
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
    }

    private var nameText: some View {
        Text(name)
            .appFont(16, weight: .medium)
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var figure: some View {
        HStack(spacing: 5) {
            if flag != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .appFont(11)
                    .foregroundStyle(Theme.segEmployeeSS)
            }
            Text(shown)
                .appFont(20, weight: .semibold)
                .foregroundStyle(Theme.accent)
        }
    }

    private var voiceValue: String {
        [s.groupVoiceValue(shown), flag, note, isOpen ? s.voiceExpanded : s.voiceCollapsed]
            .compactMap { $0 }
            .joined(separator: ". ")
    }

    /// The detail lines up under the name, past the glyph, the way a list's
    /// second line does; at an accessibility size it takes the full width.
    private var detailInset: CGFloat {
        typeSize.isAccessibilitySize ? 16 : 16 + Theme.scaled(32, typeSize) + 14
    }
}

/// What an open group shows: the median, that group's explorer, its flag, and
/// the way to change the answer it rests on.
private struct GroupDetail: View {
    @EnvironmentObject private var store: SalaryStore

    let result: CohortResult
    let cell: CohortCell
    let userGross: Double
    let changeTitle: String
    let onChange: () -> Void

    private var s: Strings { store.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(caption)
                .appFont(13)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PercentileSlider(userPercentile: Double(result.percentile), salaryAt: salaryAt, s: s)
                .padding(.top, 14)

            if result.thin || result.edge {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .appFont(9)
                        .accessibilityHidden(true)
                    Text(result.thin ? s.thinChip : s.edgeChip)
                        .appFont(10)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.segEmployeeSS)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.segEmployeeSS.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.segEmployeeSS.opacity(0.25)))
                .padding(.top, 12)
            }

            Button(action: onChange) {
                Text(changeTitle)
                    .appFont(13, weight: .medium)
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    /// Salary at a percentile (0-100) within this group's log-normal.
    private func salaryAt(_ p: Double) -> Double {
        let clamped = min(99.9, max(0.1, p))
        return cell.median * exp(cell.sigma * PercentileEngine.normInv(clamped / 100))
    }

    private var caption: String {
        let diff = userGross - result.median
        return s.medianCaption(median: eur(result.median), diff: diff, diffText: eur(abs(diff)))
    }
}

/// A group not answered yet: dimmed, in the accent, saying what to add.
private struct AddLine: View {
    let glyph: String
    let title: String
    /// What answering unlocks, said to VoiceOver.
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlyphLine(glyph: glyph, accessory: "plus", accessoryTint: Theme.accent, dimmedTile: true) {
                Text(title)
                    .appFont(16)
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(RowPressStyle())
        .accessibilityHint(hint)
    }
}

/// A group the reader HAS answered and the source has no figure for. It says
/// so, rather than asking for the answer again; the caveat under the list
/// says why. Tapping it changes the answer.
private struct NoFigureLine: View {
    @EnvironmentObject private var store: SalaryStore

    let glyph: String
    let name: String
    let kind: String
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlyphLine(glyph: glyph) {
                Text(name)
                    .appFont(16, weight: .medium)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } trailing: {
                Text(store.s.mapIslandNoData)
                    .appFont(13)
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel("\(kind): \(name)")
        .accessibilityValue(store.s.mapIslandNoData)
        .accessibilityHint(hint)
    }
}

// MARK: - A group's explorer

/// A compact version of the national explorer: drag to any percentile of the
/// group and the readout shows the salary at that level. It rests on the
/// reader's own percentile (a fixed tick marks it) and springs back on release.
///
/// It runs along percentiles, unlike the national one, because there is no
/// chart above it whose axis it would have to agree with.
private struct PercentileSlider: View {
    let userPercentile: Double
    let salaryAt: (Double) -> Double
    let s: Strings

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var scrubPct: Double? = nil

    private var percentileLabel: some View {
        Text(s.percentileEarns(s.ordinalPercentile(Int(activePct.rounded()))))
            .appFont(12)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var salaryFigure: some View {
        Text(eur(activeSalary))
            .appFont(16, weight: .medium)
            .foregroundStyle(Theme.accent)
            .contentTransition(.numericText())
        Text(s.perMonthSuffix)
            .appFont(11)
            .foregroundStyle(Theme.textSecondary)
    }

    /// v1.2a: two rows past the threshold. "O percentil 62 ganha" and
    /// "2405 EUR /mes" were fighting over one line, and the label lost: it came
    /// out as four words stacked one per line beside a figure that kept its own
    /// row to itself.
    @ViewBuilder
    private var readout: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                percentileLabel
                HStack(alignment: .firstTextBaseline, spacing: 6) { salaryFigure }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                percentileLabel
                Spacer(minLength: 6)
                salaryFigure
            }
        }
    }

    private var scrubbing: Bool { scrubPct != nil }
    private var activePct: Double { scrubPct ?? userPercentile }
    private var activeSalary: Double { salaryAt(activePct) }

    /// VoiceOver's way of dragging. Nothing ever lets go of it, so stepping
    /// back onto the reader's own percentile has to BE "you" again rather than
    /// the nearest step to it, or the line could never return to rest.
    private func step(by points: Double) {
        let to = min(99, max(1, activePct.rounded() + points))
        scrubPct = abs(to - userPercentile) < 2.5 ? nil : to
    }
    private var frac: Double { min(1, max(0, activePct / 100)) }
    private var userFrac: Double { min(1, max(0, userPercentile / 100)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            readout
                // The handle below says the same as its value, and can move it.
                .accessibilityHidden(true)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(Theme.accent.opacity(scrubbing ? 0.9 : 0.5))
                        .frame(width: max(6, frac * w), height: 6)
                    Rectangle()
                        .fill(Theme.textPrimary.opacity(0.35))
                        .frame(width: 1.5, height: 14)
                        .offset(x: min(w - 1, max(0, userFrac * w)) - 0.75)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                        .offset(x: min(w - 18, max(0, frac * w - 9)))
                }
                .frame(height: 22)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        // 1 to 99, like every percentile the app prints:
                        // rounded, 99.9 read "the 100th percentile".
                        .onChanged { v in scrubPct = min(99, max(1, v.location.x / w * 100)) }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { scrubPct = nil }
                        }
                )
                .animation(scrubbing ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: frac)
            }
            .frame(height: 22)
            .accessibilityElement()
            .accessibilityLabel(s.groupExploreVoice)
            .accessibilityValue("\(s.percentileEarns(s.ordinalPercentile(Int(activePct.rounded())))) \(eur(activeSalary))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: step(by: 5)
                case .decrement: step(by: -5)
                @unknown default: break
                }
            }
        }
    }
}
