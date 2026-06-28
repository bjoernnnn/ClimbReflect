# TODO – Action Button = Hardware-Zwilling der „Versuche"-Badge

**Repo-Stand:** `dev` @ `e3d0faf` · **Format:** Eine Aufgabe = ein Commit · *Kontext / Dateien / Aufgabe / Fertig-wenn* · Deutsch.
**Ziel (deine Vorgabe):** Action Button (Watch Ultra) verhält sich exakt wie die „Versuche"-Badge (S24):
Druck startet/stoppt den Ascent-Timer und bankt den Versuch — **ohne Bildschirm-Touch** (chalk-freundlich).

**API-Grundlage (verifiziert):** Apple `App Intents` → Action Button via `StartWorkoutIntent`-konformem Intent
mit `@Parameter var workoutStyle: WorkoutStyle`, `workout-processing` in `WKBackgroundModes`, und
`.result(actionButtonIntent:)`-**Chaining**. Chaining funktioniert nur bei **aktiver Workout-Session** und wenn
ClimbReflect in den Watch-Settings als Action-Button-Workout-App gewählt ist.

> **Warum der jetzige Intent nutzlos ist:** `StartSessionIntent` ist ein simpler `AppIntent` mit
> `openAppWhenRun = true` ohne `workoutStyle`-Parameter → Settings bietet nur „App öffnen", kein Chaining möglich.

---

## Architektur

```
Action-Button-Druck 1 → StartClimbWorkoutIntent  (StartWorkoutIntent-konform)
                         → startet Session
                         → return .result(actionButtonIntent: ToggleAttemptIntent())
Action-Button-Druck 2 → ToggleAttemptIntent  → startet Versuch-Timer (Badge gold)
                         → return .result(actionButtonIntent: ToggleAttemptIntent())
Action-Button-Druck 3 → ToggleAttemptIntent  → bankt Ascent (Timer stop)
                         → return .result(actionButtonIntent: ToggleAttemptIntent())
…
```

`ToggleAttemptIntent` ist **zustandsbasiert**: liest den aktuellen Versuch-Status aus `WorkoutManager`
(dieselbe Quelle wie die Badge) und toggelt. **Eine** gemeinsame Wahrheit — Badge und Button rufen denselben Code.

---

### AB-1 — Versuch-Toggle aus der View in `WorkoutManager` zentralisieren
- *Kontext:* Aktuell lebt die Toggle-Logik (Tipp → gold + Timer; erneut → bank, S24) in der „Versuche"-Badge
  in `LiveSessionView`. Damit Button **und** Badge denselben Code nutzen, muss die Logik in den `WorkoutManager`.
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`, `Views/LiveSessionView.swift`.
- *Aufgabe:* Methode `func toggleAttempt()` im `WorkoutManager` anlegen, die exakt das tut, was der Badge-Tap
  heute tut (Versuch starten ↔ Ascent banken inkl. aller bestehenden Snapshots: maxHR, hrSum, selectedShoe,
  selectedProject). Die Badge ruft künftig nur noch `manager.toggleAttempt()`. **Kein** Verhaltenswechsel sichtbar.
- *Fertig-wenn:* Badge-Verhalten identisch wie vorher; gesamte Toggle-Logik in `WorkoutManager.toggleAttempt()`;
  on-device verifiziert (Badge-Tap funktioniert unverändert).

### AB-2 — `workout-processing` in `WKBackgroundModes` deklarieren
- *Kontext:* Voraussetzung dafür, dass die Settings-App eine echte Workout-Aktion (statt nur „App öffnen") anbietet
  und Chaining erlaubt.
- *Dateien:* Watch-App-Info.plist bzw. `INFOPLIST_KEY_*` Build-Settings (siehe S12 — Info.plist sauber halten).
- *Aufgabe:* `WKBackgroundModes` um `workout-processing` ergänzen (falls nicht über bestehende HealthKit-Workout-
  Konfiguration schon vorhanden — vorher prüfen, nicht doppeln).
- *Fertig-wenn:* `workout-processing` deklariert; bestehende Session-Aufnahme + Recovery unverändert funktionsfähig.

### AB-3 — `StartClimbWorkoutIntent` (StartWorkoutIntent-konform) mit `workoutStyle`
- *Kontext:* Der Start-Intent muss `StartWorkoutIntent`-konform sein und `workoutStyle: @Parameter` tragen,
  sonst kein Chaining. Ersetzt die Action-Button-Rolle des alten `StartSessionIntent`.
- *Dateien:* `Intents/StartSessionIntent.swift` (erweitern/umbenennen), `WorkoutManager.swift`.
- *Aufgabe:* Intent anlegen, der `StartWorkoutIntent` adoptiert, `@Parameter var workoutStyle: WorkoutStyle` trägt,
  beim `perform()` die Session über `WorkoutManager` startet (Sportart aus `workoutStyle` ableiten) und
  `return .result(actionButtonIntent: ToggleAttemptIntent())` zurückgibt. Den alten `StartSessionIntent`
  (Shortcut-/Siri-Pfad) **behalten** für Sprachbefehle — nur die Action-Button-Rolle wandert auf den neuen Intent.
- *Fertig-wenn:* Settings-App zeigt ClimbReflect als Workout-Action für den Action Button; Druck 1 startet Session.

### AB-4 — `ToggleAttemptIntent` (re-chainend) auf gemeinsamer State-Quelle
- *Kontext:* Der wiederholbare Intent, der die Badge-Aktion auslöst. Re-chained sich selbst, damit jeder weitere
  Druck wieder toggelt.
- *Dateien:* neuer `Intents/ToggleAttemptIntent.swift`, `WorkoutManager.swift`.
- *Aufgabe:* Intent (kein `openAppWhenRun` nötig), der `@MainActor` `WorkoutManager.shared.toggleAttempt()` aufruft
  und `return .result(actionButtonIntent: ToggleAttemptIntent())` zurückgibt. **Darf den Streaming-`HKAnchoredObjectQuery`
  (S16) nicht anfassen** — nur In-Memory-Versuch-State toggeln. Wenn keine aktive Session → no-op + Re-Chain auf
  `StartClimbWorkoutIntent` (sauberer Wiedereinstieg).
- *Fertig-wenn:* Druck 2 startet Versuch (Badge gold), Druck 3 bankt Ascent, alternierend; Memory bleibt stabil
  (~22 MB, S16 unberührt); on-device auf Apple Watch Ultra mit echtem Action Button verifiziert.

### AB-5 — Recovery-Konsistenz: Chain nach Jetsam/Reattach wiederherstellen
- *Kontext:* Nach Jetsam-Kill + Recovery (S21/S16) läuft die Session weiter — der Action-Button-Chain muss wieder
  auf `ToggleAttemptIntent` zeigen, sonst würde Druck eine neue Session starten.
- *Dateien:* `WorkoutManager.swift` (`reattach()`), `PendingSessionStore.swift`.
- *Aufgabe:* Bei erfolgreichem `reattach()` den Action-Button-Chain erneut auf `ToggleAttemptIntent` setzen
  (Donation/Override wie in der Referenz-Implementierung). Sicherstellen, dass alle Give-up-/Finalize-Pfade
  (`clearLiveStatus()`, `finalizeUnrecoverableSession()`) den Chain wieder auf den Start-Intent zurücksetzen.
- *Fertig-wenn:* Nach simuliertem Kill + Recovery toggelt der Action Button weiter Versuche (startet keine neue
  Session); nach Session-Ende startet er wieder sauber eine neue.

### AB-6 — Doku + CLAUDE.md
- *Dateien:* `CLAUDE.md`, `ClimbReflect-README.md`.
- *Aufgabe:* `S23` aktualisieren/erweitern: „Action Button ist Hardware-Zwilling der Versuche-Badge via
  `StartWorkoutIntent`-Chaining. Voraussetzung: aktive Session + Nutzer wählt ClimbReflect in Action-Button-Settings.
  Toggle-Logik zentral in `WorkoutManager.toggleAttempt()` — Badge und Button teilen exakt eine Quelle."
  Kurz-Anleitung für den Nutzer (einmalige Settings-Zuweisung) ins README.
- *Fertig-wenn:* Prinzip dokumentiert; Nutzer-Setup beschrieben.

---

## ⚠️ ABSTIMMEN (klein, vor AB-3)
- **Erststart-Verhalten:** Soll Druck 1 die Session **starten** (oben beschrieben), oder gehst du davon aus, dass
  die Session immer schon on-screen gestartet ist und der Button **nur** Versuche toggelt? Das Chaining-Modell
  deckt beides ab — ich brauche nur deine Präferenz für den Default.
- **Sportart bei Button-Start:** Welche `workoutStyle → SportTyp`-Zuordnung beim Action-Button-Start (z. B. immer
  `lead`, oder letzte genutzte Sportart aus UserDefaults)?

## Validierung
On-device auf Apple Watch Ultra mit physischem Action Button (Simulator bildet den Button nicht ab).
Watch-Core-Loop (Session-Start → Banking → Klassifizieren → Ende) bleibt on-screen **unverändert** — der Button
ist rein additiv (Rücksprache-Pflicht aus CLAUDE.md damit gewahrt).
