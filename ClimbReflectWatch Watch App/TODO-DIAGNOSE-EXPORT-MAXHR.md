# TODO – Diagnose-Export, maxHF-Recovery-Fix & App-Neustart-Untersuchung

**Branch:** `dev` (Stand `e732675`)
**Kontext Test6:** App ging nach ~30 min in Hintergrund, beim Wiederöffnen lief der Timer
weiter, aber **max HF wurde auf die momentane HF zurückgesetzt**. 0 Begehungen gebankt.

Diese Datei hat drei Teile:
- **TEIL A** – Diagnose-Export aufs iPhone (keine Fotos mehr) + Lifecycle-/Memory-Instrumentierung
- **TEIL B** – Fix für maxHF-/Energie-/Ø-HF-Reset nach Recovery
- **TEIL C** – Untersuchungsplan App-Neustart (braucht die Daten aus Teil A)

> **Reihenfolge:** A und B können parallel umgesetzt werden. C ist erst nach dem
> nächsten Test mit der neuen Instrumentierung auswertbar.

---

## Root-Cause-Analyse (zur Orientierung – nicht umsetzen, nur lesen)

### Issue 1 – maxHF wird zur momentanen HF

`savePendingSnapshot()` wird **nur** an diesen Stellen gerufen:
- `startWorkout` (am Ende) → dort ist `maxHeartRate == 0` → Snapshot speichert `maxHeartRate = nil`
- `bankAttempt`, `quickBank`, `removeAttempt` → nur wenn eine Begehung mutiert wird

In Test6 wurde **keine** Begehung gebankt. Der Snapshot wurde also **einmal beim Start**
mit `maxHeartRate = nil` geschrieben und danach nie aktualisiert.

Beim Relaunch:
1. `reattach()` lädt den Snapshot. `if let max = p.maxHeartRate { … }` schlägt fehl (nil)
   → `maxHeartRate` bleibt `0`.
2. `startStreamingHeartRate()` läuft. Der Handler nimmt **nur `samples.last`** (= aktuellster
   Sample = momentane HF) und setzt `if finalBpm > maxHeartRate { maxHeartRate = finalBpm }`.
3. Ergebnis: `maxHeartRate = momentane HF`.

**Zusätzliches latentes Problem (Doppelzählung):** Bei jedem (Neu-)Start der Streaming-Query
ist `anchor: nil`. Der erste Callback liefert dann die **komplette Historie seit
`workoutStartDate`**. Für `activeEnergyKcal += delta` und `hrSum/hrCount` bedeutet das: nach
einem Relaunch wird die gesamte Historie erneut auf die aus dem Snapshot wiederhergestellten
Werte addiert → Energie und Ø-HF werden zu hoch.

### Issue 2 – App-Neustart nach ~30 min

- Log zeigt durchgängig `recoveredActiveSession state=2` (`.running`) → **die HKWorkoutSession
  überlebt**. Es ist der **App-Prozess**, der neu gestartet wird (`recoverActiveWorkoutSession()`
  liefert die Session zurück, `reattach()` läuft).
- `WKBackgroundModes` = `["workout-processing"]` ist korrekt als Array in der expliziten
  `ClimbReflectWatch-Watch-App-Info.plist` gesetzt (S1) → Background-Runtime ist da.
- Der maxHF-Reset ist der **Fingerabdruck** von `reattach()`: jeder Reset = genau ein Relaunch.
- Wahrscheinlichste Ursachen: (a) Memory-Jetsam, (b) proaktives Beenden durch watchOS nach
  längerem Hintergrund. **Aktuell nicht unterscheidbar**, weil das Log keine Lifecycle-/Memory-
  Daten enthält. → Teil A liefert genau diese Daten.

---

## TEIL A – Diagnose-Export & Instrumentierung

Ziel: (1) Logs ohne Fotos auf dem iPhone als kopierbaren Text + teilbare Datei sehen,
(2) genug Lifecycle-/Memory-Daten erfassen, um Issue 2 im nächsten Test eindeutig zu
diagnostizieren.

### A1 – Memory-Helper (Resident Memory in MB)

Neue Datei `ClimbReflectWatch Watch App/Services/MemoryFootprint.swift`:

```swift
import Foundation

enum MemoryFootprint {
    /// Resident-Memory des Prozesses in MB (gerundet). 0 bei Fehler.
    static func residentMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return Int(info.resident_size / (1024 * 1024))
    }
}
```

### A2 – Launch-Counter (macht Relaunches im Log sichtbar)

In `WorkoutManager.init()` (nach dem bestehenden `super.init()`-Block) ergänzen:

```swift
let launchCount = UserDefaults.standard.integer(forKey: "launchCount") + 1
UserDefaults.standard.set(launchCount, forKey: "launchCount")
DiagnosticLog.shared.log("app launch #\(launchCount) mem=\(MemoryFootprint.residentMB())MB")
```

> So sehen wir bei jedem Kaltstart eine hochzählende Nummer. Springt die Nummer während
> eines Trainings, wurde die App neu gestartet (≠ nur aus dem Hintergrund geweckt).

### A3 – scenePhase-Logging + Flush bei Hintergrund

In `ClimbReflectWatchApp.swift`:

```swift
@main
struct ClimbReflectWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @Environment(\.scenePhase) private var scenePhase   // NEU

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .task {
                    await workoutManager.requestAuthorization()
                    await workoutManager.recoverIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, phase in           // NEU
            let name: String
            switch phase {
            case .active:     name = "active"
            case .inactive:   name = "inactive"
            case .background: name = "background"
            @unknown default: name = "unknown"
            }
            DiagnosticLog.shared.log("scenePhase=\(name) mem=\(MemoryFootprint.residentMB())MB",
                                     flushImmediately: phase == .background)
        }
    }
}
```

> `flushImmediately` bei `.background` ist wichtig: falls watchOS die App danach beendet,
> ist der letzte Zustand sicher auf Disk.

### A4 – Periodisches Memory-Logging im Timer-Tick

In `WorkoutManager.startTimer()`, im bestehenden `Timer`-Closure (innerhalb des
`Task { @MainActor … }`), einen gedrosselten Memory-Log ergänzen. Es gibt bereits
`liveStatusTickCount` (zählt alle 2 s hoch). Wir hängen einen zweiten Zähler an:

```swift
// am Anfang von startTimer(), vor dem Timer:
memTickCount = 0
```

Neues Property bei den anderen privaten Vars (`liveStatusTickCount` etc.):
```swift
private var memTickCount = 0
```

Im Timer-Closure (nach dem `liveStatusTickCount`-Block) ergänzen:
```swift
self.memTickCount += 1
if self.memTickCount >= 30 {            // 30 × 2 s = alle 60 s
    self.memTickCount = 0
    DiagnosticLog.shared.log("tick mem=\(MemoryFootprint.residentMB())MB hr=\(Int(self.heartRate)) max=\(Int(self.maxHeartRate))")
}
```

> Damit haben wir einen Memory-Verlauf über die ganze Session. Steigt `mem` Richtung
> Jetsam-Grenze, ist es ein Leak; bleibt es flach (~17 MB) und die App startet trotzdem neu,
> ist es watchOS-Reclaim nach Hintergrund.

### A5 – Export-Funktion auf der Watch (SyncService)

In `ClimbReflectWatch Watch App/Services/SyncService.swift` neue Methode ergänzen
(z. B. direkt nach `send(dto:)`):

```swift
// Diagnose-Log ans iPhone übertragen (transferUserInfo → zuverlässig auch im Hintergrund)
func sendDiagnostics(_ entries: [DiagnosticEntry]) {
    guard let data = try? JSONEncoder().encode(entries) else { return }
    WCSession.default.transferUserInfo(["diagnosticLog": data])
}
```

### A6 – Export-Button in der Watch-Diagnose-View

In `ClimbReflectWatch Watch App/Views/DiagnosticView.swift` einen Button oberhalb von
„Log löschen" ergänzen (innerhalb des `else`-Zweigs, vor dem Lösch-Button):

```swift
Button {
    SyncService.shared.sendDiagnostics(log.entries)
    WKInterfaceDevice.current().play(.success)
} label: {
    Text("Ans iPhone senden")
        .font(.caption)
        .foregroundStyle(WatchTheme.accent)   // falls Token anders heißt: WatchTheme.textPrimary
}
```

> `import WatchKit` oben in der Datei ergänzen, falls noch nicht vorhanden (für
> `WKInterfaceDevice`).

### A7 – iOS-Seite: Empfang + Persistenz

In `ClimbReflect/.../Services/WatchSessionReceiver.swift`, in
`session(_:didReceiveUserInfo:)` **vor** dem bestehenden `watchSessionDTO`-Guard die
Diagnose-Behandlung einfügen:

```swift
nonisolated func session(_ session: WCSession,
                         didReceiveUserInfo userInfo: [String: Any] = [:]) {
    if let diagData = userInfo["diagnosticLog"] as? Data {
        Task { @MainActor [self] in self.storeDiagnostics(diagData) }
        return
    }
    guard let data = userInfo["watchSessionDTO"] as? Data else { return }
    // … bestehender Code unverändert …
}
```

Dazu im selben Receiver (als `@MainActor`-Methode + `@Published`):

```swift
@Published var diagnosticLogText: String = ""
@Published var diagnosticLogFileURL: URL?

@MainActor
private func storeDiagnostics(_ data: Data) {
    // Roh-JSON für ShareLink ablegen
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("watchDiagnostics.json")
    try? data.write(to: url, options: .atomic)
    diagnosticLogFileURL = url

    // Lesbaren Text aufbereiten
    struct Entry: Decodable { let timestamp: Date; let event: String }
    guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return }
    let df = DateFormatter(); df.dateFormat = "HH:mm:ss"
    diagnosticLogText = entries
        .map { "\(df.string(from: $0.timestamp))  \($0.event)" }
        .joined(separator: "\n")
}
```

> `WatchSessionReceiver` muss `ObservableObject` sein, damit `@Published` greift. Falls es das
> noch nicht ist: ergänzen und prüfen, dass die Instanz als `@StateObject`/`@ObservedObject`
> in der iOS-View hängt.

### A8 – iOS-Diagnose-Ansicht (kopierbarer Text + Teilen)

Neue Datei `ClimbReflect/.../Views/WatchDiagnosticsView.swift`:

```swift
import SwiftUI

struct WatchDiagnosticsView: View {
    @ObservedObject var receiver = WatchSessionReceiver.shared   // ggf. Singleton-Zugriff anpassen

    var body: some View {
        ScrollView {
            if receiver.diagnosticLogText.isEmpty {
                Text("Noch kein Log empfangen. Auf der Watch in Diagnose → „Ans iPhone senden".")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                Text(receiver.diagnosticLogText)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)   // antippen → markieren → kopieren
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .navigationTitle("Watch-Diagnose")
        .toolbar {
            if let url = receiver.diagnosticLogFileURL {
                ShareLink(item: url)   // JSON-Datei exportieren / teilen
            }
        }
    }
}
```

In `SettingsView.swift` einen `NavigationLink` zu `WatchDiagnosticsView()` ergänzen
(z. B. unter einem Abschnitt „Entwicklung"/„Diagnose").

> Falls `WatchSessionReceiver` kein `.shared`-Singleton hat, den vorhandenen
> Injection-Mechanismus nutzen (er wird in iOS bereits via `configure(modelContext:)`
> aufgesetzt – dieselbe Instanz verwenden).

**Optional (später):** Beim Session-Ende automatisch `sendDiagnostics` mitschicken, dann
ist das Log nach jedem Training ohne manuellen Tap auf dem iPhone.

---

## TEIL B – Fix maxHF / Energie / Ø-HF über Recovery

Ziel: max HF, Ø HF und Energie überleben einen Relaunch korrekt – **ohne Doppelzählung**.
Grundidee: Die Streaming-Queries lesen bei jedem (Neu-)Start ohnehin die **komplette
Historie seit `workoutStartDate`** (`anchor: nil`). Wir machen sie damit zur **maßgeblichen,
idempotenten Quelle** und nutzen den Snapshot nur noch als Anzeige-Startwert.

### B1 – HR-Streaming: alle Samples auswerten + Akkumulatoren vor Start zurücksetzen

In `startStreamingHeartRate()`:

1. **Vor** `store.execute(q)` die Ø-Akkumulatoren zurücksetzen:
   ```swift
   hrSum = 0
   hrCount = 0
   // maxHeartRate NICHT zurücksetzen – max ist idempotent und dient als Anzeige-Seed
   ```
2. Handler so umbauen, dass er **alle** Samples verarbeitet (nicht nur `.last`):
   ```swift
   let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
       [weak self] _, samples, _, _, _ in
       guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty
       else { return }
       let bpms = quantitySamples.map { $0.quantity.doubleValue(for: unit) }
       let lastBpm = bpms.last ?? 0
       let batchMax = bpms.max() ?? 0
       let batchSum = bpms.reduce(0, +)
       let batchCount = bpms.count
       Task { @MainActor [weak self] in
           guard let self else { return }
           self.heartRate = lastBpm
           if batchMax > self.maxHeartRate { self.maxHeartRate = batchMax }
           self.hrSum += batchSum
           self.hrCount += batchCount
       }
   }
   ```

> Einzel-Run: `hrSum/hrCount` ab 0, Voll-Reread + inkrementelle Updates → korrekte Summe.
> Nach Relaunch: Reset auf 0, Voll-Reread baut Ø komplett neu auf; `maxHeartRate` wird über
> die ganze Historie rekonstruiert (≥ Snapshot-Seed). **Keine Doppelzählung.**

### B2 – Energie-Streaming: Akkumulator vor Start zurücksetzen

In `startStreamingEnergy()`, **vor** `store.execute(q)`:
```swift
activeEnergyKcal = 0
```
Der Handler bleibt unverändert (`activeEnergyKcal += delta`). Durch den Voll-Reread bei
`anchor: nil` wird die Summe nach jedem (Neu-)Start vollständig neu aufgebaut → keine
Doppelzählung mehr.

### B3 – `reattach()`: nur Anzeige-Seeds restoren, Summen NICHT

In `reattach(to:)`, im Snapshot-Restore-Block, **entfernen**:
```swift
if let sum  = p.hrSum          { self.hrSum            = sum  }
if let cnt  = p.hrCount        { self.hrCount          = cnt  }
if let kcal = p.activeEnergyKcal { self.activeEnergyKcal = kcal }
```
**Behalten** (sofortige Anzeige, bevor das Streaming antwortet):
```swift
if let max  = p.maxHeartRate   { self.maxHeartRate     = max  }
if let hr   = p.lastHeartRate  { self.heartRate        = hr   }
```

> Begründung: `hrSum/hrCount/activeEnergyKcal` werden in B1/B2 ohnehin aus der vollen
> HealthKit-Historie neu berechnet. Würden wir sie hier zusätzlich restoren, käme es trotz
> Reset zu kurzzeitig falschen Zwischenwerten. `maxHeartRate` bleibt als Seed, damit die
> Anzeige nicht kurz auf „--"/aktuellen Wert springt, bis der erste Streaming-Callback kommt.

### B4 – (OPTIONAL) Snapshot periodisch aktualisieren

Nur als Absicherung für den Fall „HealthKit verweigert / kein Streaming". Im Timer-Closure
(gedrosselt, z. B. zusammen mit dem 60-s-Memory-Tick aus A4) ergänzen:
```swift
self.savePendingSnapshot()
```
> Wenn B1–B3 sauber laufen, ist das nicht zwingend nötig (max/avg/energy werden aus HealthKit
> rekonstruiert). Bei `healthKitDenied == true` hält dieser Tick wenigstens den letzten
> Anzeige-Stand aktuell. Falls es das Diff zu groß macht: weglassen.

### Test für Teil B

1. Training starten, **keine** Begehung banken.
2. ~10 min normal klettern/bewegen, dabei HF mehrfach hoch/runter → max HF merken.
3. App in den Hintergrund zwingen (Handgelenk runter, anderer Watch-Vorgang) bis Relaunch.
4. App wieder öffnen → **erwartet:** max HF bleibt der echte bisherige Maximalwert, Ø HF und
   Energie plausibel (keine Sprünge nach oben), Timer läuft korrekt weiter.
5. Diagnose → „Ans iPhone senden" → auf dem iPhone Log prüfen.

---

## TEIL C – Untersuchungsplan App-Neustart (nach Teil A auswerten)

Nach dem nächsten Test mit der neuen Instrumentierung im iPhone-Log gezielt prüfen:

1. **`app launch #N`** – springt die Nummer während des Trainings? → echter Relaunch
   (nicht nur Hintergrund-Wecken). Wie oft, in welchem Abstand?
2. **`scenePhase=…`** – Sequenz vor dem Relaunch: kommt `background` (+ Flush) und dann ein
   neues `app launch #N+1`? Oder bleibt es bei `inactive`/`active` (= App lebt, nur gedimmt)?
3. **`tick mem=…MB`** – Verlauf bis kurz vor dem Relaunch:
   - **Steigend** Richtung Jetsam-Grenze → Memory-Leak. Nächster Schritt: gezielt suchen, was
     wächst (Altimeter-Puffer, Combine-Retain-Cycles, evtl. der `builder`/Session-Pfad). Der
     `DiagnosticLog`-Ringpuffer ist auf 200 Einträge gedeckelt, also nicht die Ursache.
   - **Flach (~17 MB)** und trotzdem Relaunch → kein Leak; watchOS gibt den suspendierten
     Prozess nach längerem Hintergrund frei. Dann ist die richtige Strategie: Relaunch
     akzeptieren + **nahtlose Recovery** (durch Teil B bereits gegeben) statt Verhinderung.
4. **Zeitpunkt** – immer ~30 min? Korreliert mit Handgelenk-runter-Phasen (Autofahrt)?

**Erst nach dieser Auswertung** entscheiden wir gemeinsam über die Mitigation (Memory-Profiling
vs. Akzeptanz des Relaunch mit nahtloser Recovery). Größere Eingriffe vorher mit Rücksprache.

---

## Betroffene Dateien (Übersicht)

| Datei | Teil | Art |
|---|---|---|
| `…Watch App/Services/MemoryFootprint.swift` | A1 | neu |
| `…Watch App/Services/WorkoutManager.swift` | A2, A4, B1, B2, B3, B4 | ändern |
| `…Watch App/ClimbReflectWatchApp.swift` | A3 | ändern |
| `…Watch App/Services/SyncService.swift` | A5 | ändern |
| `…Watch App/Views/DiagnosticView.swift` | A6 | ändern |
| `ClimbReflect/.../Services/WatchSessionReceiver.swift` | A7 | ändern |
| `ClimbReflect/.../Views/WatchDiagnosticsView.swift` | A8 | neu |
| `ClimbReflect/.../Views/SettingsView.swift` | A8 | ändern (Link) |

## CLAUDE.md – neue Prinzipien zum Eintragen

- **S17** – HKAnchoredObjectQuery mit `anchor: nil` liefert beim (Neu-)Start die komplette
  Historie seit dem Predicate-Start. Akkumulatoren (`hrSum`, `hrCount`, `activeEnergyKcal`)
  müssen deshalb **vor** `execute` auf 0 gesetzt und ausschließlich aus dem Stream rekonstruiert
  werden – niemals zusätzlich aus einem Snapshot addieren (Doppelzählung).
- **S18** – Ein `maxHeartRate`-Reset auf die momentane HF nach Wiederöffnen ist der
  Fingerabdruck eines App-Relaunch via `reattach()`. Tritt er auf, wurde der Prozess neu
  gestartet – die HKWorkoutSession selbst lebt (state=2).
