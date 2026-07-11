import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]
    @Query(sort: \Project.name) private var allProjects: [Project]
    @Query private var unlocks: [AchievementUnlock]
    @ObservedObject private var watchReceiver = WatchSessionReceiver.shared

    @State private var showAddSession = false
    @State private var showSettings = false
    @State private var monthRecapDismissed = false

    // EP-10: springt in den Erfolge-Tab (DashboardView liest denselben Key).
    @AppStorage("selectedTabIndex") private var selectedTabIndex = 0

    // FO-12: Bestleistungen kommen aus der ProgressEngine (eine Quelle der Wahrheit,
    // identisch zum Level-Block im Fortschritt-Tab). Grad bereits in Anzeige-Skala.
    private var heroBoulder: String? {
        ProgressEngine.personalBests(sessions, discipline: .boulder).send?.grade
    }

    private var heroRoute: String? {
        ProgressEngine.personalBests(sessions, discipline: .rope).send?.grade
    }

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

    // EP-10: Erfolg mit dem höchsten Fortschritt < 100 % — Goal-Gradient-
    // Einstieg auf dem Homescreen. Verschwindet automatisch bei 28/28 bzw.
    // sobald kein gesperrter Erfolg mehr einen Fortschritt trägt.
    private var nextAchievement: AchievementViewData? {
        AchievementViewModel.build(sessions: sessions, projects: allProjects, unlocks: unlocks)
            .filter { !$0.isUnlocked && ($0.progress?.fraction ?? 0) > 0 && ($0.progress?.fraction ?? 0) < 1 }
            .max { ($0.progress?.fraction ?? 0) < ($1.progress?.fraction ?? 0) }
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
        NavigationStack {
            ZStack {
                MountainBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        if let status = watchReceiver.liveStatus {
                            LiveSessionBanner(status: status)
                        }

                        // Selten und darf dann oben stehen (vor der Hero-Reihe).
                        if let recap = monthRecap {
                            MonthRecapCard(recap: recap, onDismiss: dismissMonthRecap)
                        }

                        if heroBoulder != nil || heroRoute != nil {
                            heroTrophyRow
                        }

                        if let intentSession {
                            IntentFollowUpCard(session: intentSession)
                        }

                        statRow

                        if let nextAchievement {
                            Button {
                                selectedTabIndex = 3
                            } label: {
                                NextAchievementsCard(data: nextAchievement)
                            }
                            .buttonStyle(.plain)
                        }

                        pinnedProjectsCard

                        recentSessions
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAddSession = true } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Theme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .tint(Theme.accent)
                }
            }
            .sheet(isPresented: $showAddSession) { ManualSessionView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            Text("ClimbReflect")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private var statRow: some View {
        // MO-10: Rekord-Streak steht als unverlierbarer Besitz neben dem laufenden
        // Streak – nach einer Pause liest sich die Kachel als „Rekord: N Wo." statt
        // als Bestrafung (kein roter Reset, S33). Detail erst ab Rekord ≥ 2.
        let bestStreak = StatsEngine.bestClimbWeekStreak(sessions)
        return HStack(spacing: 12) {
            StatTile(value: "\(sessions.filter(\.isClimbing).count)", label: "Sessions", symbol: "figure.climbing")
            StatTile(value: "\(StatsEngine.climbWeekStreak(sessions))", label: "Streak", symbol: "flame.fill",
                     detail: bestStreak >= 2 ? "Rekord: \(bestStreak) Wo." : nil)
            // Klettersessions wie die Nachbar-Kacheln ("Sessions"/"Streak") – sonst
            // zählt "Diese Woche" Trainings mit und widerspricht der Zeile
            StatTile(value: "\(ProgressEngine.sessionsThisWeek(sessions))", label: "Diese Woche", symbol: "calendar")
        }
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
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Theme.gold.opacity(0.12)).frame(width: 36, height: 36)
                            Image(systemName: "target")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            let attempts = project.ascents.reduce(0) { $0 + $1.attempts }
                            Text("\(attempts) Versuch\(attempts == 1 ? "" : "e")")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if let grade = project.targetGradeRaw {
                            Text(grade)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .card()
        }
    }

    private var heroTrophyRow: some View {
        // fixedSize: beide Karten strecken sich auf die Höhe der höheren
        HStack(spacing: 12) {
            heroCard(title: "Bouldern", hero: heroBoulder)
            heroCard(title: "Klettern", hero: heroRoute)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func heroCard(title: String, hero: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(hero != nil ? Theme.gold : Theme.textTertiary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            if let h = hero {
                Text(h)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("–")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Text("Noch kein Top")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(hero != nil ? Theme.gold.opacity(0.25) : Color.clear, lineWidth: 1)
                )
        )
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            if sessions.isEmpty {
                Button { showAddSession = true } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.accent)
                        Text("Erste Session anlegen")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Oder importiere deine Einheiten aus Apple Health")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(sessions.prefix(5)) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}
