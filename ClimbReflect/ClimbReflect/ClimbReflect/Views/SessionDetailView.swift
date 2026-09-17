import SwiftUI
import SwiftData

// VT-8: sheet(item:) statt Bool-Flag, damit das Projekt gleich mitgegeben werden kann.
private struct AddAscentRequest: Identifiable {
    let id = UUID()
    let project: Project?
}

struct SessionDetailView: View {
    @Bindable var session: ClimbSession
    var onFertig: (() -> Void)? = nil
    var autoAddAscentProject: Project? = nil   // VT-8
    var focusReflection = false   // KR-7: aus dem Recap direkt zur Reflexion springen
    var showsRecapAction = true   // KR-7: „Zusammenfassung" im Menü unterdrücken, wenn wir schon vom Recap kommen
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var addAscentRequest: AddAscentRequest? = nil
    @State private var didAutoOpenAddAscent = false   // VT-8
    @State private var showAddTrainingSet = false
    @State private var showLocationEditor = false
    @State private var editedAscent: Ascent? = nil
    @State private var pendingDeleteAscent: Ascent? = nil   // VT-1
    @State private var reflectionExpanded = false   // EF-5
    @State private var showRecap = false   // FS-7
    @State private var reflectionJustCompleted = false   // HM-1
    @FocusState private var isTextFieldFocused: Bool

    // ST-2: distinct gymNames aus allen Sessions
    @Query(sort: \ClimbSession.date, order: .reverse) private var allSessions: [ClimbSession]
    // EP-10: Unlocks, die aus dieser Session entstanden sind (Badge-Zeile).
    @Query private var allUnlocks: [AchievementUnlock]
    private var sessionUnlocks: [AchievementUnlock] {
        allUnlocks.filter { $0.sessionID == session.id }.sorted { $0.unlockedAt < $1.unlockedAt }
    }
    private var knownGymNames: [String] { ClimbSession.knownGymNames(allSessions) }

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
            Theme.bg.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        overviewSection
                        if !sessionUnlocks.isEmpty {
                            sessionUnlocksCard
                        }
                        if session.sessionType == .training {
                            trainingSetsCard
                        }
                        ascentsSection
                        quickCheckCard
                        reflectionCard
                            .id("reflection")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .sensoryFeedback(trigger: session.ascents.count, ascentCountFeedback)
                .task {
                    guard focusReflection else { return }
                    reflectionExpanded = true
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(.snappy) { proxy.scrollTo("reflection", anchor: .top) }
                }
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // VT-5: leere, gerade erst angelegte manuelle Session verwerfen statt
                // als „Leiche" in der Historie zu behalten.
                if onFertig != nil && isPristine {
                    Button("Verwerfen", role: .destructive) {
                        NotificationService.shared.cancelReminder(for: session.id)
                        context.delete(session)
                        try? context.save()
                        onFertig?()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let onFertig {
                    Button("Fertig", action: onFertig)
                        .fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Art der Session", selection: sessionTypeBinding) {
                        ForEach(SessionType.allCases.filter { $0 != .unknown }) { type in
                            Label(type.label, systemImage: type.symbol).tag(type)
                        }
                    }
                    // FS-7: dieselbe Zusammenfassung wie nach einer neu empfangenen
                    // Watch-Session, hier jederzeit manuell aufrufbar.
                    if showsRecapAction && session.isClimbing && !session.ascents.isEmpty {
                        Button("Zusammenfassung", systemImage: "sparkles") {
                            showRecap = true
                        }
                    }
                    Divider()
                    Button("Session löschen", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Weitere Aktionen")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { isTextFieldFocused = false }
            }
        }
        .sheet(item: $addAscentRequest) { request in
            AddAscentView(session: session, preselectedProject: request.project)
        }
        .sheet(isPresented: $showRecap) {
            SessionRecapSheet(session: session)
        }
        .sensoryFeedback(.success, trigger: reflectionJustCompleted)
        .task {
            // VT-8: aus dem Projekt heraus neu angelegte Session → Erfassen-Sheet direkt öffnen.
            if let project = autoAddAscentProject, !didAutoOpenAddAscent {
                didAutoOpenAddAscent = true
                addAscentRequest = AddAscentRequest(project: project)
            }
        }
        // EP-3: deckt Reflexion-/Ascent-Änderungen ab, die in dieser Ansicht
        // ohne einzelnen Save-Aufruf passieren (Limiter-Toggle, Notizfelder …).
        .onDisappear {
            AchievementService.shared.checkNow(context: context)
        }
        .confirmationDialog("Session löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                NotificationService.shared.cancelReminder(for: session.id)
                context.delete(session)
                try? context.save()
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Session und alle Reflexionsdaten werden unwiderruflich gelöscht.")
        }
    }

    private func ascentCountFeedback(old: Int, new: Int) -> SensoryFeedback? {
        if new > old { return .success }
        if new < old { return .impact(weight: .medium) }
        return nil
    }

    // EF-5: Session-Typ direkt aus dem Header-Menü änderbar (ersetzt typePicker im Kurz-Check).
    private var sessionTypeBinding: Binding<SessionType> {
        Binding(
            get: { session.sessionType },
            set: { session.sessionTypeRaw = $0.rawValue; session.updatedAt = .now }
        )
    }

    // VT-5: keine Ascents/Sets/Reflexion → gerade erst angelegte, leere Session.
    private var isPristine: Bool {
        session.ascents.isEmpty && session.trainingSets.isEmpty && !session.reflectionCompleted
            && session.perceivedEffort == nil && session.limiterRaw.isEmpty
            && (session.learned?.isEmpty ?? true) && (session.hardestPart?.isEmpty ?? true)
            && (session.improveNext?.isEmpty ?? true) && session.techniqueFocusesRaw.isEmpty
            && session.focusRating == nil
    }

    // MARK: - Übersicht (erster Screen)

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sessionHeader
            let showAlt = ropeTypes.contains(session.sessionType) && session.altitudeTotalGain > 0
            if session.avgHeartRate != nil || session.activeEnergyKcal != nil || showAlt {
                healthCard
            }
            // SI-2/SI-3: Session-Insights
            insightsSection
        }
        .padding(.top, 8)
    }

    // MARK: - EP-10: In dieser Session freigeschaltet

    private var sessionUnlocksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("In dieser Session freigeschaltet")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(sessionUnlocks, id: \.id) { unlock in
                        VStack(spacing: 6) {
                            AchievementMedallion(
                                symbol: AchievementDefinition.definition(id: unlock.definitionID)?.symbol ?? "star.fill",
                                state: .unlocked(material: unlock.material), size: 44)
                            Text(AchievementDefinition.definition(id: unlock.definitionID)?.title ?? "")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 64)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .card()
    }

    // MARK: - Session-Insights (SI-2 / SI-3)

    @ViewBuilder
    private var insightsSection: some View {
        let insights = StatsEngine.insights(for: session)
        if session.isClimbing {
            if insights.hasFullTimeCoverage {
                SessionTimeDonut(insights: insights)
                insightsMetrics(insights: insights)
            } else if insights.hasAttemptTimes {
                // FB-10: nur Teil-Abdeckung → Donut verzerrt (ungetimte Ascents = Pause) → ausblenden
                Text("Aktivzeit aus \(insights.timedAscentCount) von \(insights.ascentCount) Versuchen erfasst — Zeitaufteilung dafür ausgeblendet.")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
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
            insights.hasAttemptTimes ? ("Aktivzeit (erfasst)",
                formatMinutes(insights.activeSeconds),
                "figure.climbing", Theme.accent) : nil,
            insights.avgAttemptSeconds.map { ("Ø Versuch",
                formatSeconds($0), "timer", Theme.accent2) },
            insights.load.map { ("Belastung (sRPE)",
                "\($0)", "gauge.medium", Theme.gold) },
            insights.successRate.map { ("Erfolgsquote",
                "\(Int($0 * 100))%", "percent", Theme.textSecondary) },
            insights.hardestTopGrade.map { ("Top-Grad",
                GradeConverter.display(grade: $0, storedIn: insights.hardestTopGradeSystem ?? .fontainebleau),
                "trophy", Theme.gold) },   // RP-17
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
                    .fill(Theme.surfaceRaised)
                    .frame(width: 56, height: 56)
                Image(systemName: session.sessionType.symbol)
                    .font(.title3.weight(.semibold))
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
                    .font(.body)
                    .foregroundStyle(session.outdoor || (session.gymName != nil) ? Theme.accent2 : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Standort bearbeiten")
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
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surfaceRaised))
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
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surfaceRaised))

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
                    Button("Fertig") { showLocationEditor = false }
                }
            }
        }
    }

    // MARK: - Vitalwerte

    private var healthCard: some View {
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
                .font(.body)
            // lineLimit(1) + Skalierung: kein Umbruch → alle Kacheln einer Reihe gleich hoch
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.surfaceRaised))
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
                    addAscentRequest = AddAscentRequest(project: nil)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Begehung hinzufügen")
            }

            let sorted = session.ascents.sorted { $0.createdAt < $1.createdAt }
            if sorted.isEmpty {
                Button {
                    addAscentRequest = AddAscentRequest(project: nil)
                } label: {
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
                            Divider().background(Theme.separator)
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
                            Divider().background(Theme.separator)
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
                    .foregroundStyle(kg > 0 ? Theme.gold : Theme.accent2)
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

    // MARK: - EF-5: Kurz-Check

    private var quickCheckCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Kurz-Check")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if session.sessionFocusLabel != nil || session.energyLabel != nil {
                watchQuestionnaireChips
                Divider().background(Theme.separator)
            }

            rpePicker

            Divider().background(Theme.separator)

            limiterPicker
        }
        .card()
    }

    // MARK: - EF-5: Reflexion

    /// Bereits erfasste Inhalte → Karte startet aufgeklappt statt eingeklappt.
    private var hasReflectionContent: Bool {
        (session.isClimbing && (!session.techniqueFocusesRaw.isEmpty || session.focusRating != nil))
            || !(session.learned ?? "").isEmpty
            || !(session.hardestPart ?? "").isEmpty
            || !(session.improveNext ?? "").isEmpty
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Reflexion")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: session.reflectionCompleted ? "checkmark.seal.fill" : "checkmark.seal")
                    .foregroundStyle(session.reflectionCompleted ? Theme.gold : Theme.textTertiary)
                    .symbolEffect(.bounce, value: session.reflectionCompleted)
            }

            if reflectionExpanded {
                if session.isClimbing {
                    techniqueFocusPicker
                    Divider().background(Theme.separator)
                    focusRatingPicker
                    Divider().background(Theme.separator)
                }

                reflectionField(
                    "Was habe ich gelernt?",
                    icon: "lightbulb.fill",
                    placeholder: session.isClimbing
                        ? "z. B. Hüfteinsatz beim Überhang verbessert…"
                        : "z. B. Max-Hangs erstmals an 10 mm gehalten…",
                    text: Binding(
                        get: { session.learned ?? "" },
                        set: { session.learned = $0.isEmpty ? nil : $0 }
                    )
                )

                reflectionField(
                    "Was war am schwersten?",
                    icon: "exclamationmark.triangle.fill",
                    placeholder: session.isClimbing
                        ? "z. B. Fingerkraft am Ende der Session…"
                        : "z. B. Letzter Satz Repeaters…",
                    text: Binding(
                        get: { session.hardestPart ?? "" },
                        set: { session.hardestPart = $0.isEmpty ? nil : $0 }
                    )
                )

                reflectionField(
                    "Was will ich verbessern?",
                    icon: "arrow.up.circle.fill",
                    placeholder: session.isClimbing
                        ? "z. B. Mehr Fokus auf Füße und Balance…"
                        : "z. B. Nächstes Mal 2 kg mehr Zusatzlast…",
                    text: Binding(
                        get: { session.improveNext ?? "" },
                        set: { session.improveNext = $0.isEmpty ? nil : $0 }
                    )
                )
            } else {
                Text("Was hast du gelernt, was war schwer, was nimmst du mit?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button("Reflexion schreiben") {
                    withAnimation(.snappy) { reflectionExpanded = true }
                }
                .buttonStyle(.bordered)
            }
        }
        .card()
        .onAppear {
            if hasReflectionContent { reflectionExpanded = true }
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
                                RoundedRectangle(cornerRadius: Theme.Radius.small)
                                    .fill(selected ? rpeColor(value) : Theme.surfaceRaised)
                            )
                            .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: session.perceivedEffort)
    }

    // E18: eine Accent-Intensitätsskala statt Gold/Rot-Stufen – eine harte Session ist kein Fehler.
    private func rpeColor(_ rpe: Int) -> Color {
        Theme.accent.opacity(0.35 + Double(rpe) * 0.065)
    }

    // MARK: - Limiter

    // RP-2: Auf der Watch erfasster Schwerpunkt + Zustand (read-only Chips)
    private var watchQuestionnaireChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Auf der Uhr erfasst")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                if let focus = session.sessionFocusLabel {
                    readOnlyChip("Schwerpunkt", value: focus, icon: "scope")
                }
                if let energy = session.energyLabel {
                    readOnlyChip("Zustand", value: energy, icon: "bolt.heart.fill")
                }
            }
        }
    }

    private func readOnlyChip(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.accent2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surfaceRaised)
        )
    }

    private var limiterPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            // FB-6: bei Training ist es die Zielkapazität, nicht der limitierende Faktor
            Text(session.isClimbing ? "Limitierende Faktoren" : "Trainiert")
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
                                RoundedRectangle(cornerRadius: Theme.Radius.small)
                                    .fill(active ? Theme.accent2.opacity(0.2) : Theme.surfaceRaised)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                                            .stroke(active ? Theme.accent2 : Color.clear, lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(active ? Theme.accent2 : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: session.limiterRaw)
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
            // FB-6: Technik/Fokus zählen nur bei Klettersessions (Picker bei Training aus)
            (session.isClimbing && !session.techniqueFocusesRaw.isEmpty) ||
            (session.isClimbing && session.focusRating != nil) ||
            session.learned != nil ||
            session.hardestPart != nil ||
            session.improveNext != nil
        if !wasCompleted && session.reflectionCompleted {
            NotificationService.shared.cancelReminder(for: session.id)
            reflectionJustCompleted.toggle()   // HM-1: .success-Haptik
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
                        .background(Capsule().fill(selected ? Theme.accent2 : Theme.surfaceRaised))
                        .foregroundStyle(selected ? Theme.bg : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: session.techniqueFocusesRaw)
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
                            .font(.title3)
                            .foregroundStyle(active ? Theme.gold : Theme.surfaceRaised)
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
        .sensoryFeedback(.selection, trigger: session.focusRating)
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

            TextField(placeholder, text: text, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2...8)
                .focused($isTextFieldFocused)
                .inset()
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
