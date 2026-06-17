import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context

    @State private var editingBetaNotes = false
    @State private var betaNotesDraft = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var editingCaption: ProjectMedia? = nil
    @State private var captionDraft = ""

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

    private var attemptHistory: [(date: Date, count: Int)] {
        ascentsGroupedBySession.map { group in
            (date: group.date, count: group.ascents.reduce(0) { $0 + $1.attempts })
        }
        .sorted { $0.date < $1.date }
    }

    private var sortedMedia: [ProjectMedia] {
        project.media.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack {
            MountainBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    if attemptHistory.count > 1 {
                        progressChart
                    }
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
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    project.isPinned.toggle()
                } label: {
                    Image(systemName: project.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(project.isPinned ? Theme.gold : Theme.textSecondary)
                }
            }
        }
        .sheet(item: $editingCaption) { media in
            captionSheet(for: media)
        }
        .onChange(of: selectedPhotos) { _, items in
            Task { await addPhotos(items) }
        }
        .preferredColorScheme(.dark)
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
                        .font(.system(size: 20))
                        .foregroundStyle(statusColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(statusColor.opacity(0.15)))
                    if let grade = project.targetGradeRaw {
                        Label(grade, systemImage: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer()
                if project.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gold)
                }
            }

            HStack(spacing: 12) {
                let tops = project.ascents.filter { $0.result == .top }.count
                let attempts = project.ascents.reduce(0) { $0 + $1.attempts }
                let days = Set(project.ascents.map {
                    Calendar.current.startOfDay(for: $0.date)
                }).count

                statPill(value: "\(attempts)", label: "Versuche")
                statPill(value: "\(tops)", label: "Tops")
                statPill(value: "\(days)", label: "Tage")
            }

            if !project.isActive {
                let toggleLabel = project.isAbandoned ? "Wieder aktivieren" : "Aufgeben"
                let toggleSymbol = project.isAbandoned ? "arrow.uturn.backward.circle" : "xmark.circle"
                Button {
                    project.statusRaw = project.isAbandoned ? nil : Project.Status.abandoned.rawValue
                } label: {
                    Label(toggleLabel, systemImage: toggleSymbol)
                        .font(.subheadline)
                        .foregroundStyle(project.isAbandoned ? Theme.accent : Theme.danger)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    project.statusRaw = Project.Status.abandoned.rawValue
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

    // MARK: - Progress Chart

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Versuche pro Session")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart(attemptHistory, id: \.date) { point in
                BarMark(
                    x: .value("Datum", point.date, unit: .day),
                    y: .value("Versuche", point.count)
                )
                .cornerRadius(4)
                .foregroundStyle(Theme.accentGradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.3))
                    AxisValueLabel(format: .dateTime.day().month(.twoDigits))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.5))
                    AxisValueLabel()
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 120)
        }
        .card()
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
                        editingBetaNotes = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent)
                }
            }
            .preferredColorScheme(.dark)
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        captionDraft = media.caption ?? ""
                        editingCaption = media
                    }

                Button {
                    context.delete(media)
                    try? context.save()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
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
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                    TextField("Beschriftung (optional)", text: $captionDraft)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgElevated))
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
            .preferredColorScheme(.dark)
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
                            if ascent.id != group.ascents.last?.id {
                                Divider().background(Theme.surfaceStroke)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                }
            }
        }
        .card()
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
        if project.isSent { return "Gesendet" }
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
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgElevated))
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
