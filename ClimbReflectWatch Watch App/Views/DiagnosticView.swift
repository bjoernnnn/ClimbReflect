import SwiftUI
import WatchKit

struct DiagnosticView: View {
    @StateObject private var log = DiagnosticLog.shared
    @State private var showClearConfirm = false

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        List {
            if log.entries.isEmpty {
                Text("Keine Einträge")
                    .font(.caption)
                    .foregroundStyle(WatchTheme.textTert)
            } else {
                ForEach(log.entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.event)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WatchTheme.textPrimary)
                            .lineLimit(3)
                        Text(Self.formatter.string(from: entry.timestamp))
                            .font(.system(size: 9))
                            .foregroundStyle(WatchTheme.textTert)
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    SyncService.shared.sendDiagnostics(log.entries)
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Text("Ans iPhone senden")
                        .font(.caption)
                        .foregroundStyle(WatchTheme.accent)
                }

                Button(role: .destructive) { showClearConfirm = true } label: {
                    Text("Log löschen")
                        .font(.caption)
                        .foregroundStyle(WatchTheme.danger)
                }
            }
        }
        .navigationTitle("Diagnose")
        .safeAreaInset(edge: .top) {
            Text(AppVersion.short)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(WatchTheme.textSecond)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(WatchTheme.bg)
        }
        .confirmationDialog("Log löschen?", isPresented: $showClearConfirm) {
            Button("Löschen", role: .destructive) { log.clear() }
            Button("Abbrechen", role: .cancel) {}
        }
    }
}
