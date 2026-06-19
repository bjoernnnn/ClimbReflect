# ClimbReflect – Schritt 3 / Fix A3: Live-Daten per Streaming statt HKLiveWorkoutBuilder

Branch: neuer Branch (z. B. `fix-a3-streaming-hr`). **Begründung:** A2 (Typen einschränken) hat
nicht geholfen — Speicher klettert auch mit nur HF + Energie auf ~286 MB in 29 Min. Ursache ist die
**Sample-Akkumulation des `HKLiveWorkoutBuilder` selbst**. Experiment A hat gezeigt: ohne Builder
bleibt der Speicher flach (20 MB) **und** die `HKWorkoutSession` hält die App im Hintergrund am
Leben. → Live-Daten künftig über Streaming-Queries, Builder nicht mehr für die laufende Sammlung.

**Architektur neu:**
- `HKWorkoutSession`: bleibt (Hintergrund-Laufzeit, Status). Wie bisher `startActivity`.
- Live-HF: `HKAnchoredObjectQuery` (Streaming) → anzeigen, **nicht** speichern → keine Akkumulation.
- Live-Energie: `HKAnchoredObjectQuery` auf `activeEnergyBurned` → laufende Summe (ein `Double`).
- **Kein** `HKLiveWorkoutBuilder` + `HKLiveWorkoutDataSource` + `beginCollection` mehr für die
  laufende Anzeige.
- Workout-Speicherung: siehe Aufgabe 4 (Designentscheidung).

---

## Aufgabe 1 — Live-HF per Streaming-Query

- *Datei:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:* Streaming-Query, die je neuem Sample nur den letzten Wert anzeigt und **nichts** hält:
  ```swift
  private var hrQuery: HKAnchoredObjectQuery?

  private func startStreamingHeartRate() {
      let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
      let unit = HKUnit.count().unitDivided(by: .minute())
      let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
          = { [weak self] _, samples, _, _, _ in
          guard let self,
                let last = (samples as? [HKQuantitySample])?.last else { return }
          let bpm = last.quantity.doubleValue(for: unit)
          Task { @MainActor in
              self.heartRate = bpm
              if bpm > self.maxHeartRate { self.maxHeartRate = bpm }
              if bpm > 0 { self.hrSum += bpm; self.hrCount += 1 }
          }
          // samples werden NICHT gespeichert → keine Akkumulation
      }
      let q = HKAnchoredObjectQuery(type: hrType, predicate: nil, anchor: nil,
                                    limit: HKObjectQueryNoLimit, resultsHandler: handler)
      q.updateHandler = handler
      store.execute(q)
      hrQuery = q
  }
  ```
- *Stoppen:* beim Beenden `if let q = hrQuery { store.stop(q) }`.
- *Fertig-wenn:* Live-HF wird angezeigt, auch im Hintergrund (Display aus), ohne Builder.

## Aufgabe 2 — Live-Energie per Streaming-Query (begrenzt)

- *Aufgabe:* Analog für `activeEnergyBurned`; die Delta-Samples zur laufenden Summe addieren:
  ```swift
  private var energyQuery: HKAnchoredObjectQuery?
  // im Handler:
  for s in (samples as? [HKQuantitySample]) ?? [] {
      let kcal = s.quantity.doubleValue(for: .kilocalorie())
      Task { @MainActor in self.activeEnergyKcal += kcal }
  }
  ```
- *Fertig-wenn:* Energie zählt hoch; Speicher bleibt davon unbeeinflusst (nur ein `Double`).

## Aufgabe 3 — `HKLiveWorkoutBuilder`-Live-Sammlung entfernen

- *Aufgabe:* In `startWorkout` und `reattach`:
  - `HKLiveWorkoutDataSource`, `wb.dataSource = …`, `beginCollection`, `wb.delegate = self` und
    `didCollectDataOf` für die **laufende** Anzeige entfernen.
  - Stattdessen nach `session.startActivity(...)` die Streaming-Queries starten
    (`startStreamingHeartRate()`, Energie).
  - `HKWorkoutSession` (startActivity) **unverändert** behalten.
- *Build-Marker:* `"S3-A3-streaming"`.
- *Fertig-wenn:* Kein `HKLiveWorkoutBuilder`-Collect mehr aktiv; App startet, HF/Energie live da.

## Aufgabe 4 — Workout am Ende speichern (DESIGNENTSCHEIDUNG)

> **Hier entscheiden:** Soll ein Workout in Apple Health gespeichert werden?

- **Variante A (empfohlen): schlankes Workout speichern.** Am Ende per `HKWorkoutBuilder`
  (nicht „Live") ein Workout mit Start/Ende + Gesamt-`activeEnergyBurned` anlegen und
  `finishWorkout()`. Optional Ø/Max-HF als Metadaten. **Keine** Per-Sample-Sammlung → minimaler
  Speicher. Vorteil: zählt für Aktivitätsringe/Health-App.
- **Variante B: gar nicht in HealthKit speichern.** App ist standalone (SwiftData = Quelle der
  Wahrheit). Einfachster Weg, null Akkumulation. Nachteil: kein Eintrag in Apple Health.

- *Fertig-wenn:* Gewählte Variante umgesetzt; bei Variante A erscheint ein Workout in Apple Health.

---

## Testlauf & Auswertung
1. Diagnose zeigt `Build: S3-A3-streaming`.
2. 30–45 Min Session (ruhig **und** ein aktiver Kletter-Lauf).
3. Memory-Log: **`mem used` muss flach bleiben** (wie bei Experiment A, ~20–40 MB), auch über
   lange Zeit und bei aktivem Klettern.
4. Prüfen: Live-HF + Energie werden korrekt angezeigt (auch nach Display-aus/Handgelenk-Heben);
   bei Variante A erscheint nach dem Beenden ein Workout in Apple Health.

**Erwartung:** Speicher flach → Leck endgültig behoben. Falls wider Erwarten doch ein Anstieg
bleibt, liegt eine zweite (kleinere) Quelle vor → dann Allocations-Profiler.
