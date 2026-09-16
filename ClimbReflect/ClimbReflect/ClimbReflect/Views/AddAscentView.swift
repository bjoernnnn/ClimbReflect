import SwiftUI
import SwiftData
import PhotosUI

/// EF-2: Quick-Log statt Datenbank-Formular – Grad wischen, Ergebnis tippen,
/// „Sichern". Alles andere ist unter „Details" zugeklappt.
struct AddAscentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.name) private var allProjects: [Project]
    @Query private var allSessions: [ClimbSession]   // VT-4: Grad-Vorbelegung

    let session: ClimbSession
    var preselectedProject: Project? = nil

    @State private var gradeSystem: GradeSystem = .fontainebleau
    @State private var selectedGrade: String = "6A"
    @State private var outcome: AscentOutcome? = nil   // E6: kein vorausgewählter Wert
    @State private var attempts: Int = 1
    @State private var note: String = ""
    @State private var wallAngle: WallAngle? = nil
    @State private var holdType: HoldType? = nil
    @State private var climbStyle: ClimbStyle? = nil
    @State private var selectedProject: Project? = nil
    @State private var newProjectName: String = ""
    @State private var showNewProjectAlert = false
    @State private var selectedShoe: Shoe? = nil
    @State private var showDetails = false
    @State private var lastSavedFeedback: String? = nil

    @Query(sort: \Shoe.startYear, order: .reverse) private var allShoes: [Shoe]
    private var activeShoes: [Shoe] { allShoes.filter { !$0.isRetired } }
    @State private var setName: String = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var isSaving = false

    private var activeProjects: [Project] { allProjects.filter(\.isActive) }
    private var discipline: ProgressEngine.Discipline { gradeSystem.isBoulder ? .boulder : .rope }

    /// Bis zu 4 unterschiedliche Grade dieser Session (gleiche Disziplin), neueste zuerst.
    private var recentGrades: [String] {
        let sameDiscipline = session.ascents
            .filter { $0.isGraded && $0.gradeSystem.isBoulder == gradeSystem.isBoulder }
            .sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
        var seen = Set<String>()
        var result: [String] = []
        for a in sameDiscipline {
            guard let converted = GradeConverter.convert(grade: a.gradeRaw, from: a.gradeSystem, to: gradeSystem) else { continue }
            if seen.insert(converted).inserted {
                result.append(converted)
                if result.count == 4 { break }
            }
        }
        return result
    }

    private var resultBinding: Binding<AscentResult> {
        Binding(
            get: { outcome?.result ?? .attempt },
            set: { newResult in
                outcome = AscentOutcome(result: newResult, style: newResult == .top ? outcome?.style : nil)
            }
        )
    }

    private var styleBinding: Binding<AscentStyle?> {
        Binding(
            get: { outcome?.style },
            set: { outcome = AscentOutcome(result: outcome?.result ?? .top, style: $0) }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    gradeBlock
                    OutcomePicker(options: AscentOutcome.quick(for: discipline), selection: $outcome)
                    projectRow
                    DisclosureGroup("Details", isExpanded: $showDetails) {
                        detailsContent
                    }
                    .tint(Theme.textPrimary)
                    .card()
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Begehung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sichern") { save(keepOpen: false) }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                        .disabled(outcome == nil || isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .alert("Neues Projekt", isPresented: $showNewProjectAlert) {
                TextField("Name", text: $newProjectName)
                Button("Anlegen") { createAndSelectProject() }
                Button("Abbrechen", role: .cancel) { newProjectName = "" }
            }
        }
        .tint(Theme.accent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(outcome != nil)
        .onAppear {
            // VT-4/E4: Projekt → letzte Begehung der Session → letzte Begehung der
            // Disziplin → niedrigster Grad (S37 – kein plausibel wirkender Default).
            let initial = GradeDefaults.initial(session: session, project: preselectedProject, allSessions: allSessions)
            gradeSystem = initial.system
            selectedGrade = initial.grade
            selectedProject = preselectedProject
            if selectedShoe == nil {
                // SH-B3: Standard-Schuh für diesen Session-Typ vorauswählen
                let sessionType = session.sessionType
                selectedShoe = activeShoes.first(where: { $0.defaultForTypes.contains(sessionType) })
                    ?? activeShoes.first(where: { $0.isBuiltInDefault })
                    ?? activeShoes.first
            }
        }
    }

    // MARK: - Grad

    private var gradeBlock: some View {
        VStack(spacing: 10) {
            Text(selectedGrade)
                .font(Theme.Typo.metricHero)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.interpolate)
                .animation(.snappy, value: selectedGrade)
            Text(gradeSystem.label)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            GradeRuler(grades: gradeSystem.grades, selection: $selectedGrade)
                .onChange(of: gradeSystem) { _, new in
                    if !new.grades.contains(selectedGrade) {
                        selectedGrade = new.grades.first ?? Ascent.ungraded
                    }
                }
            if !recentGrades.isEmpty {
                HStack(spacing: 6) {
                    Text("Zuletzt:")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    ForEach(recentGrades, id: \.self) { grade in
                        Button {
                            withAnimation(.snappy) { selectedGrade = grade }
                        } label: {
                            Text(grade)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Theme.surfaceRaised))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Projekt

    private var projectRow: some View {
        Menu {
            Picker("Projekt", selection: $selectedProject) {
                Text("Kein Projekt").tag(Project?.none)
                ForEach(activeProjects) { p in
                    Text(p.name).tag(Project?.some(p))
                }
            }
            Button("Neues Projekt …") { showNewProjectAlert = true }
        } label: {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(Theme.accent)
                Text(selectedProject?.name ?? "Kein Projekt")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .inset()
    }

    private func createAndSelectProject() {
        let trimmed = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let existing = allProjects.first { $0.name.lowercased() == trimmed.lowercased() }
        if let existing {
            selectedProject = existing
        } else {
            let p = Project(name: trimmed)
            context.insert(p)
            try? context.save()
            selectedProject = p
        }
        newProjectName = ""
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Grad-System", selection: $gradeSystem) {
                ForEach(GradeSystem.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(Theme.textPrimary)

            Picker("Ergebnis", selection: resultBinding) {
                ForEach(AscentResult.allCases) { r in
                    Label(r.label, systemImage: r.symbol).tag(r)
                }
            }
            .foregroundStyle(Theme.textPrimary)

            if resultBinding.wrappedValue == .top {
                Picker("Stil", selection: styleBinding) {
                    Text("—").tag(AscentStyle?.none)
                    ForEach(AscentStyle.allCases) { s in
                        Label(s.label, systemImage: s.symbol).tag(AscentStyle?.some(s))
                    }
                }
                .foregroundStyle(Theme.textPrimary)
            }

            Stepper("Versuche: \(attempts)", value: $attempts, in: 1...999)
                .foregroundStyle(Theme.textPrimary)

            tagRow("Wandwinkel", options: WallAngle.allCases,
                   label: { $0.label }, selection: $wallAngle)
            tagRow("Grifftyp", options: HoldType.allCases,
                   label: { $0.label }, selection: $holdType)
            tagRow("Kletterstil", options: ClimbStyle.allCases,
                   label: { $0.label }, selection: $climbStyle)

            TextField("Set / Sektion (optional)", text: $setName)
                .foregroundStyle(Theme.textPrimary)

            if !activeShoes.isEmpty {
                Picker("Schuh", selection: $selectedShoe) {
                    Text("Kein Schuh").tag(Shoe?.none)
                    ForEach(activeShoes) { s in
                        Text(s.name).tag(Shoe?.some(s))
                    }
                }
                .pickerStyle(.menu)
                .foregroundStyle(Theme.textPrimary)
            }

            photoPicker

            TextField("Beta, Schlüsselzug, Notiz…", text: $note, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3...6)
        }
        .padding(.top, 8)
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(selection: $selectedPhoto,
                         matching: .images,
                         photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    if let data = photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 60, height: 60)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous).fill(Theme.surfaceRaised))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(photoData != nil ? "Foto ändern" : "Foto hinzufügen")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("optional · Crux, Beta, Memento")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    photoData = try? await item?.loadTransferable(type: Data.self)
                }
            }
            if photoData != nil {
                Button(role: .destructive) { photoData = nil; selectedPhoto = nil } label: {
                    Label("Foto entfernen", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
    }

    @ViewBuilder
    private func tagRow<T: Identifiable & Hashable>(
        _ title: String,
        options: [T],
        label: @escaping (T) -> String,
        selection: Binding<T?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.id) { opt in
                        let selected = selection.wrappedValue == opt
                        Button {
                            selection.wrappedValue = selected ? nil : opt
                        } label: {
                            Text(label(opt))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(selected ? Theme.accent : Theme.surfaceRaised))
                                .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Bottom-Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let lastSavedFeedback {
                HStack {
                    Label(lastSavedFeedback, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("\(session.ascents.count) in dieser Session")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .contentTransition(.numericText())
                }
                .transition(.opacity)
            }
            Button("Sichern & nächste") { save(keepOpen: true) }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .controlSize(.large)
                .disabled(outcome == nil || isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .animation(.snappy, value: lastSavedFeedback)
    }

    // MARK: - Speichern

    private func save(keepOpen: Bool) {
        guard !isSaving, let outcome else { return }
        isSaving = true

        let ascent = Ascent(
            gradeSystem: gradeSystem,
            grade: selectedGrade,
            result: outcome.result,
            style: outcome.style,
            attempts: attempts,
            note: note.isEmpty ? nil : note,
            date: session.date,
            wallAngle: wallAngle,
            holdType: holdType,
            climbStyle: climbStyle,
            projectName: selectedProject?.name,
            session: session
        )
        ascent.project = selectedProject
        ascent.shoe = selectedShoe
        ascent.shoeName = selectedShoe?.name
        ascent.shoeCondition = selectedShoe?.conditionRaw
        ascent.setName = setName.isEmpty ? nil : setName
        ascent.photoData = photoData
        context.insert(ascent)

        try? context.save()
        AchievementService.shared.checkNow(context: context)   // EP-3

        // VT-3: Ein Feier-Kanal (S33) – AchievementUnlockOverlay übernimmt PB/Erst-Top/Projekt-Top.
        if outcome.result == .top {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        guard keepOpen else { dismiss(); return }

        lastSavedFeedback = "\(selectedGrade) · \(outcome.label) gesichert"
        Task {
            try? await Task.sleep(for: .seconds(2))
            lastSavedFeedback = nil
        }
        // Grad, System, Projekt, Schuh, Set bleiben für die nächste Begehung erhalten.
        self.outcome = nil
        note = ""
        photoData = nil
        selectedPhoto = nil
        wallAngle = nil
        holdType = nil
        climbStyle = nil
        attempts = 1
        isSaving = false
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self, Ascent.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let session = MockData.makeSessions()[0]
    container.mainContext.insert(session)
    return AddAscentView(session: session).modelContainer(container)
}
