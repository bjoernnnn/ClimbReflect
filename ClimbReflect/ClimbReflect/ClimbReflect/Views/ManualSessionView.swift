import SwiftUI
import SwiftData

struct ManualSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var durationMinutes = 60
    @State private var sessionType = SessionType.boulder
    @State private var gymName = ""
    @State private var outdoor = false
    @State private var outdoorConditions: OutdoorConditions? = nil
    @State private var temperatureC: Double? = nil
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
            // Art der Session zuerst – wichtigste Entscheidung
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Art der Session").foregroundStyle(Theme.textTertiary)
            }
            .listRowBackground(Theme.surface)

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
                Toggle(isOn: $outdoor) {
                    Label("Outdoor", systemImage: "mountain.2.fill")
                        .foregroundStyle(Theme.textPrimary)
                }
                .tint(Theme.accent)
                if !outdoor {
                    TextField("Halle (optional)", text: $gymName)
                        .foregroundStyle(Theme.textPrimary)
                }
            } header: {
                Text("Wo?").foregroundStyle(Theme.textTertiary)
            }
            .listRowBackground(Theme.surface)

            if outdoor {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(OutdoorConditions.allCases) { c in
                                let sel = outdoorConditions == c
                                Button { outdoorConditions = sel ? nil : c } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: c.symbol).font(.system(size: 12))
                                        Text(c.rawValue).font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Capsule().fill(sel ? Theme.accent : Theme.bgElevated))
                                    .foregroundStyle(sel ? Theme.bg : Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    HStack {
                        Image(systemName: "thermometer.medium").foregroundStyle(Theme.textTertiary)
                        TextField("Temperatur (optional)", value: $temperatureC, format: .number)
                            .foregroundStyle(Theme.textPrimary)
                            .keyboardType(.decimalPad)
                        Text("°C").foregroundStyle(Theme.textTertiary)
                    }
                } header: {
                    Text("Bedingungen").foregroundStyle(Theme.textTertiary)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func save() {
        let session = ClimbSession(
            date: date,
            durationSeconds: Double(durationMinutes * 60),
            sessionType: sessionType,
            source: .manual,
            gymName: gymName.isEmpty ? nil : gymName,
            outdoor: outdoor
        )
        session.conditionsRaw = outdoorConditions?.rawValue
        session.temperatureC = temperatureC
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
