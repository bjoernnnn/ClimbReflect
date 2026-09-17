import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Project.createdAt) private var projects: [Project]

    @State private var showAddProject = false
    @State private var newProjectName = ""
    @State private var pendingDeleteProject: Project? = nil   // VT-2
    @State private var duplicateName: String? = nil   // VT-2
    @State private var pinTrigger = false   // HM-1

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
            AppBackground()
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("Projekte")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // DZ-6: Beta-Bibliothek gehört zu Projekten, nicht zu Erfolgen.
                NavigationLink { BetaLibraryView() } label: {
                    Image(systemName: "books.vertical")
                }
                .tint(Theme.accent)
                .accessibilityLabel("Beta-Bibliothek")

                Button { showAddProject = true } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .tint(Theme.accent)
                .accessibilityLabel("Projekt hinzufügen")
            }
        }
        .sheet(isPresented: $showAddProject) {
            // FB-1: Anlegen inkl. Disziplin + Ziel-Grad
            ProjectGradeSheet(titleText: "Projekt hinzufügen", showsName: true) { name, systemRaw, targetRaw in
                createProject(name: name, gradeSystemRaw: systemRaw, targetGradeRaw: targetRaw)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pinTrigger)
    }

    // MARK: - Listen

    private var projectList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !pinnedProjects.isEmpty {
                    sectionHeader("Angepinnt", count: pinnedProjects.count)
                    ForEach(pinnedProjects) { project in
                        projectRow(project, showSentDate: false)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
                if !activeProjects.isEmpty {
                    sectionHeader("In Arbeit", count: activeProjects.count)
                    ForEach(activeProjects) { project in
                        projectRow(project, showSentDate: false)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
                if !sentProjects.isEmpty {
                    sectionHeader("Geschafft", count: sentProjects.count)
                    ForEach(sentProjects) { project in
                        projectRow(project, showSentDate: true)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
                if !abandonedProjects.isEmpty {
                    sectionHeader("Aufgegeben", count: abandonedProjects.count)
                    ForEach(abandonedProjects) { project in
                        projectRow(project, showSentDate: false)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: projects.map(\.id))
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .confirmationDialog(
            "Projekt löschen?",
            isPresented: Binding(get: { pendingDeleteProject != nil }, set: { if !$0 { pendingDeleteProject = nil } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let project = pendingDeleteProject { deleteProject(project) }
                pendingDeleteProject = nil
            }
            Button("Abbrechen", role: .cancel) { pendingDeleteProject = nil }
        } message: {
            Text("Begehungen bleiben in der Statistik erhalten, verlieren aber die Projekt-Zuordnung.")
        }
        .alert(
            "Projekt existiert bereits",
            isPresented: Binding(get: { duplicateName != nil }, set: { if !$0 { duplicateName = nil } })
        ) {
            Button("OK") { duplicateName = nil }
        } message: {
            Text("„\(duplicateName ?? "")“ ist schon in deiner Liste.")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Keine Projekte", systemImage: "target")
        } description: {
            Text("Ein Projekt ist ein Boulder oder eine Route, an der du dranbleiben willst.")
        } actions: {
            Button("Projekt anlegen") { showAddProject = true }
                .buttonStyle(.borderedProminent)
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
                .background(Capsule().fill(Theme.surfaceRaised))
        }
    }

    private func deleteProject(_ project: Project) {
        context.delete(project)
        try? context.save()
        WatchSessionReceiver.shared.pushProjectsToWatch()
    }

    private func projectRow(_ project: Project, showSentDate: Bool) -> some View {
        NavigationLink(destination: ProjectDetailView(project: project)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(project.isSent ? Theme.gold.opacity(0.15) : Theme.surfaceRaised)
                        .frame(width: 44, height: 44)
                    Image(systemName: project.isSent ? "trophy.fill"
                          : project.isAbandoned ? "xmark.circle"
                          : project.isPinned ? "pin.fill" : "target")
                        .font(.title3)
                        .foregroundStyle(project.isSent ? Theme.gold
                                         : project.isAbandoned ? Theme.textTertiary
                                         : project.isPinned ? Theme.accent
                                         : Theme.textSecondary)
                        .symbolEffect(.bounce, value: project.isPinned)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 8) {
                        // FB-1: Projekt-Ziel-Grad (Stammdatum) prominent; sonst bester Top-Grad
                        if let target = project.displayTargetGrade {
                            Text(target)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.accent)
                        } else if let grade = project.bestTopGrade {
                            Text(GradeConverter.display(grade: grade, storedIn: project.gradeSystem ?? .fontainebleau))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.accent)
                        }
                        if !project.ascents.isEmpty {
                            Text("\(project.ascents.count) Begehung\(project.ascents.count == 1 ? "" : "en") · \(project.distinctDays) Tag\(project.distinctDays == 1 ? "" : "e")")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("Noch keine Begehungen")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    if showSentDate, let date = project.sentOn {
                        Text("Geschafft am \(date.formatted(.dateTime.day().month().year()))")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                    }
                    if !project.betaNotes.isEmpty {
                        Label("Beta vorhanden", systemImage: "note.text")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.surface))
        }
        .opacity(project.isAbandoned ? 0.6 : 1)
        .buttonStyle(.plain)
        .contextMenu {
            if project.isActive {
                Button {
                    project.isPinned.toggle()
                    pinTrigger.toggle()
                    try? context.save()
                    WatchSessionReceiver.shared.pushProjectsToWatch()
                } label: {
                    Label(project.isPinned ? "Anpinnen aufheben" : "Anpinnen",
                          systemImage: project.isPinned ? "pin.slash" : "pin")
                }
                Divider()
            }
            Button(role: .destructive) {
                pendingDeleteProject = project
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private func createProject(name: String, gradeSystemRaw: String? = nil, targetGradeRaw: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { newProjectName = ""; return }
        guard !projects.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            duplicateName = trimmed
            newProjectName = ""
            return
        }
        let project = Project(name: trimmed)
        project.gradeSystemRaw = gradeSystemRaw
        project.targetGradeRaw = targetGradeRaw
        context.insert(project)
        try? context.save()
        WatchSessionReceiver.shared.pushProjectsToWatch()
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
