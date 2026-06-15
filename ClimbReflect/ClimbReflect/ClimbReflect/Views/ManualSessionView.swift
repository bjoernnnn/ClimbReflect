import SwiftUI
import SwiftData

struct ManualSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var durationMinutes = 60
    @State private var sessionType = SessionType.boulder
    @State private var createdSession: ClimbSession?
    @State private var navigateToDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                form
            }
            .navigationTitle("Neue Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Weiter") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
            .navigationDestination(isPresented: $navigateToDetail) {
                if let session = createdSession {
                    SessionDetailView(session: session, onFertig: { dismiss() })
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    private var form: some View {
        Form {
            Section {
                DatePicker("Datum & Uhrzeit", selection: $date, in: ...Date.now)
                    .datePickerStyle(.compact)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
            } header: {
                Text("Wann?").foregroundStyle(Theme.textTertiary)
            }
            .listRowBackground(Theme.surface)

            Section {
                HStack {
                    Text("\(durationMinutes) Minuten")
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Stepper("", value: $durationMinutes, in: 5...480, step: 5)
                        .labelsHidden()
                }
            } header: {
                Text("Wie lange?").foregroundStyle(Theme.textTertiary)
            }
            .listRowBackground(Theme.surface)

            Section {
                ForEach(SessionType.allCases.filter { $0 != .unknown }) { type in
                    Button { sessionType = type } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.symbol)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 22)
                            Text(type.label)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if sessionType == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Art der Session").foregroundStyle(Theme.textTertiary)
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
    }

    private func save() {
        let session = ClimbSession(
            date: date,
            durationSeconds: Double(durationMinutes * 60),
            sessionType: sessionType,
            source: .manual
        )
        context.insert(session)
        try? context.save()
        NotificationService.shared.scheduleReflectionReminder(for: session)
        createdSession = session
        navigateToDetail = true
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return ManualSessionView()
        .modelContainer(container)
}
