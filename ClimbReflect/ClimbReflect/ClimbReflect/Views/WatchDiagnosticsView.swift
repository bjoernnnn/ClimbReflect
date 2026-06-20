import SwiftUI

struct WatchDiagnosticsView: View {
    @ObservedObject var receiver = WatchSessionReceiver.shared

    var body: some View {
        ScrollView {
            if receiver.diagnosticLogText.isEmpty {
                Text("Noch kein Log empfangen.\nAuf der Watch: Diagnose \u{2192} Ans iPhone senden.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                Text(receiver.diagnosticLogText)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .navigationTitle("Watch-Diagnose")
        .toolbar {
            if let url = receiver.diagnosticLogFileURL {
                ShareLink(item: url)
            }
        }
    }
}
