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

    private var highlights: ProgressEngine.Highlights {
        ProgressEngine.periodHighlights(sessions, discipline: discipline, monthsBack: period.monthsBack)
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
                ProgressDisciplinePicker(discipline: disciplineBinding)
                    .frame(maxWidth: .infinity, alignment: .center)

                if hasData {
                    HStack {
                        Spacer()
                        ProgressPeriodPicker(selection: $period)
                    }
                    // „Alles" neutralisiert Erst-Sends (Konsens-Punkt 2) → nur bei
                    // endlichem Zeitraum zeigen.
                    if period != .all {
                        PeriodHighlightsRow(highlights: highlights)
                    }
                    LevelHeaderView(send: bests.send, flash: bests.flash,
                                    comfortGrade: comfortGrade, discipline: discipline)
                    GradeTimelineChart(points: timeline, discipline: discipline)
                    PyramidChart(rows: pyramidRows)
                    ClimbDaysCard(monthlyDays: monthlyDays, sends: totals.sends,
                                  climbDays: totals.climbDays, discipline: discipline)
                    styleLink
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

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    MockData.seedIfNeeded(container.mainContext)
    return FortschrittView().modelContainer(container)
}
