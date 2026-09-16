import SwiftUI
import SwiftData

/// Fortschritt-Tab – „Werde ich besser?“ statt Belastungs-Monitoring (S31).
/// Ersetzt inhaltlich die alte StatisticsView. Eine Disziplin zur Zeit
/// (Boulder/Seil nie gemischt), Zeitraum über die PB-Kacheln hinweg wirksam.
struct FortschrittView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]

    @AppStorage("progressDiscipline") private var disciplineRaw = ProgressEngine.Discipline.boulder.rawValue
    @State private var period: ProgressPeriod = .sixMonths

    private var discipline: ProgressEngine.Discipline {
        ProgressEngine.Discipline(rawValue: disciplineRaw) ?? .boulder
    }

    private var disciplineBinding: Binding<ProgressEngine.Discipline> {
        Binding(get: { discipline }, set: { disciplineRaw = $0.rawValue })
    }

    private var bests: (send: ProgressEngine.PersonalBest?, flash: ProgressEngine.PersonalBest?) {
        ProgressEngine.personalBests(sessions, discipline: discipline)
    }

    private var comfortGrade: String? {
        ProgressEngine.comfortGrade(sessions, discipline: discipline, monthsBack: period.monthsBack)
    }

    // FS-5: Nächste Stufe + Wohlfühl-Grad-Kandidat aus der gemeinsamen Meilenstein-Engine.
    private var milestones: [ProgressEngine.Milestone] {
        ProgressEngine.milestones(sessions, discipline: discipline, monthsBack: period.monthsBack)
    }

    private var highlights: ProgressEngine.Highlights {
        ProgressEngine.periodHighlights(sessions, discipline: discipline, monthsBack: period.monthsBack)
    }

    // DS-2: bei „Alles" ist isAllTimeBest trivial immer wahr (Zeitraum ==
    // Gesamthistorie) — die Feier gilt nur für einen echten Zeitraum-Fund
    // (Konsens-Punkt 2, wie zuvor bei den Erst-Send-Chips).
    private var celebratesSend: Bool {
        period != .all && highlights.isAllTimeBest && highlights.hardestSend != nil
    }

    private var timeline: [ProgressEngine.TimelinePoint] {
        ProgressEngine.gradeTimeline(sessions, discipline: discipline, monthsBack: period.monthsBack)
    }

    private var pyramidRows: [ProgressEngine.PyramidRow] {
        ProgressEngine.pyramid(sessions, discipline: discipline, monthsBack: period.monthsBack)
    }

    private var monthlyDays: [(month: Date, days: Int)] {
        ProgressEngine.climbDaysPerMonth(sessions, discipline: discipline, monthsBack: 6)
    }

    private var totals: (sends: Int, climbDays: Int) {
        ProgressEngine.periodTotals(sessions, discipline: discipline, monthsBack: period.monthsBack)
    }

    // MO-12: „Damals"-Rückblick (disziplin-übergreifend, deterministisch pro Woche).
    private var throwback: ClimbSession? {
        StatsEngine.throwbackSession(sessions)
    }

    // FS-5: Vormonat dauerhaft abrufbar statt nur in den ersten 7 Tagen (Review 6.4).
    private var previousMonth: Date {
        let cal = Calendar.current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return cal.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfThisMonth
    }

    private var previousMonthRecap: ProgressEngine.MonthRecap? {
        let recap = ProgressEngine.monthRecap(sessions, month: previousMonth)
        return recap.isEmpty ? nil : recap
    }

    private var mostCommonLimiter: Limiter? {
        ProgressEngine.limiterCounts(sessions, monthsBack: period.monthsBack).first?.limiter
    }

    /// Für die Empty-State-Entscheidung: gibt es überhaupt Begehungen der Disziplin?
    private var hasData: Bool {
        sessions.contains { s in s.ascents.contains { discipline.matches($0) } }
    }

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .navigationTitle("Fortschritt")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // DZ-5: zwei volle Segmented-Control-Zeilen statt einer Pill-Zeile
                // mit Spacer — native Trefferfläche, kein Element zentriert außer
                // dem Nav-Titel.
                VStack(spacing: 10) {
                    ProgressDisciplinePicker(discipline: disciplineBinding)
                    if hasData {
                        ProgressPeriodPicker(selection: $period)
                    }
                }

                if hasData {
                    sectionHeader("Wo stehe ich?")
                    LevelHeaderView(send: bests.send, flash: bests.flash,
                                    comfortGrade: comfortGrade, discipline: discipline,
                                    milestones: milestones,
                                    celebratesSend: celebratesSend,
                                    firstSends: highlights.firstSends)

                    sectionHeader("Werde ich besser?")
                    GradeTimelineChart(points: timeline, discipline: discipline)
                    PyramidChart(rows: pyramidRows)

                    sectionHeader("Trägt die Basis?")
                    ClimbDaysCard(monthlyDays: monthlyDays, sends: totals.sends,
                                  climbDays: totals.climbDays, discipline: discipline)
                    styleLink
                    if let previousMonthRecap {
                        MonthRecapCard(recap: previousMonthRecap)
                    }

                    if let throwback {
                        ThrowbackCard(session: throwback)
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .animation(.snappy, value: disciplineRaw)
            .animation(.snappy, value: period)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typo.section)
            .foregroundStyle(Theme.textPrimary)
    }

    private var styleLink: some View {
        NavigationLink {
            StyleProfileView(discipline: discipline, monthsBack: period.monthsBack)
        } label: {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stil & Limiter")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    if let mostCommonLimiter {
                        Text("Häufigster Limiter: \(mostCommonLimiter.label)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.surfaceRaised))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Noch kein Fortschritt", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Sobald du \(discipline == .boulder ? "Boulder" : "Seil")-Begehungen erfasst, siehst du hier, wo du stehst.")
        }
        .padding(.top, 40)
    }
}

// DS-5: Abnahme-Netz mit realistischen deutschen Strings — der Chip-Umbruch
// (DS-1..DS-4-Anlass) wäre hier sofort sichtbar gewesen.

#Preview("Voll") {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    for s in MockData.makeFullProgressScenario() { container.mainContext.insert(s) }
    return FortschrittView().modelContainer(container)
}

#Preview("Spärlich") {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    for s in MockData.makeSparseProgressScenario() { container.mainContext.insert(s) }
    return FortschrittView().modelContainer(container)
}

#Preview("Leer") {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return FortschrittView().modelContainer(container)
}
