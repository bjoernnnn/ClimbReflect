import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]
    @Query(sort: \Project.createdAt) private var projectEntities: [Project]

    @State private var selectedProject: DerivedProject? = nil
    @State private var showAddProject = false
    @State private var newProjectName = ""

    // Kombiniert abgeleitete Ascent-Daten mit optionalen Project-Entities
    struct DerivedProject: Identifiable {
        let name: String
        var id: String { name }
        let ascents: [Ascent]
        let entity: Project?

        var totalAttempts: Int { ascents.reduce(0) { $0 + $1.attempts } }
        var distinctDays: Int {
            let dates = Set(ascents.compactMap { Calendar.current.startOfDay(for: $0.date) })
            return dates.count
        }
        var isSent: Bool {
            if entity?.statusRaw == Project.Status.abandoned.rawValue { return false }
            return ascents.contains { $0.result == .top }
        }
        var isAbandoned: Bool { entity?.statusRaw == Project.Status.abandoned.rawValue }
        var isActive: Bool { !isSent && !isAbandoned }
        var isPinned: Bool { entity?.isPinned ?? false }
        var sentOn: Date? { ascents.filter { $0.result == .top }.map(\.date).min() }
        var lastAttempt: Date { ascents.map(\.date).max() ?? .distantPast }
        var bestTopGrade: String? {
            ascents.filter { $0.result == .top }
                .max { $0.sortOrder < $1.sortOrder }?.gradeRaw
        }
        var betaNotes: String { entity?.betaNotes ?? "" }
    }

    private var derivedProjects: [DerivedProject] {
        let allAscents = sessions.flatMap(\.ascents).filter { $0.projectName != nil }
        var byName: [String: [Ascent]] = [:]
        for a in allAscents { byName[a.projectName!, default: []].append(a) }
        return byName.map { name, ascents in
            DerivedProject(
                name: name,
                ascents: ascents,
                entity: projectEntities.first { $0.name == name }
            )
        }
    }

    private var pinnedProjects: [DerivedProject] {
        derivedProjects.filter { $0.isActive && $0.isPinned }
            .sorted { $0.lastAttempt > $1.lastAttempt }
    }
    private var activeProjects: [DerivedProject] {
        derivedProjects.filter { $0.isActive && !$0.isPinned }
            .sorted { $0.lastAttempt > $1.lastAttempt }
    }
    private var sentProjects: [DerivedProject] {
        derivedProjects.filter(\.isSent)
            .sorted { ($0.sentOn ?? .distantPast) > ($1.sentOn ?? .distantPast) }
    }
    private var abandonedProjects: [DerivedProject] {
        derivedProjects.filter(\.isAbandoned)
            .sorted { $0.lastAttempt > $1.lastAttempt }
    }

    var body: some View {
        ZStack {
            MountainBackground()
            if derivedProjects.isEmpty {
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
        .sheet(item: $selectedProject) { project in
            ProjectDetailSheet(project: project) { notes, abandoned, pinned in
                saveProjectEntity(name: project.name, betaNotes: notes, abandoned: abandoned, pinned: pinned)
            }
        }
        .alert("Projekt hinzufügen", isPresented: $showAddProject) {
            TextField("Projektname", text: $newProjectName)
            Button("Hinzufügen") { createProjectEntity(name: newProjectName) }
            Button("Abbrechen", role: .cancel) { newProjectName = "" }
        } message: {
            Text("Name des Projekts (Route oder Boulder)")
        }
        .preferredColorScheme(.dark)
    }

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
            Text("Trage bei einer Begehung einen Projektnamen ein, oder tippe auf + um ein Projekt anzulegen.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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

    private func projectRow(_ project: DerivedProject, showSentDate: Bool) -> some View {
        let rowContent = projectRowContent(project, showSentDate: showSentDate)
        return Group {
            if let entity = project.entity {
                NavigationLink(destination: ProjectDetailView(project: entity)) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                Button { selectedProject = project } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func projectRowContent(_ project: DerivedProject, showSentDate: Bool) -> some View {
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
                    }
                    Text("\(project.totalAttempts) Versuch\(project.totalAttempts == 1 ? "" : "e") · \(project.distinctDays) Tag\(project.distinctDays == 1 ? "" : "e")")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
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

    private func createProjectEntity(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { newProjectName = ""; return }
        if !projectEntities.contains(where: { $0.name == trimmed }) {
            context.insert(Project(name: trimmed))
            try? context.save()
        }
        newProjectName = ""
    }

    private func saveProjectEntity(name: String, betaNotes: String, abandoned: Bool, pinned: Bool) {
        if let existing = projectEntities.first(where: { $0.name == name }) {
            existing.betaNotes = betaNotes
            existing.statusRaw = abandoned ? Project.Status.abandoned.rawValue : nil
            existing.isPinned = pinned
        } else {
            let p = Project(name: name, betaNotes: betaNotes,
                            statusRaw: abandoned ? Project.Status.abandoned.rawValue : nil,
                            isPinned: pinned)
            context.insert(p)
        }
        try? context.save()
    }
}

// MARK: - Projekt-Detail-Sheet

private struct ProjectDetailSheet: View {
    let project: ProjectsView.DerivedProject
    let onSave: (String, Bool, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var betaNotes: String
    @State private var isAbandoned: Bool
    @State private var isPinned: Bool

    init(project: ProjectsView.DerivedProject, onSave: @escaping (String, Bool, Bool) -> Void) {
        self.project = project
        self.onSave = onSave
        _betaNotes = State(initialValue: project.betaNotes)
        _isAbandoned = State(initialValue: project.isAbandoned)
        _isPinned = State(initialValue: project.isPinned)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Stats-Übersicht
                        HStack(spacing: 12) {
                            statTile(value: "\(project.totalAttempts)", label: "Versuche")
                            statTile(value: "\(project.distinctDays)", label: "Tage")
                            if let grade = project.bestTopGrade {
                                statTile(value: grade, label: "Bester Top")
                            }
                        }

                        // Beta-Notizen
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Beta-Notizen", systemImage: "note.text")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                            ZStack(alignment: .topLeading) {
                                if betaNotes.isEmpty {
                                    Text("z. B. Schlüsselzug: Heel-Hook links, dann dynamisch zum Sloperkante…")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textTertiary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 18)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $betaNotes)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(10)
                            }
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgElevated))
                        }

                        // Anpinnen + Status
                        VStack(spacing: 0) {
                            Toggle(isOn: $isPinned) {
                                Label("Angepinnt", systemImage: "pin.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .tint(Theme.gold)
                            .padding(14)

                            Divider().background(Theme.surfaceStroke).padding(.horizontal, 14)

                            Toggle(isOn: $isAbandoned) {
                                Label("Projekt aufgegeben", systemImage: "xmark.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .tint(Theme.danger)
                            .padding(14)
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        onSave(betaNotes, isAbandoned, isPinned)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
    }
}

// MARK: - Identifiable extension for sheet

extension ProjectsView.DerivedProject: @unchecked Sendable {}

#Preview {
    NavigationStack {
        ProjectsView()
    }
    .modelContainer(try! ModelContainer(
        for: ClimbSession.self, Ascent.self, Project.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
}
