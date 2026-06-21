import SwiftUI
import WatchKit

// Tab-Reihenfolge Klettern:  [Steuerung] ← [Session] → [Klassifizieren]
// Tab-Reihenfolge Training:  [Steuerung] ← [Session]
// Nach Ende: ContentView zeigt SessionEndFlowView via pendingSummaryDTO (Blackscreen-Fix)

struct LiveSessionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @ObservedObject private var syncService = SyncService.shared
    @State private var currentTab = 1
    @State private var showEndConfirm = false
    @State private var selectedAttempt: WatchAttempt? = nil
    @State private var showDiscardConfirm = false
    @State private var showProjectPicker = false

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        NavigationStack {
            if workoutManager.isTraining {
                trainingTabView
            } else {
                climbingTabView
            }
        }
        .onChange(of: workoutManager.sessionEndedUnexpectedly) { _, ended in
            guard ended else { return }
            // endWorkout() setzt pendingSummaryDTO → ContentView zeigt SessionEndFlowView
            Task { @MainActor in
                _ = await workoutManager.endWorkout()
                workoutManager.sessionEndedUnexpectedly = false
            }
        }
        .onChange(of: isLuminanceReduced) { _, reduced in
            // P2-7.3: Sensoren nach Aufwachen sofort synchronisieren
            if !reduced { workoutManager.resyncSensors() }
        }
        .onChange(of: workoutManager.attemptState) { _, state in
            if case .awaitingResult = state, !workoutManager.isTraining {
                currentTab = 2
            }
        }
        .onChange(of: currentTab) { _, tab in
            DiagnosticLog.shared.logVerbose("tab=\(tab) mem=\(MemoryFootprint.residentMB())MB")
        }
        .onChange(of: showProjectPicker) { _, open in
            DiagnosticLog.shared.logVerbose("projectPicker \(open ? "open" : "close") mem=\(MemoryFootprint.residentMB())MB")
        }
        .onAppear {
            // E2: iPhone-Befehle verarbeiten
            SyncService.shared.onCommand = { [workoutManager] cmd in
                switch cmd {
                case "pause":   workoutManager.pauseWorkout()
                case "resume":  workoutManager.resumeWorkout()
                case "end":     Task { _ = await workoutManager.endWorkout() }
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
            Group {
                if currentTab == 2 {
                    AttemptLogView(onBank: { currentTab = 1 })
                } else {
                    Color.clear
                }
            }
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(WatchTheme.bg)
        .sheet(isPresented: $showProjectPicker) {
            projectPickerSheet
        }
        .confirmationDialog("Session beenden?", isPresented: $showEndConfirm) {
            Button("Beenden", role: .destructive) {
                Task { _ = await workoutManager.endWorkout() }
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
                Task { _ = await workoutManager.endWorkout() }
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
    }

    // MARK: - Tab 1 (Klettern): Session-Info + Verlauf

    private var sessionInfoPage: some View {
        TabView {
            statsPage
                .overlay {
                    if workoutManager.attemptState == .awaitingResult {
                        quickResultOverlay
                    }
                }
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
        VStack(spacing: 6) {
            HStack {
                elapsedView
                    .foregroundStyle(workoutManager.isPaused ? WatchTheme.textTert : WatchTheme.accent)
                Spacer(minLength: 0)
            }

            if !workoutManager.healthKitActive {
                hkWarningBanner
            }

            // A2: vitalsRow liest Sensor-Werte nur noch über Blatt-Views
            vitalsRow
                .opacity(isLuminanceReduced ? 0.6 : 1.0)

            HStack(spacing: 8) {
                attemptToggleBadge
                statBadge(value: "\(topCount)",
                          label: "Tops", icon: "checkmark.circle.fill",
                          color: WatchTheme.accent)
            }

            // B1: pendingBanner entfernt (kein Auto-Detektor mehr)

            if !syncService.knownProjects.isEmpty {
                Button { showProjectPicker = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "target")
                            .font(.system(size: 10))
                            .foregroundStyle(workoutManager.selectedProject != nil
                                             ? WatchTheme.gold : WatchTheme.textTert)
                        Text(workoutManager.selectedProject?.name ?? "Projekt wählen")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(workoutManager.selectedProject != nil
                                             ? WatchTheme.textPrimary : WatchTheme.textTert)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(WatchTheme.elevated)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
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

    // MARK: - C1: Versuche-Badge als Start/Stopp-Schalter (Doppeltipp-Geste)

    @ViewBuilder
    private var attemptToggleBadge: some View {
        Button { workoutManager.handleActionButton() } label: {
            if case .active(let startTime) = workoutManager.attemptState {
                TimelineView(.periodic(from: startTime, by: 1)) { _ in
                    Text(formatDuration(Date().timeIntervalSince(startTime)))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(Color.orange.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                statBadge(value: "\(workoutManager.attempts.count)",
                          label: "Versuche", icon: "figure.climbing",
                          color: WatchTheme.textSecond)
            }
        }
        .buttonStyle(.plain)
        .handGestureShortcut(.primaryAction)
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

                elapsedView
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

    // MARK: - HealthKit-Warnbanner

    private var hkWarningBanner: some View {
        let message = workoutManager.healthKitDenied
            ? "HealthKit verweigert – Einstellungen"
            : "Kein HealthKit – kein Hintergrund"
        return HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(WatchTheme.danger)
                .font(.system(size: 11))
            Text(message)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WatchTheme.danger)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(WatchTheme.danger.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Vitals Row (A2: Sensor-Werte in Blatt-Views isoliert)

    private var vitalsRow: some View {
        HStack(spacing: 0) {
            HeartRateCell()
            vitalSep
            if workoutManager.isTraining {
                EnergyCell()
            } else {
                AltitudeGainCell()
            }
            vitalSep
            MaxHRCell()
        }
        .background(WatchTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var vitalSep: some View {
        Divider().frame(height: 28).background(WatchTheme.elevated)
    }

    // MARK: - Hilfsmethoden

    private var topCount: Int {
        workoutManager.attempts.filter { $0.result == .top }.count
    }

    // TimelineView aktualisiert sich auch im Always-On-Modus selbstständig.
    @ViewBuilder
    private var elapsedView: some View {
        if let start = workoutManager.workoutStartDate {
            TimelineView(.periodic(from: start, by: 1)) { _ in
                Text(formatElapsed(workoutManager.currentElapsed()))
                    .font(.system(.title, design: .monospaced, weight: .bold))
            }
        } else {
            Text("00:00")
                .font(.system(.title, design: .monospaced, weight: .bold))
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let s = Int(t)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
    private func timeAgo(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "jetzt" }
        return "vor \(mins) min"
    }

    // MARK: - Projekt-Picker Sheet (P5.7)

    private var projectPickerSheet: some View {
        NavigationStack {
        List {
            Button {
                workoutManager.selectedProject = nil
                showProjectPicker = false
            } label: {
                HStack {
                    Text("Kein Projekt")
                        .font(.system(size: 13))
                        .foregroundStyle(WatchTheme.textSecond)
                    Spacer()
                    if workoutManager.selectedProject == nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11))
                            .foregroundStyle(WatchTheme.accent)
                    }
                }
            }
            ForEach(syncService.knownProjects) { project in
                Button {
                    workoutManager.selectedProject = project
                    showProjectPicker = false
                } label: {
                    HStack {
                        Text(project.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(WatchTheme.textPrimary)
                            .lineLimit(2)
                        Spacer()
                        if workoutManager.selectedProject?.id == project.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11))
                                .foregroundStyle(WatchTheme.accent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Projekt")
        }
    }

    private func statBadge(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 11))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(WatchTheme.textPrimary)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(WatchTheme.textSecond)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(WatchTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - A2: Blatt-Views für Live-Sensor-Werte

private struct HeartRateCell: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "heart.fill").foregroundStyle(WatchTheme.danger).font(.system(size: 11))
            Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.textPrimary)
            Text("BPM").font(.system(size: 9)).foregroundStyle(WatchTheme.textSecond)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
    }
}

private struct AltitudeGainCell: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.up.forward").foregroundStyle(WatchTheme.gold).font(.system(size: 11))
            Text(workoutManager.totalAltitudeGain > 0
                 ? String(format: "%.0f", workoutManager.totalAltitudeGain)
                 : "--")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.textPrimary)
            Text("m").font(.system(size: 9)).foregroundStyle(WatchTheme.textSecond)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
    }
}

private struct EnergyCell: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "flame.fill").foregroundStyle(WatchTheme.gold).font(.system(size: 11))
            Text("\(Int(workoutManager.activeEnergyKcal))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.textPrimary)
            Text("kcal").font(.system(size: 9)).foregroundStyle(WatchTheme.textSecond)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
    }
}

private struct MaxHRCell: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.up.heart.fill")
                .foregroundStyle(WatchTheme.danger.opacity(0.7)).font(.system(size: 11))
            Text(workoutManager.maxHeartRate > 0 ? "\(Int(workoutManager.maxHeartRate))" : "--")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.textPrimary)
            Text("Max").font(.system(size: 9)).foregroundStyle(WatchTheme.textSecond)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
    }
}
