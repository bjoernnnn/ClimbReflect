import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Bindable var session: ClimbSession
    var onFertig: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, dd. MMMM yyyy · HH:mm"
        return f
    }()

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            MountainBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sessionHeader
                    if session.avgHeartRate != nil || session.activeEnergyKcal != nil {
                        redpointCard
                    }
                    reflectionCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: session.sessionType.symbol)
                        .foregroundStyle(Theme.accent)
                    Text(session.sessionType == .unknown ? "Session" : session.sessionType.label)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let onFertig {
                    Button("Fertig", action: onFertig)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                } else {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(Theme.danger)
                }
            }
        }
        .confirmationDialog("Session löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                context.delete(session)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Session und alle Reflexionsdaten werden unwiderruflich gelöscht.")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var sessionHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.bgElevated)
                    .frame(width: 56, height: 56)
                Image(systemName: session.sessionType.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateFormatter.string(from: session.date))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 10) {
                    Label("\(session.durationMinutes) Min", systemImage: "clock")
                    if session.source == .healthKit {
                        Label("Redpoint", systemImage: "heart.text.square.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Redpoint-Daten

    private var redpointCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Daten aus Redpoint", systemImage: "heart.text.square.fill")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 10) {
                if let avg = session.avgHeartRate {
                    metricTile("Ø HF", value: "\(Int(avg)) bpm",
                               symbol: "heart.fill", color: Theme.danger)
                }
                if let max = session.maxHeartRate {
                    metricTile("Max HF", value: "\(Int(max)) bpm",
                               symbol: "heart.fill", color: Theme.danger.opacity(0.7))
                }
                if let kcal = session.activeEnergyKcal {
                    metricTile("Energie", value: "\(Int(kcal)) kcal",
                               symbol: "flame.fill", color: Theme.gold)
                }
            }
        }
        .card()
    }

    private func metricTile(_ label: String, value: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.system(size: 15))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgElevated))
    }

    // MARK: - Tagebuch / Reflexion

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Mein Tagebuch", systemImage: "pencil.and.list.clipboard")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            typePicker

            Divider().background(Theme.surfaceStroke)

            rpePicker

            Divider().background(Theme.surfaceStroke)

            limiterPicker

            Divider().background(Theme.surfaceStroke)

            reflectionField(
                "Was habe ich gelernt?",
                icon: "lightbulb.fill",
                placeholder: "z. B. Hüfteinsatz beim Überhang verbessert…",
                text: Binding(
                    get: { session.learned ?? "" },
                    set: { session.learned = $0.isEmpty ? nil : $0 }
                )
            )

            reflectionField(
                "Was war am schwersten?",
                icon: "exclamationmark.triangle.fill",
                placeholder: "z. B. Fingerkraft am Ende der Session…",
                text: Binding(
                    get: { session.hardestPart ?? "" },
                    set: { session.hardestPart = $0.isEmpty ? nil : $0 }
                )
            )

            reflectionField(
                "Was will ich verbessern?",
                icon: "arrow.up.circle.fill",
                placeholder: "z. B. Mehr Fokus auf Füße und Balance…",
                text: Binding(
                    get: { session.improveNext ?? "" },
                    set: { session.improveNext = $0.isEmpty ? nil : $0 }
                )
            )
        }
        .card()
    }

    // MARK: - Session-Typ

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Art der Session")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SessionType.allCases.filter { $0 != .unknown }) { type in
                        let selected = session.sessionType == type
                        Button {
                            session.sessionTypeRaw = type.rawValue
                            session.updatedAt = .now
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: type.symbol)
                                Text(type.label)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(selected ? Theme.accent : Theme.bgElevated))
                            .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - RPE

    private var rpePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Anstrengung (RPE)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let rpe = session.perceivedEffort {
                    Text("\(rpe)/10")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(rpeColor(rpe))
                }
            }

            HStack(spacing: 5) {
                ForEach(1...10, id: \.self) { value in
                    let selected = session.perceivedEffort == value
                    Button {
                        session.perceivedEffort = value
                        updateReflectionCompleted()
                        session.updatedAt = .now
                    } label: {
                        Text("\(value)")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selected ? rpeColor(value) : Theme.bgElevated)
                            )
                            .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func rpeColor(_ rpe: Int) -> Color {
        switch rpe {
        case 1...4: return Theme.accent
        case 5...7: return Theme.gold
        default:    return Theme.danger
        }
    }

    // MARK: - Limiter

    private var limiterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Limitierende Faktoren")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Limiter.allCases) { limiter in
                    let active = session.limiters.contains(limiter)
                    Button { toggleLimiter(limiter) } label: {
                        Text(limiter.label)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(active ? Theme.accent2.opacity(0.2) : Theme.bgElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(active ? Theme.accent2 : Color.clear, lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(active ? Theme.accent2 : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleLimiter(_ limiter: Limiter) {
        var current = session.limiters
        if let idx = current.firstIndex(of: limiter) {
            current.remove(at: idx)
        } else {
            current.append(limiter)
        }
        session.limiterRaw = current.map(\.rawValue)
        updateReflectionCompleted()
        session.updatedAt = .now
    }

    private func updateReflectionCompleted() {
        let wasCompleted = session.reflectionCompleted
        session.reflectionCompleted =
            session.perceivedEffort != nil ||
            !session.limiterRaw.isEmpty ||
            session.learned != nil ||
            session.hardestPart != nil ||
            session.improveNext != nil
        if !wasCompleted && session.reflectionCompleted {
            NotificationService.shared.cancelReminder(for: session.id)
        }
    }

    // MARK: - Textfelder

    private func reflectionField(_ title: String, icon: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72)
                    .padding(10)
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgElevated))
            .onChange(of: text.wrappedValue) { _, _ in
                updateReflectionCompleted()
                session.updatedAt = .now
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let session = MockData.makeSessions()[0]
    container.mainContext.insert(session)
    return NavigationStack {
        SessionDetailView(session: session)
    }
    .modelContainer(container)
}
