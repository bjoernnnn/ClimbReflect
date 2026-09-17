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

    // PG-10: alle abgeleiteten Werte einmal pro Render berechnen statt in
    // Computed Properties, die bei jedem Zugriff erneut über die Engine laufen
    // (Abnahme 4.7).
    private struct Snapshot {
        let bests: (send: ProgressEngine.PersonalBest?, flash: ProgressEngine.PersonalBest?)
        let comfortGrade: String?
        let milestones: [ProgressEngine.Milestone]
        let highlights: ProgressEngine.Highlights
        let timeline: [ProgressEngine.TimelinePoint]
        let pyramid: [ProgressEngine.PyramidRow]
        let monthlyDays: [(month: Date, days: Int)]
        let totals: (sends: Int, climbDays: Int)
        let mostCommonLimiter: Limiter?
        let hasData: Bool
        let celebratesSend: Bool

        init(sessions: [ClimbSession], discipline: ProgressEngine.Discipline, period: ProgressPeriod) {
            bests = ProgressEngine.personalBests(sessions, discipline: discipline)
            comfortGrade = ProgressEngine.comfortGrade(sessions, discipline: discipline, monthsBack: period.monthsBack)
            milestones = ProgressEngine.milestones(sessions, discipline: discipline, monthsBack: period.monthsBack)
            highlights = ProgressEngine.periodHighlights(sessions, discipline: discipline, monthsBack: period.monthsBack)
            timeline = ProgressEngine.gradeTimeline(sessions, discipline: discipline, monthsBack: period.monthsBack)
            pyramid = ProgressEngine.pyramid(sessions, discipline: discipline, monthsBack: period.monthsBack)
            monthlyDays = ProgressEngine.climbDaysPerMonth(sessions, discipline: discipline, monthsBack: 6)
            totals = ProgressEngine.periodTotals(sessions, discipline: discipline, monthsBack: period.monthsBack)
            mostCommonLimiter = ProgressEngine.limiterCounts(sessions, monthsBack: period.monthsBack).first?.limiter
            hasData = sessions.contains { s in s.ascents.contains { discipline.matches($0) } }
            // DS-2: bei „Alles" ist isAllTimeBest trivial immer wahr (Zeitraum ==
            // Gesamthistorie) — die Feier gilt nur für einen echten Zeitraum-Fund
            // (Konsens-Punkt 2, wie zuvor bei den Erst-Send-Chips).
            celebratesSend = period != .all && highlights.isAllTimeBest && highlights.hardestSend != nil
        }
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

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .navigationTitle("Fortschritt")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder private var content: some View {
        let s = Snapshot(sessions: sessions, discipline: discipline, period: period)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // DZ-5: zwei volle Segmented-Control-Zeilen statt einer Pill-Zeile
                // mit Spacer — native Trefferfläche, kein Element zentriert außer
                // dem Nav-Titel.
                VStack(spacing: 10) {
                    ProgressDisciplinePicker(discipline: disciplineBinding)
                    if s.hasData {
                        ProgressPeriodPicker(selection: $period)
                    }
                }

                if s.hasData {
                    SectionHeader("Wo stehe ich?")
                    LevelHeaderView(send: s.bests.send, flash: s.bests.flash,
                                    comfortGrade: s.comfortGrade, discipline: discipline,
                                    milestones: s.milestones,
                                    celebratesSend: s.celebratesSend,
                                    firstSends: s.highlights.firstSends)

                    SectionHeader("Werde ich besser?")
                    GradeTimelineChart(points: s.timeline, discipline: discipline)
                    PyramidChart(rows: s.pyramid)

                    SectionHeader("Trägt die Basis?")
                    ClimbDaysCard(monthlyDays: s.monthlyDays, sends: s.totals.sends,
                                  climbDays: s.totals.climbDays, discipline: discipline)
                    styleLink(mostCommonLimiter: s.mostCommonLimiter)
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
            .sensoryFeedback(.selection, trigger: disciplineRaw)
            .sensoryFeedback(.selection, trigger: period)
        }
    }

    private func styleLink(mostCommonLimiter: Limiter?) -> some View {
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
            .background(RoundedRectangle.theme(Theme.Radius.medium).fill(Theme.surfaceRaised))
        }
        .buttonStyle(.card)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Noch kein Fortschritt", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Sobald du \(discipline.label)-Begehungen erfasst, siehst du hier, wo du stehst.")
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
