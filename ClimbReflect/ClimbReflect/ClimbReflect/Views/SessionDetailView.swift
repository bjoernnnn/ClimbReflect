import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Bindable var session: ClimbSession
    var onFertig: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showAddAscent = false
    @State private var showAddTrainingSet = false
    @State private var showLocationEditor = false
    @State private var editedShoe: Ascent? = nil

    // ST-2: distinct gymNames aus allen Sessions
    @Query(sort: \ClimbSession.date, order: .reverse) private var allSessions: [ClimbSession]
    private var knownGymNames: [String] {
        Array(Set(allSessions.compactMap(\.gymName).filter { !$0.isEmpty })).sorted()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, dd. MMMM yyyy · HH:mm"
        return f
    }()

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let twoColumns = [GridItem(.flexible()), GridItem(.flexible())]
    private let ropeTypes: [SessionType] = [.lead, .topRope, .autoBelay]

    var body: some View {
        ZStack {
            MountainBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overviewSection
                    if session.sessionType == .training {
                        trainingSetsCard
                    }
                    ascentsSection
                    reflectionCard
                }
                .padding(.horizontal, 20)
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
        .sheet(isPresented: $showAddAscent) {
            AddAscentView(session: session)
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

    // MARK: - Übersicht (erster Screen)

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sessionHeader
            let showAlt = ropeTypes.contains(session.sessionType) && session.altitudeTotalGain > 0
            if session.avgHeartRate != nil || session.activeEnergyKcal != nil || showAlt {
                redpointCard
            }
            // Kurzstat-Leiste
            let tops = session.ascents.filter { $0.result == .top }.count
            let total = session.ascents.count
            if total > 0 {
                HStack(spacing: 12) {
                    Label("\(tops) Top\(tops == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                    Label("\(total - tops) Versuch\(total - tops == 1 ? "" : "e")",
                          systemImage: "arrow.clockwise.circle")
                        .foregroundStyle(Theme.gold)
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .card()
            }
            // SI-2/SI-3: Session-Insights
            insightsSection

            // A3: Session-Verlauf
            if session.isClimbing {
                SessionFatigueView(session: session)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Session-Insights (SI-2 / SI-3)

    @ViewBuilder
    private var insightsSection: some View {
        let insights = StatsEngine.insights(for: session)
        if session.isClimbing {
            if insights.hasAttemptTimes {
                SessionTimeDonut(insights: insights)
                insightsMetrics(insights: insights)
            } else if session.durationSeconds > 0 {
                Text("Zur Zeitaufteilung gibt es für diese Session keine Daten – Aktivzeit wird nur bei Watch-Sessions mit Start/Stopp pro Versuch gemessen.")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                insightsMetrics(insights: insights)
            }
        }
    }

    @ViewBuilder
    private func insightsMetrics(insights: StatsEngine.SessionInsights) -> some View {
        let items: [(label: String, value: String, symbol: String, color: Color)?] = [
            insights.hasAttemptTimes ? ("Aktivzeit",
                formatMinutes(insights.activeSeconds),
                "figure.climbing", Theme.accent) : nil,
            insights.avgAttemptSeconds.map { ("Ø Versuch",
                formatSeconds($0), "timer", Theme.accent2) },
            insights.load.map { ("Belastung (sRPE)",
                "\($0)", "gauge.medium", Theme.gold) },
            insights.successRate.map { ("Erfolgsquote",
                "\(Int($0 * 100))%", "percent", Theme.textSecondary) },
            insights.hardestTopGrade.map { ("Top-Grad",
                $0, "trophy", Theme.gold) },
        ]
        let valid = items.compactMap { $0 }
        if !valid.isEmpty {
            let cols = valid.count >= 4
                ? [GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(Array(valid.enumerated()), id: \.offset) { _, item in
                        metricTile(item.label, value: item.value, symbol: item.symbol, color: item.color)
                    }
                }
            }
            .card()
        }
    }

    private func formatMinutes(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        return "\(m) Min"
    }

    private func formatSeconds(_ t: Double) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Begehungen-Sektion (zweiter Screen)

    private var ascentsSection: some View {
        ascentsCard
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
                    .font(.system(size: 16))
                    .foregroundStyle(session.outdoor || (session.gymName != nil) ? Theme.accent2 : Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
        .sheet(isPresented: $showLocationEditor) {
            locationEditorSheet
        }
    }

    // MARK: - ST-2: Standort-Editor

    private var locationEditorSheet: some View {
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
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgElevated))
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
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgElevated))

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
                                                        session.gymName == gym ? Theme.accent : Theme.bgElevated
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { showLocationEditor = false }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Vitalwerte

    private var redpointCard: some View {
        let showAlt = ropeTypes.contains(session.sessionType) && session.altitudeTotalGain > 0
        let metricCount = (session.avgHeartRate != nil ? 1 : 0)
            + (session.maxHeartRate != nil ? 1 : 0)
            + (session.activeEnergyKcal != nil ? 1 : 0)
            + (showAlt ? 1 : 0)
        return VStack(alignment: .leading, spacing: 14) {
            Label("Vitalwerte", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if metricCount >= 4 {
                LazyVGrid(columns: twoColumns, spacing: 10) {
                    metricsContent(showAlt: showAlt)
                }
            } else {
                HStack(spacing: 10) {
                    metricsContent(showAlt: showAlt)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private func metricsContent(showAlt: Bool) -> some View {
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
        if showAlt {
            metricTile("Höhenmeter", value: "\(Int(session.altitudeTotalGain)) m",
                       symbol: "arrow.up.forward", color: Theme.accent)
        }
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

    // MARK: - Begehungen (P3.1)

    private var ascentsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Begehungen", systemImage: "figure.climbing")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showAddAscent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
            }

            let sorted = session.ascents.sorted { $0.createdAt < $1.createdAt }
            if sorted.isEmpty {
                Text("Noch keine Begehungen erfasst.\nTippe auf + um Boulder oder Routen hinzuzufügen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(sorted) { ascent in
                        AscentRowView(ascent: ascent)
                            .contentShape(Rectangle())
                            .onTapGesture { editedShoe = ascent }
                        if ascent.id != sorted.last?.id {
                            Divider().background(Theme.surfaceStroke)
                        }
                    }
                }
                .sheet(item: $editedShoe) { ascent in
                    EditAscentAssociationsSheet(ascent: ascent)
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
                                .foregroundStyle(Theme.gold)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.top, 4)
                }
            }
        }
        .card()
    }

    // MARK: - T2: Trainings-Sets

    private var trainingSetsCard: some View {
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
                            Divider().background(Theme.surfaceStroke)
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
                .font(.system(size: 16))
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
                    .foregroundStyle(kg > 0 ? Theme.gold : Theme.accent2)
            }

            Button(role: .destructive) {
                context.delete(t)
            } label: {
                Image(systemName: "trash").font(.caption).foregroundStyle(Theme.danger.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private func formatKg(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))" : String(format: "%.2g", kg)
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

            techniqueFocusPicker

            Divider().background(Theme.surfaceStroke)

            focusRatingPicker

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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selected ? Theme.accent : Theme.bgElevated))
                        .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
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
            !session.techniqueFocusesRaw.isEmpty ||
            session.focusRating != nil ||
            session.learned != nil ||
            session.hardestPart != nil ||
            session.improveNext != nil
        if !wasCompleted && session.reflectionCompleted {
            NotificationService.shared.cancelReminder(for: session.id)
        }
    }

    // MARK: - Technik-Fokus (P3.6)

    private var techniqueFocusPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Technik-Fokus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if !session.techniqueFocuses.isEmpty {
                    Button("Löschen") {
                        session.techniqueFocusesRaw = []
                        updateReflectionCompleted()
                        session.updatedAt = .now
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(TechniqueFocus.allCases) { focus in
                    let selected = session.techniqueFocuses.contains(focus)
                    Button {
                        var current = session.techniqueFocuses
                        if let idx = current.firstIndex(of: focus) {
                            current.remove(at: idx)
                        } else {
                            current.append(focus)
                        }
                        session.techniqueFocusesRaw = current.map(\.rawValue)
                        updateReflectionCompleted()
                        session.updatedAt = .now
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: focus.symbol)
                            Text(focus.label)
                        }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(selected ? Theme.accent2 : Theme.bgElevated))
                        .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Fokus-Bewertung (A7)

    private var focusRatingPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Fokus-Bewertung")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if session.focusRating != nil {
                    Button("Löschen") {
                        session.focusRating = nil
                        updateReflectionCompleted()
                        session.updatedAt = .now
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                }
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    let active = (session.focusRating ?? 0) >= star
                    Button {
                        session.focusRating = session.focusRating == star ? nil : star
                        updateReflectionCompleted()
                        session.updatedAt = .now
                    } label: {
                        Image(systemName: active ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundStyle(active ? Theme.gold : Theme.bgElevated)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.1), value: session.focusRating)
                }
                Spacer()
                if let r = session.focusRating {
                    Text(focusRatingLabel(r))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func focusRatingLabel(_ r: Int) -> String {
        switch r {
        case 1: return "Abgelenkt"
        case 2: return "Wenig Fokus"
        case 3: return "Okay"
        case 4: return "Fokussiert"
        default: return "Im Flow"
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
