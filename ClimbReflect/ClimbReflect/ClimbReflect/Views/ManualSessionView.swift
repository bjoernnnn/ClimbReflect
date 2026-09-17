import SwiftUI
import SwiftData

struct ManualSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClimbSession.date, order: .reverse) private var allSessions: [ClimbSession]

    var preselectedProject: Project? = nil   // VT-8

    @State private var date = Date()
    @State private var durationMinutes = 90
    @State private var sessionType: SessionType
    @State private var gymName = ""
    @State private var outdoor = false
    @State private var outdoorConditions: OutdoorConditions? = nil
    @State private var temperatureC: Double? = nil
    @State private var createdSession: ClimbSession?
    @State private var navigateToDetail = false
    @State private var gymChipTap = 0

    private static let durationPresets = [60, 90, 120, 150, 180]

    private var knownGymNames: [String] {
        let prefix = gymName.trimmingCharacters(in: .whitespaces).lowercased()
        let known = ClimbSession.knownGymNames(allSessions)
        let filtered = prefix.isEmpty ? known : known.filter { $0.lowercased().hasPrefix(prefix) }
        return Array(filtered.prefix(5))
    }

    init(preselectedProject: Project? = nil) {
        self.preselectedProject = preselectedProject
        let isRopeProject = preselectedProject?.gradeSystem.map { !$0.isBoulder } ?? false
        _sessionType = State(initialValue: isRopeProject ? .lead : .boulder)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                form
            }
            .navigationTitle("Session nachtragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Weiter") { save() }
                        .fontWeight(.semibold)
                }
            }
            .navigationDestination(isPresented: $navigateToDetail) {
                if let session = createdSession {
                    SessionDetailView(session: session, onFertig: { dismiss() }, autoAddAscentProject: preselectedProject)
                }
            }
        }
        .tint(Theme.accent)
    }

    private var form: some View {
        Form {
            // Art der Session zuerst – wichtigste Entscheidung
            Section {
                SessionTypeGrid(selection: $sessionType)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Art der Session").foregroundStyle(Theme.textTertiary)
            }

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
                    Text(Duration.seconds(durationMinutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Stepper("", value: $durationMinutes, in: 15...480, step: 15)
                        .labelsHidden()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.durationPresets, id: \.self) { minutes in
                            let selected = durationMinutes == minutes
                            Button { durationMinutes = minutes } label: {
                                Text(durationChipLabel(minutes))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(selected ? Theme.accent : Theme.surfaceRaised))
                                    .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                .sensoryFeedback(.selection, trigger: durationMinutes)
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
                .sensoryFeedback(.selection, trigger: outdoor)
                if !outdoor {
                    TextField("Halle (optional)", text: $gymName)
                        .foregroundStyle(Theme.textPrimary)
                    if !knownGymNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(knownGymNames, id: \.self) { gym in
                                    Button {
                                        gymName = gym
                                        gymChipTap += 1
                                    } label: {
                                        Text(gym)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(Theme.surfaceRaised))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .sensoryFeedback(.selection, trigger: gymChipTap)
                    }
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
                                        Image(systemName: c.symbol).font(.caption2)
                                        Text(c.rawValue).font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Capsule().fill(sel ? Theme.accent : Theme.surfaceRaised))
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

    private func durationChipLabel(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60
        let formatted = hours.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", hours)
            : String(format: "%.1f", hours).replacingOccurrences(of: ".", with: ",")
        return "\(formatted) h"
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
        AchievementService.shared.checkNow(context: context)   // EP-3
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
