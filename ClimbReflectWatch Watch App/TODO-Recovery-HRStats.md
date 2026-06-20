# ClimbReflect – HR-/Energie-Stats über Recovery bewahren

Branch: `dev`. **Problem:** Nach einer Recovery (App-Prozess gekillt, Session überlebt) setzt sich
`maxHeartRate` auf den aktuellen Wert zurück. Auch `hrSum`/`hrCount` (für Ø-HF) und
`activeEnergyKcal` gehen verloren, weil sie reine In-Memory-Properties sind und der
`PendingSessionStore`-Snapshot sie nicht enthält.

**Lösung:** Diese Werte in `PendingSession` aufnehmen und in `reattach()` wiederherstellen.

---

## Aufgabe 1 — `PendingSession` um HR-/Energie-Felder erweitern

- *Datei:* `ClimbReflectWatch Watch App/Services/PendingSessionStore.swift`
- *Aufgabe:* Felder ergänzen (mit Defaults für Abwärtskompatibilität bestehender Snapshots):
  ```swift
  struct PendingSession: Codable {
      let id: UUID
      let startDate: Date
      let sessionTypeRaw: String
      let projectID: String?
      let projectName: String?
      let ascents: [WatchSessionDTO.AscentDTO]
      let accumulatedPaused: TimeInterval

      // NEU: HR-/Energie-Stats für Recovery
      var maxHeartRate: Double?
      var hrSum: Double?
      var hrCount: Int?
      var activeEnergyKcal: Double?
      var lastHeartRate: Double?       // aktuell angezeigte HF
      // ...
  }
  ```
  Optionals + Codable-Defaults → alte Snapshots (ohne diese Felder) laden weiterhin korrekt.
- *Fertig-wenn:* `PendingSession` kompiliert; alte Snapshots ohne diese Felder laden ohne Crash.

## Aufgabe 2 — `savePendingSnapshot()` um die neuen Werte ergänzen

- *Datei:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:* Im `PendingSession(...)`-Initializer die aktuellen Stats mitgeben:
  ```swift
  let snapshot = PendingSession(
      id: UUID(),
      startDate: startDate,
      sessionTypeRaw: sessionType.rawValue,
      projectID: selectedProject?.id,
      projectName: selectedProject?.name,
      ascents: attempts.map { $0.toDTO() },
      accumulatedPaused: accumulatedPaused,
      maxHeartRate: maxHeartRate,
      hrSum: hrSum,
      hrCount: hrCount,
      activeEnergyKcal: activeEnergyKcal,
      lastHeartRate: heartRate
  )
  ```
- *Fertig-wenn:* Jeder Snapshot enthält die aktuellen HR-/Energie-Stats.

## Aufgabe 3 — `reattach()` stellt die Stats wieder her

- *Datei:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:* Im `if let p = PendingSessionStore.load()`-Block in `reattach()` ergänzen:
  ```swift
  if let max = p.maxHeartRate   { self.maxHeartRate = max }
  if let sum = p.hrSum          { self.hrSum = sum }
  if let cnt = p.hrCount        { self.hrCount = cnt }
  if let kcal = p.activeEnergyKcal { self.activeEnergyKcal = kcal }
  if let hr = p.lastHeartRate   { self.heartRate = hr }
  ```
- *Fertig-wenn:* Nach einer Recovery zeigt die App die bisherige Max-HF und Energie korrekt an
  (nicht auf 0 / aktuellen Wert zurückgesetzt).

---

## Testlauf

1. Session starten, ein paar Minuten warten bis HF/Max-HF stabil sind (z. B. Max = 120).
2. App in den Hintergrund gehen lassen (Handgelenk senken, warten).
3. Wenn die App gekillt + recovert wird (`recoveredActiveSession state=2`): Max-HF muss
   weiterhin 120 zeigen (nicht den aktuellen niedrigeren Wert).
4. Energie-Anzeige muss ebenfalls den akkumulierten Wert zeigen.
