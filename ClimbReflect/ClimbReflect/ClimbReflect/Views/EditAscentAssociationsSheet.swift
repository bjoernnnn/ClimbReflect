import SwiftUI
import SwiftData

/// EF-3: gleicher Aufbau wie das Quick-Log (AddAscentView) – GradeRuler +
/// OutcomePicker sichtbar, Rest unter „Details" (beim Bearbeiten aufgeklappt).
struct EditAscentAssociationsSheet: View {
    @Bindable var ascent: Ascent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Project.name) private var allProjects: [Project]
    @Query(sort: \Shoe.startYear, order: .reverse) private var allShoes: [Shoe]

    private var activeProjects: [Project] { allProjects.filter(\.isActive) }
    private var activeShoes: [Shoe] { allShoes.filter { !$0.isRetired } }

    // FB-3: Grad/Ergebnis/Stil/Versuche lokal editieren, auf „Fertig" schreiben
    @State private var systemRaw: String = GradeSystem.fontainebleau.rawValue
    @State private var gradeRaw: String = Ascent.ungraded
    @State private var outcome: AscentOutcome? = nil
    @State private var attempts: Int = 1
    @State private var didLoad = false
    @State private var showDeleteConfirm = false
    @State private var showDetails = true   // EF-3: beim Bearbeiten aufgeklappt

    // VT-1: Ursprungswerte für Abbrechen-Erkennung
    @State private var originalSystemRaw: String = GradeSystem.fontainebleau.rawValue
    @State private var originalGradeRaw: String = Ascent.ungraded
    @State private var originalOutcome: AscentOutcome? = nil
    @State private var originalAttempts: Int = 1

    private var system: GradeSystem { GradeSystem(rawValue: systemRaw) ?? .fontainebleau }
    private var discipline: ProgressEngine.Discipline { system.isBoulder ? .boulder : .rope }

    private var outcomeOptions: [AscentOutcome] {
        var opts = AscentOutcome.quick(for: discipline)
        if let outcome, !opts.contains(outcome) {
            opts.append(outcome)
        }
        return opts
    }

    private var hasChanges: Bool {
        systemRaw != originalSystemRaw || gradeRaw != originalGradeRaw
            || outcome != originalOutcome || attempts != originalAttempts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    gradeBlock
                    OutcomePicker(options: outcomeOptions, selection: $outcome)
                    DisclosureGroup("Details", isExpanded: $showDetails) {
                        detailsContent
                    }
                    .tint(Theme.textPrimary)
                    .card()
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Begehung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { save(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadIfNeeded)
            .confirmationDialog("Begehung löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    context.delete(ascent)
                    try? context.save()
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die Begehung wird aus Statistik und Projekt entfernt. Freigeschaltete Erfolge bleiben erhalten.")
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .tint(Theme.accent)
    }

    // MARK: - Grad

    private var gradeBlock: some View {
        VStack(spacing: 10) {
            Text(gradeRaw)
                .font(Theme.Typo.metricHero)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.interpolate)
                .animation(.snappy, value: gradeRaw)
            Text(system.label)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            GradeRuler(grades: system.grades, selection: $gradeRaw)
        }
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Grad-System", selection: $systemRaw) {
                ForEach(GradeSystem.allCases) { s in
                    Text(s.label).tag(s.rawValue)
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(Theme.textPrimary)
            .onChange(of: systemRaw) { _, _ in
                if !system.grades.contains(gradeRaw) {
                    gradeRaw = system.grades.first ?? Ascent.ungraded
                }
            }

            Stepper("Versuche: \(attempts)", value: $attempts, in: 1...99)
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Projekt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        projectChip(nil, label: "Kein Projekt")
                        ForEach(activeProjects) { p in
                            projectChip(p, label: p.name)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if !activeShoes.isEmpty || ascent.shoeName != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Schuh")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activeShoes) { s in
                                shoeChip(s, label: s.name)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Button("Begehung löschen", role: .destructive) {
                showDeleteConfirm = true
            }
        }
        .padding(.top, 8)
    }

    // FB-3: aktuelle Werte in die lokalen States laden (einmalig)
    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        systemRaw = ascent.gradeSystemRaw
        gradeRaw = ascent.gradeRaw
        attempts = ascent.attempts
        let loadedResult = AscentResult(rawValue: ascent.resultRaw) ?? .attempt
        let loadedStyle = ascent.styleRaw.flatMap(AscentStyle.init(rawValue:))
        outcome = AscentOutcome(result: loadedResult, style: loadedStyle)
        originalSystemRaw = systemRaw
        originalGradeRaw = gradeRaw
        originalAttempts = attempts
        originalOutcome = outcome
    }

    private func save() {
        guard let outcome else { return }
        ascent.gradeSystemRaw = systemRaw
        ascent.gradeRaw = gradeRaw
        ascent.resultRaw = outcome.result.rawValue
        ascent.styleRaw = outcome.style?.rawValue
        ascent.attempts = max(1, attempts)
        ascent.session?.updatedAt = .now
        try? context.save()
    }

    @ViewBuilder
    private func projectChip(_ project: Project?, label: String) -> some View {
        let selected = ascent.project?.id == project?.id && (project != nil || ascent.project == nil)
        Button {
            ascent.project = project
            ascent.projectName = project?.name
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.accent : Theme.surfaceRaised))
                .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shoeChip(_ shoe: Shoe?, label: String) -> some View {
        let selected = ascent.shoe?.id == shoe?.id && (shoe != nil || ascent.shoe == nil)
        Button {
            ascent.shoe = shoe
            ascent.shoeName = shoe?.name
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.accent2 : Theme.surfaceRaised))
                .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
