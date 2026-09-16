import SwiftUI
import SwiftData
import PhotosUI

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ClimbSession.date, order: .reverse) private var allSessions: [ClimbSession]   // VT-8

    @State private var editingBetaNotes = false
    @State private var betaNotesDraft = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var editingCaption: ProjectMedia? = nil
    @State private var captionDraft = ""
    @State private var showDeleteConfirm = false
    @State private var showGradeEditor = false   // FB-1
    @State private var editedAscent: Ascent? = nil   // GR-2
    @State private var pendingDeleteAscent: Ascent? = nil   // VT-1
    @State private var showSessionChoice = false   // VT-8
    @State private var addAscentSession: ClimbSession? = nil   // VT-8
    @State private var showNewSessionForProject = false   // VT-8

    // VT-8: Klettersessions der letzten 3 Kalendertage, deren Disziplin zum Projekt passt.
    private var candidateSessions: [ClimbSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -3, to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
        let projectIsBoulder = project.gradeSystem?.isBoulder
        return allSessions
            .filter { $0.isClimbing && $0.date >= cutoff }
            .filter { session in
                guard let projectIsBoulder else { return true }
                return GradeDefaults.discipline(for: session.sessionType).isBoulder == projectIsBoulder
            }
            .sorted { $0.date > $1.date }
            .prefix(3)
            .map { $0 }
    }

    private func relativeDayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "heute" }
        if cal.isDateInYesterday(date) { return "gestern" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private var sortedAscents: [Ascent] {
        project.ascents.sorted { $0.date > $1.date }
    }

    private var ascentsGroupedBySession: [(date: Date, ascents: [Ascent])] {
        let grouped = Dictionary(grouping: sortedAscents) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { date in
            (date: date, ascents: grouped[date]!.sorted { $0.createdAt < $1.createdAt })
        }
    }

    private var sortedMedia: [ProjectMedia] {
        project.media.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    if !project.isAbandoned {
                        addAscentButton
                    }
                    ProjectDayTimeline(project: project)
                    betaNotesCard
                    mediaGallery
                    if !ascentsGroupedBySession.isEmpty {
                        attemptTimeline
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        project.isPinned.toggle()
                        try? context.save()
                    } label: {
                        Label(project.isPinned ? "Anpinnen aufheben" : "Anpinnen",
                              systemImage: project.isPinned ? "pin.slash" : "pin")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Projekt löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .confirmationDialog("Projekt löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                context.delete(project)
                try? context.save()
                WatchSessionReceiver.shared.pushProjectsToWatch()
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Projekt wird gelöscht. Bestehende Begehungen bleiben erhalten.")
        }
        .sheet(item: $editingCaption) { media in
            captionSheet(for: media)
        }
        .sheet(isPresented: $showGradeEditor) {
            // FB-1: Ziel-Grad in der Detailansicht bearbeiten (Name bleibt unverändert)
            ProjectGradeSheet(
                titleText: "Grad festlegen",
                showsName: false,
                name: project.name,
                gradeSystemRaw: project.gradeSystemRaw,
                targetGradeRaw: project.targetGradeRaw
            ) { _, systemRaw, targetRaw in
                project.gradeSystemRaw = systemRaw
                project.targetGradeRaw = targetRaw
                try? context.save()
                WatchSessionReceiver.shared.pushProjectsToWatch()
            }
        }
        .onChange(of: selectedPhotos) { _, items in
            Task { await addPhotos(items) }
        }
        .confirmationDialog("Zu welcher Session?", isPresented: $showSessionChoice, titleVisibility: .visible) {
            ForEach(candidateSessions) { session in
                Button("\(session.sessionType.label) · \(relativeDayLabel(session.date))") {
                    addAscentSession = session
                }
            }
            Button("Neue Session …") { showNewSessionForProject = true }
            Button("Abbrechen", role: .cancel) {}
        }
        .sheet(item: $addAscentSession) { session in
            AddAscentView(session: session, preselectedProject: project)
        }
        .sheet(isPresented: $showNewSessionForProject) {
            ManualSessionView(preselectedProject: project)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: project.isPinned)
        .sensoryFeedback(.impact(weight: .medium), trigger: project.statusRaw)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: statusSymbol)
                        .font(.title3)
                        .foregroundStyle(statusColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(statusColor.opacity(0.15)))
                    // FB-1: Ziel-Grad (Stammdatum) – tappbar; fehlt er → Hinweis-Chip
                    Button { showGradeEditor = true } label: {
                        if let grade = project.displayTargetGrade {
                            Label(grade, systemImage: "chart.bar.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        } else {
                            Label("Grad festlegen", systemImage: "plus.circle")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if project.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.gold)
                        .symbolEffect(.bounce, value: project.isPinned)
                }
            }

            HStack(spacing: 12) {
                let tops = project.ascents.filter { $0.result == .top }.count

                statPill(value: "\(project.distinctDays)", label: "Tage")
                statPill(value: "\(project.ascents.count)", label: "Begehungen")
                statPill(value: "\(tops)", label: "Tops")
            }

            if project.isAbandoned {
                Button {
                    project.statusRaw = nil
                    try? context.save()
                } label: {
                    Label("Wieder aktivieren", systemImage: "arrow.uturn.backward.circle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            } else if !project.isSent {
                Button {
                    project.statusRaw = Project.Status.abandoned.rawValue
                    try? context.save()
                } label: {
                    Label("Aufgeben", systemImage: "xmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    // MARK: - VT-8: Begehung direkt aus dem Projekt

    private var addAscentButton: some View {
        Button {
            showSessionChoice = true
        } label: {
            Label("Begehung erfassen", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.accent)
    }

    // MARK: - Beta Notes

    private var betaNotesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Beta-Notizen", systemImage: "note.text")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    betaNotesDraft = project.betaNotes
                    editingBetaNotes = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(Theme.accent)
                }
            }
            if project.betaNotes.isEmpty {
                Text("Noch keine Beta-Notizen. Tippe auf Bearbeiten.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Text(project.betaNotes)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .card()
        .sheet(isPresented: $editingBetaNotes) {
            betaNotesSheet
        }
    }

    private var betaNotesSheet: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ZStack(alignment: .topLeading) {
                    if betaNotesDraft.isEmpty {
                        Text("z. B. Schlüsselzug: Heel-Hook links, dann dynamisch…")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 22)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $betaNotesDraft)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                }
                .padding()
            }
            .navigationTitle("Beta-Notizen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { editingBetaNotes = false }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        project.betaNotes = betaNotesDraft
                        try? context.save()
                        editingBetaNotes = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - Media Gallery (P5.6)

    private var mediaGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Fotos", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Theme.accent)
                }
            }
            if sortedMedia.isEmpty {
                Text("Noch keine Fotos. Tippe auf + um Bilder hinzuzufügen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(sortedMedia) { media in
                        mediaThumb(media)
                    }
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private func mediaThumb(_ media: ProjectMedia) -> some View {
        if let data = media.imageData, let uiImage = UIImage(data: data) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                    .onTapGesture {
                        captionDraft = media.caption ?? ""
                        editingCaption = media
                    }

                Button {
                    context.delete(media)
                    try? context.save()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .padding(4)
            }

            if let caption = media.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private func captionSheet(for media: ProjectMedia) -> some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    if let data = media.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                            .padding(.horizontal)
                    }
                    TextField("Beschriftung (optional)", text: $captionDraft)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surfaceRaised))
                        .padding(.horizontal)
                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Foto bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { editingCaption = nil }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        media.caption = captionDraft.isEmpty ? nil : captionDraft
                        try? context.save()
                        editingCaption = nil
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - Attempt Timeline

    private var attemptTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verlauf")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            ForEach(ascentsGroupedBySession, id: \.date) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.date.formatted(.dateTime.day().month().year()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)

                    VStack(spacing: 0) {
                        ForEach(group.ascents) { ascent in
                            AscentRowView(ascent: ascent)
                                .contentShape(Rectangle())
                                .onTapGesture { editedAscent = ascent }   // GR-2: Grad/Ergebnis/Stil korrigierbar
                                .contextMenu {
                                    Button {
                                        editedAscent = ascent
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        pendingDeleteAscent = ascent
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            if ascent.id != group.ascents.last?.id {
                                Divider().background(Theme.separator)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surface))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                }
            }
        }
        .card()
        .sheet(item: $editedAscent) { ascent in
            EditAscentAssociationsSheet(ascent: ascent)
        }
        .confirmationDialog(
            "Begehung löschen?",
            isPresented: Binding(get: { pendingDeleteAscent != nil }, set: { if !$0 { pendingDeleteAscent = nil } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let ascent = pendingDeleteAscent { deleteAscent(ascent) }
                pendingDeleteAscent = nil
            }
            Button("Abbrechen", role: .cancel) { pendingDeleteAscent = nil }
        } message: {
            Text("Die Begehung wird aus Statistik und Projekt entfernt. Freigeschaltete Erfolge bleiben erhalten.")
        }
    }

    private func deleteAscent(_ ascent: Ascent) {
        context.delete(ascent)
        try? context.save()
        AchievementService.shared.checkNow(context: context)   // EP-3
    }

    // MARK: - Helpers

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let media = ProjectMedia(imageData: data)
            context.insert(media)
            project.media.append(media)
        }
        try? context.save()
        selectedPhotos = []
    }

    private var statusLabel: String {
        if project.isSent { return "Geschafft" }
        if project.isAbandoned { return "Aufgegeben" }
        return "Aktiv"
    }

    private var statusSymbol: String {
        if project.isSent { return "checkmark.circle.fill" }
        if project.isAbandoned { return "xmark.circle" }
        return "target"
    }

    private var statusColor: Color {
        if project.isSent { return Theme.accent }
        if project.isAbandoned { return Theme.textTertiary }
        return Theme.gold
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surfaceRaised))
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Project.self, Ascent.self, ProjectMedia.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let p = Project(name: "Cheetah 8b")
    container.mainContext.insert(p)
    return NavigationStack {
        ProjectDetailView(project: p)
    }
    .modelContainer(container)
}
