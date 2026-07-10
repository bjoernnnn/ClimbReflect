import SwiftUI

/// „Damals" am Fuß des Fortschritt-Tabs (MO-12): eine eigene Reflexion von vor
/// ≥ 90 Tagen macht Distanz erlebbar, die kein Chart transportiert. Bewusst der
/// ruhigste Ort der Seite – ein Nachklang, kein Attention-Grabber (kein
/// Akzentrand). Reines Zitat, keine Deutung.
struct ThrowbackCard: View {
    let session: ClimbSession

    private var quote: String {
        let learned = session.learned?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return learned.isEmpty ? (session.hardestPart ?? "") : learned
    }

    var body: some View {
        NavigationLink {
            SessionDetailView(session: session)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Damals")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("· \(session.date.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(quote)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
    }
}
