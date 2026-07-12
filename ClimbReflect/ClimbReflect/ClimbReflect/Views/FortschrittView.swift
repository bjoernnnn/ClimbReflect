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

    private var comfortCandidate: (grade: String, sample: Int)? {
        ProgressEngine.comfortCandidate(sessions, discipline: discipline, monthsBack: period.monthsBack)
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

    // MO-8: Basis = historischer Höchst-Send, Zählung = gewählter Zeitraum.
    private var nextGrade: String? {
        bests.send.flatMap { ProgressEngine.nextGrade(afterOrder: $0.order, discipline: discipline) }
    }

    private var nextGradeTries: Int {
        guard let nextGrade else { return 0 }
        return pyramidRows.first { $0.grade == nextGrade }?.failedTries ?? 0
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

    /// Für die Empty-State-Entscheidung: gibt es überhaupt Begehungen der Disziplin?
    private var hasData: Bool {
        sessions.contains { s in s.ascents.contains { discipline.matches($0) } }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MountainBackground()
                content
            }
            .navigationTitle("Fortschritt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // DS-1: eine Kopfzeile statt drei Ausrichtungen — Disziplin führend,
                // Zeitraum rechts. Kein Element zentriert außer dem Nav-Titel.
                HStack {
                    ProgressDisciplinePicker(discipline: disciplineBinding)
                    Spacer()
                    if hasData {
                        ProgressPeriodPicker(selection: $period)
                    }
                }

                if hasData {
                    LevelHeaderView(send: bests.send, flash: bests.flash,
                                    comfortGrade: comfortGrade, discipline: discipline,
                                    nextGrade: nextGrade, nextGradeTries: nextGradeTries,
                                    comfortCandidate: comfortCandidate,
                                    celebratesSend: celebratesSend,
                                    firstSends: highlights.firstSends)
                    GradeTimelineChart(points: timeline, discipline: discipline)
                    PyramidChart(rows: pyramidRows)
                    ClimbDaysCard(monthlyDays: monthlyDays, sends: totals.sends,
                                  climbDays: totals.climbDays, discipline: discipline)
                    styleLink
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
        }
    }

    private var styleLink: some View {
        NavigationLink {
            StyleProfileView(discipline: discipline, monthsBack: period.monthsBack)
        } label: {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(Theme.accent)
                Text("Stil & Limiter")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.bgElevated))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textTertiary)
            Text("Noch keine Daten")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Erfasse Begehungen dieser Disziplin, um deinen Fortschritt zu sehen.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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
