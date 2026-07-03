# TODO – Action Button trackt Ascents in laufender Session (löst O-3)

**Branch:** `dev` · **Repo-Stand:** `origin/dev` @ `1b0e4a9` (28.06.2026)
**Pfade:** Watch `ClimbReflectWatch Watch App/`, iOS `ClimbReflect/ClimbReflect/ClimbReflect/`
**Format:** Eine Aufgabe = ein Commit. Jeder Block: *Kontext / Dateien / Aufgabe / Fertig-wenn*. Deutsch.

> **Ersetzt** den Punkt **O-3** in `TODO-SESSION-INSIGHTS.md` und präzisiert `TODO-ACTIONBUTTON.md`
> (AB-3/AB-4/AB-5) mit dem hier verifizierten Befund. Nach Übernahme kann `TODO-ACTIONBUTTON.md`
> gelöscht werden (Teil 4).
>
> **Push-Hinweis:** Basiert auf `origin/dev` @ `1b0e4a9`. Lokale ungepushte Commits ggf. zuerst pushen.

---

## Befund (verifiziert)

**Die In-App-Logik ist bereits vollständig korrekt** und braucht *keine* Änderung:
- Der „Versuche"-Badge (`LiveSessionView`, Z. 243) ruft `workoutManager.handleActionButton()`.
- `handleActionButton()` (`WorkoutManager`, Z. 329) ist die Zustandsmaschine: `idle → active(start) →
  awaitingResult`. Erster Aufruf startet den Versuch-Timer (`.start`-Haptik + `altimeter.startAscentTracking()`),
  zweiter Aufruf stoppt ihn und setzt `awaitingResult`.
- `LiveSessionView` springt bei `awaitingResult` auf **Tab 2 → `AttemptLogView` (Klassifikation)** —
  sowohl per `onChange(of: attemptState)` (Z. 39) als auch per `onAppear` (Z. 52, Race-Fix).

→ **Genau dein Wunschverhalten ist in der App schon verdrahtet.** Es fehlt nur die zuverlässige
Brücke vom **physischen Action Button** zu `handleActionButton()`.

**Warum der Button heute nichts toggelt — zwei zusammenwirkende Ursachen:**

1. **Falscher Action-Button-Pfad gewählt.** Auf der Apple Watch ist der Action Button laut Apple
   *ausschließlich* für **Workout-/Tauch-Sessions** vorgesehen — beliebige App-Shortcuts gibt es nur am
   iPhone. Dein in den Settings gewähltes **„Training starten"** ist der App-Shortcut `StartSessionIntent`
   (aus `ClimbShortcuts`). Der **kann auf der Uhr nicht ins Versuchs-Toggle chainen** → es erscheint nur
   der orange System-Screen. Der einzige Pfad, der `.result(actionButtonIntent:)` honoriert, ist die
   **Workout-Aktivität** (im Screenshot unter „Training": **Bouldern / Vorstieg** = `StartClimbWorkoutIntent`).

2. **`StartClimbWorkoutIntent` ist diagnostisch blind und ohne Idle-Fallback.** Sein `perform()`
   (`StartSessionIntent.swift`, Z. 98–105):
   - **loggt nicht** (im Gegensatz zu `StartSessionIntent`/`ToggleAttemptIntent`) → bei einem Druck auf den
     Workout-Pfad gibt es **keine Evidenz** im DiagnosticLog, ob der Intent überhaupt feuert;
   - tut bei `isRunning == false` **gar nichts** (kein Session-Start) und liefert trotzdem den Chain zurück.

**Verifizierte API-Grundlage** (Apple-Doku „Action button…", KhaosT/WatchActionButtonExample, Apple-Forum):
`.result(actionButtonIntent:)`-Chaining funktioniert nur, wenn **(a)** `workout-processing` in
`WKBackgroundModes` ✓, **(b)** `@Parameter var workoutStyle` ✓, **(c)** eine **aktive Workout-Session**
läuft und **(d)** ClimbReflect in den Action-Button-Settings als **Workout-App** gewählt ist. **Wichtig:**
Seit **watchOS 26.5** wird der frühere „App nur öffnen + Intent donaten"-Pfad **nicht mehr** unterstützt —
der Button **muss** auf eine *konkrete Aktivität* gesetzt werden. (Geräte-Stand 06/2026: watchOS 26.x.)

> **Gute Nachricht für deinen Wunsch „Session on-screen starten, Button nur toggeln":** Kriterium (c)
> ist „**aktive** Session" — **nicht** „vom Button gestartete" Session. Eine on-screen gestartete Session
> erfüllt (c). Solange ClimbReflect als Workout-App gewählt ist und die Session läuft, toggelt der Button.

---

## Schritt 1 — Sofort prüfen: Action-Button-Konfiguration (vermutlich 80 % des Problems)

Ohne Code-Änderung, am Gerät / in der Watch-App testen:

1. iPhone → **Watch**-App → **Action-Knopf** → **Erstes Drücken** (oder am Ultra:
   **Einstellungen → Action-Knopf**).
2. Als Aktion **nicht** „ClimbReflect → Training starten" wählen, sondern unter der Rubrik **„Training"**
   direkt **„Vorstieg"** (= ClimbReflect-Workout). Der Haken muss auf **Vorstieg** sitzen, **nicht** auf
   „Training starten".
3. Test: **Session on-screen starten** (Vorstieg) → Action Button drücken → Versuch-Timer sollte starten
   (Badge gold) → erneut drücken → Banken → Klassifikation (Tab 2).

Wenn das bereits funktioniert: nur noch Schritt 2-Tasks zur Härtung/Diagnose + Doku. Wenn nicht:
Schritt 2 macht den Workout-Pfad robust **und** liefert über das DiagnosticLog den Beweis, welcher
Intent feuert.

---

## ⚠️ ABSTIMMEN (eine Entscheidung, vor AB-A)

**Idle-Druck (Button gedrückt, *bevor* eine Session läuft) — was soll passieren?**

- **(A) Empfohlen:** Button startet eine **Vorstieg-Session** (über `PendingStart`, wie heute
  `StartSessionIntent`). Vorteil: kein „toter" Druck, und der Chain etabliert sich garantiert über einen
  echten Workout-Start. Dein gewünschter Flow (on-screen starten → Button toggelt nur) bleibt **unberührt**
  — diese Variante greift nur, wenn du den Button *vor* dem Start drückst.
- **(B) Deine wörtliche Vorgabe:** Idle-Druck macht **nichts** (no-op). Funktioniert technisch, *sofern*
  du die Session immer zuerst on-screen startest; ein versehentlicher Druck davor gibt dann aber kein
  Feedback.

**Default in den Tasks unten: (A)**, weil robuster und für dich folgenlos. Sag kurz Bescheid, falls (B).

---

## Schritt 2 — Code-Härtung

### AB-A — `StartClimbWorkoutIntent` robust + diagnostizierbar machen
- *Kontext:* Der Workout-Intent ist der einzige Pfad, der auf der Uhr chaint. Er muss loggen (Diagnose)
  und in **allen** Zuständen sinnvoll handeln.
- *Dateien:* `ClimbReflectWatch Watch App/Intents/StartSessionIntent.swift` (enthält `StartClimbWorkoutIntent`),
  `Services/WorkoutManager.swift`.
- *Aufgabe:* In `StartClimbWorkoutIntent.perform()`:
  ```swift
  let manager = WorkoutManager.shared
  DiagnosticLog.shared.log("StartClimbWorkoutIntent: style=\(workoutStyle) isRunning=\(manager.isRunning) state=\(String(describing: manager.attemptState))")
  if manager.isRunning {
      manager.handleActionButton()              // → Versuch toggeln (= Badge-Verhalten)
  } else {
      // ABSTIMMEN-Default (A): Session über PendingStart starten (App-Start erledigt den HK-Start)
      PendingStart.set(workoutStyle == .boulder ? "boulder" : "lead")
  }
  return .result(actionButtonIntent: ToggleAttemptIntent())
  ```
  `openAppWhenRun` **explizit** setzen (`static var openAppWhenRun: Bool { true }`) statt sich auf das
  Protocol-Default zu verlassen — nötig, damit der Bank-Druck den Klassifikations-Screen in den Vordergrund holt.
  *(Bei ABSTIMMEN-(B): im `else`-Zweig nur loggen, kein `PendingStart.set`.)*
- *Fertig-wenn:* Bei jedem Action-Button-Druck auf dem Workout-Pfad erscheint **genau eine**
  `StartClimbWorkoutIntent:`-Zeile bzw. (ab dem 2. Druck) eine `ToggleAttemptIntent:`-Zeile im DiagnosticLog;
  bei laufender Session toggelt Druck 1 den Versuch.

### AB-B — `handleActionButton()` gegen „kein Workout" absichern
- *Kontext:* `handleActionButton()` prüft `isTraining`/`attemptState`, aber **nicht** `isRunning`. Über den
  Intent-Pfad (oder nach Jetsam-Kill vor Recovery) kann es ohne aktive Session aufgerufen werden und würde
  `attemptState = .active` setzen, obwohl gar kein Workout läuft → Geister-Versuch.
- *Dateien:* `Services/WorkoutManager.swift` (`handleActionButton()`).
- *Aufgabe:* Am Anfang von `handleActionButton()`:
  ```swift
  guard isRunning else {
      DiagnosticLog.shared.log("handleActionButton ignoriert: keine aktive Session")
      return
  }
  ```
  (Trainings-Pause/Resume-Zweig bleibt darunter unverändert, da Training ebenfalls `isRunning` voraussetzt.)
- *Fertig-wenn:* Ein Action-Button-Druck ohne laufende Session erzeugt **keinen** `attemptState`-Wechsel;
  der bestehende Badge-/Toggle-Flow bei laufender Session ist unverändert (on-device verifiziert).

### AB-C — „Training starten"-App-Shortcut vom Action-Button-Pfad entkoppeln (Disambiguierung)
- *Kontext:* Der App-Shortcut `StartSessionIntent` (über `ClimbShortcuts`) erscheint als „Training starten"
  und verleitet dazu, den **nicht** chainenden Pfad zu wählen. Auf der Uhr toggelt er nie.
- *Dateien:* `ClimbReflectWatch Watch App/Intents/StartSessionIntent.swift` (`ClimbShortcuts`).
- *Aufgabe:* Entscheiden + umsetzen:
  - **Empfohlen:** `StartSessionIntent` **aus `ClimbShortcuts` entfernen** (oder ganz löschen, falls du den
    Siri-Befehl „Starte ClimbReflect" nicht brauchst), damit in den Action-Button-Settings nur noch der
    Workout-Pfad (Bouldern/Vorstieg) auswählbar ist. `StartClimbWorkoutIntent` braucht **keinen**
    `AppShortcutsProvider` — die `StartWorkoutIntent`-Konformität registriert die Aktivität selbst.
  - **Falls Siri-Start bleiben soll:** `StartSessionIntent` als Shortcut **behalten**, aber im README klar
    als „nur Siri/iPhone, nicht Action Button" kennzeichnen (Schritt 3).
- *Fertig-wenn:* In den Watch-Action-Button-Settings ist unter ClimbReflect **kein** App-Shortcut „Training
  starten" mehr wählbar (bzw. dokumentiert, dass nur der Workout-Pfad toggelt); der Workout-Pfad
  (Bouldern/Vorstieg) erscheint weiterhin.

### AB-D — Chain nach Jetsam-Recovery wiederherstellen (AB-5 aus `TODO-ACTIONBUTTON.md`)
- *Kontext:* `reattach()` setzt `isRunning = true`, etabliert aber **keinen** Action-Button-Chain neu. Nach
  Jetsam-Kill + Recovery (S16/S21) zeigt der Button daher wieder auf den Start-Intent statt auf
  `ToggleAttemptIntent` → der nächste Druck würde fälschlich eine neue Session starten/öffnen.
- *Dateien:* `Services/WorkoutManager.swift` (`reattach()`), ggf. `Intents/ToggleAttemptIntent.swift`.
- *Aufgabe:* Nach erfolgreichem `reattach()` den Action-Button-Chain wieder auf `ToggleAttemptIntent`
  setzen (Donation/Override analog Referenz-Implementierung). Sicherstellen, dass `finishSession()`,
  `clearLiveStatus()` und `finalizeUnrecoverableSession()` den Chain wieder auf den **Start-Intent**
  zurücksetzen, damit nach Session-Ende sauber neu gestartet werden kann.
- *Fertig-wenn:* Nach simuliertem Kill + Recovery toggelt der Action Button **weiter Versuche** (startet
  keine neue Session); nach Session-Ende startet er wieder sauber. DiagnosticLog belegt beides.

### AB-E — On-device Diagnose-Protokoll (Beleg statt Hypothese)
- *Kontext:* Nach AB-A liegt für jeden Druck eine Log-Zeile vor. Damit lässt sich der Pfad eindeutig belegen
  (Methodik: Beweis vor Annahme).
- *Dateien:* — (reine Verifikation; Ergebnis in `CLAUDE.md`/Commit-Message festhalten).
- *Aufgabe:* Ablauf am Ultra mit physischem Action Button (Simulator bildet ihn nicht ab):
  1. Action Button auf **ClimbReflect → Vorstieg** (Workout) setzen.
  2. Session **on-screen** starten → Action Button drücken → Einstellungen → **Diagnose** öffnen.
  3. Erwartet: `StartClimbWorkoutIntent: … isRunning=true …`, danach `actionButton -> active(...)`.
  4. Erneut drücken → erwartet `ToggleAttemptIntent: … isRunning=true …` + `actionButton -> awaitingResult`
     + App im Vordergrund auf Tab 2 (Klassifikation).
  - Kein Log → Intent feuert nicht → Konfiguration (Workout-Pfad? ClimbReflect als Workout-App?) prüfen.
  - Log mit `isRunning=false` bei laufender Session → Prozess-/Instanz-Problem → in Commit dokumentieren.
- *Fertig-wenn:* Diagnose-Log belegt die Kette `StartClimbWorkoutIntent(isRunning=true) → ToggleAttemptIntent
  → awaitingResult`; zweiter Druck landet in `AttemptLogView`.

### AB-F — Doku: `CLAUDE.md` + README + O-3 schließen
- *Dateien:* `ClimbReflectWatch Watch App/CLAUDE.md`, `ClimbReflect/ClimbReflect-README.md`,
  `ClimbReflect/TODO-SESSION-INSIGHTS.md`.
- *Aufgabe:*
  - **S23 (aktualisieren):** „Action Button = Hardware-Zwilling der Versuche-Badge über
    `StartWorkoutIntent`-Chaining (`StartClimbWorkoutIntent` → `.result(actionButtonIntent: ToggleAttemptIntent)`).
    Voraussetzungen: `workout-processing`, `@Parameter workoutStyle`, **aktive** Session, ClimbReflect als
    **Workout-App** in den Action-Button-Settings. Auf der Uhr nur Workout-/Tauch-Pfad (App-Shortcuts =
    iPhone). Ab **watchOS 26.5** zwingend konkrete Aktivität (Vorstieg) konfigurieren — kein „open + donate".
    Toggle-Logik zentral in `handleActionButton()` (mit `isRunning`-Guard); Chain nach Recovery neu setzen."
  - **README:** Kurz-Anleitung „Action Button einrichten" (Schritt 1 oben), inkl. Hinweis, dass **Vorstieg
    (Training)** und **nicht** „Training starten" zu wählen ist.
  - **O-3** in `TODO-SESSION-INSIGHTS.md` als erledigt markieren (Verweis auf diese Datei).
- *Fertig-wenn:* S23 spiegelt den verifizierten Stand; Nutzer-Setup im README; O-3 geschlossen.

---

## Teil 4 — Aufräumen

Nach Übernahme dieser Datei kann `ClimbReflectWatch Watch App/TODO-ACTIONBUTTON.md` entfernt werden
(Inhalt hier präzisiert/abgelöst):
```bash
git rm "ClimbReflectWatch Watch App/TODO-ACTIONBUTTON.md"
git add TODO-ACTIONBUTTON-ASCENT.md
git commit -m "docs: Action-Button-Ascent-Plan (löst O-3); alte TODO-ACTIONBUTTON.md entfernt"
```

## Reihenfolge
1. **Schritt 1** (Konfiguration) zuerst testen — evtl. ist nur das die Lösung.
2. **AB-A → AB-B → AB-C → AB-D**, dann **AB-E** (Beleg), zuletzt **AB-F** (Doku) + Teil 4.

## Validierung
On-device auf Apple Watch Ultra mit physischem Action Button. Die on-screen Core-Loop (Start → Banking →
Klassifizieren → Ende) bleibt **unverändert** — der Button ist rein additiv (Rücksprache-Pflicht aus
`CLAUDE.md` gewahrt). Memory bleibt stabil (~22 MB, S16) — die Intents fassen den
`HKAnchoredObjectQuery`-Stream **nicht** an, sondern toggeln nur den In-Memory-`attemptState`.
