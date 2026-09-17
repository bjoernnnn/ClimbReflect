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
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var addAscentRequest: AddAscentRequest? = nil
    @State private var didAutoOpenAddAscent = false   // VT-8
    @State private var reflectionExpanded = false   // EF-5
    @State private var showRecap = false   // FS-7
    @FocusState private var isTextFieldFocused: Bool

    // EP-10: Unlocks, die aus dieser Session entstanden sind (Badge-Zeile).
    @Query private var allUnlocks: [AchievementUnlock]
    private var sessionUnlocks: [AchievementUnlock] {
        allUnlocks.filter { $0.sessionID == session.id }.sorted { $0.unlockedAt < $1.unlockedAt }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SessionSummaryHeader(session: session)
                            .padding(.top, 8)
                        if !sessionUnlocks.isEmpty {
                            sessionUnlocksCard
                        }
                        if session.sessionType == .training {
                            SessionTrainingCard(session: session)
                        }
                        SessionAscentsCard(session: session) {
                            addAscentRequest = AddAscentRequest(project: nil)
                        }
                        SessionQuickCheckCard(session: session)
                        SessionReflectionCard(session: session, isExpanded: $reflectionExpanded, isTextFieldFocused: $isTextFieldFocused)
                            .id("reflection")
                        // E25: Messwerte stehen am Ende – Kontext, kein Einstieg.
                        if SessionInsightsSection(session: session).hasContent {
                            SectionHeader("Messwerte")
                            SessionInsightsSection(session: session)
                        }
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
        .navigationTitle(session.sessionType == .unknown ? "Session" : session.sessionType.label)
        .navigationBarTitleDisplayMode(.inline)
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
