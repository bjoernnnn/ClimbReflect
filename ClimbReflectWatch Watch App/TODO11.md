# ClimbReflect – TODO11: Energie-/Speicher-Refactoring der Watch-App

Stand: Branch `dev` (`af69cac`).

**Warum:** Die Watch-App wird im Vordergrund wegen Speicherüberschreitung gejetsamt (300 MB,
per-process-limit, ~12 MB/Min Wachstum, 8 % Dauer-CPU über 25 Min). Eine einzelne bewiesene
Ursache haben wir nicht – also reduzieren wir **breit** alle plausiblen Quellen für Speicher-
und Energieverbrauch (Render-Churn, Sensor-Last, Task-/IO-Churn, Wakeups). Ziel: stabile
Speicherkurve über eine lange Session **und** spürbar weniger Energieverbrauch, ohne dass sich
die App für den Nutzer schlechter anfühlt.

**Vorgehen:** Eine Aufgabe = ein Commit. Wenn möglich vor/nach mit dem Allocations-Profiler auf
der echten Uhr gegenmessen (Persistent Bytes sollte flacher werden). **Teil A** ist freigegeben
und kann direkt umgesetzt werden. **Teil B** sind größere, übergreifende Änderungen – die bitte
**erst nach Björns Freigabe** umsetzen (siehe Markierung).

---

## Teil A – Sofort umsetzbar (UX-neutral, keine Rücksprache nötig)

### A1 — Sekündliches Re-Rendering des ganzen Screens beenden
- *Kontext:* Der Timer setzt jede Sekunde `elapsedSeconds` (`@Published`) → der gesamte
  `LiveSessionView`-Baum wird jede Sekunde neu ausgewertet. Die Uhr läuft seit TODO8 ohnehin
  über `TimelineView`.
- *Dateien:* `Services/WorkoutManager.swift`, `Views/LiveSessionView.swift`
- *Aufgabe:* Im Timer-Tick `self.elapsedSeconds = …` entfernen; `broadcastLiveStatus()` nutzt
  `Int(currentElapsed())` direkt. Uhranzeige ausschließlich über das bestehende
  `TimelineView(.periodic(from: start, by: 1))` + `currentElapsed()`.
- *Komfort:* Uhr tickt unverändert jede Sekunde (TimelineView, auch im Always-On).
- *Fertig-wenn:* Sekundenanzeige flüssig, aber der Screen rendert nicht mehr 1×/s komplett neu.

### A2 — Live-Werte in kleine Blatt-Views isolieren
- *Kontext:* Lesen die großen Container `heartRate`/`totalAltitudeGain` direkt, rendert bei jeder
  Sensor-Änderung der ganze Baum neu.
- *Dateien:* `Views/LiveSessionView.swift`
- *Aufgabe:* Je eine Mini-Subview für HF, Höhe, Zeit, die nur ihren Wert liest. Container
  (TabView, Metrik-Karte, Versuchs-`ScrollView`, Projektliste) lesen diese Werte **nicht** mehr
  direkt.
- *Komfort:* Identische Darstellung; Werte aktualisieren sich weiterhin live, nur lokal.
- *Fertig-wenn:* Eine HF-/Höhen-Änderung rendert nur die jeweilige Zahl neu.

### A3 — Höhen-Publish drosseln, HK-Sample-Tasks bündeln
- *Dateien:* `Services/WorkoutManager.swift`
- *Aufgabe:* `totalAltitudeGain` nur publizieren, wenn sich der gerundete Meterwert ändert (max.
  alle 3–5 s). In `didCollectDataOf` **ein** `Task { @MainActor }` pro Callback statt eins pro
  Typ.
- *Komfort:* Höhe ändert sich langsam – nicht wahrnehmbar; HF bleibt live.
- *Fertig-wenn:* Deutlich weniger Publishes/Tasks pro Sekunde.

### A4 — Timer-Wakeups reduzieren
- *Dateien:* `Services/WorkoutManager.swift`
- *Aufgabe:* Da die Uhr über `TimelineView` läuft, muss der Timer nur noch Detektor-HF,
  Rope-Höhe und den 5-s-Broadcast bedienen. Intervall auf 2 s anheben (Detektor-HF/Altitude
  alle 2 s genügt; Broadcast entsprechend anpassen).
- *Komfort:* Keine sichtbare Änderung.
- *Fertig-wenn:* Halb so viele Timer-Wakeups, Funktion unverändert.

### A5 — Live-Status-Broadcast sparsamer
- *Dateien:* `Services/WorkoutManager.swift`
- *Aufgabe:* `updateApplicationContext` nur senden, wenn sich etwas Relevantes geändert hat
  (oder Intervall 5 s → 10 s). Pausen/Start/Ende weiterhin sofort.
- *Komfort:* iPhone-Live-Banner bleibt aktuell genug.
- *Fertig-wenn:* Weniger WC-Transfers, Banner weiterhin korrekt.

### A6 — Diagnose-Log: Disk-Schreibzugriffe entkoppeln
- *Kontext:* `DiagnosticLog.persist()` schreibt bei **jedem** Event die komplette 200-Einträge-
  JSON atomar auf Disk.
- *Dateien:* `Services/DiagnosticLog.swift`
- *Aufgabe:* Schreiben debouncen (z. B. höchstens alle 10 s und beim App-Hintergrund/Beenden)
  statt bei jedem `log()`. In-Memory-Liste bleibt sofort aktuell.
- *Komfort:* Diagnose-Ansicht unverändert; nur weniger IO.
- *Fertig-wenn:* Log vollständig, aber deutlich weniger Schreibvorgänge.

### A7 — Sensoren deterministisch beenden + Retain sauber halten
- *Dateien:* `Services/AltimeterService.swift`, `Services/AttemptDetector.swift`,
  `Services/WorkoutManager.swift`
- *Aufgabe:* Sicherstellen, dass Altimeter, Accelerometer und Timer bei `endWorkout`,
  `discardWorkout` **und** unerwartetem Ende zuverlässig gestoppt werden. In
  `AltimeterService.start()` die starke `[self]`-Capture im Update-Handler vermeiden (Update nur
  weiterreichen, ohne den Actor stark zu halten).
- *Komfort:* Keine sichtbare Änderung.
- *Fertig-wenn:* Nach Sessionende laufen keine Sensor-Callbacks mehr; kein Handler hält Objekte
  unnötig.

---

## Teil B – Größere Änderungen: nach Björns Freigabe umsetzen

Alle Punkte sind freigegeben und sollen umgesetzt werden:

### B1 — Boulder-Auto-Erkennung (Accelerometer) entfernen
- *Kontext:* Das Accelerometer läuft die ganze Boulder-Session mit 5 Hz – der größte
  kontinuierliche Sensorverbraucher. Das Feature ist eine Heuristik (Versuchs-*Vorschlag*);
  manuelles Banken funktioniert unabhängig davon.
- *Datei:* `Services/AttemptDetector.swift`, `Services/WorkoutManager.swift`,
  `Views/LiveSessionView.swift`
- *Aufgabe:*
  1. `AttemptDetector` komplett entfernen (oder als Datei behalten, aber die Methoden
     `startMotionDetection()`, `stopMotionDetection()` als No-Ops, falls irgendwo noch
     aufgerufen).
  2. Aus `WorkoutManager.startWorkout`: den `detector.startMotionDetection()`-Aufruf + die
     Closure `detector.onSuggestion` entfernen.
  3. Aus `WorkoutManager.endWorkout`: `detector.stopMotionDetection()` entfernen.
  4. Aus `LiveSessionView`: die Vorschlags-UI (`suggestAttempt`, `suggestVersuch`-Banner,
     `dismissSuggestion`-Button) entfernen.
  5. Der Action Button (`handleActionButton`) bleibt und triggert manuelles Banken – das läuft
     über `quickBank(result:)` und braucht keine Erkennung.
- *Komfort:* Manuelles Banken über Action Button ist unverändert schnell (Versuch starten →
  Ergebnis, Taste drücken). Kein Auto-Vorschlag mehr, aber das war eine Heuristik – manuell ist
  präzise.
- *Fertig-wenn:* Accelerometer läuft nicht mehr. Action Button bankt weiterhin zuverlässig.
  `suggestAttempt` wird nie mehr `true`. Die gesamte `AttemptDetector`-Klasse ist aus dem
  Workflow raus.

### B2 — Always-On-Display wie vorgesehen, nicht ändern
- *Rationale:* Das aktuelle Verhalten (Display schaltet aus bei Handgelenk-Senken, wird wieder
  aktiv beim Drehen) ist das beabsichtigte. Behalten wie ist.

### B3 — Höhen-Tracking nur während eines Versuchs
- *Kontext:* Der Höhenmesser läuft aktuell die ganze Session für `totalGain` +
  Seil-Auto-Erkennung. Neue Anforderung: nur während eines aktiven Versuchs messen. Das spart
  Sensor-Last und ist aussagekräftiger (nur echte Kletterarbeit wird gemessen).
- *Dateien:* `Services/AltimeterService.swift`, `Services/WorkoutManager.swift`,
  `Views/LiveSessionView.swift`
- *Aufgabe:*
  1. `AltimeterService` bekommt neue States/Logik:
     - `isTrackingAscent: Bool` (nur beim Versuch `true`)
     - `start()` → lädt die Kalibrierung, läuft aber nur **passiv** (Barometer wird gelesen,
       aber nicht in `totalGain` summiert)
     - `startAscentTracking()` → setzt `isTrackingAscent = true` und beginnt Höhensammlung
     - `stopAscentTracking()` → gibt die Netto-Höhe zurück, setzt `isTrackingAscent = false`
     - `totalGain` wächst **nur**, wenn `isTrackingAscent == true`
  2. `updateAltitude(_ rel:)` im Detektor (Seil-Auto-Erkennung): darf weiterhin laufen (nur
     bei `.rope`-Sessions relevant), benötigt aber **nur** die letzte und vorherige Höhe, nicht
     `totalGain`.
  3. In `LiveSessionView`: `totalAltitudeGain` zeigt die **Netto-Höhe des aktuellen Versuchs**
     (nicht Gesamt). Wenn kein Versuch aktiv, bleibt `0` oder wird nicht angezeigt.
- *Komfort:* Live-Höhenanzeige während eines Versuchs bleibt; Gesamthöhe der Session wird nicht
  mehr gezählt (das war ohnehin eine Hilfsgröße; wichtig ist Netto pro Versuch).
- *Fertig-wenn:* Außerhalb eines aktiven Versuchs bleibt `totalGain` bei `0`. Beim
  Versuchsstart (`startAscentTracking`) wird die Basis gemessen; beim Beenden Netto berechnet.
  Die angezeigt Höhe ist die des aktuellen Versuchs.

### B4 — `WorkoutManager` aufteilen: nicht machen
- *Rationale:* A1/A2 sollten ausreichen; kein Umbau nötig.

### B5 — Recovery-Netz: Session nach App-Beendigung wiederherstellen
- *Kontext:* Falls trotz alledem die App mal gekillt wird, soll der Nutzer beim Öffnen nicht in
  der Sportart-Auswahl landen, sondern direkt in seiner Session – mit allen gebankten Versuchen.
  (Details aus TODO9 P0.)
- *Dateien:* `Services/WorkoutManager.swift`, `Services/PendingSessionStore.swift`,
  `Models/WatchAttempt.swift`, `ClimbReflectWatchApp.swift`
- *Aufgabe:*
  1. **Reverse-Init für `WatchAttempt`:** `init(fromDTO dto: AscentDTO, sessionType: WatchSessionType)`
     anlegen, der die DTO-Felder zurück zu `WatchAttempt` macht.
  2. **Recovery-Logik in `WorkoutManager`:** neue Methode `recoverIfNeeded() async`:
     ```swift
     func recoverIfNeeded() async {
         // 1) Noch aktive HK-Workout-Session?
         if HKHealthStore.isHealthDataAvailable(),
            let recovered = try? await store.recoverActiveWorkoutSession() {
             await reattach(to: recovered)
             return
         }
         // 2) Keine aktive Session → geloggte Versuche retten
         recoverPendingSessionIfNeeded()
     }

     private func reattach(to ws: HKWorkoutSession) async {
         let wb = ws.associatedWorkoutBuilder()
         wb.dataSource = HKLiveWorkoutDataSource(healthStore: store,
                                                 workoutConfiguration: ws.workoutConfiguration)
         ws.delegate = self
         wb.delegate = self
         self.session = ws
         self.builder = wb

         // Live-State aus Snapshot herstellen
         if let p = PendingSessionStore.load() {
             self.sessionType = WatchSessionType(rawValue: p.sessionTypeRaw) ?? .boulder
             self.workoutStartDate = p.startDate
             self.accumulatedPaused = p.accumulatedPaused
             if let id = p.projectID, let name = p.projectName {
                 self.selectedProject = ProjectInfo(id: id, name: name)
             }
             self.attempts = p.ascents.map { WatchAttempt(fromDTO: $0, sessionType: self.sessionType) }
         }

         self.isPaused = (ws.state == .paused)
         self.isRunning = true
         self.elapsedSeconds = Int(currentElapsed())
         
         await altimeter.start()
         if !isTraining { /* keine Erkennung mehr */ }
         if !isPaused { startTimer() }
         DiagnosticLog.shared.log("recoveredActiveSession ascents=\(attempts.count)")
     }
     ```
  3. **In `ClimbReflectWatchApp`:** Nach Auth die Recovery aufrufen:
     ```swift
     .task {
         await workoutManager.requestAuthorization()
         await workoutManager.recoverIfNeeded()
     }
     ```
  4. **Snapshot speichern** bei jedem Versuch-Update (`bankAttempt`, `quickBank`, `removeAttempt`,
     `startWorkout`).
- *Komfort:* Der Nutzer kommt nach einem Kill oder Beenden nahtlos zurück in seine Session mit
  allen Versuchen. Kein Datenverlust.
- *Fertig-wenn:* App während Session hart beenden → neu öffnen → direkt in der laufenden
  Session mit allen Versuchen, nicht in der Sportart-Auswahl.

---

## Abnahme

- **Speicher:** 30-Min-Session auf der echten Uhr, Allocations „Persistent Bytes" bleibt flach
  (Ziel grob < 80–100 MB), kein Jetsam.
- **Energie:** Über eine vergleichbare Session messbar weniger Akkuverbrauch (weniger Wakeups,
  weniger Sensor-Last, weniger Render).
- **Komfort unverändert:** Uhr tickt flüssig, HF live, Always-On wie gewählt (an/aus je nach
  Handgelenk), Banken über Action Button normal, Beenden/Fragebogen normal.
- **Funktionalität:** Boulder-Auto-Vorschlag ist weg (Action Button bleibt), Höhen-Tracking nur
  beim Versuch, Recovery beim Start funktioniert.

## Reihenfolge
1. **Teil A komplett** (A1–A7) – risikoarm, großer Effekt erwartet.
2. **Teil B parallel** (B1, B3, B5) – alle freigegeben, können parallel mit A laufen.
3. Danach **profilen**: reicht das? Wenn ja, fertig.
4. Falls nicht: gezielt die vom Profiling gezeigte Quelle nachziehen (falls eine andere als B1/B3/B5).
