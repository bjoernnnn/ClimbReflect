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
- 4 Tabs: **Heute** (Hero, Quick-Add, Live-Banner, letzte Sessions, gepinnte Projekte,
  „Nächster Erfolg"-Karte), **Fortschritt** (Level/Verlauf/Pyramide/Volumen/Stil,
  `ProgressEngine`), **Projekte**, **Erfolge** (Gipfelmarken-Sammlung,
  `AchievementEngine`/`AchievementUnlock`, ERFOLGE-KONZEPT-V2). Jeder Tab hat einen
  eigenen `NavigationStack`.

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

**S14 – `healthKitActive`-Flag nach Recovery wiederherstellen (sonst lügt der Banner).**
Das Flag `healthKitActive` (steuert den Banner „Kein HealthKit – kein Hintergrund") wird nur in
`startWorkout` (nach `beginCollection`) und in `didChangeTo .running` auf `true` gesetzt. Bei der
**Recovery** (`reattach`) wird es **nicht** gesetzt – und `didChangeTo .running` feuert dort nicht,
weil die wiederhergestellte Session schon `.running` ist. Folge: nach jedem Recovery erscheint der
**falsche** Banner „Kein HealthKit", obwohl HealthKit läuft (HF wird erfasst). Das hat eine ganze
Fehlersuche fehlgeleitet (man dachte, HealthKit deaktiviere sich). → In `reattach()` immer
`healthKitActive = (ws.state == .running || ws.state == .paused)` setzen. **Merke:** HF-Anzeige
> 0 BPM beweist, dass HealthKit aktiv ist – der Banner ist dann ein App-Bug, kein Permission-
Problem. Status-Anzeigen immer an den **echten** Session-Status koppeln, nicht an ein Flag, das
in einem Pfad vergessen werden kann.

**S15 – HF-Anzeige als Wahrheits-Check für HealthKit.**
Zeigt die Live-Ansicht eine plausible HF (> 0), liefert HealthKit Daten → HealthKit ist aktiv.
Das ist der schnellste Weg, ein echtes Berechtigungsproblem von einem Anzeige-Bug zu unterscheiden.
(Hinweis: Seit S16 kommt die Live-HF aus einer Streaming-Query, nicht mehr aus dem Builder.)

**S16 – KEIN `HKLiveWorkoutBuilder` für die Live-Datensammlung (Speicherleck!).**
Der `HKLiveWorkoutBuilder` mit `HKLiveWorkoutDataSource` + `beginCollection` hält **alle**
gesammelten Samples bis Session-Ende im Speicher → der phys_footprint klettert ans 300-MB-Limit →
Jetsam (per-process-limit). Belegt durch Messung: mit Builder 298 MB nach 138 Min (bzw. 286 MB
nach 29 Min wach); Builder aus → flach (~20 MB); Streaming-Fix → flach (17 MB über 20 Min).
**Die Rate skaliert mit der HF-Sample-Frequenz** (wach/aktiv schneller, Schlaf langsamer) – das
erklärte die scheinbar zufällige Abbruchzeit (5–138 Min). Das Einschränken von `typesToCollect`
hilft **nicht** (HF allein reicht zum Volllaufen). **Lösung:** `HKWorkoutSession` für die
Hintergrundlaufzeit behalten, Live-HF/Energie über `HKAnchoredObjectQuery` (Streaming) beziehen
und Samples **verwerfen** (keine Akkumulation); am Ende optional ein schlankes Workout via den
assoziierten `HKWorkoutBuilder` speichern (ohne Per-Sample-Sammlung).
**ACHTUNG (Regression-Erkenntnis):** `beginCollection` auf dem assoziierten Builder ist **trotzdem
nötig** — ohne aktive Collection bewahrt `recoverActiveWorkoutSession()` die Session nicht über
einen Kill hinweg, und watchOS behandelt die App nicht als aktive Workout-App (aggressiveres
Backgrounding). Fix: `beginCollection` aufrufen, aber **keine `HKLiveWorkoutDataSource` setzen** →
der Builder hat nichts zu sammeln → kein Speicherleck, aber Session-Preservation funktioniert.
Beim Beenden die Streaming-Queries mit `store.stop(query)` stoppen. **Merke:** Für lange
Always-Recording-Sessions: Streaming für Live-Daten, Builder nur als Anker für Recovery.

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

- **Falscher „Kein HealthKit"-Banner (S14) – ZUERST:** `reattach()` setzt `healthKitActive` nicht
  → nach jeder Recovery falscher Banner. Schnell zu fixen, nimmt die Verwirrung raus.
- **Speicher-Jetsam (S3) – die eigentliche Ursache des Verschwindens:** Energie-/Speicher-Fixes
  (TODO11: A1/A2 Re-Render, B1 Accelerometer, B3 Höhe) liegen auf `feature/energy-efficiency`,
  **nicht** auf dem getesteten `fix/wkbackgroundmodes`. Zusammenführen + per 30–60-Min-Test
  (kein neuer JetsamEvent) verifizieren. Wenn HealthKit aktiv ist, wächst der Speicher schneller
  (HKLiveWorkoutBuilder + per-Sekunde-Re-Render) → Kill → Recovery → falscher Banner (S14).
- **Doppeltes Beenden (S4):** Zwei `end`-Events im Log. `endWorkout()` per `isFinishing`-Flag
  gegen Doppelaufruf absichern; `sessionEndedUnexpectedly` nicht bei bewusstem Ende setzen.
- **HealthKit-Berechtigung/Onboarding:** Dev-Builds setzen Berechtigungen teils zurück. Klares
  Onboarding + Status-Check (`authorizationStatus(for: workoutType)`) vor Session-Start; nicht
  still im Timer-only-Modus starten. Aber: Gating an den **echten** Status koppeln (S14).
- **Frontmost (Ziel):** Nach behobenem Leck verifizieren, dass die laufende Workout-Session die
  App frontmost hält; nur falls nötig `WKExtendedRuntimeSession`.
- **Projekt-Sync zur Watch (W-1 → PS-1, weiter gehärtet):** Der Kontext-Button verschwand
  komplett, wenn `knownProjects`/`knownShoes` leer ankamen (W-1-Fix: Button bleibt immer sichtbar,
  Tap löst `SyncService.requestListSync()` aus). PS-1 hat zwei weitere Lecks geschlossen: (1)
  `saveListCache()` persistierte nur nicht-leere Listen – ein gelöschtes letztes Projekt kam nach
  Watch-Neustart aus dem Cache zurück; jetzt wird auch `[]` explizit gespeichert. (2)
  `selectedProject`/`selectedShoe` wurden nie gegen die aktuelle Liste abgeglichen – ein gelöschtes,
  zuvor gewähltes Projekt blieb aktiv bankbar; `SyncService.onListsUpdated` (zentral in
  `WorkoutManager.init()`, analog `onCommand`) räumt das jetzt nach jedem Sync auf. **Offen
  bleibt:** die grundsätzliche Zuverlässigkeit von `updateApplicationContext` beim Start ist nicht
  geräteseitig verifiziert. Bei erneuten leeren Listen: Diagnose-Log auf `sync:`-Einträge prüfen.
- **Grad-Skalen:** Picker-Leiter (`Enums`) und `GradeConverter` divergieren – perspektivisch eine
  kanonische Leiter pro Disziplin. Bereits geprüft (GR-1): die Watch-Leitern (`WatchEnums`) sind
  gegenüber den iPhone-Leitern nur an den Rändern kürzer (fehlende Extremgrade oben/unten), die
  String-Notation selbst ist identisch – kein Case-/Format-Mismatch, nur ein Range-Thema.
- **CloudKit-Sync (CK-1):** Roadmap CK-P0…P3 (siehe TODO15-FEEDBACK-CLOUD.md). **CK-P0 erledigt**
  (Schema CloudKit-tauglich: `.unique` entfernt, Defaults ergänzt, S38) – CloudKit ist weiterhin
  **nicht aktiv**. CK-P1 (Entitlements/Capabilities, iCloud-Container) braucht einen Apple-
  Developer-Account mit iCloud-Fähigkeit – vor Fortsetzung klären. CK-P2 (Aktivierung hinter Flag)
  und CK-P3 (Zwei-Geräte-Verifikation) erst danach, jede Phase eigener Commit.

**S17 – `HKAnchoredObjectQuery` mit `anchor: nil` liefert beim (Neu-)Start die komplette
  Historie seit dem Predicate-Start.** Akkumulatoren (`hrSum`, `hrCount`, `activeEnergyKcal`)
  müssen deshalb **vor** `execute` auf 0 gesetzt und ausschließlich aus dem Stream rekonstruiert
  werden – niemals zusätzlich aus einem Snapshot addieren (Doppelzählung). `maxHeartRate` ist
  idempotent (immer das bisherige Maximum) und darf als Anzeige-Seed aus dem Snapshot gesetzt
  bleiben.

**S18 – Ein `maxHeartRate`-Reset auf die momentane HF nach Wiederöffnen ist der
  Fingerabdruck eines App-Relaunch via `reattach()`.** Tritt er auf, wurde der Prozess neu
  gestartet – die `HKWorkoutSession` selbst lebt (state=2). Ursache war: Snapshot beim Start
  schreibt `maxHeartRate = nil` (noch 0); Streaming-Query nimmt nur `.last`-Sample → max = aktuelle
  HF. Behoben in B1/B3: alle Samples auswerten + maxHeartRate als Seed aus Snapshot restoren.

**S19 – Memory-Leak liegt in der verschachtelten Paging-`TabView`, nicht im Altimeter.**
  Reproduziert: Speicher flach, bis Tab 2 (`AttemptLogView`) das erste Mal besucht wird; danach
  linearer Anstieg ~10 MB/min bis Jetsam. Nach Recovery ohne Tab-2-Besuch flach trotz ascents.
  Lehre: `.page`-TabView mit verschachteltem `.verticalPage`-TabView + 1-Hz-`TimelineView`
  vermeiden; modale Sheets statt Swipe-Tabs für selten genutzte Views.

**S20 – Korrelation ≠ Ursache (Altimeter-Fehlspur).** Das Auto-Re-Arm
  (`startAscentTracking()` nach jedem Bank) ließ den Altimeter wie den Leak-Trigger aussehen,
  weil Banken und Tracking gekoppelt waren. Erst Entkopplung (Subscription nur während echtem
  Versuch) + Test über die AttemptLogView zeigte: Leak besteht ohne aktiven Altimeter.

**S21 – Recovery nach Jetsam.** `recoverActiveWorkoutSession()` liefert bei laufender Session
  `state=2` → `reattach()`. Liefert sie eine beendete Session oder `nil`, **muss**
  `finalizeUnrecoverableSession()` laufen (DTO syncen + `clearLiveStatus()`), sonst läuft das
  Handy weiter, während die Watch in der Auswahl steht. Recover-Logging gibt den Zweig preis.

**S22 – Memory-Leak war AttemptLogView als Dauer-Tab in der Paging-`TabView`.** Als modales
  Sheet (oder content-gated: `if currentTab == 2 { AttemptLogView(…) } else { Color.clear }`)
  flach; als dauerhaft gehaltener Swipe-Tab Leak (~10 MB/min, vermutlich retainierter
  Wheel-`Picker`). Lehre: schwere/zustandsbehaftete Views nicht dauerhaft als Pager-Tab halten;
  content-gaten oder als Sheet öffnen.

**S27 – Aktivzeit ist gemessen, nie geschätzt.**
  Zeitaufteilung in den Session-Insights basiert ausschließlich auf `Ascent.durationSeconds`
  (gemessen im Watch-Start/Stopp-Flow). Ohne Daten: Hinweistext anzeigen (oder Diagramm
  ausblenden), **nie** schätzen oder interpolieren (Vorgabe S6). Kennzahlen leben in
  `StatsEngine.insights(for:)`.

**S28 – Schuh spiegelt die Projekt-Architektur.**
  `Shoe`-Modell (SwiftData) ist erstklassig wie `Project`. iPhone = Source of Truth
  (Anlage nur dort). Watch wählt aus `knownShoes`/`selectedShoe`; Snapshot beim Banken in
  `WatchAttempt.shoeInfo`. Empfang ohne Auto-Anlegen: bei unbekannter ID/Name bleibt
  `ascent.shoe = nil`, `shoeName`-Cache bleibt erhalten. `deleteRule: .nullify` – Schuh
  löschen entfernt keine Begehungen aus der Statistik.

**S29 – Training wird nur auf dem iPhone erfasst.**
  `TrainingSet`-Sets (Hangboard, Repeaters, Klimmzüge etc.) werden ausschließlich in
  `SessionDetailView` auf dem iPhone eingegeben. Watch ist **kein** Eingabekanal für Training.
  Die Watch-Session-Integration (T5) ist explizit **ABSTIMMEN** – nicht implementieren ohne
  Rücksprache. `TrainingSet` ist eine Beziehung zu `ClimbSession` mit `deleteRule: .cascade`.

**S26 – iPhone Live Activity lässt sich nur im Vordergrund starten** (`Activity.request`).
  Watch startet Session → iPhone wacht im Hintergrund auf → `request()` schlägt fehl (still).
  Fix: `lastStatus` puffern, bei `scenePhase == .active` `retryIfNeeded()` aufrufen → startet
  beim nächsten Vordergrund-Werden. Echter Hintergrund-Start nur via Push-to-Start (APNs/Server).

**S25 – System-Uhrzeit/Statusleiste ist in watchOS nicht ausblendbar** (Apple: Watch ist
  Zeitmessgerät). Inhalte oben **links** platzieren, um die Uhr oben rechts nicht zu
  überschneiden. VideoPlayer-Hack o. Ä. bewusst vermeiden – fragil und App-Store-Risiko.

**S24 – Versuch-Start/Stopp läuft über die „Versuche"-Badge** (Tipp → gold + Timer; erneut
  → zurück zur Anzahl + Auto-Nav zu Tab 2). Kein separater Button → kein Layout-Shift.
  Auslöser zusätzlich per `.handGestureShortcut(.primaryAction)` (Doppeltipp). Verbose-Logging
  über `DiagnosticLog.isVerbose`-Schalter (Standard: aus) kontrollierbar.

**S23 – Action Button ist Hardware-Zwilling der Versuche-Badge via `StartWorkoutIntent`-Chaining.**
  **Voraussetzungen (alle vier nötig):** (a) `workout-processing` in `WKBackgroundModes` ✓,
  (b) `@Parameter var workoutStyle` ✓, (c) **aktive** HK-Session (nicht zwingend Button-gestartet —
  on-screen-Start reicht), (d) ClimbReflect als **Workout-App** (nicht App-Shortcut!) in Action-Button-
  Settings: Watch Einstellungen → Action Button → Training → **Vorstieg** (= `StartClimbWorkoutIntent`).
  Ab **watchOS 26.5** ist der App-Shortcuts-Pfad nicht mehr chainbar; nur Workout-Aktivität toggelt.
  **Architektur:** `StartClimbWorkoutIntent.perform()` loggt + ruft `handleActionButton()` (wenn
  `isRunning`), sonst `startFromActionButton()` für den Idle-Druck (AB-G: startet die Session
  **direkt im Intent** – das frühere `PendingStart`-Flag wurde nur im `.task` beim Kaltstart
  konsumiert und verpuffte, wenn der Prozess schon im Hintergrund lebte) → chains zu
  `ToggleAttemptIntent`, das sich selbst re-chaint. `recoverIfNeeded()` ist single-flight
  (App-`.task` und Intent dürfen parallel aufrufen). Toggle-Logik ausschließlich in `WorkoutManager.handleActionButton()` — Badge und
  Button teilen die Quelle. `handleActionButton()` hat `guard isRunning` an erster Stelle (kein
  Ghost-Versuch bei Jetsam-Kill vor Recovery). `openAppWhenRun = true` öffnet App beim zweiten Druck
  (awaitingResult) damit Tab 2 / Klassifikation sichtbar wird. `ClimbShortcuts` wurde entfernt — der
  App-Shortcuts-Pfad ist auf der Uhr nutzlos und verursacht Fehlkonfigurationen.
  **Jetsam-Recovery:** Chain fällt nach Kill auf `StartClimbWorkoutIntent` zurück → erster Druck nach
  Recovery ruft `handleActionButton()` mit `isRunning=true` und re-etabliert den Chain. Session-Ende
  beendet die HKWorkoutSession → System setzt Action-Button automatisch auf Start-Zustand zurück.

**S30 – Grade nie über den rohen `sortOrder` skalenübergreifend vergleichen.**
  `GradeSystem.sortOrder(of:)` ist ein Index in die *eigene* Picker-Leiter – Fb vs. V-Scale
  bzw. French vs. UIAA sind damit nicht vergleichbar (6B+ „schlug" V5). Für Vergleiche/Maxima
  über Skalen hinweg: `Ascent.canonicalOrder` (Index in der gemeinsamen Disziplin-Leiter des
  `GradeConverter`, Fallback eigene Skala). Boulder- und Seilgrade bleiben grundsätzlich
  getrennt (Charts: `DisciplinePicker`). `gradePyramid`/`maxGradeTrend` arbeiten pro Disziplin
  und konvertieren ins Anzeige-System. ACWR: Akutlast = aktuelle Woche, chronisch = 4-Wochen-Ø;
  sRPE ohne erfasstes RPE zählt 0 (S27: nie schätzen – gilt auch für Körpergewicht beim
  Fingerkraft-Trend → Chart zeigt Zusatzgewicht).

**S31 – Fortschritt statt Belastung.**
  Die Auswertung beantwortet „Werde ich besser?", nicht „Bin ich überlastet?". **Keine**
  ACWR-/Deload-/Form-/Fatigue-Deutungsschicht und keine RPE-/Minuten-Trend-Charts mehr
  (in TODO12/FO-13 entfernt). RPE, HF und Dauer werden weiterhin **erfasst** und als
  **Rohwerte** im Session-Detail gezeigt – aber nicht mehr in Belastungs-Kennzahlen
  gedeutet. Neue Auswertungen leben in `ProgressEngine` (rein funktional, `Discipline`
  boulder/rope, nie gemischt); `StatsEngine` bleibt ausschließlich Erfolge + Session-
  Insights. Referenz: `FORTSCHRITT-KONZEPT.md`.

**S32 – Ehrliche Statistik oder gar keine.**
  Quoten (Send-Rate, Stil-Quoten, Wohlfühl-Grad) werden erst ab `minSampleSize = 5`
  Begehungen gezeigt und tragen die Stichprobe sichtbar mit; darunter: nichts, kein
  Ein-Begehung-Prozentwert. In Zeitreihen sind Monate ohne Daten **Lücken**, keine
  Nullen (Ausnahme: Klettertage/Volumen, wo 0 eine echte Aussage ist). **Kein
  `attempts`-basierter Wert** (z. B. „Ø Versuche bis Top") bis es eine echte Route-
  Identität gibt – Watch-Ascents haben `attempts = 1`, das verfälscht jede Quote
  (FB-8). Schwellen (`comfortSendQuote = 0.6`, `minSampleSize = 5`) zentral in
  `ProgressEngine`. Grad-Vergleiche über `canonicalOrder` (S30), Anzeige in der
  eingestellten Skala. Referenz: `FORTSCHRITT-KONZEPT.md` Abschnitt 4.

**S33 – Motivation ohne Manipulation.** Gefeiert werden ausschließlich echte,
aus den Daten belegte Ereignisse (Erst-Send, PB, Unlock, Comeback) — genau
einmal, im Moment ihres Entstehens (Feier-Kanal: `AchievementUnlockOverlay`,
sonst keiner). Keine Schuld-Mechanik: kein „Du warst lange nicht klettern",
kein bestrafender Streak-Reset als alleinige Anzeige (Rekord steht daneben),
keine Engagement-Notifications ohne Ereignis. Keine variable Belohnung ohne
Leistungsbezug (rotierende Inhalte deterministisch pro Woche), keine
Punkte-/XP-Ökonomie (Overjustification). Nähe zu Zielen mit echten Zahlen,
nie mit Prognosen; Leerzustände zeigen Fortschritt zur Schwelle (n/5) statt
Quoten darunter. Umsetzung: TODO13-MOTIVATION.md (Motivations-Layer, macht
Fortschritt *sichtbar*), Feier-Ebene: TODO13-ERFOLGE-PREMIUM.md/S34. Referenz:
`FORTSCHRITT-KONZEPT.md` Abschnitt „Motivations-Layer (TODO13)".

**S34 – Erfolge sind persistierte Ereignisse, kein Live-Zustand.** Ein Erfolg
entsteht ausschließlich über `AchievementEngine.evaluate` (rein, aus Sessions/
Projekten/bestehenden Unlocks) und wird als `AchievementUnlock` persistiert —
niemals als bei jedem Render neu abgeleiteter Boolean (das war W1 der
Alt-Architektur: löschbare Vergangenheit, kein „Freigeschaltet am …"). Einmal
freigeschaltet bleibt freigeschaltet, auch wenn die auslösenden Daten später
gelöscht werden (Widerrufs-Politik). Feiern nur über `transform`/`opacity`
(kein animiertes Layout/Blur), vollständig abschaltbar
(`achievementEffectsEnabled`) und `accessibilityReduceMotion` wird zusätzlich
immer respektiert. Keine wöchentlich/monatlich wiederkehrenden Erfolge
(Spam-/Übertrainings-Nudge, S31) — nur einmalige, gestufte oder pro-Ereignis
wiederholbare Definitionen. Referenz: `ERFOLGE-KONZEPT-V2.md`.
**ER-1-Entscheidung (TODO15):** S34 bleibt unangetastet (Option A, kein
Widerruf). Testdaten-Aufräumen läuft über einen `#if DEBUG`-Button „Erfolge
neu berechnen" in `SettingsView` (löscht alle Unlocks, wertet neu aus,
markiert sofort als gesehen) — kein Produktions-Widerruf, keine neue Regel.

**S35 – WatchConnectivity-Callbacks (`onCommand`, `onListsUpdated`) gehören in
den Singleton, nie in eine View.** Ein `SyncService.onCommand`-Wiring in
`LiveSessionView.onAppear` verpuffte, sobald eine andere View aktiv war
(End-Flow, Auswahl) oder `onAppear` erneut feuerte — der iPhone-Banner-Befehl
kam nie an, ohne dass irgendwo ein Fehler sichtbar wurde. Callbacks mit
App-weiter Gültigkeit einmalig in `WorkoutManager.init()` registrieren
(Singleton-Lebensdauer), nicht an einen View-Lifecycle koppeln. Guards gegen
doppelte/verspätete Zustellung (`isPaused`-Check vor `pauseWorkout()`, analog
zum bestehenden S4-Muster) sind Pflicht, sobald ein Befehl mehrfach oder
verspätet ankommen kann (`transferUserInfo` ist nicht Echtzeit).

**S36 – Cache-Persistenz muss auch den Leer-Zustand explizit schreiben.**
`saveListCache()` schrieb nur bei nicht-leerer Liste (`if !list.isEmpty`) —
das letzte gelöschte Element „überlebte" jeden Watch-Neustart, weil der alte,
nicht-leere Cache-Eintrag nie überschrieben wurde. Ein Cache, der einen
Löschvorgang korrekt abbilden soll, muss `[]` genauso persistieren wie jeden
anderen Zustand. Gilt für jeden Watch-seitigen Empfangs-Cache (Listen,
Flags) — „leer" ist ein echter, speicherwürdiger Zustand, kein Fehlen von Daten.

**S37 – Die Mitte einer Skala ist kein neutraler Default.** Ein
`gradeIndex = count / 2`-Fallback traf bei der 18-teiligen French-Leiter exakt
den plausibel wirkenden Grad „7a" — sah wie eine echte Vorbelegung aus, war
aber Zufall der Leiterlänge. Ein Fallback ohne echte Grundlage sollte
**erkennbar** falsch sein (z. B. Index 0 = niedrigster Grad), nicht zufällig
einen glaubwürdigen Wert treffen — sonst bleibt der Nutzer-Fehler unbemerkt.
Gilt allgemein für jeden „Mitte der Range"-Default über echten fachlichen
Werten (Grade, Prozentsätze, Datumsbereiche).

**S38 – CloudKit-Voraussetzungen sind ein Schema-Umbau, kein Schalter.**
`ModelConfiguration(cloudKitDatabase:)` „einschalten" allein crasht/verliert
Daten: CloudKit verbietet `@Attribute(.unique)` (keine Unique-Constraints) und
verlangt für **jedes** nicht-optionale Attribut einen deklarierten Default
(`= wert`, nicht nur eine Zuweisung im `init`). CK-P0 hat das über alle 7
`@Model`-Klassen nachgezogen, ohne CloudKit zu aktivieren — Dedupe-Logik
(`watchSessionID`-Upsert etc.) bleibt bewusst app-seitig, da CloudKit dafür
keinen DB-Mechanismus bietet. Referenz: TODO15-FEEDBACK-CLOUD.md CK-1.

---

*Dieses Dokument bei jeder größeren Entscheidung/jedem Fix aktualisieren, damit der rote Faden
erhalten bleibt.*
