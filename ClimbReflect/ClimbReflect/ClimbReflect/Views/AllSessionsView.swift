import SwiftUI
import SwiftData

struct AllSessionsView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]

    var body: some View {
        ZStack {
            MountainBackground()

            if sessions.isEmpty {
                Text("Noch keine Sessions.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(sessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                SessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Alle Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    MockData.seedIfNeeded(container.mainContext)
    return NavigationStack { AllSessionsView() }
        .modelContainer(container)
}
