import SwiftUI
import SwiftData

struct BetaLibraryView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]
    @State private var searchText = ""

    private var notedAscents: [(ascent: Ascent, session: ClimbSession)] {
        sessions.flatMap { s in
            s.ascents
                .filter { $0.note != nil && !($0.note!.isEmpty) }
                .map { (ascent: $0, session: s) }
        }
        .filter { pair in
            guard !searchText.isEmpty else { return true }
            let q = searchText.lowercased()
            return pair.ascent.gradeRaw.lowercased().contains(q)
                || pair.ascent.note!.lowercased().contains(q)
                || (pair.ascent.projectName?.lowercased().contains(q) ?? false)
        }
        .sorted { $0.ascent.date > $1.ascent.date }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if notedAscents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.textTertiary)
                    Text(searchText.isEmpty ? "Keine Beta-Notizen" : "Kein Ergebnis")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(searchText.isEmpty
                         ? "Füge Notizen zu deinen Begehungen hinzu, um Beta und Schlüsselzüge zu speichern."
                         : "Suche anpassen oder anderen Suchbegriff eingeben.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                List {
                    ForEach(notedAscents, id: \.ascent.id) { pair in
                        betaRow(pair.ascent, session: pair.session)
                            .listRowBackground(Theme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Beta-Bibliothek")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Grad, Projekt oder Stichwort")
        .preferredColorScheme(.dark)
    }

    private func betaRow(_ ascent: Ascent, session: ClimbSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ascent.gradeRaw)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(ascent.gradeSystem.label)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.bgElevated))
                if let name = ascent.projectName {
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Image(systemName: ascent.result.symbol)
                    .foregroundStyle(ascent.result.color)
                Text(ascent.date.formatted(.dateTime.day().month()))
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(ascent.note!)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { BetaLibraryView() }
        .modelContainer(try! ModelContainer(
            for: ClimbSession.self, Ascent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
