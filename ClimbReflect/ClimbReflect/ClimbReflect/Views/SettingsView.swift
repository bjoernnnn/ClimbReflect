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
                            Text("Redpoint / Apple Health").foregroundStyle(Theme.textTertiary)
                        } footer: {
                            Text("Importiert Kletter-Workouts aus Redpoint (Apple Health). Bereits importierte Sessions werden nicht doppelt angelegt.")
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .listRowBackground(Theme.surface)
                    }

                    // MARK: Daten
                    Section {
                        HStack {
                            Label("Sessions gesamt", systemImage: "figure.climbing")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(sessions.count)")
                                .foregroundStyle(Theme.textSecondary)
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
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

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
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    MockData.seedIfNeeded(container.mainContext)
    return SettingsView().modelContainer(container)
}
