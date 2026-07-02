import SwiftUI

// FB-1: Editor für Projekt-Stammdaten (Name + Disziplin + Ziel-Grad).
// Wird sowohl beim Anlegen als auch in der Detailansicht verwendet.
struct ProjectGradeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("boulderScale") private var boulderScale: String = GradeSystem.fontainebleau.rawValue
    @AppStorage("routeScale") private var routeScale: String = GradeSystem.french.rawValue

    let titleText: String
    let showsName: Bool
    /// (name, gradeSystemRaw, targetGradeRaw)
    let onSave: (String, String, String?) -> Void

    @State private var name: String
    @State private var isBoulder: Bool
    @State private var gradeIndex: Int   // Index in system.grades, -1 = kein Ziel

    init(titleText: String,
         showsName: Bool,
         name: String = "",
         gradeSystemRaw: String? = nil,
         targetGradeRaw: String? = nil,
         onSave: @escaping (String, String, String?) -> Void) {
        self.titleText = titleText
        self.showsName = showsName
        self.onSave = onSave
        _name = State(initialValue: name)
        let sys = gradeSystemRaw.flatMap(GradeSystem.init(rawValue:))
        let boulder = sys.map { $0 == .fontainebleau || $0 == .vScale } ?? true
        _isBoulder = State(initialValue: boulder)
        if let sys, let raw = targetGradeRaw, let idx = sys.grades.firstIndex(of: raw) {
            _gradeIndex = State(initialValue: idx)
        } else {
            _gradeIndex = State(initialValue: -1)
        }
    }

    private var system: GradeSystem {
        isBoulder
            ? (GradeSystem(rawValue: boulderScale) ?? .fontainebleau)
            : (GradeSystem(rawValue: routeScale) ?? .french)
    }

    var body: some View {
        NavigationStack {
            Form {
                if showsName {
                    Section("Name") {
                        TextField("Projektname", text: $name)
                    }
                }
                Section("Disziplin") {
                    Picker("Disziplin", selection: $isBoulder) {
                        Text("Boulder").tag(true)
                        Text("Seil").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isBoulder) { _, _ in gradeIndex = -1 }
                }
                Section("Ziel-Grad") {
                    Picker("Grad", selection: $gradeIndex) {
                        Text("Kein Ziel").tag(-1)
                        ForEach(Array(system.grades.enumerated()), id: \.offset) { idx, g in
                            Text(g).tag(idx)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(showsName && name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func save() {
        let target = gradeIndex >= 0 && gradeIndex < system.grades.count
            ? system.grades[gradeIndex] : nil
        onSave(name.trimmingCharacters(in: .whitespaces), system.rawValue, target)
        dismiss()
    }
}
