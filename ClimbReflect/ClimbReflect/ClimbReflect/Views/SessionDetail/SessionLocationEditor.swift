import SwiftUI
import SwiftData

/// PG-5: aus SessionDetailView ausgelagert (reiner Refactor, keine
/// Verhaltensänderung) – Standort-Editor (ST-2). Die frühere Kopfzeile
/// SessionHeaderRow ist mit PG-6 in SessionSummaryHeader aufgegangen.
struct SessionLocationEditor: View {
    @Bindable var session: ClimbSession
    @Environment(\.dismiss) private var dismiss

    // ST-2: distinct gymNames aus allen Sessions
    @Query(sort: \ClimbSession.date, order: .reverse) private var allSessions: [ClimbSession]
    private var knownGymNames: [String] { ClimbSession.knownGymNames(allSessions) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Toggle("Outdoor", isOn: Binding(
                        get: { session.outdoor },
                        set: { session.outdoor = $0; session.updatedAt = .now }
                    ))
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.textPrimary)

                    if session.outdoor {
                        // A8: Outdoor-Bedingungen
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Bedingungen")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                            HStack(spacing: 8) {
                                ForEach(OutdoorConditions.allCases) { c in
                                    let sel = session.conditions == c
                                    Button {
                                        session.conditionsRaw = sel ? nil : c.rawValue
                                        session.updatedAt = .now
                                    } label: {
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
                            HStack(spacing: 8) {
                                Image(systemName: "thermometer.medium").foregroundStyle(Theme.textTertiary)
                                TextField("Temperatur (°C)", value: Binding(
                                    get: { session.temperatureC },
                                    set: { session.temperatureC = $0; session.updatedAt = .now }
                                ), format: .number)
                                .foregroundStyle(Theme.textPrimary)
                                .keyboardType(.decimalPad)
                                Text("°C").foregroundStyle(Theme.textTertiary)
                            }
                            .padding(12)
                            .background(RoundedRectangle.theme(Theme.Radius.small).fill(Theme.surfaceRaised))
                        }
                    } else if !session.outdoor {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Halle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)

                            TextField("Hallenname", text: Binding(
                                get: { session.gymName ?? "" },
                                set: { session.gymName = $0.isEmpty ? nil : $0; session.updatedAt = .now }
                            ))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(12)
                            .background(RoundedRectangle.theme(Theme.Radius.small).fill(Theme.surfaceRaised))

                            // Quick-Pick aus bekannten Hallen
                            if !knownGymNames.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(knownGymNames, id: \.self) { gym in
                                            Button {
                                                session.gymName = gym
                                                session.updatedAt = .now
                                            } label: {
                                                Text(gym)
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Capsule().fill(
                                                        session.gymName == gym ? Theme.accent : Theme.surfaceRaised
                                                    ))
                                                    .foregroundStyle(session.gymName == gym ? Theme.bg : Theme.textSecondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Standort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
