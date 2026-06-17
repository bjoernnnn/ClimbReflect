# ClimbReflect – TODO9: Watch-Session überlebt App-Beendigung

Stand: Review Branch `dev` (`af69cac`). TODO8 ist umgesetzt.

**Problem (reproduziert):** Während eines Trainings verschwindet die Watch-App nach einiger
Zeit aus dem Vordergrund; beim erneuten Öffnen steht man wieder bei der Sportart-Auswahl –
die laufende Session ist weg. Ursache (im Code verifiziert): `ContentView` schaltet allein
über `workoutManager.isRunning`, das bei einem frischen Prozessstart `false` ist, und es gibt
**keine** Wiederaufnahme einer noch laufenden Workout-Session. Wird die App im Hintergrund
beendet, kommt sie als „frisch" zurück.

**Zwei Schichten:**
- *Schicht 2 (sicher behebbar, Hauptfix):* Beim Start eine noch aktive Workout-Session über
  `HKHealthStore.recoverActiveWorkoutSession()` reaktivieren und zurück in `LiveSessionView`
  routen. watchOS bewahrt eine aktive Session über App-Beendigung hinweg auf – genau dafür.
- *Schicht 1 (Ursache fürs Beenden):* Eine Session ohne wirksam aktive HK-Workout-Session
  bekommt keine Hintergrundlaufzeit. `startWorkout` verschluckt HK-Fehler aktuell still
  (`catch { print }`). Das muss sichtbar werden, sonst „läuft" eine Session, die gar nicht
  geschützt ist.

Format wie gewohnt: *Kontext / Dateien / Aufgabe / Fertig-wenn*. Reihenfolge P0 → P1 → P2.
Eine Aufgabe = ein Commit.

---

## P0 – Laufende Session beim App-Start wiederaufnehmen

### P0-1 — `WatchAttempt` aus `AscentDTO` rekonstruierbar machen (Voraussetzung)
- *Kontext:* Für die Recovery müssen die im Snapshot (P0-2) als `[AscentDTO]` gespeicherten
  Versuche wieder zu `WatchAttempt` werden, damit `LiveSessionView` sie anzeigt. Aktuell gibt
  es nur `WatchAttempt.toDTO()`, keinen Rückweg.
- *Dateien:* `ClimbReflectWatch Watch App/Models/WatchAttempt.swift` (Name ggf. anpassen),
  `ClimbReflectWatch Watch App/Models/WatchSessionDTO.swift`
- *Aufgabe:* Einen Initializer `init(fromDTO dto: AscentDTO, sessionType: WatchSessionType)`
  ergänzen, der **exakt** die Felder von `toDTO()` umkehrt (gradeSystem, grade, result, style,
  attempts/Versuche, altitudeGain, projectInfo aus `projectID`+`projectName`, sessionType).
  Felder, die das DTO nicht trägt (z. B. `heartRateAtBanking`), auf `nil` setzen.
- *Fertig-wenn:* `WatchAttempt(fromDTO: a.toDTO(), sessionType: t)` ergibt für jedes Feld, das
  das DTO transportiert, denselben Wert wie das Original.

### P0-2 — Aktive Workout-Session beim Start wiederaufnehmen
- *Kontext:* Der eigentliche Fix. Beim Launch prüfen, ob noch eine Session läuft; wenn ja,
  Delegates/Builder neu verbinden, Live-State aus dem Snapshot herstellen und `isRunning = true`
  → `ContentView` zeigt automatisch `LiveSessionView`.
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`,
  `ClimbReflectWatch Watch App/ClimbReflectWatchApp.swift`
- *Aufgabe:*
  1. In `WorkoutManager` die bestehende `recoverPendingSessionIfNeeded()` durch eine
     kombinierte Methode ersetzen/erweitern:
     ```swift
     /// Beim App-Start aufrufen (nach requestAuthorization).
     func recoverIfNeeded() async {
         // 1) Noch aktive Workout-Session? → live wiederaufnehmen
         if HKHealthStore.isHealthDataAvailable(),
            let recovered = try? await store.recoverActiveWorkoutSession() {
             await reattach(to: recovered)
             return
         }
         // 2) Keine aktive Session mehr → geloggte Versuche aus Snapshot retten
         recoverPendingSessionIfNeeded()   // bestehende Logik: DTO senden + Snapshot löschen
     }

     private func reattach(to ws: HKWorkoutSession) async {
         let wb = ws.associatedWorkoutBuilder()
         wb.dataSource = HKLiveWorkoutDataSource(healthStore: store,
                                                 workoutConfiguration: ws.workoutConfiguration)
         ws.delegate = self
         wb.delegate = self
         self.session = ws
         self.builder = wb

         // Live-State aus dem Snapshot herstellen (Versuche, Start, Pause, Projekt, Typ)
         if let p = PendingSessionStore.load() {
             self.sessionType       = WatchSessionType(rawValue: p.sessionTypeRaw) ?? .boulder
             self.workoutStartDate  = p.startDate
             self.accumulatedPaused = p.accumulatedPaused
             if let id = p.projectID, let name = p.projectName {
                 self.selectedProject = ProjectInfo(id: id, name: name)
             }
             self.attempts = p.ascents.map { WatchAttempt(fromDTO: $0, sessionType: self.sessionType) }
         } else {
             self.workoutStartDate = wb.startDate   // Fallback
         }

         self.isPaused      = (ws.state == .paused)
         self.isRunning     = true
         self.elapsedSeconds = Int(currentElapsed())

         // Sensoren/Detektor wieder hochfahren (Altimeter-totalGain startet bei 0 – ok)
         await altimeter.start()
         if !isTraining { detector.onSuggestion = { [weak self] in
             Task { @MainActor in self?.suggestAttempt = true; self?.pendingClassifications += 1 } }
             if !sessionType.usesBarometer { detector.startMotionDetection() }
         }
         if !isPaused { startTimer() }
         DiagnosticLog.shared.log("recoveredActiveSession state=\(ws.state.rawValue) ascents=\(attempts.count)")
     }
     ```
  2. Wichtig: `reattach` darf den Snapshot **nicht** löschen (er wird erst in `finishSession()`
     gelöscht) und **kein** DTO senden – die Session läuft ja weiter.
  3. In `ClimbReflectWatchApp.swift` den Aufruf umstellen – Recovery **nach** der Auth, und
     das alte `recoverPendingSessionIfNeeded()` im `.onAppear` entfernen:
     ```swift
     .task {
         await workoutManager.requestAuthorization()
         await workoutManager.recoverIfNeeded()
     }
     ```
  4. Hinweis Ø-HF: Da `reattach` denselben Builder weiterverwendet, liefert
     `wb.statistics(for: .heartRate)` beim Beenden weiterhin den Schnitt über die **ganze**
     Session – nichts weiter nötig.
- *Fertig-wenn:* Training starten, ein paar Versuche banken, Watch-App hart beenden
  (Force-Quit) bzw. lange genug aufs Zifferblatt zurückfallen lassen, dann App erneut öffnen →
  man landet **direkt wieder in der laufenden Session** mit allen gebankten Versuchen, nicht
  bei der Sportart-Auswahl. Beenden + Fragebogen funktionieren normal.

---

## P1 – Ursache sichtbar machen: keine stille Timer-Session

### P1-3 — HealthKit-Status erfassen und in der Live-Ansicht anzeigen
- *Kontext:* `startWorkout` fängt HK-Fehler ab und läuft im reinen Timer-Modus weiter – ohne
  aktive Workout-Session gibt es keine Hintergrundlaufzeit, und genau dann wird die App nach
  einer Weile beendet. Aktuell merkt der Nutzer davon nichts.
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`,
  `ClimbReflectWatch Watch App/Views/LiveSessionView.swift`
- *Aufgabe:*
  1. Neues `@Published var healthKitActive = false`. In `startWorkout` im `do`-Zweig **nach**
     erfolgreichem `try await wb.beginCollection(at:)` → `healthKitActive = true` und
     `DiagnosticLog.shared.log("beginCollection ok")`. Im `catch` → `healthKitActive = false`
     und `DiagnosticLog.shared.log("HK setup failed: \(error.localizedDescription)")`.
  2. Im `didChangeTo`-Delegate bei `.running` ebenfalls `healthKitActive = true` setzen
     (bestätigt, dass die Session wirklich läuft).
  3. Vor dem Start grob prüfen, ob die Schreib-Berechtigung verweigert ist:
     `if store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingDenied { … log … }`.
  4. In `LiveSessionView` ein dezentes Warnbanner zeigen, solange `!healthKitActive`, z. B.
     „Ohne HealthKit – Aufzeichnung übersteht keinen Hintergrund". So ist sofort sichtbar, ob
     der Schutz greift.
- *Fertig-wenn:* Bei erteilter HK-Berechtigung erscheint kein Banner und das Diagnose-Log
  zeigt `beginCollection ok` + `didChangeTo 2`. Bei verweigerter/fehlender Berechtigung
  erscheint das Banner und der Grund steht im Diagnose-Log.

### P1-4 — Unerwartetes Session-Ende in Recovery überführen
- *Kontext:* `sessionEndedUnexpectedly` (TODO8 P1-4) leitet aktuell in die Finalisierung.
  Zusammen mit P0 soll ein unerwartetes Ende kein Datenverlust sein.
- *Dateien:* `ClimbReflectWatch Watch App/Views/LiveSessionView.swift`
- *Aufgabe:* Sicherstellen, dass beim Auslösen von `sessionEndedUnexpectedly` die bereits
  gebankten Versuche über den normalen End-/Fragebogen-Pfad gespeichert werden (der Snapshot
  aus P0-2 ist ohnehin vorhanden). Kein zusätzlicher Sende-Pfad, der dupliziert.
- *Fertig-wenn:* Wird die Session vom System beendet, gehen die geloggten Versuche in die
  Speicherung statt verloren.

---

## P2 – Hintergrundlaufzeit absichern

### P2-5 — `WKBackgroundModes` als Array sicherstellen und im Build verifizieren
- *Kontext:* `WKBackgroundModes` kommt aktuell nur aus dem Build-Setting
  `INFOPLIST_KEY_WKBackgroundModes = "workout-processing"`. Dieser Schlüssel wird von Xcode
  **nicht zuverlässig** als Array ins generierte Info.plist übernommen. Ohne gültiges
  `WKBackgroundModes`-Array darf die Workout-Session im Hintergrund nicht weiterlaufen.
- *Dateien:* `ClimbReflect.xcodeproj/project.pbxproj`,
  neu: `ClimbReflectWatch-Watch-App-Info.plist`
- *Aufgabe:*
  1. Explizite Watch-Info.plist (wieder) anlegen mit dem Array:
     ```xml
     <key>WKBackgroundModes</key>
     <array><string>workout-processing</string></array>
     ```
  2. Für das Watch-Target in **Debug und Release** `INFOPLIST_FILE =
     "ClimbReflectWatch-Watch-App-Info.plist"` setzen; `GENERATE_INFOPLIST_FILE = YES` darf
     bleiben (Xcode merged den Rest korrekt – so lief es, als die App im Hintergrund überlebte).
  3. **Verifizieren:** Nach dem Build die gebaute `…app/Info.plist` öffnen (Finder →
     Paketinhalt zeigen) und prüfen, dass `WKBackgroundModes` ein **Array** mit
     `workout-processing` ist und `WKApplication = true` vorhanden ist.
- *Fertig-wenn:* Im gebauten Produkt steht `WKBackgroundModes` als Array; bei abgesenktem
  Handgelenk läuft die Session weiter (Diagnose-Log zeigt kein vorzeitiges `didChangeTo 3/6`).

---

## Reihenfolge, Abhängigkeiten & Test

1. **P0-1** (Reverse-Init) zuerst – Voraussetzung für **P0-2** (Recovery, der Hauptfix).
2. **P1-3** (HK-Status sichtbar) – deckt die eigentliche Ursache auf und ist die beste
   Live-Diagnose; **P1-4** hängt an P0-2.
3. **P2-5** – Hintergrundlaufzeit absichern.

**Gesamttest (entscheidend):** Training starten → mehrere Versuche banken → Watch-App per
Force-Quit beenden (Seitentaste gedrückt halten o. ä.) → App erneut öffnen.
- Erwartung mit P0: Du bist sofort wieder in der laufenden Session inkl. aller Versuche.
- Mit P1/P2: Idealerweise tritt das Beenden gar nicht mehr auf, weil die Session im
  Hintergrund korrekt aktiv bleibt. Falls doch, fängt P0 es sauber auf.

**Diagnose-Hinweis:** Nach einem Vorfall im Diagnose-Log prüfen: Erscheint `beginCollection ok`
und `didChangeTo 2` (running)? Steht am Ende `didChangeTo 3/6`? Daraus lässt sich ablesen, ob
Schicht 1 (HK/Hintergrund) noch nachgebessert werden muss.
