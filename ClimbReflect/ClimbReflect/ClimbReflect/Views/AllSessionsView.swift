import SwiftUI
import SwiftData

struct AllSessionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]

    var body: some View {
        ZStack {
            MountainBackground()

            if sessions.isEmpty {
                Text("Noch keine Sessions.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                List {
                    ForEach(sessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            SessionRow(session: session)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Alle Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { EditButton() }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
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
