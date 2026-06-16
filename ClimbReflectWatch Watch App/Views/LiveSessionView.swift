import SwiftUI
import WatchKit

// Tab-Reihenfolge Klettern:  [Steuerung] ← [Session] → [Klassifizieren]
// Tab-Reihenfolge Training:  [Steuerung] ← [Session]
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
    @State private var showDiscardConfirm = false

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        NavigationStack(path: $navPath) {
            if workoutManager.isTraining {
                trainingTabView
            } else {
                climbingTabView
            }
        }
        .onAppear {
            // E2: iPhone-Befehle verarbeiten
            SyncService.shared.onCommand = { [workoutManager] cmd in
                switch cmd {
                case "pause":   workoutManager.pauseWorkout()
                case "resume":  workoutManager.resumeWorkout()
                case "end":
                    Task {
                        let dto = await workoutManager.endWorkout()
                        if let d = dto { SyncService.shared.send(dto: d) }
                        workoutManager.finishSession()
                    }
                default: break
                }
            }
        }
    }

    // MARK: - Klettern: 3-Tab-View

    private var climbingTabView: some View {
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
        .confirmationDialog("Session verwerfen?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) {
                workoutManager.discardWorkout()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Session wird nicht gespeichert.")
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
                SessionSummaryView(dto: sessionDTO, onDone: {
                    navPath = []
                    workoutManager.finishSession()
                })
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Training: 2-Tab-View

    private var trainingTabView: some View {
        TabView(selection: $currentTab) {
            controlsPage.tag(0)
            trainingInfoPage.tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(WatchTheme.bg)
        .confirmationDialog("Training beenden?", isPresented: $showEndConfirm) {
            Button("Beenden", role: .destructive) {
                Task {
                    sessionDTO = await workoutManager.endWorkout()
                    navPath = [.questionnaire]
                }
            }
            Button("Weiter", role: .cancel) {}
        }
        .confirmationDialog("Training verwerfen?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) {
                workoutManager.discardWorkout()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dieses Training wird nicht gespeichert.")
        }
        .navigationDestination(for: WatchNavStep.self) { step in
            switch step {
            case .questionnaire:
                if let dto = sessionDTO {
                    SessionEndQuestionnaireView(dto: dto, skipFocus: true) { enriched in
                        SyncService.shared.send(dto: enriched)
                        sessionDTO = enriched
                        navPath = [.summary]
                    }
                }
            case .summary:
                SessionSummaryView(dto: sessionDTO, onDone: {
                    navPath = []
                    workoutManager.finishSession()
                })
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Tab 1 (Klettern): Session-Info + Verlauf (Wetter-App-Muster: verticalPage)

    private var sessionInfoPage: some View {
        TabView {
            // ── Seite 1: Stats ──
            statsPage
                .overlay {
                    if workoutManager.attemptState == .awaitingResult {
                        quickResultOverlay
                    }
                }

            // ── Seite 2: Verlauf (nur sichtbar wenn Begehungen vorhanden) ──
            if !workoutManager.attempts.isEmpty {
                historyPage
            }
        }
        .tabViewStyle(.verticalPage)
        .background(WatchTheme.bg)
        .sheet(item: $selectedAttempt) { attempt in
            AscentDetailView(attempt: attempt) {
                workoutManager.removeAttempt(id: attempt.id)
            }
        }
    }

    private var statsPage: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            Text(elapsedFormatted)
                .font(.system(.title, design: .monospaced, weight: .bold))
                .foregroundStyle(workoutManager.isPaused ? WatchTheme.textTert : WatchTheme.accent)

            vitalsRow
                .opacity(isLuminanceReduced ? 0.6 : 1.0)

            HStack(spacing: 8) {
                statBadge(value: "\(workoutManager.attempts.count)",
                          label: "Versuche", icon: "figure.climbing",
                          color: WatchTheme.textSecond)
                statBadge(value: "\(topCount)",
                          label: "Tops", icon: "checkmark.circle.fill",
                          color: WatchTheme.accent)
            }

            if workoutManager.pendingClassifications > 0 { pendingBanner }

            Spacer(minLength: 0)

            actionStateIndicator.padding(.bottom, 4)
        }
        .padding(.horizontal, 8)
    }

    private var historyPage: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                ForEach(workoutManager.attempts.reversed()) { attempt in
                    ascentRow(attempt)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    // MARK: - D1: Action-Button Indikator & Quick-Result-Overlay

    private var actionStateIndicator: some View {
        Group {
            switch workoutManager.attemptState {
            case .idle:
                EmptyView()
            case .active:
                HStack(spacing: 6) {
                    Circle()
                        .fill(WatchTheme.danger)
                        .frame(width: 8, height: 8)
                        .symbolEffect(.pulse, options: .repeating)
                    Text("Versuch läuft")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WatchTheme.danger)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(WatchTheme.danger.opacity(0.12))
                .clipShape(Capsule())
            case .awaitingResult:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var quickResultOverlay: some View {
        VStack(spacing: 10) {
            Text("Ergebnis?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WatchTheme.textPrimary)

            HStack(spacing: 8) {
                quickResultButton(label: "Top", icon: "checkmark.circle.fill",
                                  color: WatchTheme.accent, result: .top)
                quickResultButton(label: "Versuch", icon: "arrow.clockwise.circle",
                                  color: WatchTheme.gold, result: .attempt)
            }

            Button {
                Task { await workoutManager.quickBank(result: .quit) }
            } label: {
                Label("Abbruch", systemImage: "xmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WatchTheme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(WatchTheme.danger.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button {
                workoutManager.attemptState = .idle
            } label: {
                Text("Abbrechen")
                    .font(.system(size: 10))
                    .foregroundStyle(WatchTheme.textTert)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(WatchTheme.bg.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(8)
    }

    private func quickResultButton(label: String, icon: String, color: Color, result: WatchAscentResult) -> some View {
        let btn = Button {
            Task { await workoutManager.quickBank(result: result) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WatchTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        return AnyView(result == .top ? AnyView(btn.handGestureShortcut(.primaryAction)) : AnyView(btn))
    }

    // MARK: - Tab 1 (Training): Trainings-Info

    private var trainingInfoPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                Spacer(minLength: 0).frame(height: 8)

                Text(elapsedFormatted)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(workoutManager.isPaused ? WatchTheme.textTert : WatchTheme.accent)

                if let target = workoutManager.trainingTarget {
                    HStack(spacing: 6) {
                        Image(systemName: target.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(WatchTheme.accent)
                        Text(target.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(WatchTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(WatchTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
                }

                vitalsRow
                    .opacity(isLuminanceReduced ? 0.6 : 1.0)

                Spacer(minLength: 0).frame(height: 8)
            }
            .padding(.horizontal, 8)
        }
        .background(WatchTheme.bg)
    }

    private func ascentRow(_ attempt: WatchAttempt) -> some View {
        Button { selectedAttempt = attempt } label: {
            HStack(spacing: 8) {
                Image(systemName: attempt.result?.symbol ?? "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(attempt.result?.color ?? WatchTheme.textTert)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attempt.grade ?? "–")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(WatchTheme.textPrimary)
                    if attempt.altitudeGain > 0.5 {
                        Text(String(format: "%.0f m", attempt.altitudeGain))
                            .font(.system(size: 9))
                            .foregroundStyle(WatchTheme.textTert)
                    }
                }

                if let style = attempt.style {
                    Text(style.shortLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(WatchTheme.gold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(WatchTheme.gold.opacity(0.15))
                        .clipShape(Capsule())
                        .fixedSize()
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
            .handGestureShortcut(.primaryAction)

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

            Button { showDiscardConfirm = true } label: {
                Label("Verwerfen", systemImage: "trash")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WatchTheme.textTert)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(WatchTheme.elevated)
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

    // MARK: - Shared UI

    private var vitalsRow: some View {
        HStack(spacing: 0) {
            vitalCell(value: heartStr, unit: "BPM",
                      icon: "heart.fill", color: WatchTheme.danger)
            vitalSep
            if workoutManager.isTraining {
                vitalCell(value: "\(Int(workoutManager.activeEnergyKcal))", unit: "kcal",
                          icon: "flame.fill", color: WatchTheme.gold)
            } else {
                vitalCell(value: String(format: "%.0f", workoutManager.totalAltitudeGain), unit: "m",
                          icon: "arrow.up.forward", color: WatchTheme.gold)
            }
            vitalSep
            vitalCell(value: maxHRStr, unit: "Max",
                      icon: "arrow.up.heart.fill", color: WatchTheme.danger.opacity(0.7))
        }
        .background(WatchTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var scrollHint: some View {
        Image(systemName: "chevron.compact.down")
            .font(.system(size: 14))
            .foregroundStyle(WatchTheme.textTert)
            .padding(.bottom, 4)
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
