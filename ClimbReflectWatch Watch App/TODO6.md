# ClimbReflect – TODO5 (priorisiert für Claude Code)

Stand: Review auf Branch `feature/projects` (Commit `a0813da`).
Bitte **von oben nach unten** abarbeiten (P0 → P1 → P2 → P3), innerhalb einer Stufe
in der angegebenen Reihenfolge. Jeder Punkt hat *Kontext*, betroffene *Dateien*, die
*Aufgabe* (Schritt für Schritt) und ein *Fertig-wenn*-Kriterium.

## Arbeitsweise

- Pfade sind **relativ zur Repo-Wurzel**. Der iOS-Quellcode liegt verschachtelt unter
  `ClimbReflect/ClimbReflect/ClimbReflect/`, die Watch-App unter `ClimbReflectWatch Watch App/`.
- Eine Aufgabe = ein Commit mit sprechender Message. Nach jeder Aufgabe kompilieren und
  betroffene `#Preview`s prüfen.
- Stil beibehalten: deutsche UI-Strings, `Theme`/`WatchTheme`-Farben, MVVM-nah,
  `StatsEngine` rein funktional.
- **P0 zuerst vollständig** – das sind drei stille Datenfehler. Insbesondere **P0-3
  VOR dem Merge von `feature/projects` nach `main`**, weil dieser Merge ein Schema-Change ist.

## Status der Projekt-Funktion (NICHT neu bauen)

Die Mehr-Session-Projekte sind auf `feature/projects` bereits end-to-end umgesetzt
(`Project` als `@Model` mit Relationship, Migration, iPhone-Picker, Watch-Picker,
DTO-Transfer mit `projectID`, Rück-Verlinkung beim Empfang). Hier ist **kein** Neubau
nötig – nur die Robustheits-Punkte P2-7/P2-8.

---

## P0 – Stille Datenfehler (zuerst, in dieser Reihenfolge)

### P0-1 — Watch: korrekte Ø-Herzfrequenz senden  *(= „Punkt 1")*
- *Kontext:* Beim Beenden wird `avgHeartRate: heartRate > 0 ? heartRate : nil` gesendet.
  `heartRate` ist aber der zuletzt per `mostRecentQuantity()` empfangene **Momentanwert**,
  nicht der Session-Durchschnitt. Auf dem iPhone steht das als „Ø HF" – falsch.
  (Der iPhone-Import via `discreteAverage` macht es bereits korrekt; nur der Watch-Pfad nicht.)
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:*
  1. In `endWorkout()` **vor** `wb.finishWorkout()` den HealthKit-Durchschnitt lesen:
     ```swift
     let bpmUnit = HKUnit.count().unitDivided(by: .minute())
     let hrStats = builder?.statistics(for: HKQuantityType(.heartRate))
     let avgHR = hrStats?.averageQuantity()?.doubleValue(for: bpmUnit)
     let maxHR = hrStats?.maximumQuantity()?.doubleValue(for: bpmUnit)
     ```
  2. Im DTO `avgHeartRate: avgHR` und `maxHeartRate: maxHR ?? (maxHeartRate > 0 ? maxHeartRate : nil)`.
  3. **Fallback** für den Fall, dass das HK-Setup fehlschlug (`builder == nil`): laufenden
     Mittelwert mitführen. In `workoutBuilder(_:didCollectDataOf:)` beim HR-Sample
     `hrSum += bpm; hrCount += 1` zählen (zwei neue `private var`), und am Ende
     `avgHR ?? (hrCount > 0 ? hrSum / Double(hrCount) : nil)` verwenden.
- *Fertig-wenn:* Nach einer Session zeigt das iPhone eine Ø-HF, die plausibel zwischen
  Ruhe- und Max-HF liegt (nicht den letzten Messwert). Bei fehlgeschlagenem HK-Setup ist
  der Wert entweder der laufende Mittelwert oder `nil`, nie der Momentanwert.

### P0-2 — Watch: Höhenmeter-Rauschen filtern  *(= „Punkt 3")*
- *Kontext:* `AltimeterService.handleAltitude` addiert **jedes** positive Delta auf
  `totalGain`. Barometrische Relativhöhe rauscht/driftet → über eine 2-h-Session summieren
  sich leicht zweistellige Phantom-Höhenmeter. Für „Wie viel bin ich heute geklettert?"
  unbrauchbar genau.
- *Dateien:* `ClimbReflectWatch Watch App/Services/AltimeterService.swift`
- *Aufgabe:*
  1. Rausch-Schwelle einführen:
     ```swift
     private let noiseFloor = 0.3  // Meter; darunter = Sensorrauschen
     // in handleAltitude(_:):
     if delta > noiseFloor { totalGain += delta }
     ```
  2. Optional robuster: vor der Delta-Bildung die rohe Höhe leicht glätten (gleitender
     Mittelwert über die letzten 3–5 Samples). Die Per-Versuch-Netto-Höhe
     (`ascentMaxAltitude - base`) ist von max-min ohnehin robust; dort genügt die Glättung.
- *Fertig-wenn:* Eine ruhige 60-Min-Session ohne echte Höhenänderung erzeugt ≈ 0 m
  `totalGain` statt zweistelliger Werte; reale Aufstiege (Seil) werden weiterhin gezählt.

### P0-3 — Stillen Daten-Delete durch versionierte Migration ersetzen  *(= „Punkt 4")*
- *Kontext:* Der `catch`-Block in `ClimbReflectApp.init` löscht bei fehlgeschlagener
  Container-Erstellung den **kompletten** Store (inkl. wal/shm) – ohne Hinweis. Der Merge
  von `feature/projects` nach `main` ist genau so ein Schema-Change (neue Relationship
  `Ascent.project`, neue `Project`-Felder, neues `ProjectMedia`-Model) → erhöhtes Risiko,
  dass echte Nutzerdaten verschwinden. Ohne CloudKit-Backup ist das der gefährlichste Punkt.
- *Dateien:* `ClimbReflect/ClimbReflect/ClimbReflect/ClimbReflectApp.swift`
  (+ neue Datei für `SchemaMigrationPlan`)
- *Aufgabe:*
  1. **Migration absichern:** Eine `VersionedSchema` für die alte (main) und neue
     (projects) Schema-Version anlegen und einen `SchemaMigrationPlan` mit **lightweight**
     `MigrationStage` (die Änderungen sind additiv → kein Custom-Code nötig). Den Container
     mit `migrationPlan:` erzeugen.
  2. **Auto-Delete entschärfen:** Das Löschen nur noch in `#if DEBUG`. Im Release-Build
     **nicht** löschen, sondern den Store sichern und den Fehler sichtbar machen:
     ```swift
     } catch {
         #if DEBUG
         // bisheriger Reset-Pfad (Store + wal/shm entfernen, neu erstellen)
         #else
         let ts = Int(Date().timeIntervalSince1970)
         let backup = config.url.deletingPathExtension()
             .appendingPathExtension("backup-\(ts).sqlite")
         try? FileManager.default.copyItem(at: config.url, to: backup)
         fatalError("SwiftData-Migration fehlgeschlagen – Store gesichert als \(backup.lastPathComponent)")
         #endif
     }
     ```
     (Bei umgesetztem Migrationsplan greift der `catch` im Normalfall gar nicht.)
- *Fertig-wenn:* Ein Update von der alten Schema-Version (App von `main` mit echten
  Sessions/Begehungen installiert) auf die neue (`feature/projects`) migriert die Daten
  **verlustfrei**. Im Fehlerfall werden im Release keine Daten ohne Sicherung gelöscht.
- *Testhinweis:* Erst `main` bauen, App nutzen (manuelle Session + Begehungen anlegen),
  dann auf `feature/projects` updaten und prüfen, dass alles erhalten ist.

---

## P1 – Verbleibende Funktions-/Konnektivitätsfehler (Watch ist primärer Aufnahmeweg)

> Hinweis: Da die App vollständig standalone funktioniert und die Watch ein Hauptweg
> der Aufnahme ist, treffen diese Fehler den Kernloop – nicht nur Randfälle.

### P1-4 — Boulder-Auto-Erkennung feuert nie (eingefrorene HF)
- *Kontext:* `WorkoutManager.startWorkout` ruft `detector.startMotionDetection(currentHR: heartRate)`
  auf, wenn `heartRate` noch 0 ist. Der Wert wird als Konstante in den Accelerometer-Closure
  eingefangen und nie aktualisiert → die Bedingung `currentHR > 100` (AttemptDetector.swift:52)
  wird nie wahr. Das W4.2-Feature ist tot (der manuelle Action-Button funktioniert, der
  Vorschlag nicht).
- *Dateien:* `ClimbReflectWatch Watch App/Services/AttemptDetector.swift`,
  `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:*
  1. Im Detector eine veränderliche Property statt eines eingefangenen Parameters:
     `var currentHR: Double = 0`; im Burst-Check `self.currentHR > 100` lesen.
  2. `startMotionDetection()` ohne HR-Parameter aufrufen; im WorkoutManager-Timer-Tick
     (in `startTimer`) zusätzlich `detector.currentHR = heartRate` setzen.
- *Fertig-wenn:* Bei Bewegung mit HF > 100 erscheint nach dem Burst ein Versuchsvorschlag;
  solange die HF noch 0/niedrig ist, nicht.

### P1-5 — Doppel-Sessions verhindern (Idempotenz auf der Watch-Session-ID)
- *Kontext:* `WatchSessionReceiver.insert` legt immer eine neue `ClimbSession` an. Es gibt
  keinen Dedupe über `WatchSessionDTO.id`. Doppelzustellung / erneutes Senden
  (Pending-Queue, Fragebogen-Nachsendung, Fern-Ende) erzeugt eine zweite Session.
- *Dateien:* `ClimbReflect/ClimbReflect/ClimbReflect/Services/WatchSessionReceiver.swift`,
  `ClimbReflect/ClimbReflect/ClimbReflect/Models/ClimbSession.swift`
- *Aufgabe:*
  1. `var watchSessionID: UUID?` zu `ClimbSession` hinzufügen (additiv – siehe Migration P0-3).
  2. In `insert(dto:)` per `dto.id` **upserten**: existiert eine Session mit
     `watchSessionID == dto.id`, deren Felder (RPE, Begehungen) aktualisieren statt neu anlegen.
     Beim Neuanlegen `watchSessionID = dto.id` setzen.
- *Fertig-wenn:* Dasselbe DTO zweimal empfangen → genau eine Session; eine nachgereichte
  (angereicherte) Fassung aktualisiert dieselbe Session statt sie zu duplizieren.

### P1-6 — Fern-Beenden vom iPhone überspringt den Fragebogen
- *Kontext:* In `LiveSessionView` sendet `onCommand "end"` das DTO sofort (`rpe = nil`) und
  ruft `finishSession()` – anders als das lokale Beenden, das in den Fragebogen führt. Wer
  vom iPhone-Banner stoppt, bekommt eine Session ohne RPE/Fokus, und auf der Watch
  verschwindet der Fragebogen kommentarlos.
- *Dateien:* `ClimbReflectWatch Watch App/Views/LiveSessionView.swift`
- *Aufgabe:* Im `onCommand`-`"end"`-Zweig denselben Pfad wie lokal nutzen:
  `sessionDTO = await workoutManager.endWorkout(); navPath = [.questionnaire]` (statt sofort
  senden + finishen). **Voraussetzung: P1-5**, damit ein eventuelles Sofort-Senden +
  spätere Anreicherung dieselbe Session trifft.
- *Fertig-wenn:* Beenden über das iPhone-Banner führt auf der Watch in den Fragebogen; die
  resultierende Session hat RPE, sofern beantwortet; keine Doppel-Session.

---

## P2 – Projekt-Kette: Feinschliff (Funktion vorhanden, robuster machen)

### P2-7 — Duplikat-Projekte beim Empfang vermeiden
- *Kontext:* In `WatchSessionReceiver.insert` wird im Name-Fallback ein **neues** `Project`
  angelegt, wenn weder `projectID` noch Name matchen. Bei am iPhone gelöschten/umbenannten
  Projekten oder Nicht-UUID-`ProjectInfo.id` (Namens-Fallback der Watch) entstehen so
  Geister-Duplikate.
- *Dateien:* `ClimbReflect/ClimbReflect/ClimbReflect/Services/WatchSessionReceiver.swift`
- *Aufgabe:* Vor dem Neuanlegen strenger matchen (getrimmt + case-insensitive). Entscheiden
  und dokumentieren: Wenn nur eine `projectID` ohne Match vorliegt → **kein** Neuanlegen,
  sondern `ascent.project = nil` lassen und `projectName` als Cache behalten (das iPhone
  bleibt Source of Truth für Projekte).
- *Fertig-wenn:* Ein auf der Watch getaggter Versuch landet im bestehenden iPhone-Projekt;
  es entstehen keine doppelten Projekte mit identischem Namen.

### P2-8 — Watch-Projektauswahl über App-Neustart erhalten (optional)
- *Kontext:* `WorkoutManager.selectedProject` ist nur In-Memory; bei Watch-App-Neustart
  mitten in der Session (selten, da `workout-processing` die App am Leben hält) verloren.
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:* `selectedProject` in UserDefaults persistieren, solange `isRunning`; beim Start
  wiederherstellen; in `finishSession()` löschen.
- *Fertig-wenn:* Watch-App-Neustart während einer laufenden Session behält das gewählte
  Projekt; nachfolgende Versuche bleiben korrekt zugeordnet.

---

## P3 – UX & Sonstiges (niedriger, aber spürbar)

### P3-9 — Dashboard entlasten (standalone-fokussiert)
- *Kontext:* Das Dashboard stapelt ~14 Karten/Charts in einem einzigen Scroll. Da die App
  standalone ist, muss der schnelle Aufnahme-/Reflexionsweg vorne stehen, nicht hinter
  einer Analytics-Wand.
- *Dateien:* `ClimbReflect/ClimbReflect/ClimbReflect/Views/DashboardView.swift` (+ neue Tab-Container)
- *Aufgabe:* In eine `TabView` aufteilen, z. B. **Heute** (Hero + „+" Quick-Add +
  Live-Banner + letzte Sessions), **Statistik** (alle Charts: Wochen, RPE, Limiter,
  Sessiontyp, Pyramide, Antistyle, Recap), **Projekte**, **Erfolge**.
- *Fertig-wenn:* Die Startansicht zeigt Aufnahme/Reflexion/letzte Sessions ohne langes
  Scrollen; die Analysen sind einen Tab entfernt.

### P3-10 — Grad-Skalen aus einer Quelle
- *Kontext:* Die Picker-Leiter (`Enums.GradeSystem.grades`) und die Converter-Leiter
  (`GradeConverter`) divergieren (V0+, Duplikate, UIAA-Umfang) → `GradeConverter.display`
  kann beim Umschalten der Anzeige-Skala unerwartete/verlustbehaftete Werte liefern.
- *Dateien:* `ClimbReflect/ClimbReflect/ClimbReflect/Models/Enums.swift`,
  `ClimbReflect/ClimbReflect/ClimbReflect/Models/GradeConverter.swift`
- *Aufgabe:* Eine kanonische Leiter pro Disziplin (Boulder/Route) als Source of Truth;
  Picker und Converter daraus ableiten. Echte Mehrdeutigkeiten (ein Fb-Grad ≈ zwei V-Grade)
  als Bereich/„~" kennzeichnen statt still kollabieren.
- *Fertig-wenn:* Anzeige-Skala umschalten ist im Round-Trip stabil und verlustfrei.

### P3-11 — HealthKit-Fehlertext schärfen (optional – Import ist nur Kür)
- *Kontext:* Standalone → der Redpoint-Import ist optional. Wird er genutzt, sind „keine
  Workouts gefunden" und „Zugriff verweigert" ununterscheidbar; die aktuelle Meldung
  verweist nur auf den Redpoint-Export.
- *Dateien:* `ClimbReflect/ClimbReflect/ClimbReflect/Services/RedpointHealthService.swift`,
  `ClimbReflect/ClimbReflect/ClimbReflect/Views/DashboardView.swift`
- *Aufgabe:* Die `noClimbingWorkouts`-Meldung um den Berechtigungs-Fall ergänzen und einen
  Button anbieten, der via `UIApplication.openSettingsURLString` zu den Health-Einstellungen
  springt.
- *Fertig-wenn:* Bei leerem Import-Ergebnis versteht der Nutzer beide möglichen Ursachen und
  kann die Berechtigung direkt prüfen.

---

## Reihenfolge & Abhängigkeiten (Kurzfassung)

1. **P0-1, P0-2, P0-3** (stille Datenfehler) – P0-3 vor dem Merge nach `main`.
2. **P1-5** vor **P1-6** (Dedupe ist Voraussetzung fürs saubere Fern-Beenden).
3. **P1-4** unabhängig.
4. **P2-7 / P2-8** (Projekt-Robustheit), dann **P3** (UX/Feinschliff).
