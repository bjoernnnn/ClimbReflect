# TODO – Gesamt: Memory-Leak-Fix (Altimeter) + Recovery-Absicherung nach Jetsam

**Branch:** `dev` @ `89eb055`
**Eine Datei, alles drin.** Reihenfolge: TEIL 1 → 2 → 3, dann testen (TEIL 4).
Diese Datei ersetzt `TODO-LEAK-RUNDE2-ALTIMETER.md` und `TODO-RECOVERY-NACH-JETSAM.md`.

---

## Befund (Zusammenfassung aus 4 Diagnose-Läufen)

1. **Memory-Leak:** Speicher flach bis zum **ersten gebankten Versuch**, danach linear
   ~8–11 MB/min bis ~230 MB → **watchOS-Jetsam-Kill** (≈ alle 30 min). Reproduziert in mehreren
   Läufen; früher Bank → früher Leak. Das verschachtelte TabView wurde per Test **L-A
   ausgeschlossen** (Leak trat trotz deaktivierter `historyPage` auf). Einziger
   **kontinuierlicher, bank-getriggerter** Prozess ist die **Altimeter-Höhenmessung**: durch das
   Auto-Re-Arm (`startAscentTracking()` nach jedem Bank) bleibt die CMAltimeter-Subscription +
   die laufende `totalGain`/`@Published`-Aktualisierung **dauerhaft aktiv** statt nur während
   eines Versuchs.

2. **Recovery nach Jetsam:** Nach dem Kill greift die Wiederherstellung manchmal nicht
   (kein `recoveredActiveSession`). Dann landet die **Watch in der Sportauswahl**, während das
   **Handy die Live-Anzeige weiterführt** – weil in den Recovery-Fehlerpfaden kein „Session
   beendet" ans Handy geht und die Pending-Session nicht finalisiert wird.

**Strategie:** TEIL 1 behebt die Leak-Wurzel (Altimeter nur noch während echter Versuche aktiv).
TEIL 2+3 sichern den Fall ab, dass watchOS die App doch beendet (Watch/Handy laufen nie
auseinander). TEIL 4 verifiziert; falls der Leak wider Erwarten bleibt, steht der
Instruments-Fallback drin.

---

## TEIL 1 – Leak-Fix: Altimeter-Subscription nur während eines Versuchs

### 1.1 `AltimeterService.swift` komplett ersetzen

Datei `ClimbReflectWatch Watch App/Services/AltimeterService.swift` durch folgenden Inhalt
ersetzen:

```swift
import CoreMotion
import Foundation

// Höhenmessung via CMAltimeter.
// LEAK-FIX: Die Relative-Altitude-Subscription läuft NUR während eines aktiven Versuchs
// (startAscentTracking … stopAscentTracking) – nicht über die ganze Session. Damit kann
// CoreMotion keine Daten über Minuten/Stunden akkumulieren.
// totalGain: Netto-Höhe des aktuellen Versuchs (0 außerhalb eines Versuchs).

actor AltimeterService {
    private let altimeter = CMAltimeter()
    private(set) var totalGain: Double = 0
    private var tracking = false
    private var ascentMaxAltitude: Double = 0

    /// No-op: Subscription wird erst in startAscentTracking() gestartet.
    /// (Aufrufe in startWorkout()/reattach() bleiben unschädlich.)
    func start() {}

    /// Hartstopp bei Session-Ende: sicherstellen, dass keine Updates mehr laufen.
    func stop() {
        if tracking { altimeter.stopRelativeAltitudeUpdates() }
        tracking = false
        totalGain = 0
        ascentMaxAltitude = 0
    }

    /// Beginnt einen Versuch: startet Höhen-Updates und misst die Netto-Höhe.
    func startAscentTracking() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        ascentMaxAltitude = 0
        totalGain = 0
        guard !tracking else { return }      // doppelten Start vermeiden
        tracking = true
        let queue = OperationQueue()
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let rel = data.relativeAltitude.doubleValue
            Task { [weak self] in await self?.handleAltitude(rel) }
        }
    }

    /// Beendet den Versuch, stoppt Höhen-Updates, gibt Netto-Höhe (max − 0) zurück.
    func stopAscentTracking() -> Double {
        let gain = max(0, ascentMaxAltitude)   // base = 0, da relativeAltitude bei Start = 0
        if tracking { altimeter.stopRelativeAltitudeUpdates() }
        tracking = false
        totalGain = 0
        ascentMaxAltitude = 0
        return gain
    }

    private func handleAltitude(_ rel: Double) {
        guard tracking else { return }
        if rel > ascentMaxAltitude { ascentMaxAltitude = rel }
        totalGain = ascentMaxAltitude
    }
}
```

> Effekt: Zwischen Versuchen keine Subscription, `totalGain = 0`, keine `totalAltitudeGain`-
> `@Published`-Updates → kein Dauerprozess mehr, der mit der Zeit Speicher zieht.

### 1.2 Auto-Re-Arm entfernen (`WorkoutManager.swift`)

**In `quickBank(result:)`** diese zwei Zeilen (direkt nach `attemptState = .idle`) **löschen**:

```swift
        DiagnosticLog.shared.log("ascentTracking start mem=\(MemoryFootprint.residentMB())MB")
        await altimeter.startAscentTracking()
```

**In `bankAttempt(gradeSystem:grade:result:style:)`** diese zwei Zeilen (direkt nach
`savePendingSnapshot()`) **löschen**:

```swift
        DiagnosticLog.shared.log("ascentTracking start mem=\(MemoryFootprint.residentMB())MB")
        await altimeter.startAscentTracking()
```

> Die `stopAscentTracking()`-Zeilen am Anfang beider Methoden **bleiben**. Scharfgeschaltet wird
> nur noch in `handleActionButton()` (`.idle → .active`, dort bleibt
> `Task { await altimeter.startAscentTracking() }` unverändert).

### 1.3 Keine weiteren Änderungen nötig

- `await altimeter.start()` in `startWorkout` und `reattach`: bleibt stehen (jetzt No-op).
- `await altimeter.stop()` in `endWorkout`/`discardWorkout`/Delegate: bleibt (Hartstopp).

### Hinweis zur Verhaltensänderung (bewusst)

Höhe wird jetzt nur erfasst, wenn ein Versuch über den **Action-Button** gestartet wurde
(`.idle → .active`). Wird ein Versuch **nur** über die AttemptLogView gebankt, ohne vorher den
Action-Button zu drücken, ist `altitudeGain = 0`. Das ist korrekter als vorher (vorher
akkumulierte zwischen den Versuchen nur Sensor-Rauschen). Falls du Höhe auch für
AttemptLogView-Begehungen willst, bitte Rücksprache – das lösen wir dann separat ohne
Dauer-Subscription.

---

## TEIL 2 – Recovery-Branch protokollieren (`WorkoutManager.swift`)

Damit ein erneuter Recovery-Fehler eindeutig ist.

**In `recoverIfNeeded()`** den HK-Block so erweitern:

```swift
        if HKHealthStore.isHealthDataAvailable(),
           let recovered = try? await store.recoverActiveWorkoutSession() {
            DiagnosticLog.shared.log("recover: hk session state=\(recovered.state.rawValue)")
            await reattach(to: recovered)
            return
        }
        DiagnosticLog.shared.log("recover: keine HK-Session – finalize")
        await finalizeUnrecoverableSession()
```

> (Ersetzt den bisherigen Aufruf `recoverPendingSessionIfNeeded()` durch
> `await finalizeUnrecoverableSession()` – siehe TEIL 3.)

**In `reattach(to:)`** den Guard erweitern:

```swift
        guard ws.state == .running || ws.state == .paused else {
            DiagnosticLog.shared.log("reattach abgebrochen: state=\(ws.state.rawValue)")
            await finalizeUnrecoverableSession()
            return
        }
```

> `state.rawValue`: 1=notStarted, 2=running, 3=ended, 4=paused, 5=prepared, 6=stopped.

---

## TEIL 3 – Saubere Finalisierung + Handy-Reconciliation

Ziel: In **jedem** Pfad, in dem die Session nicht wieder aufgenommen wird, sind Watch (→ Auswahl)
und Handy (→ Live-Anzeige beendet) synchron.

### 3.1 Neue Methode `finalizeUnrecoverableSession()` einfügen

Im `WorkoutManager` (z. B. direkt nach `reattach(to:)` oder anstelle des alten
`recoverPendingSessionIfNeeded()`):

```swift
/// Session kann nicht wieder aufgenommen werden → sauber finalisieren:
/// Begehungen ans Handy syncen (falls vorhanden) und Handy-Live-Anzeige in jedem Fall beenden.
private func finalizeUnrecoverableSession() async {
    if let pending = PendingSessionStore.load(), !pending.ascents.isEmpty {
        let avg: Double? = {
            guard let sum = pending.hrSum, let cnt = pending.hrCount, cnt > 0 else { return nil }
            return sum / Double(cnt)
        }()
        let dto = WatchSessionDTO(
            id: pending.id,
            workoutUUID: nil,
            date: pending.startDate,
            durationSeconds: -pending.accumulatedPaused + Date().timeIntervalSince(pending.startDate),
            sessionTypeRaw: pending.sessionTypeRaw,
            avgHeartRate: avg,
            maxHeartRate: pending.maxHeartRate,
            activeEnergyKcal: pending.activeEnergyKcal,
            altitudeTotalGain: 0,
            ascents: pending.ascents,
            rpe: nil, focusRaw: nil, energyRaw: nil
        )
        SyncService.shared.send(dto: dto)
        DiagnosticLog.shared.log("finalize: DTO gesendet ascents=\(pending.ascents.count)")
    } else {
        DiagnosticLog.shared.log("finalize: keine ascents – nur Live-Status löschen")
    }
    PendingSessionStore.clear()
    clearLiveStatus()      // leeres Data → Handy setzt liveStatus = nil (Live-Anzeige aus)
    isRunning = false
}
```

### 3.2 Altes `recoverPendingSessionIfNeeded()` entfernen

Die Methode `recoverPendingSessionIfNeeded()` wird durch `finalizeUnrecoverableSession()` ersetzt
und kann gelöscht werden (sie wird nach den Änderungen in TEIL 2 nicht mehr aufgerufen). Vorher
prüfen, dass es keine weiteren Aufrufer gibt:
`grep -n "recoverPendingSessionIfNeeded" .` → sollte 0 Treffer ergeben.

> `clearLiveStatus()` existiert bereits (private, sendet leeres `Data` via
> `updateApplicationContext`). Auf iOS-Seite wird leeres `Data` schon als „session ended"
> interpretiert (`liveStatus = nil`).

---

## TEIL 4 – Test & Verifikation

### 4.1 Leak-Verifikation (Pflicht)
1. Build, Watch-App, Session starten.
2. **2–3 Versuche** über den Action-Button starten **und** banken.
3. ~15 min ruhig laufen lassen, Diagnose-Log beobachten (`tick … Δ=…`).
4. **Erwartet:** Speicher bleibt flach (Δ≈0), evtl. kleine kurzlebige Anstiege **während** eines
   aktiven Versuchs, die danach wieder fallen. **Kein** dauerhafter `app launch #N`-Jetsam mehr.

- **Flach → Leak behoben. Fertig.**
- **Steigt weiter** → Quelle ist nicht (nur) der Altimeter. Dann **nicht** weiter raten, sondern
  **Instruments** (siehe 4.3) und Ergebnis melden.

### 4.2 Recovery-Verifikation
1. Während einer Session die App hart beenden lassen (oder Jetsam abwarten, falls 4.1 nicht
   sofort greift).
2. Beim Wieder-Öffnen ins Diagnose-Log schauen:
   - `recover: hk session state=…` bzw. `recover: keine HK-Session – finalize`
   - ggf. `reattach abgebrochen: state=…` + `finalize: …`
3. **Erwartet:** Entweder saubere Wiederaufnahme (`recoveredActiveSession`) **oder** Watch in der
   Auswahl **und** Handy-Live-Anzeige beendet – nie mehr beides auseinander.

### 4.3 Instruments-Fallback (nur falls 4.1 nicht flach)
Xcode → Product → Profile (⌘I) → **Allocations**. Session starten, 1 Versuch banken, 3–5 min
laufen lassen, „Mark Generation" alle 60 s. Der Allocation-Typ mit stetig wachsenden
„Persistent Bytes" über die Generations ist das Leck → Namen an mich, dann ziele ich gezielt.

---

## Reihenfolge & Commit

1. TEIL 1 (Altimeter) + TEIL 2 (Logging) + TEIL 3 (Finalize) umsetzen.
2. `grep -n "recoverPendingSessionIfNeeded" .` → 0 Treffer prüfen.
3. Bauen, Test 4.1 + 4.2.
4. Committen + nach `origin/dev` pushen (auch die noch lokalen Breadcrumb-/maxHF-Stände, falls
   nicht schon geschehen).

## Offen / nachgelagert (nicht in dieser Datei umsetzen)
- L-A-Teständerung (`historyPage` auskommentiert) wieder aktivieren, sobald der Leak bestätigt
  behoben ist.
- Optional „Session aus Snapshot fortsetzen" statt finalisieren – erst nach Recovery-Logdaten,
  mit Rücksprache.
