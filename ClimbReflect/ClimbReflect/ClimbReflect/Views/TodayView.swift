import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]
    @Query(sort: \Project.name) private var allProjects: [Project]
    @Query private var unlocks: [AchievementUnlock]
    @ObservedObject private var watchReceiver = WatchSessionReceiver.shared

    @State private var showAddSession = false
    @State private var showSettings = false
    @State private var monthRecapDismissed = false

    // EP-10: springt in den Erfolge-Tab (DashboardView liest denselben Key).
    @AppStorage("selectedTabIndex") private var selectedTabIndex = 0

    // FS-3: LevelHeroCard nur zeigen, wenn es überhaupt eine Klettersession gibt.
    private var hasClimbingSession: Bool { sessions.contains(where: \.isClimbing) }

    // MO-13: Monatsrückblick des Vormonats. Sichtbar nur in den ersten 7 Tagen des
    // Monats, wenn der Vormonat nicht leer ist und die Karte noch nicht quittiert
    // wurde. Dismiss persistiert über den dynamischen Key `monthRecapSeen-YYYY-MM`
    // (Vormonat) direkt in UserDefaults (@AppStorage kann keine dynamischen Keys).
    private var previousMonth: Date {
        let cal = Calendar.current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return cal.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfThisMonth
    }

    private var monthRecapSeenKey: String {
        let c = Calendar.current.dateComponents([.year, .month], from: previousMonth)
        return String(format: "monthRecapSeen-%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private var monthRecap: ProgressEngine.MonthRecap? {
        guard Calendar.current.component(.day, from: Date()) <= 7,
              !monthRecapDismissed,
              !UserDefaults.standard.bool(forKey: monthRecapSeenKey) else { return nil }
        let recap = ProgressEngine.monthRecap(sessions, month: previousMonth)
        return recap.isEmpty ? nil : recap
    }

    private func dismissMonthRecap() {
        UserDefaults.standard.set(true, forKey: monthRecapSeenKey)
        withAnimation { monthRecapDismissed = true }
    }

    // MO-11: jüngste Kletter-Session mit nicht-leerem Vorsatz. Sobald eine neuere
    // Kletter-Session existiert (mit oder ohne eigenen Vorsatz), verschwindet die
    // Karte automatisch.
    private var intentSession: ClimbSession? {
        guard let latest = sessions.first(where: \.isClimbing),
              let improve = latest.improveNext,
              !improve.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return latest
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    dateLine

                    if let status = watchReceiver.liveStatus {
                        LiveSessionBanner(status: status)
                    }

                    // Selten und darf dann oben stehen (vor der Hero-Reihe).
                    if let recap = monthRecap {
                        MonthRecapCard(recap: recap, onDismiss: dismissMonthRecap)
                    }

                    if hasClimbingSession {
                        LevelHeroCard(sessions: sessions, projects: allProjects, unlocks: unlocks) { discipline in
                            UserDefaults.standard.set(discipline.rawValue, forKey: "progressDiscipline")
                            selectedTabIndex = 1
                        }
                    }

                    if let intentSession {
                        IntentFollowUpCard(session: intentSession)
                    }

                    pinnedProjectsCard

                    recentSessions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Heute")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .tint(Theme.accent)
                .accessibilityLabel("Einstellungen")
                Button { showAddSession = true } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .tint(Theme.accent)
                .accessibilityLabel("Session hinzufügen")
            }
        }
        .sheet(isPresented: $showAddSession) { ManualSessionView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sensoryFeedback(.impact(weight: .light), trigger: monthRecapDismissed)
    }

    // MARK: - Sections

    // DZ-4: Large Title trägt den Markennamen; hier nur noch das Datum.
    private var dateLine: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .font(Theme.Typo.label)
            .foregroundStyle(Theme.textSecondary)
    }

    @ViewBuilder
    private var pinnedProjectsCard: some View {
        let pinned = allProjects.filter { $0.isPinned && $0.isActive }
        if !pinned.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Angepinnte Projekte", systemImage: "pin.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                ForEach(pinned) { project in
                    // VT-6: tappbar statt totem Text; keine attempts-Anzeige (S32).
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Theme.gold.opacity(0.12)).frame(width: 36, height: 36)
                                Image(systemName: "target")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.gold)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(project.distinctDays > 0
                                     ? "\(project.distinctDays) Klettertag\(project.distinctDays == 1 ? "" : "e")"
                                     : "Noch nicht geklettert")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if let grade = project.targetGradeRaw {
                                Text(grade)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        }
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("Deine erste Session", systemImage: "applewatch")
                } description: {
                    Text("Starte eine Session auf der Apple Watch – sie erscheint danach automatisch hier.")
                } actions: {
                    Button("Session nachtragen") { showAddSession = true }
                        .buttonStyle(.bordered)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("Letzte Sessions")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    NavigationLink(destination: AllSessionsView()) {
                        Text("Alle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                ForEach(sessions.prefix(5)) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: sessions.prefix(5).map(\.id))
    }

}
