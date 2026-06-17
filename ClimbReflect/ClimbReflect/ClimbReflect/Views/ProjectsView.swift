import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt) private var projects: [Project]

    @State private var showAddProject = false
    @State private var newProjectName = ""

    private var pinnedProjects: [Project] {
        projects.filter { $0.isPinned && $0.isActive }
    }
    private var activeProjects: [Project] {
        projects.filter { $0.isActive && !$0.isPinned }
            .sorted { $0.lastAttempt > $1.lastAttempt }
    }
    private var sentProjects: [Project] {
        projects.filter(\.isSent)
            .sorted { ($0.sentOn ?? .distantPast) > ($1.sentOn ?? .distantPast) }
    }
    private var abandonedProjects: [Project] {
        projects.filter(\.isAbandoned)
            .sorted { $0.lastAttempt > $1.lastAttempt }
    }

    var body: some View {
        ZStack {
            MountainBackground()
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("Projekte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddProject = true } label: {
                    Image(systemName: "plus")
                }
                .tint(Theme.accent)
            }
        }
        .alert("Projekt hinzufügen", isPresented: $showAddProject) {
            TextField("Projektname", text: $newProjectName)
            Button("Hinzufügen") { createProject(name: newProjectName) }
            Button("Abbrechen", role: .cancel) { newProjectName = "" }
        } message: {
            Text("Name des Projekts (Route oder Boulder)")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Listen

    private var projectList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !pinnedProjects.isEmpty {
                    sectionHeader("Angepinnt", count: pinnedProjects.count)
                    ForEach(pinnedProjects) { project in
                        projectRow(project, showSentDate: false)
                    }
                }
                if !activeProjects.isEmpty {
                    sectionHeader("In Arbeit", count: activeProjects.count)
                    ForEach(activeProjects) { project in
                        projectRow(project, showSentDate: false)
                    }
                }
                if !sentProjects.isEmpty {
                    sectionHeader("Gesendet ✓", count: sentProjects.count)
                    ForEach(sentProjects) { project in
                        projectRow(project, showSentDate: true)
                    }
                }
                if !abandonedProjects.isEmpty {
                    sectionHeader("Aufgegeben", count: abandonedProjects.count)
                    ForEach(abandonedProjects) { project in
                        projectRow(project, showSentDate: false)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textTertiary)
            Text("Keine Projekte")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Tippe auf + um ein neues Projekt anzulegen, oder wähle beim Erfassen einer Begehung ein Projekt aus.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showAddProject = true
            } label: {
                Label("Projekt anlegen", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 4)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.bgElevated))
        }
    }

    private func projectRow(_ project: Project, showSentDate: Bool) -> some View {
        NavigationLink(destination: ProjectDetailView(project: project)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(project.isSent ? Theme.accent.opacity(0.15) : Theme.bgElevated)
                        .frame(width: 44, height: 44)
                    Image(systemName: project.isSent ? "checkmark.circle.fill"
                          : project.isAbandoned ? "xmark.circle"
                          : project.isPinned ? "pin.fill" : "target")
                        .font(.system(size: 20))
                        .foregroundStyle(project.isSent ? Theme.accent
                                         : project.isAbandoned ? Theme.textTertiary
                                         : project.isPinned ? Theme.gold
                                         : Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 8) {
                        if let grade = project.bestTopGrade {
                            Text(grade)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.accent)
                        } else if let target = project.targetGradeRaw {
                            Text("Ziel: \(target)")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        if project.totalAttempts > 0 {
                            Text("\(project.totalAttempts) Versuch\(project.totalAttempts == 1 ? "" : "e") · \(project.distinctDays) Tag\(project.distinctDays == 1 ? "" : "e")")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("Noch keine Begehungen")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    if showSentDate, let date = project.sentOn {
                        Text("Gesendet \(date.formatted(.dateTime.day().month().year()))")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                    if !project.betaNotes.isEmpty {
                        Label("Beta vorhanden", systemImage: "note.text")
                            .font(.caption2)
                            .foregroundStyle(Theme.gold)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        }
        .buttonStyle(.plain)
    }

    private func createProject(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { newProjectName = ""; return }
        guard !projects.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            newProjectName = ""
            return
        }
        context.insert(Project(name: trimmed))
        try? context.save()
        newProjectName = ""
    }
}

#Preview {
    NavigationStack {
        ProjectsView()
    }
    .modelContainer(try! ModelContainer(
        for: ClimbSession.self, Ascent.self, Project.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
