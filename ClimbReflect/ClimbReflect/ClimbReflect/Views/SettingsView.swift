import SwiftUI
import SwiftData
#if canImport(HealthKit)
import HealthKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [ClimbSession]

    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var showDeleteSamplesConfirm = false
    @State private var exportURL: URL?
    @State private var showExportSheet = false
    @State private var notificationsEnabled = NotificationService.shared.isEnabled

    @AppStorage("boulderScale") private var boulderScale: String = GradeSystem.fontainebleau.rawValue
    @AppStorage("routeScale") private var routeScale: String = GradeSystem.french.rawValue

    private var boulderGradeSystems: [GradeSystem] { [.fontainebleau, .vScale] }
    private var routeGradeSystems: [GradeSystem] { [.french, .uiaa] }

    private var healthKitAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    private var sampleCount: Int {
        sessions.filter { $0.source == .manual && $0.learned == "Mock-Eintrag" }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    // MARK: Health / Sync
                    if healthKitAvailable {
                        Section {
                            HStack {
                                Label("Apple Health", systemImage: "heart.fill")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("Verbunden")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                            }

                            Button {
                                Task { await syncFromHealth() }
                            } label: {
                                HStack {
                                    Label(
                                        isImporting ? "Importiere…" : "Jetzt synchronisieren",
                                        systemImage: isImporting
                                            ? "arrow.triangle.2.circlepath"
                                            : "arrow.down.heart.fill"
                                    )
                                    .foregroundStyle(Theme.accent)
                                    if isImporting {
                                        Spacer()
                                        ProgressView().tint(Theme.accent)
                                    }
                                }
                            }
                            .disabled(isImporting)
                        } header: {
                            Text("Apple Health (optional)").foregroundStyle(Theme.textTertiary)
                        } footer: {
                            Text("Importiert Kletter-Workouts aus Apple Health / Redpoint. Die Watch-Aufzeichnung ist die primäre Quelle — dieser Import ist optional.")
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .listRowBackground(Theme.surface)
                    }

                    // MARK: Grad-Skala
                    Section {
                        Picker("Boulder", selection: $boulderScale) {
                            ForEach(boulderGradeSystems) { s in
                                Text(s.label).tag(s.rawValue)
                            }
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)

                        Picker("Route", selection: $routeScale) {
                            ForEach(routeGradeSystems) { s in
                                Text(s.label).tag(s.rawValue)
                            }
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)
                    } header: {
                        Text("Grad-Skala").foregroundStyle(Theme.textTertiary)
                    } footer: {
                        Text("Legt fest, in welcher Skala Grad-Anzeigen erscheinen. Die Originaldaten bleiben unverändert gespeichert.")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Daten
                    Section {
                        HStack {
                            Label("Sessions gesamt", systemImage: "figure.climbing")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(sessions.count)")
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Button {
                            exportJSON()
                        } label: {
                            Label("Sessions exportieren (JSON)", systemImage: "square.and.arrow.up")
                                .foregroundStyle(Theme.accent)
                        }

                        if sampleCount > 0 {
                            Button(role: .destructive) {
                                showDeleteSamplesConfirm = true
                            } label: {
                                Label("Beispieldaten löschen (\(sampleCount))", systemImage: "trash")
                                    .foregroundStyle(Theme.danger)
                            }
                        }
                    } header: {
                        Text("Meine Daten").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Benachrichtigungen
                    Section {
                        Toggle(isOn: $notificationsEnabled) {
                            Label("Reflexions-Erinnerung", systemImage: "bell.fill")
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .tint(Theme.accent)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await NotificationService.shared.requestAuthorization()
                                    if granted {
                                        NotificationService.shared.isEnabled = true
                                    } else {
                                        notificationsEnabled = false
                                    }
                                }
                            } else {
                                NotificationService.shared.isEnabled = false
                            }
                        }
                    } header: {
                        Text("Benachrichtigungen").foregroundStyle(Theme.textTertiary)
                    } footer: {
                        Text("Sendet 2 Stunden nach einer Session eine Erinnerung, die Reflexion auszufüllen.")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Datenschutz
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(Theme.accent)
                                .font(.system(size: 20))
                            Text("Alle deine Daten bleiben ausschließlich auf deinem Gerät gespeichert. Es werden keine Daten an externe Server übertragen.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Datenschutz").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Schuhe (SH-2)
                    Section {
                        NavigationLink(destination: ShoesView()) {
                            Label("Schuhe verwalten", systemImage: "shoeprints.fill")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    } header: {
                        Text("Ausrüstung").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Diagnose
                    Section {
                        NavigationLink(destination: WatchDiagnosticsView()) {
                            Label("Watch-Diagnose", systemImage: "stethoscope")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    } header: {
                        Text("Entwicklung").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // MARK: Version
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(Theme.textPrimary)
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
            .alert("Apple Health / Redpoint", isPresented: .constant(importMessage != nil), presenting: importMessage) { _ in
                Button("OK") { importMessage = nil }
            } message: { Text($0) }
            .confirmationDialog(
                "Beispieldaten löschen?",
                isPresented: $showDeleteSamplesConfirm,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) { deleteSamples() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("\(sampleCount) Beispielsession(s) werden unwiderruflich gelöscht.")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    // MARK: - Aktionen

    private func syncFromHealth() async {
        isImporting = true
        defer { isImporting = false }
        do {
            let n = try await RedpointHealthService.shared.importNewSessions(into: context)
            importMessage = n > 0 ? "\(n) neue Session(s) importiert." : "Keine neuen Workouts gefunden."
        } catch {
            importMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func deleteSamples() {
        let toDelete = sessions.filter { $0.source == .manual && $0.learned == "Mock-Eintrag" }
        toDelete.forEach { context.delete($0) }
    }

    private func exportJSON() {
        struct ExportSession: Encodable {
            let id: String
            let date: Date
            let durationMinutes: Int
            let sessionType: String
            let source: String
            let perceivedEffort: Int?
            let limiters: [String]
            let learned: String?
            let hardestPart: String?
            let improveNext: String?
            let reflectionCompleted: Bool
        }
        let data = sessions.map {
            ExportSession(
                id: $0.id.uuidString,
                date: $0.date,
                durationMinutes: $0.durationMinutes,
                sessionType: $0.sessionTypeRaw,
                source: $0.sourceRaw,
                perceivedEffort: $0.perceivedEffort,
                limiters: $0.limiterRaw,
                learned: $0.learned,
                hardestPart: $0.hardestPart,
                improveNext: $0.improveNext,
                reflectionCompleted: $0.reflectionCompleted
            )
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(data) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClimbReflect-Sessions.json")
        try? jsonData.write(to: url)
        exportURL = url
        showExportSheet = true
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    MockData.seedIfNeeded(container.mainContext)
    return SettingsView().modelContainer(container)
}
