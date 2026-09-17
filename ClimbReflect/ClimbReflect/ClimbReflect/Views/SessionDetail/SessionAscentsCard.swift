import SwiftUI
import SwiftData

/// PG-5: aus SessionDetailView ausgelagert (reiner Refactor, keine
/// Verhaltensänderung) – Begehungen-Karte (P3.1) inkl. contextMenu,
/// Edit-Sheet, Lösch-Dialog.
struct SessionAscentsCard: View {
    @Bindable var session: ClimbSession
    var onAddAscent: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editedAscent: Ascent? = nil
    @State private var pendingDeleteAscent: Ascent? = nil   // VT-1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Begehungen", systemImage: "figure.climbing")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button(action: onAddAscent) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Begehung hinzufügen")
            }

            let sorted = session.ascents.sorted { $0.createdAt < $1.createdAt }
            if sorted.isEmpty {
                Button(action: onAddAscent) {
                    Label("Erste Begehung erfassen", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(spacing: 0) {
                    ForEach(sorted) { ascent in
                        AscentRowView(ascent: ascent)
                            .contentShape(Rectangle())
                            .onTapGesture { editedAscent = ascent }
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
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        if ascent.id != sorted.last?.id {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
                .animation(reduceMotion ? nil : .snappy, value: sorted.map(\.id))
                .sheet(item: $editedAscent) { ascent in
                    EditAscentAssociationsSheet(ascent: ascent)
                }
                .confirmationDialog(
                    "Begehung löschen?",
                    isPresented: Binding(get: { pendingDeleteAscent != nil }, set: { if !$0 { pendingDeleteAscent = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Löschen", role: .destructive) {
                        if let ascent = pendingDeleteAscent {
                            context.delete(ascent)
                            try? context.save()
                        }
                        pendingDeleteAscent = nil
                    }
                    Button("Abbrechen", role: .cancel) { pendingDeleteAscent = nil }
                } message: {
                    Text("Die Begehung wird aus Statistik und Projekt entfernt. Freigeschaltete Erfolge bleiben erhalten.")
                }

                let tops = sorted.filter { $0.result == .top }
                if !tops.isEmpty {
                    HStack(spacing: 16) {
                        Label("\(tops.count) Top\(tops.count == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                        let attempts = sorted.filter { $0.result == .attempt }.count
                        if attempts > 0 {
                            Label("\(attempts) Versuch\(attempts == 1 ? "" : "e")",
                                  systemImage: "arrow.clockwise.circle.fill")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.top, 4)
                }
            }
        }
        .card()
    }
}
