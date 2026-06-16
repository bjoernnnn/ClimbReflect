# Fix-Anweisung für Claude Code – 3 Bugs aus dem echten Watch-Test

Bitte diese drei Bugs beheben. Ursachen sind analysiert, exakte Änderungen unten.
Pfade relativ zum iOS-Quell-Root `ClimbReflect/ClimbReflect/ClimbReflect/` bzw. zum
Watch-Ordner `ClimbReflectWatch Watch App/`.

---

## Bug 1: Eigene Watch-Sessions werden als „Von Redpoint erkannt" importiert

**Ursache:** Der Redpoint-Import liest ALLE `.climbing`-Workouts aus HealthKit – auch die,
die die eigene Watch-App selbst geschrieben hat – und legt sie mit `source = .healthKit` an.

**Fix:** In `Services/RedpointHealthService.swift`, Methode `fetchClimbingWorkouts()`, die
Workouts der eigenen App herausfiltern. Ersetze:

```swift
        return try await descriptor.result(for: store)
```
durch:
```swift
        let workouts = try await descriptor.result(for: store)
        // Eigene iOS-/Watch-Workouts NICHT als "Redpoint" re-importieren –
        // nur echte Fremd-Workouts (Redpoint etc.) übernehmen.
        return workouts.filter {
            !$0.sourceRevision.source.bundleIdentifier.hasPrefix("de.dreselbjoern.ClimbReflect")
        }
```

**Fertig wenn:** Eine über die ClimbReflect-Watch aufgezeichnete Session erscheint auf dem
iPhone nur als Watch-Session (`source = .watch`), nie als „Redpoint".

---

## Bug 2: „Session beenden" zeigt keinen Fragebogen

**Ursache:** `WorkoutManager.endWorkout()` setzt `isRunning = false`. `ContentView` zeigt
`LiveSessionView` nur solange `isRunning == true` – die View (inkl. NavigationStack) wird
also abgebaut, bevor `navPath = [.questionnaire]` den Fragebogen pushen kann.

**Fix Teil A** – in `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`, Methode
`endWorkout()`: den gesamten `// Reset`-Block ENTFERNEN (nur dort entfernen, `clearLiveStatus()`,
den Stop-Haptik-Aufruf und `return dto` behalten). Also diese Zeilen löschen:

```swift
        // Reset
        isRunning = false
        isPaused = false
        session = nil
        builder = nil
        attempts = []
        elapsedSeconds = 0
        heartRate = 0
        maxHeartRate = 0
        activeEnergyKcal = 0
        attemptState = .idle
        trainingTarget = nil
```

**Fix Teil B** – neue Methode in `WorkoutManager` hinzufügen (z. B. direkt unter `endWorkout()`):

```swift
    /// Setzt den State zurück – erst NACH Fragebogen + Zusammenfassung aufrufen.
    func finishSession() {
        isRunning = false
        isPaused = false
        session = nil
        builder = nil
        attempts = []
        elapsedSeconds = 0
        heartRate = 0
        maxHeartRate = 0
        activeEnergyKcal = 0
        attemptState = .idle
        trainingTarget = nil
    }
```

**Fix Teil C** – in `ClimbReflectWatch Watch App/Views/LiveSessionView.swift` an BEIDEN Stellen
(`climbingTabView` und `trainingTabView`) den Summary-`onDone` so ändern, dass er zusätzlich
`finishSession()` aufruft. Ersetze jeweils:

```swift
            case .summary:
                SessionSummaryView(dto: sessionDTO, onDone: { navPath = [] })
```
durch:
```swift
            case .summary:
                SessionSummaryView(dto: sessionDTO, onDone: {
                    navPath = []
                    workoutManager.finishSession()
                })
```

**Fix Teil D** – im `.onAppear`-Block von `LiveSessionView` (Fernsteuerung „end") nach dem
Senden ebenfalls `finishSession()` aufrufen. Ersetze:

```swift
                case "end":
                    Task {
                        let dto = await workoutManager.endWorkout()
                        // Keine Fragebogen für Fernsteuerung – direkt senden
                        if let d = dto { SyncService.shared.send(dto: d) }
                    }
```
durch:
```swift
                case "end":
                    Task {
                        let dto = await workoutManager.endWorkout()
                        if let d = dto { SyncService.shared.send(dto: d) }
                        workoutManager.finishSession()
                    }
```

**Fertig wenn:** „Session beenden" → Fragebogen erscheint → danach Zusammenfassung → „Fertig"
führt zurück zur Sportartauswahl.

---

## Bug 3: Sportart muss zweimal angetippt werden

**Ursache:** `SportSelectionView` nutzt eine eigene `NavigationStack` +
`navigationDestination(isPresented: $navigateToSession)`, die mit dem `isRunning`-Umschalten
in `ContentView` konkurriert (zwei Wege wollen gleichzeitig zu `LiveSessionView`).

**Fix:** In `ClimbReflectWatch Watch App/Views/SportSelectionView.swift` die redundante
Navigation entfernen und allein auf das `isRunning`-Umschalten von `ContentView` setzen.
Ersetze den kompletten Inhalt der Datei durch:

```swift
import SwiftUI

// W2.1: Sporttypauswahl beim Session-Start
// Kein eigener NavigationStack: ContentView schaltet via workoutManager.isRunning
// automatisch auf LiveSessionView um (sonst Double-Tap durch konkurrierende Navigation).

struct SportSelectionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showTrainingSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Klettern")
                    .font(.headline)
                    .foregroundStyle(WatchTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                ForEach(WatchSessionType.allCases) { type in
                    Button {
                        if type == .training {
                            showTrainingSetup = true
                        } else {
                            Task { await workoutManager.startWorkout(type: type) }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: type.symbol)
                                .foregroundStyle(WatchTheme.accent)
                                .frame(width: 24)
                            Text(type.label)
                                .foregroundStyle(WatchTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(WatchTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
        .background(WatchTheme.bg)
        .sheet(isPresented: $showTrainingSetup) {
            TrainingSetupView { target in
                showTrainingSetup = false
                Task { await workoutManager.startWorkout(type: .training, target: target) }
            }
        }
    }
}
```

**Fertig wenn:** Ein einziger Tipp auf eine Sportart (auch Auto-Belay) startet die Session
direkt.

---

## Hinweis: „Health wird immer wieder gefragt" – KEIN Code-Bug

Entitlements sind korrekt (`com.apple.developer.healthkit`). Ursache ist, dass **jede
Neuinstallation aus Xcode die HealthKit-Freigabe zurücksetzt** (normales Dev-Verhalten);
zusätzlich fragen iPhone und Watch getrennt. Beim Endnutzer passiert das nicht.
→ Keine Änderung nötig. (Optional: Auth nur einmal anfragen und mit einem UserDefaults-Flag
merken – rein kosmetisch.)

---

## Nach den Fixes: bitte erneut bauen und gegentesten
1. Sportart 1× tippen → startet sofort (Bug 3)
2. Session beenden → Fragebogen → Zusammenfassung (Bug 2)
3. Auf dem iPhone: Session erscheint als Watch-Session, nicht „Redpoint" (Bug 1)
