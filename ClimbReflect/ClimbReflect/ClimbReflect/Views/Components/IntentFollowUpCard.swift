import SwiftUI

/// Vorsatz-Schleife auf „Heute" (MO-11): der zuletzt formulierte Fokus taucht
/// beim nächsten Öffnen wieder auf (Implementation Intentions / Zeigarnik).
/// Kein Abhaken, keine Bewertung – nach der nächsten Kletter-Session verschwindet
/// die Karte wortlos (keine Schuld-Mechanik, S33).
struct IntentFollowUpCard: View {
    let session: ClimbSession

    var body: some View {
        NavigationLink {
            SessionDetailView(session: session)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundStyle(Theme.accent2)
                    Text("Dein Fokus fürs nächste Mal".uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                // Björns eigene Stimme → kein Kursiv (das läse sich als App-Stimme).
                Text(session.improveNext ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(session.date.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
    }
}
