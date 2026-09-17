import SwiftUI
import SwiftData

/// PG-5: aus SessionDetailView ausgelagert (reiner Refactor, keine
/// Verhaltensänderung) – Kopfzeile (Datum, Dauer, Quelle, Standort-Chip) mit
/// dem Standort-Editor als Sheet, da beide eng gekoppelt sind.
struct SessionHeaderRow: View {
    @Bindable var session: ClimbSession
    @State private var showLocationEditor = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, dd. MMMM yyyy · HH:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: 16) {
            IconTile(symbol: session.sessionType.symbol, tint: Theme.accent, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateFormatter.string(from: session.date))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 10) {
                    Label(session.durationText, systemImage: "clock")
                    switch session.source {
                    case .watch:
                        Label("Apple Watch", systemImage: "applewatch")
                            .foregroundStyle(Theme.accent)
                    case .healthKit:
                        Label("Apple Health", systemImage: "heart.fill")
                            .foregroundStyle(Theme.accent)
                    case .manual:
                        EmptyView()
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                // ST-1: Standort-Chip
                if session.outdoor {
                    Label("Outdoor", systemImage: "mountain.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accent2.opacity(0.12)))
                } else if let gym = session.gymName, !gym.isEmpty {
                    Label(gym, systemImage: "building.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accent2.opacity(0.12)))
                }
            }
            Spacer()
            // ST-2: Standort-Editor öffnen
            Button {
                showLocationEditor.toggle()
            } label: {
                Image(systemName: "mappin.and.ellipse")
                    .font(.body)
                    .foregroundStyle(session.outdoor || (session.gymName != nil) ? Theme.accent2 : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Standort bearbeiten")
        }
        .padding(.top, 8)
        .sheet(isPresented: $showLocationEditor) {
            SessionLocationEditor(session: session)
        }
    }
}

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
