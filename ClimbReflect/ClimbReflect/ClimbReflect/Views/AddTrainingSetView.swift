import SwiftUI
import SwiftData

struct AddTrainingSetView: View {
    let session: ClimbSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TrainingKind = .hangboardMaxHang
    @State private var edgeMM: Int = 18
    @State private var addedWeightKg: Double = 0
    @State private var reps: Int = 5
    @State private var durationSeconds: Double = 10
    @State private var sets: Int = 1
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    Section("Übung") {
                        Picker("Art", selection: $kind) {
                            ForEach(TrainingKind.allCases) { k in
                                Label(k.rawValue, systemImage: k.symbol).tag(k)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundStyle(Theme.textPrimary)

                        Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    if kind.hasEdge {
                        Section("Leistengröße") {
                            Stepper("\(edgeMM) mm", value: $edgeMM, in: 6...35, step: 2)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }

                    if kind.hasReps {
                        Section("Wiederholungen") {
                            Stepper("\(reps) Wdh.", value: $reps, in: 1...50)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }

                    if kind.hasDuration {
                        Section("Hänge-/Haltezeit") {
                            Stepper("\(Int(durationSeconds)) s", value: $durationSeconds, in: 1...120, step: 1)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }

                    if kind.hasWeight {
                        Section("Zusatzgewicht") {
                            Stepper(addedWeightKg == 0 ? "Kein Zusatz" : "+\(formatWeight(addedWeightKg)) kg",
                                    value: $addedWeightKg, in: -30...100, step: 1.25)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }

                    Section("Notiz (optional)") {
                        TextField("z. B. Crimps, ermüdet ab Set 3…", text: $note)
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.bg)
                .foregroundStyle(Theme.textPrimary)
            }
            .navigationTitle("Trainings-Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hinzufügen") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(kg))"
            : String(format: "%.2g", kg)
    }

    private func save() {
        let order = session.trainingSets.count
        for _ in 0..<sets {
            let t = TrainingSet(kind: kind, order: order, date: .now)
            t.edgeMM = kind.hasEdge ? edgeMM : nil
            t.addedWeightKg = kind.hasWeight && addedWeightKg != 0 ? addedWeightKg : nil
            t.reps = kind.hasReps ? reps : nil
            t.durationSeconds = kind.hasDuration ? durationSeconds : nil
            t.sets = nil
            t.note = note.isEmpty ? nil : note
            t.session = session
            context.insert(t)
        }
        dismiss()
    }
}
