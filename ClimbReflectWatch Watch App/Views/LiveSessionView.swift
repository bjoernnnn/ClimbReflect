import SwiftUI
import WatchKit

// Tab-Reihenfolge: [Steuerung] ← [Session] → [Klassifizieren]
// Nach Ende: Fragebogen → Zusammenfassung

enum WatchNavStep: Hashable {
    case questionnaire, summary
}

struct LiveSessionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var currentTab = 1
    @State private var showEndConfirm = false
    @State private var navPath = [WatchNavStep]()
    @State private var sessionDTO: WatchSessionDTO? = nil
    @State private var selectedAttempt: WatchAttempt? = nil

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        NavigationStack(path: $navPath) {
            TabView(selection: $currentTab) {
                controlsPage.tag(0)
                sessionInfoPage.tag(1)
                AttemptLogView(onBank: { currentTab = 1 }).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .background(WatchTheme.bg)
            .confirmationDialog("Session beenden?", isPresented: $showEndConfirm) {
                Button("Beenden", role: .destructive) {
                    Task {
                        sessionDTO = await workoutManager.endWorkout()
                        navPath = [.questionnaire]
                    }
                }
                Button("Weiter", role: .cancel) {}
            }
            .navigationDestination(for: WatchNavStep.self) { step in
                switch step {
                case .questionnaire:
                    if let dto = sessionDTO {
                        SessionEndQuestionnaireView(dto: dto) { enriched in
                            SyncService.shared.send(dto: enriched)
                            sessionDTO = enriched
                            navPath = [.summary]
                        }
                    }
                case .summary:
                    SessionSummaryView(dto: sessionDTO, onDone: { navPath = [] })
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Tab 1: Session-Info + Verlauf (nach unten scrollen)

    private var sessionInfoPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Bereich 1: Vitals (füllt den Screen genau) ──
                statsSection
                    .containerRelativeFrame(.vertical)

                // ── Bereich 2: Verlauf (nach unten scrollen) ──
                if !workoutManager.attempts.isEmpty {
                    historySection
                        .padding(.bottom, 12)
                }
            }
        }
        .background(WatchTheme.bg)
        .sheet(item: $selectedAttempt) { attempt in
            AscentDetailView(attempt: attempt) {
                workoutManager.removeAttempt(id: attempt.id)
            }
        }
    }

    private var statsSection: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            // Timer
            Text(elapsedFormatted)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .foregroundStyle(workoutManager.isPaused ? WatchTheme.textTert : WatchTheme.accent)

            // Vitalzeichen
            if !isLuminanceReduced {
                HStack(spacing: 0) {
                    vitalCell(value: heartStr, unit: "BPM",
                              icon: "heart.fill", color: WatchTheme.danger)
                    vitalSep
                    vitalCell(value: "\(Int(workoutManager.activeEnergyKcal))", unit: "kcal",
                              icon: "flame.fill", color: WatchTheme.gold)
                    vitalSep
                    vitalCell(value: maxHRStr, unit: "Max",
                              icon: "arrow.up.heart.fill", color: WatchTheme.danger.opacity(0.7))
                }
                .background(WatchTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Stats-Badges
            HStack(spacing: 8) {
                statBadge(value: "\(workoutManager.attempts.count)",
                          label: "Versuche", icon: "figure.climbing", color: WatchTheme.textSecond)
                statBadge(value: "\(topCount)",
                          label: "Tops", icon: "checkmark.circle.fill", color: WatchTheme.accent)
            }

            // Pending-Banner
            if workoutManager.pendingClassifications > 0 {
                pendingBanner
            }

            Spacer(minLength: 0)

            // Scroll-Hinweis (nur wenn Einträge vorhanden)
            if !workoutManager.attempts.isEmpty {
                VStack(spacing: 2) {
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 14))
                        .foregroundStyle(WatchTheme.textTert)
                    Text("Verlauf")
                        .font(.system(size: 9))
                        .foregroundStyle(WatchTheme.textTert)
                }
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Verlauf-Sektion

    private var historySection: some View {
        VStack(spacing: 0) {
            // Trennlinie mit Label
            HStack(spacing: 6) {
                Rectangle().fill(WatchTheme.elevated).frame(height: 1)
                Text("VERLAUF")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WatchTheme.textTert)
                    .fixedSize()
                Rectangle().fill(WatchTheme.elevated).frame(height: 1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)

            // Ascent-Rows (neueste zuerst)
            LazyVStack(spacing: 5) {
                ForEach(workoutManager.attempts.reversed()) { attempt in
                    ascentRow(attempt)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 8)
            .animation(.spring(duration: 0.3), value: workoutManager.attempts.count)
        }
    }

    private func ascentRow(_ attempt: WatchAttempt) -> some View {
        Button { selectedAttempt = attempt } label: {
            HStack(spacing: 8) {
                Image(systemName: attempt.result?.symbol ?? "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(attempt.result?.color ?? WatchTheme.textTert)
                    .frame(width: 18)

                Text(attempt.grade ?? "–")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WatchTheme.textPrimary)

                if let style = attempt.style {
                    Text(style.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(WatchTheme.gold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(WatchTheme.gold.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(timeAgo(attempt.date))
                    .font(.system(size: 9))
                    .foregroundStyle(WatchTheme.textTert)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(WatchTheme.textTert)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(WatchTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 0: Steuerung

    private var controlsPage: some View {
        VStack(spacing: 10) {
            Text(workoutManager.sessionType.label)
                .font(.footnote)
                .foregroundStyle(WatchTheme.textTert)
                .padding(.top, 8)

            Button {
                if workoutManager.isPaused { workoutManager.resumeWorkout() }
                else { workoutManager.pauseWorkout() }
            } label: {
                Label(workoutManager.isPaused ? "Weiter" : "Pause",
                      systemImage: workoutManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WatchTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(WatchTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) { showEndConfirm = true } label: {
                Label("Session beenden", systemImage: "stop.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WatchTheme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(WatchTheme.danger.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Unklassifizierter-Banner

    private var pendingBanner: some View {
        Button { currentTab = 2 } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(WatchTheme.gold)
                    .font(.system(size: 13))
                VStack(alignment: .leading, spacing: 1) {
                    Text(workoutManager.pendingClassifications == 1
                         ? "1 Versuch erkannt"
                         : "\(workoutManager.pendingClassifications) Versuche erkannt")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WatchTheme.textPrimary)
                    Text("Zum Klassifizieren wischen →")
                        .font(.system(size: 9))
                        .foregroundStyle(WatchTheme.textSecond)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(WatchTheme.gold.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(WatchTheme.gold.opacity(0.35), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hilfsmethoden

    private var topCount: Int {
        workoutManager.attempts.filter { $0.result == .top }.count
    }
    private var heartStr: String {
        workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--"
    }
    private var maxHRStr: String {
        workoutManager.maxHeartRate > 0 ? "\(Int(workoutManager.maxHeartRate))" : "--"
    }
    private var elapsedFormatted: String {
        let s = workoutManager.elapsedSeconds
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
    private func timeAgo(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "jetzt" }
        return "vor \(mins) min"
    }

    private func vitalCell(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 11))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.textPrimary)
            Text(unit).font(.system(size: 9)).foregroundStyle(WatchTheme.textSecond)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
    }

    private var vitalSep: some View {
        Divider().frame(height: 28).background(WatchTheme.elevated)
    }

    private func statBadge(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 11))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(WatchTheme.textPrimary)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(WatchTheme.textSecond)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(WatchTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
