# TODO – Memory-Leak lokalisieren (Issue 2 Root Cause)

**Branch:** `dev`
**Bestätigt durch Test (watchDiagnostics, 13:34–15:38):**
Speicher flach bei 25–29 MB für 33 min, dann **linearer Anstieg ~8–10 MB/min ab 14:08**,
bis ~169 MB → **Jetsam-Kill + Neustart** (`app launch #3 mem=16MB` um 14:41). Danach
`recoveredActiveSession state=2` → Session lebte, nur der Prozess war neu.

⇒ **Issue 2 = Memory-Leak**, kein watchOS-Hintergrund-Reclaim. Issue 1 (max HF-Reset) ist eine
Folge davon: jeder Jetsam-Neustart triggert `reattach()`.

**Statisch ausgeschlossen:** unbegrenzte Arrays im Code, zusätzliche CoreMotion-Streams,
HR-Historie/Charts in Views, `AttemptDetector` (auf `dev` nicht vorhanden), Altimeter (1/s,
nur Skalare). Leck ist framework-seitig **oder** an eine Aktion um 14:08 gebunden.

Diese Datei: (1) Aktions-Breadcrumbs, damit der nächste Test den Auslöser zeigt,
(2) ein A/B-Isolationsexperiment, (3) eine Defensiv-Härtung der Streaming-Queries.

---

## TEIL A – Aktions-Breadcrumbs (zeigt den Auslöser im Log)

Ziel: Im nächsten Test soll exakt sichtbar sein, welche Aktion mit dem Speicher-Knick
zusammenfällt. Nur leichtgewichtige `DiagnosticLog.shared.log(...)`-Aufrufe – kein
Verhaltens­wechsel.

### A1 – Tab-Wechsel in LiveSessionView

In `LiveSessionView.swift`, am `body` der View einen Observer ergänzen (zu den bestehenden
`.onChange`-Modifiern):

```swift
.onChange(of: currentTab) { _, tab in
    DiagnosticLog.shared.log("tab=\(tab) mem=\(MemoryFootprint.residentMB())MB")
}
```

### A2 – Action-Button-Zustand

In `WorkoutManager.handleActionButton()` am Ende jedes `case` (oder einmal am Methodenende)
den neuen Zustand loggen:

```swift
DiagnosticLog.shared.log("actionButton -> \(String(describing: attemptState)) mem=\(MemoryFootprint.residentMB())MB")
```

### A3 – Ascent-Tracking Start/Stop (Altimeter)

`startAscentTracking()` und `stopAscentTracking()` laufen im `AltimeterService`-Actor – dort
ist `DiagnosticLog` (MainActor) nicht direkt erreichbar. Stattdessen an den **Aufrufstellen**
im `WorkoutManager` loggen:
- in `handleActionButton` (`.idle` → `.active`, vor/nach `altimeter.startAscentTracking()`)
- in `quickBank` und `bankAttempt` (vor `altimeter.startAscentTracking()`)
- in `quickBank`/`bankAttempt` nach `altimeter.stopAscentTracking()`

Beispiel:
```swift
DiagnosticLog.shared.log("ascentTracking start mem=\(MemoryFootprint.residentMB())MB")
```

### A4 – Sheets / Sub-Views

`onAppear`/`onDisappear`-Logs in den Views, die während des Kletterns geöffnet werden:
- `AttemptLogView` (`.onAppear { DiagnosticLog.shared.log("AttemptLogView appear") }`)
- `SessionEndQuestionnaireView` (appear/disappear)
- Projekt-Picker: in `LiveSessionView` `.onChange(of: showProjectPicker) { _, open in
  DiagnosticLog.shared.log("projectPicker \(open ? "open" : "close")") }`

### A5 – Speicher-Delta pro Minute (Knick sofort sichtbar)

Im bestehenden 60-s-Memory-Tick (`WorkoutManager.startTimer`, `memTickCount >= 30`) das Delta
zum letzten Tick mitloggen. Neues Property `private var lastMemMB = 0`, dann:

```swift
let m = MemoryFootprint.residentMB()
let d = m - self.lastMemMB
self.lastMemMB = m
DiagnosticLog.shared.log("tick mem=\(m)MB Δ=\(d >= 0 ? "+" : "")\(d) hr=\(Int(self.heartRate)) max=\(Int(self.maxHeartRate))")
```

> Damit springt die Zeile mit dem ersten großen `Δ+` genau auf den Auslöser-Zeitpunkt – und
> die Breadcrumbs (A1–A4) direkt daneben zeigen, welche Aktion es war.

---

## TEIL B – A/B-Isolationsexperiment (falls Breadcrumbs nicht reichen)

Wenn der Auslöser aus den Breadcrumbs nicht eindeutig ist, die Sensor-Streams nacheinander
deaktivieren (jeweils ein eigener Test-Build, gleiche ~30-min-Bedingung). Stil wie A/A2/A3:

- **Experiment L1 – Altimeter aus:** In `startWorkout` (und `reattach`) `await altimeter.start()`
  auskommentieren sowie alle `altimeter.startAscentTracking()`-Aufrufe. Test ~30 min.
  → Speicher flach? **Altimeter ist die Quelle.**
- **Experiment L2 – Energie-Query aus:** Altimeter wieder an, `startStreamingEnergy()` nicht
  aufrufen. Test. → flach? **Energie-Query ist die Quelle.**
- **Experiment L3 – HR-Query aus:** nur `startStreamingHeartRate()` weglassen. Test.
  → flach? **HR-Query ist die Quelle.**
- **Experiment L4 – Builder aus:** `wb.beginCollection` / `self.builder = wb` weglassen
  (Session bleibt, nur kein Builder). Test. → flach? **Builder retainiert Samples.**

Jeweils das Ergebnis in `FEHLERSUCHE.md` mit Label (L1–L4) festhalten.

> Erwartung nach Code-Lage: L1 (Altimeter) und L4 (Builder) sind die wahrscheinlichsten
> Kandidaten, weil beide framework-seitig kontinuierlich laufen. Der Knick um 14:08 deutet aber
> auf eine **ausgelöste** Aktion hin – deshalb zuerst die Breadcrumbs (Teil A) auswerten.

---

## TEIL C – Defensiv-Härtung Streaming-Queries (unabhängig sinnvoll)

`startStreamingHeartRate()` / `startStreamingEnergy()` stoppen aktuell **keine** bereits
laufende Query, bevor sie eine neue starten. Falls je ein Pfad sie doppelt aufruft (Race
zwischen `startWorkout` und `recoverIfNeeded`, o. ä.), laufen mehrere Anchored-Queries parallel
und halten je internen Zustand. Defensiv absichern:

In beiden Methoden **ganz am Anfang**:
```swift
if let q = hrQuery { store.stop(q); hrQuery = nil }       // in startStreamingHeartRate
```
```swift
if let q = energyQuery { store.stop(q); energyQuery = nil } // in startStreamingEnergy
```

> Erklärt zwar kaum 10 MB/min allein, ist aber korrekt und schließt eine Fehlerquelle aus.

### Altimeter-Härtung (optional, in `AltimeterService.start()`)

Statt pro Höhen-Update ein `Task { await self?.handleAltitude(rel) }` zu spawnen, eine serielle
Queue mit `maxConcurrentOperationCount = 1` verwenden, damit sich bei Verzögerung keine
Operationen/Tasks stauen:

```swift
let queue = OperationQueue()
queue.qualityOfService = .utility
queue.maxConcurrentOperationCount = 1   // NEU
```

---

## Erwartetes Ergebnis nächster Test

Im exportierten Log sollte erkennbar sein:
1. Eine `tick … Δ+`-Zeile, ab der das Wachstum beginnt.
2. Direkt davor/daneben eine Breadcrumb (`tab=…`, `actionButton -> …`, `ascentTracking start`,
   `AttemptLogView appear`, `projectPicker open`).

Damit benennen wir die Aktion – und (über Teil B falls nötig) die Komponente – eindeutig.
Größeren Umbau der gefundenen Quelle erst nach Rücksprache.
