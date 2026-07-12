import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<AchievementUnlock> { !$0.seenByUser }, sort: \AchievementUnlock.unlockedAt)
    private var unseenUnlocks: [AchievementUnlock]

    // EP-7: nur .full-Erfolge feiern im Vollbild-Overlay; .quiet läuft über
    // den Toast (EP-8). Reihenfolge-Vorrang: Overlay zuerst, Toast danach.
    private var unseenFullUnlocks: [AchievementUnlock] {
        unseenUnlocks.filter {
            AchievementDefinition.definition(id: $0.definitionID)?.celebration == .full
        }
    }

    // EP-8: leise Feier für .quiet-Erfolge — eigene Queue, nie gleichzeitig
    // mit dem Vollbild-Overlay (Overlay hat Vorrang, Toast läuft danach).
    private var unseenQuietUnlocks: [AchievementUnlock] {
        unseenUnlocks.filter {
            AchievementDefinition.definition(id: $0.definitionID)?.celebration == .quiet
        }
    }

    @State private var batchTotal = 0
    @State private var toastUnlock: AchievementUnlock?

    // EP-10: gemeinsame Tab-Auswahl, damit „Nächster Erfolg" (Today) direkt
    // in den Erfolge-Tab springen kann, ohne eine Binding-Kette durchzureichen.
    @AppStorage("selectedTabIndex") private var selectedTabIndex = 0

    private var currentUnlock: AchievementUnlock? { unseenFullUnlocks.first }
    private var pagerText: String? {
        guard batchTotal > 1 else { return nil }
        let index = max(1, batchTotal - unseenFullUnlocks.count + 1)
        return "\(index) von \(batchTotal)"
    }

    var body: some View {
        TabView(selection: $selectedTabIndex) {
            TodayView()
                .tabItem { Label("Heute", systemImage: "house.fill") }
                .tag(0)

            FortschrittView()
                .tabItem { Label("Fortschritt", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(1)

            NavigationStack { ProjectsView() }
                .tabItem { Label("Projekte", systemImage: "target") }
                .tag(2)

            AchievementsView()
                .tabItem { Label("Erfolge", systemImage: "trophy.fill") }
                .tag(3)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .overlay {
            if let unlock = currentUnlock {
                AchievementUnlockOverlay(unlock: unlock, pagerText: pagerText) {
                    markSeen(unlock)
                }
                .id(unlock.id)   // frische Choreografie je Unlock (State-Reset)
            }
        }
        .overlay(alignment: .top) {
            if let toastUnlock, currentUnlock == nil {
                AchievementToast(unlock: toastUnlock)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toastUnlock.id)
            }
        }
        .onChange(of: unseenFullUnlocks.count) { _, new in
            if new == 0 { batchTotal = 0 }
            else if new > batchTotal { batchTotal = new }
        }
        .onChange(of: unseenQuietUnlocks.map(\.id)) { _, _ in advanceToastIfNeeded() }
        .onChange(of: currentUnlock?.id) { _, _ in advanceToastIfNeeded() }
        .task {
            if !unseenFullUnlocks.isEmpty { batchTotal = unseenFullUnlocks.count }
            advanceToastIfNeeded()
        }
    }

    private func markSeen(_ unlock: AchievementUnlock) {
        unlock.seenByUser = true
        try? context.save()
    }

    /// Zeigt den nächsten leisen Unlock, wenn gerade kein Vollbild-Overlay
    /// läuft und aktuell kein Toast sichtbar ist; blendet nach 2,5 s wieder aus.
    private func advanceToastIfNeeded() {
        guard currentUnlock == nil, toastUnlock == nil, let next = unseenQuietUnlocks.first else { return }
        toastUnlock = next
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            markSeen(next)
            // UserDefaults.bool(forKey:) liefert false für einen fehlenden Key —
            // @AppStorage("achievementEffectsEnabled") default ist aber true.
            let effectsEnabled = UserDefaults.standard.object(forKey: "achievementEffectsEnabled") == nil
                ? true : UserDefaults.standard.bool(forKey: "achievementEffectsEnabled")
            let reduced = !effectsEnabled || UIAccessibility.isReduceMotionEnabled
            if reduced {
                toastUnlock = nil
            } else {
                withAnimation(.easeIn(duration: 0.22)) { toastUnlock = nil }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    MockData.seedIfNeeded(container.mainContext)
    return DashboardView().modelContainer(container)
}
