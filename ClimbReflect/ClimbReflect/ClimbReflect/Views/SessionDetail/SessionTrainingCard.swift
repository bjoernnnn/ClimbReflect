import SwiftUI
import SwiftData

/// PG-5: aus SessionDetailView ausgelagert (reiner Refactor, keine
/// Verhaltensänderung) – Trainings-Sets (T2).
struct SessionTrainingCard: View {
    @Bindable var session: ClimbSession

    @Environment(\.modelContext) private var context
    @State private var showAddTrainingSet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Training", systemImage: "dumbbell.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showAddTrainingSet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Trainingssatz hinzufügen")
            }

            let sorted = session.trainingSets.sorted { $0.date < $1.date }
            if sorted.isEmpty {
                Text("Noch keine Übungen erfasst.\nTippe auf + um Sets hinzuzufügen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(sorted) { t in
                        trainingSetRow(t)
                        if t.id != sorted.last?.id {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
        .card()
        .sheet(isPresented: $showAddTrainingSet) {
            AddTrainingSetView(session: session)
        }
    }

    private func trainingSetRow(_ t: TrainingSet) -> some View {
        HStack(spacing: 10) {
            Image(systemName: t.kind.symbol)
                .font(.body)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(t.kind.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 8) {
                    if let mm = t.edgeMM {
                        Text("\(mm) mm").font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                    if let dur = t.durationSeconds {
                        Text("\(Int(dur)) s").font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                    if let r = t.reps {
                        Text("\(r)×").font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                    if let note = t.note, !note.isEmpty {
                        Text(note).font(.caption2).foregroundStyle(Theme.textTertiary).lineLimit(1)
                    }
                }
            }

            Spacer()

            if let kg = t.addedWeightKg, kg != 0 {
                Text(kg > 0 ? "+\(formatKg(kg)) kg" : "\(formatKg(kg)) kg")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Button(role: .destructive) {
                context.delete(t)
            } label: {
                Image(systemName: "trash").font(.caption).foregroundStyle(Theme.danger.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trainingssatz löschen")
        }
        .padding(.vertical, 6)
    }

    private func formatKg(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))" : String(format: "%.2g", kg)
    }
}
