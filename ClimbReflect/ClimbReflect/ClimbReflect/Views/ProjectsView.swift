import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]

    private struct Project: Identifiable {
        let name: String
        var id: String { name }
        let ascents: [Ascent]
        var totalAttempts: Int { ascents.reduce(0) { $0 + $1.attempts } }
        var isSent: Bool { ascents.contains { $0.result == .top } }
        var sentOn: Date? { ascents.first { $0.result == .top }?.date }
        var hardestGrade: String? {
            ascents.filter { $0.result == .top }
                   .max { $0.sortOrder < $1.sortOrder }?.gradeRaw
        }
        var lastAttempt: Date { ascents.map(\.date).max() ?? .distantPast }
    }

    private var projects: [Project] {
        let allAscents = sessions.flatMap(\.ascents).filter { $0.projectName != nil }
        var byName: [String: [Ascent]] = [:]
        for a in allAscents {
            byName[a.projectName!, default: []].append(a)
        }
        return byName.map { Project(name: $0.key, ascents: $0.value) }
            .sorted { ($0.isSent ? 1 : 0, $0.lastAttempt) < ($1.isSent ? 1 : 0, $1.lastAttempt) }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if projects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.textTertiary)
                    Text("Keine Projekte")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Trage bei einer Begehung einen Projektnamen ein, um mehrere Sessions zu verknüpfen.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                List {
                    ForEach(projects) { project in
                        projectRow(project)
                            .listRowBackground(Theme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Projekte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(project.isSent ? Theme.accent.opacity(0.15) : Theme.bgElevated)
                    .frame(width: 44, height: 44)
                Image(systemName: project.isSent ? "checkmark.circle.fill" : "target")
                    .font(.system(size: 20))
                    .foregroundStyle(project.isSent ? Theme.accent : Theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 8) {
                    if let grade = project.hardestGrade {
                        Text(grade)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    Text("\(project.totalAttempts) Versuch\(project.totalAttempts == 1 ? "" : "e")")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if project.isSent, let date = project.sentOn {
                        Text("·  gesendet \(date.formatted(.dateTime.day().month()))")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        ProjectsView()
    }
    .modelContainer(try! ModelContainer(
        for: ClimbSession.self, Ascent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
