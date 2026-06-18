# ClimbReflect – Fix: Blackscreen beim Beenden (End-/Fragebogen-Flow entkoppeln)

Branch: `dev`. Behebt den Bug, dass nach dem Beenden eines Trainings der Fragebogen
(Zustand/Anstrengung) schwarz/unbedienbar ist und nur ein Force-Quit hilft.

**Ursache (verifiziert):** Der Fragebogen wird in der `NavigationStack` der `LiveSessionView`
präsentiert (`navigationDestination(for: WatchNavStep.self)`). `endWorkout()` ruft
`finishSession()` auf, das **sofort** `isRunning = false` setzt (WorkoutManager Z.432). ContentView
schaltet dann augenblicklich von `LiveSessionView` auf `SportSelectionView` um und **zerstört die
`LiveSessionView` samt der Navigation zum Fragebogen** → Blackscreen. Nach langem Training/Recovery
ist das Timing besonders fragil.

**Lösungsidee:** Den End-Flow (Fragebogen → Zusammenfassung) aus der `LiveSessionView` herauslösen
und in ContentView über einen **eigenen Zustand** steuern, unabhängig von `isRunning`.

---

## P0-1 — Eigenen Zustand für den End-Flow im WorkoutManager

- *Datei:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:*
  1. Property ergänzen: `@Published var pendingSummaryDTO: WatchSessionDTO? = nil`.
  2. In `endWorkout()` direkt **bevor** `finishSession()` gerufen wird (also bevor `isRunning`
     auf false geht), das fertige DTO setzen:
     ```swift
     self.pendingSummaryDTO = dto   // treibt den End-Flow in ContentView
     finishSession()                // setzt isRunning = false
     return dto
     ```
  3. `finishSession()` unverändert lassen (`isRunning = false`), aber `pendingSummaryDTO` dort
     **nicht** zurücksetzen.
- *Fertig-wenn:* Nach `endWorkout()` ist `pendingSummaryDTO != nil` und `isRunning == false`.

## P0-2 — ContentView: End-Flow hat Vorrang vor isRunning

- *Datei:* `ClimbReflectWatch Watch App/ContentView.swift`
- *Aufgabe:*
  ```swift
  var body: some View {
      if let dto = workoutManager.pendingSummaryDTO {
          SessionEndFlowView(dto: dto)            // eigener NavigationStack
      } else if workoutManager.isRunning {
          LiveSessionView()
      } else {
          SportSelectionView()
      }
  }
  ```
- *Fertig-wenn:* Solange `pendingSummaryDTO != nil`, wird der End-Flow gezeigt – egal, was
  `isRunning` macht oder ob zwischendurch eine Recovery feuert.

## P0-3 — `SessionEndFlowView` (neu) mit eigenem NavigationStack

- *Datei:* neu `ClimbReflectWatch Watch App/Views/SessionEndFlowView.swift`
- *Aufgabe:* Den bestehenden Fragebogen + die Zusammenfassung hier hosten (Views
  wiederverwenden), unabhängig von `LiveSessionView`:
  ```swift
  struct SessionEndFlowView: View {
      @EnvironmentObject var workoutManager: WorkoutManager
      let dto: WatchSessionDTO
      @State private var enrichedDTO: WatchSessionDTO?

      var body: some View {
          NavigationStack {
              if let enriched = enrichedDTO {
                  SessionSummaryView(dto: enriched, onDone: {
                      workoutManager.pendingSummaryDTO = nil   // → zurück zur SportAuswahl
                  })
              } else {
                  SessionEndQuestionnaireView(dto: dto) { enriched in
                      enrichedDTO = enriched
                  }
              }
          }
      }
  }
  ```
- *Fertig-wenn:* Fragebogen → Zusammenfassung → „Fertig" läuft sauber; danach landet man bei der
  Sportart-Auswahl.

## P0-4 — End-Flow aus `LiveSessionView` entfernen

- *Datei:* `ClimbReflectWatch Watch App/Views/LiveSessionView.swift`
- *Aufgabe:* Die `navigationDestination(for: WatchNavStep.self)`-Blöcke für Fragebogen/
  Zusammenfassung (Z.92/138) und den zugehörigen `navPath`/`sessionDTO`-Navigationscode
  entfernen. Der End-Button ruft nur noch:
  ```swift
  Task { _ = await workoutManager.endWorkout() }   // ContentView übernimmt via pendingSummaryDTO
  ```
- *Fertig-wenn:* `LiveSessionView` enthält keine Fragebogen-/Summary-Navigation mehr; kein doppelter
  `navigationDestination(for: WatchNavStep.self)` mehr im View-Baum.

---

## P1 — Recovery einer bereits beendeten Session abfangen (Nebenbefund)

- *Kontext:* Log zeigte `recoveredActiveSession state=3` (ended). Eine beendete Session sollte
  nicht wie eine laufende reattacht werden.
- *Datei:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift` (`reattach`/`recoverIfNeeded`)
- *Aufgabe:* In `reattach(to ws:)` zu Beginn prüfen:
  ```swift
  guard ws.state == .running || ws.state == .paused else {
      DiagnosticLog.shared.log("recovered ended session state=\(ws.state.rawValue) – nicht reattachen")
      // beendete Session aufräumen statt als laufend zu behandeln
      return
  }
  ```
- *Fertig-wenn:* Eine beim Start vorgefundene beendete Session führt **nicht** in die LiveSession,
  sondern wird ignoriert/aufgeräumt.

---

## Fertig-wenn (gesamt)
- Beenden eines Trainings (auch nach langer Session oder nach einer Recovery) zeigt **zuverlässig**
  den Fragebogen, **kein** Blackscreen, **kein** Force-Quit nötig.
- Genau **ein** `end`-Event pro bewusstem Beenden.
