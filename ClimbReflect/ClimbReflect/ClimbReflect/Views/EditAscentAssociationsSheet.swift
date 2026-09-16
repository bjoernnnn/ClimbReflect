import SwiftUI
import SwiftData

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
    @State private var resultRaw: String = AscentResult.attempt.rawValue
    @State private var styleRaw: String? = nil
    @State private var attempts: Int = 1
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

    // VT-1: Ursprungswerte für Abbrechen-Erkennung
    @State private var originalSystemRaw: String = GradeSystem.fontainebleau.rawValue
    @State private var originalGradeRaw: String = Ascent.ungraded
    @State private var originalResultRaw: String = AscentResult.attempt.rawValue
    @State private var originalStyleRaw: String? = nil
    @State private var originalAttempts: Int = 1

    private var system: GradeSystem { GradeSystem(rawValue: systemRaw) ?? .fontainebleau }
    private var result: AscentResult { AscentResult(rawValue: resultRaw) ?? .attempt }

    private var hasChanges: Bool {
        systemRaw != originalSystemRaw || gradeRaw != originalGradeRaw
            || resultRaw != originalResultRaw || styleRaw != originalStyleRaw
            || attempts != originalAttempts
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    // FB-3: Grad + System
                    Section {
                        Picker("System", selection: $systemRaw) {
                            ForEach(GradeSystem.allCases) { s in
                                Text(s.label).tag(s.rawValue)
                            }
                        }
                        .onChange(of: systemRaw) { _, _ in
                            if !system.grades.contains(gradeRaw) {
                                gradeRaw = system.grades.first ?? Ascent.ungraded
                            }
                        }
                        Picker("Grad", selection: $gradeRaw) {
                            ForEach(system.grades, id: \.self) { g in Text(g).tag(g) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 90)
                    } header: {
                        Text("Grad").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // FB-3: Ergebnis + Stil + Versuche
                    Section {
                        Picker("Ergebnis", selection: $resultRaw) {
                            ForEach(AscentResult.allCases) { r in
                                Text(r.label).tag(r.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        if result == .top {
                            Picker("Stil", selection: styleBinding) {
                                Text("—").tag(String?.none)
                                ForEach([AscentStyle.flash, .onsight, .redpoint]) { s in
                                    Text(s.label).tag(String?.some(s.rawValue))
                                }
                            }
                        }
                        Stepper("Versuche: \(attempts)", value: $attempts, in: 1...99)
                    } header: {
                        Text("Ergebnis").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // Projekt-Zuordnung
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                projectChip(nil, label: "Kein Projekt")
                                ForEach(activeProjects) { p in
                                    projectChip(p, label: p.name)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Projekt").foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surface)

                    // Schuh-Zuordnung
                    if !activeShoes.isEmpty || ascent.shoeName != nil {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(activeShoes) { s in
                                        shoeChip(s, label: s.name)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            Text("Schuh").foregroundStyle(Theme.textTertiary)
                        }
                        .listRowBackground(Theme.surface)
                    }

                    // VT-1: Begehung löschen
                    Section {
                        Button("Begehung löschen", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Begehung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { save(); dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
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

    private var styleBinding: Binding<String?> {
        Binding(get: { styleRaw }, set: { styleRaw = $0 })
    }

    // FB-3: aktuelle Werte in die lokalen States laden (einmalig)
    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        systemRaw = ascent.gradeSystemRaw
        gradeRaw = ascent.gradeRaw
        resultRaw = ascent.resultRaw
        styleRaw = ascent.styleRaw
        attempts = ascent.attempts
        originalSystemRaw = systemRaw
        originalGradeRaw = gradeRaw
        originalResultRaw = resultRaw
        originalStyleRaw = styleRaw
        originalAttempts = attempts
    }

    private func save() {
        ascent.gradeSystemRaw = systemRaw
        ascent.gradeRaw = gradeRaw
        ascent.resultRaw = resultRaw
        // Stil nur bei Top sinnvoll
        ascent.styleRaw = (result == .top) ? styleRaw : nil
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
                .background(Capsule().fill(selected ? Theme.accent : Theme.bgElevated))
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
                .background(Capsule().fill(selected ? Theme.accent2 : Theme.bgElevated))
                .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
