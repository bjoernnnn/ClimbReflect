# ClimbReflect – TODO8: Aufzeichnung stabilisieren & App härten

Stand: Review `main` `a30d1c4`. Ziel: die beiden Symptome aus dem finalen Test beseitigen
(„zeichnet ab einer Weile nicht mehr auf" + „stürzt ab") und den Aufzeichnungspfad
grundsätzlich robust machen. Format wie gewohnt: *Kontext / Dateien / Aufgabe / Fertig-wenn*.
Eine Aufgabe = ein Commit. Reihenfolge P0 → P1 → P2.

> Hintergrund (Diagnose): Die Live-Session (Uhr, Höhen-UI, Seil-Erkennung, Live-Status)
> hängt komplett an einem 1-Sekunden-`Timer` auf dem Main-RunLoop. Mit
> `WKSupportsAlwaysOnDisplay = YES` feuert dieser Timer bei abgesenktem Handgelenk nicht
> mehr mit 1 Hz → `elapsedSeconds` friert ein und timergetriebene Arbeit pausiert. Das ist
> die Hauptursache. Dazu kommen ein Crash-Risiko (Motion-Updates auf der Main-Queue),
> verschluckte Session-Fehler und In-Memory-Versuche, die bei einem Absturz verloren gehen.

---

## P0 – Aufzeichnung zuverlässig machen

### P0-1 — Verstrichene Zeit monoton aus dem Startdatum, nicht aus einem Timer-Zähler
- *Kontext:* `elapsedSeconds` wird nur via `elapsedSeconds += 1` im Timer hochgezählt
  (`WorkoutManager.startTimer`) und direkt angezeigt (`LiveSessionView` Z. 178/334/534).
  Im Always-On-Zustand stoppt der Timer → die Uhr friert ein und läuft nach dem
  Handgelenk-Heben falsch weiter. (Die DTO-Dauer nutzt bereits korrekt `workoutStartDate`.)
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`,
  `ClimbReflectWatch Watch App/Views/LiveSessionView.swift`
- *Aufgabe:*
  1. Pausenzeit sauber verbuchen. In `WorkoutManager`:
     ```swift
     private(set) var workoutStartDate: Date?         // sichtbar für die View machen
     private var accumulatedPaused: TimeInterval = 0
     private var pauseStartedAt: Date?

     func currentElapsed() -> TimeInterval {
         guard let start = workoutStartDate else { return 0 }
         if let p = pauseStartedAt {                  // aktuell pausiert → einfrieren
             return max(0, p.timeIntervalSince(start) - accumulatedPaused)
         }
         return max(0, Date().timeIntervalSince(start) - accumulatedPaused)
     }
     ```
  2. `pauseWorkout()`: `pauseStartedAt = Date()` setzen.
     `resumeWorkout()`: `if let p = pauseStartedAt { accumulatedPaused += Date().timeIntervalSince(p); pauseStartedAt = nil }`.
     `finishSession()`: `accumulatedPaused = 0; pauseStartedAt = nil`.
  3. Im Timer-Tick statt `elapsedSeconds += 1` → `self.elapsedSeconds = Int(self.currentElapsed())`.
  4. In `LiveSessionView` die Uhr mit `TimelineView` rendern, damit sie auch im Always-On
     selbstständig korrekt aktualisiert:
     ```swift
     if let start = workoutManager.workoutStartDate {
         TimelineView(.periodic(from: start, by: 1)) { _ in
             Text(format(workoutManager.currentElapsed()))
         }
     }
     ```
- *Fertig-wenn:* Handgelenk während einer Session 2–3 Minuten absenken, dann heben — die
  angezeigte Zeit ist exakt die real verstrichene Zeit (kein Stehenbleiben, kein Nachlaufen),
  Pausen werden korrekt abgezogen.

### P0-2 — Laufende Session crash-sicher zwischenspeichern (kein Datenverlust)
- *Kontext:* `attempts` lebt nur im Speicher und wird erst beim Beenden (nach Fragebogen) zu
  einem DTO. Stürzt die App ab oder wird sie vom System beendet, sind **alle in der Session
  geloggten Begehungen weg** – das deckt sich mit „Training war nicht zu gebrauchen".
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
  (+ kleine neue Datei `PendingSessionStore.swift`)
- *Aufgabe:*
  1. `Codable`-Snapshot definieren: `PendingSession { id, startDate, sessionTypeRaw,
     projectInfo, ascents: [AscentDTO] }` (AscentDTO ist bereits Codable).
  2. Nach jeder Mutation (`startWorkout`, `bankAttempt`, `quickBank`, `removeAttempt`) den
     Snapshot in eine Datei im App-Container schreiben (z. B. `pendingSession.json`).
  3. Beim Start (`WorkoutManager.init` bzw. `ContentView.onAppear`): existiert ein Snapshot,
     der nicht sauber beendet wurde → aus ihm einen `WatchSessionDTO` rekonstruieren und über
     den normalen Sende-Pfad ans iPhone schicken (Begehungen gerettet), dann Snapshot löschen.
     Optional: dem Nutzer „Letzte Session wiederherstellen?" anbieten.
  4. Snapshot in `finishSession()` und nach erfolgreichem Senden löschen.
- *Fertig-wenn:* App während einer Session mit mehreren gebankten Versuchen hart beenden
  (Force-Quit), neu starten → die Begehungen sind nicht verloren (werden gesendet oder
  zur Wiederherstellung angeboten).

---

## P1 – Crash-Härtung

### P1-3 — Accelerometer-Updates von der Main-Queue nehmen
- *Kontext:* `AttemptDetector.startMotionDetection` liefert 5×/s an `OperationQueue.main`
  (Z. 46) plus `DispatchQueue.main.asyncAfter`. Nach einer gedimmten Phase kann ein
  Rückstau die Main-Queue blockieren → watchOS-Watchdog-Kill (wirkt wie ein Absturz).
- *Dateien:* `ClimbReflectWatch Watch App/Services/AttemptDetector.swift`
- *Aufgabe:*
  1. Dedizierte Hintergrund-Queue verwenden:
     ```swift
     private let motionQueue: OperationQueue = {
         let q = OperationQueue(); q.maxConcurrentOperationCount = 1
         q.qualityOfService = .utility; return q
     }()
     // ...
     motion.startAccelerometerUpdates(to: motionQueue) { [weak self] data, _ in ... }
     ```
  2. Burst-Berechnung läuft auf der Queue; nur den Vorschlag auf den Main-Thread holen
     (`DispatchQueue.main.async { self?.onSuggestion?() }`).
  3. `currentHR` wird vom Main-Tick geschrieben und hier gelesen → für die Heuristik
     unkritisch; zur Sicherheit als einfachen Snapshot lesen (kein Crash, kein Lock nötig).
- *Fertig-wenn:* Lange Boulder-Session mit vielen Handgelenk-Bewegungen und Dimm-Phasen
  läuft ohne Hänger/Beendigung durch.

### P1-4 — Session-Statuswechsel und -Fehler behandeln statt verschlucken
- *Kontext:* `workoutSession(didChangeTo:)` ist leer, `didFailWithError` macht nur `print`.
  Beendet/pausiert watchOS die Session unerwartet oder tritt ein Fehler auf, merkt es die App
  nie – die UI zeigt weiter „läuft", nichts wird erfasst.
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`,
  `ClimbReflectWatch Watch App/Views/LiveSessionView.swift`
- *Aufgabe:*
  1. Neue `@Published var sessionEndedUnexpectedly = false` und `@Published var lastError: String?`.
  2. `didChangeTo` auswerten (auf den Main-Actor hüpfen):
     ```swift
     Task { @MainActor [weak self] in
         guard let self else { return }
         switch toState {
         case .paused:  if !self.isPaused { self.isPaused = true; self.timer?.invalidate() }
         case .running: if self.isPaused { self.isPaused = false; self.startTimer() }
         case .ended, .stopped: if self.isRunning { self.sessionEndedUnexpectedly = true }
         default: break
         }
     }
     ```
  3. `didFailWithError`: `lastError` setzen und `sessionEndedUnexpectedly = true`.
  4. `LiveSessionView` beobachtet `sessionEndedUnexpectedly` → leitet in die Finalisierung
     (Fragebogen / Speichern) statt die Session tot weiterlaufen zu lassen. Dank P0-2 sind die
     Daten ohnehin schon gesichert.
- *Fertig-wenn:* Wird die Session von außen beendet (z. B. Berechtigung entzogen, Systemende),
  reagiert die App sichtbar und die bisherigen Daten gehen in die Speicherung.

---

## P2 – Konfiguration & Diagnose härten

### P2-5 — Eine einzige Info.plist-Quelle, Hintergrundmodus im Build verifizieren
- *Kontext:* Das Watch-Target hat gleichzeitig `GENERATE_INFOPLIST_FILE = YES` **und** eine
  explizite `INFOPLIST_FILE`. `WKBackgroundModes`/`UIBackgroundModes` kommen aus zwei Quellen.
  Bricht dieser Merge je das Array, verliert die App die Hintergrund-Laufzeit komplett →
  Aufzeichnung stoppt hart.
- *Dateien:* `ClimbReflect.xcodeproj/project.pbxproj`,
  `ClimbReflectWatch-Watch-App-Info.plist`
- *Aufgabe:* Eine Strategie wählen. Empfehlung: `GENERATE_INFOPLIST_FILE = YES` behalten,
  die explizite `ClimbReflectWatch-Watch-App-Info.plist` entfernen und die nötigen Keys als
  Build-Settings führen (`INFOPLIST_KEY_WKBackgroundModes = "workout-processing"` ist schon da;
  die leere `UIBackgroundModes` entfällt). Danach im **gebauten** Produkt prüfen, dass
  `WKBackgroundModes` als Array mit `workout-processing` und `WKApplication = YES` vorhanden ist.
- *Fertig-wenn:* Gebautes Watch-App-`Info.plist` enthält genau ein `WKBackgroundModes`-Array
  mit `workout-processing`; keine Doppel-/Konfliktquelle mehr.

### P2-6 — In-App-Diagnoseprotokoll (da Geräte-Logs nicht zugänglich)
- *Kontext:* Ohne Crash-Logs ist eine Ferndiagnose unmöglich. Ein leichtes, persistentes
  Ereignisprotokoll macht künftige Fehler auch ohne Xcode-Console sichtbar.
- *Dateien:* neue Datei `ClimbReflectWatch Watch App/Services/DiagnosticLog.swift`,
  Einbindung in `WorkoutManager` und eine kleine Anzeige in den Watch-Einstellungen
- *Aufgabe:*
  1. Ring-Puffer (z. B. letzte 200 Einträge) mit Zeitstempel, persistiert als Datei/JSON.
  2. Ereignisse loggen: `start`, `pause`, `resume`, `bank`, `end`, `didChangeTo <state>`,
     `didFailWithError <msg>`, `recovered pending session`, App-Start/Foreground.
  3. In den Watch-Einstellungen eine einfache Liste „Diagnose" anzeigen (read-only),
     optional per WatchConnectivity ans iPhone spiegeln.
- *Fertig-wenn:* Nach einer problematischen Session lässt sich in der App ablesen, was zuletzt
  passierte (z. B. „didChangeTo ended" oder „didFailWithError …") – ohne Geräte-Logs.

### P2-7 — Kleinere Robustheit
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`,
  `AltimeterService.swift`, `AttemptDetector.swift`
- *Aufgabe:*
  1. **Auth vor Start absichern:** In `startWorkout` sicherstellen, dass
     `requestAuthorization()` durchlief (sonst kurz awaiten), bevor die HK-Session aufgesetzt
     wird – verhindert „timer-only"-Sessions ohne Hintergrund beim allerersten Start.
  2. **Idempotenter Sensor-Start:** `AltimeterService.start()` / `startMotionDetection()`
     gegen Doppelstart absichern (Flag), damit kein zweiter Update-Stream entsteht.
  3. **Resync beim Handgelenk-Heben:** auf `isLuminanceReduced == false` bzw. `scenePhase
     == .active` `elapsedSeconds` und `totalAltitudeGain` einmal aus den Quellen neu setzen.
- *Fertig-wenn:* Mehrfaches Starten/Beenden hintereinander erzeugt keine doppelten Streams;
  nach jedem Aufwachen stimmen Zeit und Höhenmeter sofort.

---

## Reihenfolge & Abhängigkeiten

1. **P0-1** (monotone Zeit) und **P0-2** (Crash-Recovery) zuerst – sie beheben die zwei
   konkreten Symptome.
2. **P1-3** (Motion-Queue) und **P1-4** (Session-Delegates) – Stabilität; P1-4 nutzt P0-2.
3. **P2-5/6/7** – Konfiguration, Diagnose, Feinschliff. P2-6 hilft, falls nach P0/P1 doch
   noch etwas auftritt.
