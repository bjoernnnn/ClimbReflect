# ClimbReflect – Fehlersuche: Watch-App wird während des Workouts beendet

**Zweck:** Lebendes Dokument, das wir Schritt für Schritt gemeinsam abarbeiten. Es hält das
Fehlerbild, alle bereits getesteten Hypothesen (mit Ergebnis) und einen strukturierten
Diagnoseplan fest. Nach jedem Schritt aktualisieren wir die Tabellen.

Stand: Branch `dev` (`a81bcbc`), getestet auf Apple Watch Ultra.

---

## 1. Fehlerbild (Symptom)

Während eines laufenden Workouts (bisher v. a. `lead`/Seil) wird die Watch-App nach
**variabler Zeit** beendet:
- Die App ist plötzlich **nicht mehr im Vordergrund**; beim Öffnen steht man wieder bei der
  Sportart-Auswahl **oder** sieht die Live-Session mit einem **roten Banner**.
- Diagnose-Log zeigt dann `recoveredActiveSession state=2` → der **App-Prozess wurde beendet**,
  aber die **HK-Workout-Session hat überlebt** (state=2 = running), und die Recovery hat sie
  wieder angebunden.
- Das **iPhone** läuft unbeeinflusst weiter.
- Nach der Recovery läuft die Aufzeichnung weiter (HF wird angezeigt, z. B. 69 BPM).

**Wichtig – Variabilität:** Die Zeit bis zum Beenden schwankt stark (~10 Min, ~24–25 Min, in
anderen Läufen **~50 Min ohne sichtbares Problem**). Der Fehler ist also **nicht deterministisch**,
sondern vermutlich **nutzungsabhängig**.

## 2. Zielverhalten

- App bleibt während des Workouts die aktive Trainings-App und wird **nicht** beendet.
- Display darf bei abgesenktem Handgelenk **aus** sein; beim Heben erscheint **die App** (nicht
  das Zifferblatt). Aufzeichnung läuft durchgehend.
- Kein roter Fehlerbanner, kein Datenverlust.

## 3. Umgebung

- Gerät: Apple Watch Ultra. **Kein** Always-On-Modus aktiv (Display nur bei Handgelenk-Heben an).
- Branch: `dev` (`a81bcbc`), per Clean-Build (Cmd+Shift+K) frisch auf die Uhr installiert.
- Session-Typ in den Tests: `lead` (Seil), `.climbing`, `locationType = .indoor`.
- Stack: SwiftUI, HealthKit (`HKWorkoutSession` + `HKLiveWorkoutBuilder` + `HKLiveWorkoutDataSource`),
  WatchConnectivity.

## 4. Gesicherte Fakten

- ✅ **Ein** historischer JetsamEvent (.ips, **alter** Code): `per-process-limit`, **300,0 MB**,
  Prozess `ClimbReflectWatch Watch App`, Zustand `active, frontmost`, ~25 Min. → damals
  Speicher-Jetsam.
- ✅ HealthKit funktioniert, wenn HF angezeigt wird (HF kommt nur aus dem aktiven Builder).
- ✅ Recovery funktioniert (bindet die überlebende Session wieder an).
- ✅ Hintergrundlaufzeit funktioniert grundsätzlich (Session überlebt → `state=2` bei Recovery).
- ✅ App-Code auf `dev` ist auditiert und **sauber** (kein Leck in eigenen Datenstrukturen,
  siehe §6).
- ✅ Build ist bestätigt aktueller `dev`-Stand (Clean-Build, frisch installiert).
- ❌ **Keine** JetsamEvent-Datei für die `dev`-Tests vorhanden → Kill-Ursache auf `dev`
  **unbestätigt**.

## 5. Bereits getestete Hypothesen & Ergebnisse

| # | Hypothese | Getestet / geprüft wie | Ergebnis |
|---|-----------|------------------------|----------|
| H1 | Timer friert im Always-On ein → Uhr/Logik stoppt | Zeit auf monoton + `TimelineView` umgestellt | ❌ widerlegt (Problem blieb; Always-On ohnehin inaktiv) |
| H2 | `WKBackgroundModes` fehlt/kein Array → keine Hintergrundlaufzeit | explizite Info.plist mit Array wiederhergestellt | ❌ als alleinige Ursache widerlegt (Session überlebt jetzt = `state=2`) |
| H3 | HealthKit-Berechtigung verloren / deaktiviert sich | HF = 69 BPM beweist aktives HK; Banner ist Anzeigefehler | ❌ widerlegt (HK war aktiv) |
| H4 | Recovery beendet die Session selbst | `end`-Event war **manuelles** Beenden durch Nutzer | ❌ widerlegt |
| H5 | Per-Sekunde-Re-Render des ganzen Views (Speicher) | A1 (kein `elapsedSeconds`-Tick) + A2 (Leaf-Views) | ❌ kein Effekt aufs Timing (gleiche ~25 Min) |
| H6 | Accelerometer/Boulder-Auto-Erkennung (Speicher/Energie) | B1: `AttemptDetector` entfernt | ❌ kein Effekt aufs Timing |
| H7 | App-Code-Leck (Arrays, Retain-Cycles, Task-Stürme) | vollständiges Audit aller Dauer-Pfade | ❌ kein Leck gefunden (Code sauber) |
| H8 | Alter/stale Build | Nutzer: Clean-Build von aktuellem `dev`, frisch installiert | ❌ ausgeschlossen |
| H9 | `reattach()` setzt `healthKitActive` nicht → falscher Banner | auf `dev` gefixt (Zeile 122) | ✅ Banner-Fix vorhanden (Banner-Ursprung im aktuellen Test noch zu verifizieren) |
| H10 | Doppeltes Beenden (`end` 2×) | TODO14 P0-2 (`isFinishing`) auf `dev` | ✅ Fix vorhanden |
| H11 | Always-On-Rendering häuft Speicher an | Nutzer: Uhr **nicht** im Always-On | ⬇️ stark abgewertet |

**Audit-Details zu H7 (Code ist sauber):** `WorkoutManager` (2-s-Timer, ein Task pro
HK-Callback, Snapshot nur bei Nutzer-Aktionen, Recovery geguarded, Broadcast alle 10 s),
`AltimeterService` (kein Array, `[weak self]`, begrenzt), `LiveSessionView` (`TimelineView` nur um
die Uhr, Leaf-Views, keine Dauer-Animationen), `SyncService`, `DiagnosticLog` – alle ohne
unbegrenztes Wachstum.

## 6. Offene Hypothesen (noch nicht widerlegt)

| # | Hypothese | Warum plausibel | Wie testen |
|---|-----------|-----------------|------------|
| O1 | **Kill ist gar kein Speicher-Jetsam** auf `dev` | keine .ips vorhanden; alter .ips war auf altem Code | Memory-Logging + Analyse-Dateien prüfen (Schritt 1+2) |
| O2 | **HealthKit-Live-Collection** (`HKLiveWorkoutBuilder`) wächst im Speicher | konstant über alle Code-Versionen; Framework-intern | Memory-Logging; Experiment „Collection reduzieren" |
| O3 | **Watchdog/Hang** beendet die App | Session überlebt auch bei Watchdog; intermittierend | Analyse-Dateien auf Hang/Crash-Log prüfen |
| O4 | **Nutzungsabhängiger** Effekt (Handgelenk-Heben-Häufigkeit, Bewegung, HF-Rate) | erklärt 25 vs 50 Min | Memory-Logging + Verhalten mitschreiben |
| O5 | Falscher Banner stammt aus einem **anderen** Pfad als Recovery | Banner trat trotz H9-Fix auf | gezielt Banner-Trigger im Test beobachten |

## 7. Strukturierter Diagnose-Plan (Schritt für Schritt)

> Wir gehen **einen** Schritt nach dem anderen. Nach jedem Schritt Ergebnis hier eintragen,
> dann nächsten Schritt.

### Schritt 1 — Speicherverbrauch sichtbar machen (Instrumentierung)
**Ziel:** Ohne .ips feststellen, **ob** Speicher die Ursache ist.
**Aufgabe:** Im `DiagnosticLog` jede Minute den verfügbaren/genutzten Speicher loggen, z. B.
`os_proc_available_memory()` (verfügbarer Speicher in Bytes) und/oder die residente Größe.
Zusätzlich `scenePhase`-Wechsel (active/inactive/background) loggen.
**Erwartete Auswertung:**
- Speicher fällt kontinuierlich Richtung Limit, dann Kill → **es ist Speicher** (→ Schritt 3).
- Speicher bleibt stabil, App stirbt trotzdem → **kein Speicher** (→ Schritt 4).
**Status:** ✅ **Implementiert auf `dev`** – `MemoryProbe.swift` (phys_footprint + os_proc_available_memory),
minutenweises Logging im 2-s-Timer (`mem used=…MB avail=…MB t=…min`, sofort persistiert),
Startwert beim Session-Beginn, `scenePhase`-Wechsel (inkl. flush bei `.background`).

### Schritt 2 — Analyse-Dateien prüfen (Kill-Mechanismus bestätigen)
**Ziel:** Art der Beendigung feststellen.
**Aufgabe:** Nach einem Fehlversuch auf dem **iPhone**: Einstellungen → Datenschutz & Sicherheit
→ Analyse & Verbesserungen → **Analysedaten**. Dort nach Dateien suchen, die mit `JetsamEvent`,
`ClimbReflect` oder `WatchdogResource`/Hang beginnen (Datum des Tests).
**Erwartete Auswertung:**
- `JetsamEvent` mit `per-process-limit` ~300 MB → Speicher (→ Schritt 3).
- Crash-Log (Exception) → Absturz (→ eigener Fix).
- Hang/Watchdog-Report → Watchdog (→ Schritt 4).
- Nichts → wahrscheinlich Suspension/Watchdog (→ Schritt 4).
**Status:** _offen (Nutzer hat aktuell keine Datei – Schritt 1 ersetzt dies notfalls)_

### Schritt 3 — NUR falls Speicher bestätigt: Framework-Quelle isolieren
**Ziel:** HealthKit-Collection als Quelle bestätigen/ausschließen.
**Aufgabe:** Testlauf, bei dem die `HKWorkoutSession` (für Hintergrund) bleibt, aber der
`HKLiveWorkoutBuilder`/`beginCollection` **testweise weggelassen** wird. Mit Memory-Logging aus
Schritt 1.
**Erwartete Auswertung:**
- Speicher bleibt flach → **HealthKit-Collection** ist die Quelle → gezielter Fix (collected
  types beschränken / periodisch entlasten / Builder-Strategie ändern).
- Speicher wächst weiter → Quelle liegt woanders → Allocations-Profiler (Schritt 5).
**Status:** _offen_

### Schritt 4 — NUR falls kein Speicher: Beendigungs-Mechanismus eingrenzen
**Ziel:** Watchdog/Suspension vs. Systemende unterscheiden.
**Aufgabe:** Mit `scenePhase`- und Heartbeat-Logging (Schritt 1) prüfen, ob die App kurz vor dem
Kill in `background` ging und wie lange. Prüfen, ob `didChangeTo`-Events (3/6) auftreten. Ggf.
Hauptthread-Last beobachten.
**Erwartete Auswertung:** zeigt, ob die App suspendiert + beendet wird (Hintergrund-Thema) oder
hängt (Watchdog).
**Status:** _offen_

### Schritt 5 — Allocations/Leaks-Profiler (endgültiges Pinpointing)
**Ziel:** Exakte Allokationsgruppe identifizieren.
**Aufgabe:** Xcode → Profile → Allocations (+ Leaks), echte Uhr, ~10–15 Min, „Persistent Bytes"
nach steigender Kategorie absuchen (CoreAnimation/Render, HealthKit, CoreMotion, App-Objekte).
**Status:** _offen (sobald Mac/Zeit verfügbar)_

## 8. Diagnose-Hilfen

- **Diagnose-Log-Statuscodes (`didChangeTo N`):** 1 notStarted, 2 running, 3 ended, 4 paused,
  5 prepared, 6 stopped.
- **Schlüssel-Signaturen im Log:**
  - `recoveredActiveSession state=2` → App-Prozess war tot, Session überlebte, Recovery lief.
  - `beginCollection ok` → HealthKit-Session aktiv.
  - `end ascents=… duration=…s` → Beenden (Quelle prüfen: manuell vs. automatisch).
- **Wahrheits-Check HealthKit:** HF-Anzeige > 0 BPM = HK aktiv (Banner dann = Anzeigefehler).
- **JetsamEvent lesen:** Speicher = `rpages × pageSize / 1048576` MB; `reason: per-process-limit`
  + `largestProcess` = gekillter Prozess.

## 9. Nächster konkreter Schritt

**→ Schritt 1 ist implementiert.** Bitte einen Lauf bis zum Fehler machen und danach
Watch → Einstellungen → Diagnose öffnen. Gesuchte Muster:
- `mem start used=…MB avail=…MB` – Ausgangswert
- `mem used=…MB avail=…MB t=…min` – minütlich
- `scenePhase=…` – Vordergrund/Hintergrund-Wechsel

**Was schicken:** Foto oder Abschrift der letzten ~20 Log-Einträge (vor allem die `mem`- und
`scenePhase`-Zeilen kurz vor dem Verschwinden).

Dann tragen wir das Ergebnis hier in §5 ein und entscheiden: Schritt 3 (Speicher) oder
Schritt 4 (kein Speicher / Watchdog).
