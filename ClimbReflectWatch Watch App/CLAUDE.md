# CLAUDE.md – ClimbReflect: Roter Faden für Entwicklung & Reviews

Dieses Dokument hält Architektur, Grundsätze, gelernte Stolpersteine und Konventionen fest,
damit Claude (Analyse/TODO-Autor) und Claude Code (Umsetzung) über Sessions hinweg konsistent
arbeiten. **Bei Unsicherheit: hier nachsehen, bevor neu entschieden wird.**

---

## 1. Projektüberblick

- **Was:** Native iOS- + watchOS-App zum Aufzeichnen und Reflektieren von Kletter-Trainings
  (Bouldern, Seil: Lead/Toprope/Auto-Belay, Training). Sessions, Begehungen (Ascents), Projekte
  über mehrere Sessions, Statistiken, Grad-Pyramide, Erfolge.
- **Eigenständig:** Die App zeichnet **vollständig selbst** auf (Watch-Live-Session + manuelle
  iPhone-Eingabe). Der HealthKit-Import aus „Redpoint" ist **optional**, kein Pflichtweg.
- **Stack:** SwiftUI, SwiftData, HealthKit, WatchConnectivity, Swift Charts. UI: erzwungenes
  Dark-Theme, durchgehend Deutsch.
- **Bundle-ID:** `de.dreselbjoern.ClimbReflect` (Watch: `…watchkitapp`).

---

## 2. Architektur

### 2.1 Datenmodell (SwiftData)
- **`ClimbSession`** – eine Trainingseinheit (Datum, Typ, Dauer, RPE/Fokus/Energie, HF-Werte).
- **`Ascent`** – eine geloggte Begehung (Grad, Ergebnis, Stil, Versuche, Wandwinkel/Grifftyp/
  Kletterart-Tags, Notiz, optional Foto). Relation `session` und `project`.
- **`Project`** – **erstklassiges** Mehr-Session-Konstrukt mit echter Relationship
  `@Relationship(deleteRule: .nullify, inverse: \Ascent.project) var ascents: [Ascent]`, plus
  `media: [ProjectMedia]`, `isPinned`, `gradeSystemRaw`, `targetGradeRaw`. Status (aktiv/gesendet/
  aufgegeben) wird aus den Ascents abgeleitet.
- **`ProjectMedia`** – Beta-Fotos/Notizen zum Projekt (cascade delete).
- **Migration:** `AppMigrationPlan` (VersionedSchema V1→V2, lightweight). `ProjectMigration`
  überführt alte `projectName`-Strings in echte `Project`-Relationen.

### 2.2 Watch ↔ iPhone (WatchConnectivity)
- **Session-Transfer Watch→iPhone:** `transferUserInfo` (hintergrundsicher, persistiert) →
  iPhone `didReceiveUserInfo`. **Nicht** `sendMessage` für den Session-Transfer (scheitert im
  Hintergrund).
- **Live-Status & Projekte iPhone↔Watch:** `updateApplicationContext` (immer „letzter Stand").
- **DTOs** (`WatchSessionDTO`, `AscentDTO`) sind auf beiden Seiten **identisch**. `AscentDTO`
  trägt `projectName` + `projectID`.
- **Dedupe:** iPhone-seitig Upsert über `watchSessionID` (verhindert Doppel-Sessions). Projekt-
  Verlinkung beim Empfang über `projectID` (Name als Fallback); **iPhone ist Source of Truth**
  für Projekte → bei unbekannter ID kein Neuanlegen.

### 2.3 Watch-Live-Session (Kern)
- **`WorkoutManager`** (`@MainActor`, ObservableObject) steuert alles: `HKWorkoutSession` +
  `HKLiveWorkoutBuilder` (`.climbing` bzw. `.functionalStrengthTraining`, `locationType = .indoor`).
- **Zeit:** monoton aus `workoutStartDate` + Pausenverrechnung (`currentElapsed()`), angezeigt via
  `TimelineView`. **Nicht** über einen Sekunden-Zähler (siehe Stolperstein S2).
- **Recovery:** `recoverActiveWorkoutSession()` beim Kaltstart → `reattach()` an eine noch
  laufende Session, State aus `PendingSessionStore`-Snapshot herstellen, zurück in `LiveSessionView`.
- **Crash-Sicherung:** `PendingSessionStore` schreibt nach jeder Versuch-Mutation einen Snapshot
  ([AscentDTO] + Start + Pause + Projekt) auf Disk.
- **Diagnose:** `DiagnosticLog` (Ring-Puffer, persistiert) – sichtbar in der Watch-„Diagnose"-
  Ansicht. Loggt start/pause/resume/bank/end, `didChangeTo <state>`, `didFailWithError`,
  `recoveredActiveSession`, `beginCollection ok`.
- **`WorkoutManager` wird NICHT aufgesplittet** (feste Entscheidung).

### 2.4 iPhone-UI
- 4 Tabs: **Heute** (Hero, Quick-Add, Live-Banner, letzte Sessions, gepinnte Projekte),
  **Statistik** (alle Charts), **Projekte**, **Erfolge**. Jeder Tab hat einen eigenen
  `NavigationStack`.

---

## 3. Grundsätze (Do)

1. **Eigenständigkeit zuerst.** Watch-Aufnahme + manuelle Eingabe müssen vollständig ohne
   Redpoint/HealthKit-Import funktionieren.
2. **Datensicherheit.** Kein stiller Datenverlust. Migrationen versioniert; im Fehlerfall sichern,
   nicht löschen. Laufende Sessions per Snapshot crash-sicher.
3. **Komfort erhalten.** Performance-/Energie-Refactorings dürfen die UX nicht verschlechtern:
   Uhr tickt flüssig, HF live, Always-On-Verhalten wie gewollt.
4. **Energieeffizienz.** Wenig Wakeups, wenig Sensor-Last, wenig Re-Renders, wenig Disk-IO.
5. **Offizielle Mechanismen.** Hintergrund/Frontmost nur über `HKWorkoutSession` /
   `WKBackgroundModes` / ggf. `WKExtendedRuntimeSession` – keine Hacks (z. B. stummes Audio).
6. **Sichtbarkeit statt stiller Degradierung.** Wenn HealthKit/Workout-Session fehlschlägt, das
   sichtbar machen (Banner + Diagnose-Log), nicht so tun, als würde aufgezeichnet.
7. **iPhone ist Source of Truth für Projekte.** Watch wählt nur aus gepushten Projekten.

---

## 4. Stolpersteine (gelernte Lektionen – nicht wiederholen)

**S1 – `WKBackgroundModes` muss ein Array in einer expliziten `Info.plist` sein.**
Das Build-Setting `INFOPLIST_KEY_WKBackgroundModes = "workout-processing"` erzeugt **nicht
zuverlässig** das benötigte Array. Ohne gültiges Array verliert die Workout-Session die
Hintergrundlaufzeit und watchOS beendet sie. → Explizite `ClimbReflectWatch-Watch-App-Info.plist`
mit `<key>WKBackgroundModes</key><array><string>workout-processing</string></array>`.

**S2 – Verstrichene Zeit nie über einen `Timer`-Zähler führen.**
Mit `WKSupportsAlwaysOnDisplay = YES` feuert ein 1-Hz-`Timer` im gedimmten Zustand nicht → die
Uhr friert ein / läuft falsch. → Monoton aus `workoutStartDate` rechnen, mit `TimelineView`
anzeigen.

**S3 – Speicherlimit der Uhr (~300 MB per-process).**
Die App wurde bei ~25 Min wegen Speicherüberschreitung gejetsamt (frontmost). Hauptverdacht:
**per-Sekunde-Re-Render des ganzen `LiveSessionView`-Baums** (HF/Zeit/Höhe als `@Published`
ändern sich 1–3×/s) + Dauer-Sensorik. → `elapsedSeconds` nicht jede Sekunde publishen; Live-Werte
in **kleine Blatt-Views** isolieren, damit nicht der ganze Screen neu rendert; Tasks/Publishes
drosseln. Symptom „App verschwindet nach ~24–25 Min" = sehr wahrscheinlich dieser Jetsam.

**S4 – Eine laufende Session nicht doppelt beenden.**
`didChangeTo .ended` darf bei **absichtlichem** Ende kein zweites `endWorkout()` triggern, sonst
`didFailWithError 'end' from 'Ended'` (roter Banner). → `endWorkout()` idempotent (guard gegen
`.ended/.stopped`); `sessionEndedUnexpectedly` nicht bei bewusstem Ende setzen.

**S5 – Recovery nur beim Kaltstart.**
`recoverIfNeeded()` nicht bei jedem App-Erscheinen laufen lassen; `guard !isRunning, session == nil`.
Beim Öffnen alte Fehler (`lastError`/`sessionEndedUnexpectedly`) zurücksetzen, sonst erscheint ein
veralteter roter Banner.

**S6 – Session-Statuswechsel/-Fehler nie verschlucken.**
`workoutSession(didChangeTo:)` und `didFailWithError` auswerten und im Diagnose-Log festhalten
(State-Codes: 1 notStarted, 2 running, 3 ended, 4 paused, 5 prepared, 6 stopped).

**S7 – String-basierte Projekt-Gruppierung war eine Sackgasse.**
Früher `Ascent.projectName` als Freitext → verwaiste Daten bei Umbenennung, Phantom-Projekte bei
Tippfehlern. → Echte `Project ↔ [Ascent]`-Relationship mit `deleteRule: .nullify`. Projekt löschen
darf Begehungen nie aus der Statistik entfernen.

**S8 – Ø-Herzfrequenz aus dem Builder, nicht der letzte Messwert.**
Watch: `wb.statistics(for: .heartRate)?.averageQuantity()` (mit laufendem Mittelwert als Fallback),
**nicht** den letzten `mostRecentQuantity()`-Wert als „Ø" senden.

**S9 – Höhenmeter: Rauschen filtern, nur beim Versuch messen.**
Barometer driftet/rauscht → nur Deltas über einer Schwelle (`noiseFloor ≈ 0.3 m`) zählen. Und:
Höhe **nur während eines aktiven Versuchs** sammeln (nicht die ganze Session).

**S10 – Accelerometer/Boulder-Auto-Erkennung ist entfernt.**
Die 5-Hz-Auto-Erkennung war heuristisch, fehleranfällig (eingefrorene HF) und ein Energie-/
Speicher-Verbraucher. **Entfernt**; Versuche werden **manuell über den Action Button** gebankt.

**S11 – Always-On-Verhalten ist gewollt.**
Display geht bei abgesenktem Handgelenk aus und beim Drehen wieder an. Das ist beabsichtigt – nicht
„reparieren". Ziel ist nur, dass die **App** (nicht das Zifferblatt) erscheint, solange das Workout
läuft.

**S12 – `INFOPLIST_FILE` + `GENERATE_INFOPLIST_FILE` sauber halten.**
Doppelquellen für Info.plist-Schlüssel sind eine Fehlerquelle (siehe S1). Klar dokumentieren,
welcher Schlüssel woher kommt; nach Build im gebauten `Info.plist` verifizieren.

**S13 – CoreMotion/Altimeter-Updates nicht auf der Main-Queue.**
Sensor-Handler auf eine dedizierte Hintergrund-`OperationQueue`; nur Ergebnisse auf den
Main-Actor holen. Sonst Rückstau → Watchdog-Hang.

---

## 5. Branch- & Arbeitsweise-Konventionen

- **Branches:** `main` (stabil), `dev`, plus Feature-/Fix-Branches (`feature/projects`,
  `feature/energy-efficiency`, `fix/wkbackgroundmodes`, …). **Wichtig:** Fixes/Features können auf
  verschiedenen Branches liegen – vor einem Test sicherstellen, dass **alle** nötigen Teile auf
  **einem** Branch zusammen sind.
- **Pfade:** iOS-Quellcode dreifach verschachtelt unter `ClimbReflect/ClimbReflect/ClimbReflect/`;
  Watch unter `ClimbReflectWatch Watch App/` (Leerzeichen → in Shell quoten).
- **TODO-Format:** `.md`-Dateien mit *Kontext / Dateien / Aufgabe (Schritt für Schritt, ggf.
  Code-Skizze) / Fertig-wenn*. Eine Aufgabe = ein Commit. Große, übergreifende Änderungen vorher
  mit Björn abstimmen (Rücksprache).
- **Sprache/Stil:** UI-Strings Deutsch, Dark-Theme, `Theme`/`WatchTheme`-Farben, MVVM-nah,
  `StatsEngine` rein funktional + Tests.
- **Repo-Zugriff (Claude):** `git fetch origin '+refs/heads/*:refs/remotes/origin/*'` holt alle
  Branches.

---

## 6. Diagnose ohne Geräte-Logs

- **In-App-Diagnose:** Watch → Einstellungen → „Diagnose" zeigt den `DiagnosticLog`. Nach einem
  Vorfall die letzten Einträge ansehen.
  - `start` → `beginCollection ok` → `didChangeTo 2` = Session läuft sauber.
  - `didChangeTo 3/6` mitten in der Session = Session beendet (extern oder durch Bug).
  - `recoveredActiveSession state=2` = App war weg, Session überlebte, Recovery hat reattacht.
  - `didFailWithError 'end' from 'Ended'` = doppeltes/verspätetes `end()` (S4).
- **JetsamEvent (`.ips`):** Einstellungen → Datenschutz → Analyse. Speicher = `rpages × pageSize /
  1048576` MB; `reason: per-process-limit` + `largestProcess` identifiziert den Kill. ~300 MB +
  `active, frontmost` = Speicherleck (S3).

---

## 7. Offene Punkte / aktuelle Baustelle

- **Speicher-Jetsam (S3):** Energie-/Speicher-Fixes (TODO11: A1/A2 Re-Render, B1 Accelerometer,
  B3 Höhe) auf den aktiven Branch bringen und per 30-Min-Test verifizieren. **Dies ist die
  wahrscheinliche Ursache des „App verschwindet nach ~24 Min".**
- **Roter Banner (S4/S5):** `endWorkout()` idempotent, kein Doppel-Ende, alte Fehler beim Öffnen
  zurücksetzen.
- **Frontmost (Ziel):** Nach behobenem Leck verifizieren, dass die laufende Workout-Session die
  App frontmost hält; nur falls nötig `WKExtendedRuntimeSession`.
- **Projekt-Sync zur Watch:** `knownProjects` kam im Test leer an – prüfen, ob
  `updateApplicationContext` beim Start zuverlässig ankommt (ggf. persistieren). Die Funktion muss
  zurück (Projekt auf der Uhr wählbar).
- **Grad-Skalen:** Picker-Leiter (`Enums`) und `GradeConverter` divergieren – perspektivisch eine
  kanonische Leiter pro Disziplin.

---

*Dieses Dokument bei jeder größeren Entscheidung/jedem Fix aktualisieren, damit der rote Faden
erhalten bleibt.*
