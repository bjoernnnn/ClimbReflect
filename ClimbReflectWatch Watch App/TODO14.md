# ClimbReflect – TODO14: Der „Kein HealthKit"-Banner lügt + der echte Kill (Speicher)

Stand: getestet auf Branch `fix/wkbackgroundmodes` (`525f8ca`).

**Korrigierte Diagnose (mit Beweis):** Der rote Banner „Kein HealthKit – kein Hintergrund" ist
ein **Anzeigefehler**, kein echtes Berechtigungsproblem. Beweis: Das Foto der Live-Session zeigt
**69 BPM** – diese HF kann nur aus dem **aktiven** HealthKit-Builder kommen. Björn hatte HealthKit
korrekt aktiviert; es hat sich **nicht** deaktiviert.

**Die echte Kette:**
1. Session startet mit HealthKit → `healthKitActive = true`, HF wird erfasst, läuft im Hintergrund.
2. App wird **gekillt** (sehr wahrscheinlich Speicher-Jetsam – die Energie-Fixes sind auf diesem
   Branch nicht enthalten; HK-aktiv = HKLiveWorkoutBuilder + per-Sekunde-Re-Render = Speicher-
   wachstum).
3. watchOS bewahrt die laufende Session auf → Recovery `reattach()` (HF läuft weiter = 69 BPM).
4. **`reattach()` setzt `healthKitActive` NICHT auf `true`** → Flag bleibt `false` → falscher
   Banner. Zusätzlich feuert `didChangeTo .running` nach Reattach nicht (Status unverändert), also
   wird das Flag auch dort nicht korrigiert.

**Belegte Code-Stellen:**
- `WorkoutManager.swift`: `healthKitActive` wird true gesetzt in Zeile 249 (nach beginCollection)
  und 556 (didChangeTo .running), false in 252 (catch) und 482 (finishSession). **Nicht** in
  `reattach()`.
- `heartRate` wird nur in `didCollectDataOf` (Zeile 601) gesetzt → 69 BPM = HK liefert Daten.
- Log: zwei `end`-Events (`duration=3256s`/`3258s`) = Doppel-Ende (S4).

---

## P0 – Sofortfixes

### P0-1 — `reattach()` muss `healthKitActive` korrekt wiederherstellen (falscher Banner)
- *Kontext:* Nach Recovery bleibt `healthKitActive = false`, obwohl die Session läuft → falscher
  „Kein HealthKit"-Banner. Das ist der Auslöser für Björns „HealthKit deaktiviert sich".
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:*
  1. In `reattach(to ws:)` nach dem Setzen von `self.session`/`self.builder` ergänzen:
     ```swift
     // Recovered session läuft → HealthKit ist aktiv. Flag explizit setzen,
     // da didChangeTo(.running) bei unverändertem Status nicht feuert.
     self.healthKitActive = (ws.state == .running || ws.state == .paused)
     ```
  2. Defensiv auch bei `.running` im `didChangeTo` (schon vorhanden) belassen.
- *Fertig-wenn:* Nach einer Recovery zeigt die App **keinen** „Kein HealthKit"-Banner, solange
  die Session läuft und HF erfasst wird.

### P0-2 — Doppeltes Beenden verhindern (S4)
- *Kontext:* Bewusstes Beenden ruft `endWorkout()` auf → `ws.end()` → `didChangeTo .ended` setzt
  `sessionEndedUnexpectedly = true` → `.onChange`-Handler ruft `endWorkout()` ein zweites Mal.
  Ergebnis: zwei `end`-Log-Events (`3256s`/`3258s`), ggf. doppelt gesendetes DTO.
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`,
  `ClimbReflectWatch Watch App/Views/LiveSessionView.swift`
- *Aufgabe:*
  1. Flag `private var isFinishing = false` in `WorkoutManager`. Am Anfang von `endWorkout()`:
     `guard !isFinishing else { return nil }; isFinishing = true`. In `finishSession()` zurücksetzen.
  2. Im `didChangeTo .ended/.stopped`-Zweig: `sessionEndedUnexpectedly` **nicht** setzen, wenn
     `isFinishing == true` (bewusstes Ende).
- *Fertig-wenn:* Bewusstes Beenden erzeugt genau **ein** `end`-Event und genau ein gesendetes DTO.

### P0-3 — Den echten Kill beheben: Energie-/Speicher-Fixes auf diesen Branch bringen
- *Kontext:* Der eigentliche Grund, warum die App verschwindet, ist der Kill (Speicher-Jetsam).
  Die Fixes liegen auf `feature/energy-efficiency` (Commit `451b028`: TODO11 A1–A7, B1, B3), aber
  **nicht** auf dem getesteten Branch.
- *Aufgabe:* `feature/energy-efficiency` und `fix/wkbackgroundmodes` auf **einen** Branch
  zusammenführen, sodass alles zusammen ist:
  - WKBackgroundModes-Array (Info.plist) + entfernter `INFOPLIST_KEY`-String
  - Recovery (TODO9) + P0-1/P0-2 oben
  - Energie/Speicher: A1 (kein per-Sekunde-`elapsedSeconds`-Publish), A2 (Live-Werte in
    Blatt-Views), A3–A7, B1 (Accelerometer entfernt), B3 (Höhe nur beim Versuch)
- *Fertig-wenn:* Ein Branch enthält alles; Build läuft.

---

## P1 – Verifikation & Komfort

### P1-1 — Jetsam-Test (echte Ursache bestätigen)
- *Aufgabe:* 30–60-Min-Session auf der echten Uhr **mit aktivem HealthKit**. Danach in
  Einstellungen › Datenschutz › Analyse prüfen, ob ein **neuer** `JetsamEvent-…ClimbReflect`
  entstand. Falls Profiler verfügbar: „Persistent Bytes" muss flach bleiben.
- *Fertig-wenn:* Lange Session ohne Jetsam, ohne Verschwinden, ohne falschen Banner.

### P1-2 — HealthKit-Berechtigung robuster machen (Björns „muss mehrmals aktivieren")
- *Kontext:* Bei Entwickler-Builds setzt iOS HealthKit-Berechtigungen teils zurück (Neuinstall).
  Das ist teils erwartbar in der Entwicklung. Damit es im Alltag nicht stört:
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`,
  Onboarding/Sport-Auswahl-View
- *Aufgabe:*
  1. `requestAuthorization()` einmal beim ersten Start klar im Onboarding (mit kurzer Erklärung,
     warum HealthKit nötig ist: Hintergrundaufzeichnung).
  2. Vor jedem Session-Start `store.authorizationStatus(for: HKObjectType.workoutType())` prüfen.
     Bei `.sharingDenied` einen klaren Hinweis zeigen (auf der Watch: „HealthKit in den
     Einstellungen erlauben"), statt still im Timer-only-Modus zu starten.
  3. **Wichtig:** Den Banner/das Gating an den **echten** Status koppeln (Workout-Session aktiv),
     nicht nur an ein Flag, das bei Recovery falsch sein kann (siehe P0-1).
- *Fertig-wenn:* Ist HealthKit erteilt, läuft alles ohne Banner; ist es verweigert, bekommt der
  Nutzer einen klaren, umsetzbaren Hinweis statt einer stillen Timer-only-Session.

---

## Reihenfolge
1. **P0-1** (falscher Banner) – schnell, nimmt die Verwirrung raus.
2. **P0-2** (Doppel-Ende) – schnell.
3. **P0-3** (Energie/Speicher zusammenführen) – behebt den eigentlichen Kill.
4. **P1-1** Test → bestätigen, dass die App nicht mehr verschwindet.
5. **P1-2** HealthKit-Onboarding/Status – Komfort, verhindert echte „vergessen"-Fälle.

## Ehrliche Einordnung
Der „Kein HealthKit"-Banner war ein **falsches Signal** (App-Bug, nicht HealthKit). Das hat die
Fehlersuche fehlgeleitet. Der **eigentliche** Fehler ist, dass die App gekillt wird – mit hoher
Wahrscheinlichkeit der Speicher-Jetsam, dessen Fixes auf diesem Branch fehlen. P0-1 macht die
Anzeige ehrlich, P0-3 behebt die Ursache. Bitte nach P0 + Test das Diagnose-Log / einen etwaigen
neuen JetsamEvent schicken – dann ist es endgültig bestätigt.
