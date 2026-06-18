# ClimbReflect – Fehlersuche Schritt 3: Leckquelle isolieren

Branch: `dev` (mit Schritt-1-Memory-Logging). **Speicherleck ist bestätigt** (298 MB bei
t=138min). Ziel jetzt: herausfinden, **was** die ~300 MB hält. Diagnose-Experimente, gemessen
über das vorhandene Memory-Log – kein Profiler nötig (aber als Goldstandard empfohlen, siehe unten).

**Bekanntes Muster:**
- Grundleck ~2 MB/Min (auch im Schlaf, Display aus) → Verdacht: `HKLiveWorkoutBuilder` hält alle
  Samples der Session.
- Schneller Anteil beim aktiven Klettern (5–25 Min bis Limit) → Verdacht: Rendering/Interaktion.
- **Für den Alltag ist der schnelle (rendering-/interaktionsabhängige) Anteil entscheidend.**

> Wichtig: Diese Experimente sind **temporäre Diagnose-Builds** (HF-Anzeige darf dabei fehlen).
> Build-Marker pro Experiment anpassen (z. B. „S3-A-noBuilder"), damit klar ist, was läuft.

---

## Experiment A — HealthKit-Collection abschalten (Grundleck testen)

- *Hypothese:* Der `HKLiveWorkoutBuilder` akkumuliert über die Zeit → Grundleck.
- *Datei:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:* In `startWorkout` die `HKWorkoutSession` (für Hintergrund) **behalten**, aber den
  Builder/Collection **auskommentieren**:
  - kein `HKLiveWorkoutDataSource` setzen,
  - kein `builder.beginCollection(...)`,
  - `didCollectDataOf` liefert dann nichts (HF bleibt 0 – für den Test ok).
  - Build-Marker auf „S3-A-noBuilder".
- *Test:* 30–45 Min, möglichst **wenig** Interaktion (Display meist aus).
- *Auswertung über Memory-Log:*
  - `mem used` bleibt **flach** → **Builder ist die Grundleck-Quelle**.
  - `mem used` steigt trotzdem → Grundleck liegt woanders (Sensoren/Tasks/Render) → Experiment B.

## Experiment B — Rendering-Anteil testen (schnelles Leck)

- *Hypothese:* Das Rendering beim Handgelenk-Heben / aktiver Nutzung leakt (trotz A1/A2).
- *Vorgehen:* Builder wieder an (normaler `dev`), aber während des Tests **bewusst** viel
  interagieren (oft Handgelenk heben, zwischen Tabs wechseln) und das Memory-Log mit einem
  „ruhigen" Lauf vergleichen.
- *Auswertung:*
  - Deutlich schnellerer `mem used`-Anstieg bei viel Interaktion → **Rendering/SwiftUI** ist der
    schnelle Verursacher → gezielt im `LiveSessionView`/TabView nach pro-Erscheinen-Allokationen
    suchen (Profiler).

## Goldstandard — Allocations / Memory-Graph-Profiler (exakte Quelle)

- Xcode → Product → Profile → **Allocations** (+ ggf. **VM Tracker**/Memory-Graph), echte Uhr,
  10–15 Min Session.
- „Persistent Bytes" nach der am stärksten **wachsenden** Kategorie absuchen:
  CoreAnimation/Rendering, HealthKit, CoreMotion, App-Objekte.
- Der Memory-Graph zeigt, **welche** Objekte sich anhäufen und wer sie hält (Retain-Pfad).

---

## Auswertung & nächster Schritt

- **Builder = Quelle:** Optionen prüfen – nur nötige Typen sammeln (`HKLiveWorkoutDataSource` mit
  eingeschränkter `typesToCollect`), bzw. akzeptieren, dass sehr lange Sessions (>2 h) viel Speicher
  brauchen. (Für reale Klettersessions meist < 2 h relevant.)
- **Rendering = Quelle:** Im `LiveSessionView`/TabView nach Views suchen, die pro `onAppear`/
  Szenenwechsel allokieren und nicht freigeben; ggf. TabView-Seiten/`TimelineView`-Verhalten beim
  Vordergrund-Wechsel prüfen.
- Ergebnis in `FEHLERSUCHE.md` (Schritt 3) eintragen.

**Hinweis:** Da die **Recovery zuverlässig funktioniert**, überlebt die App einen Jetsam aktuell
ohne Datenverlust. Der Blackscreen beim Beenden (`TODO-Blackscreen.md`) ist unabhängig davon und
sollte zuerst gefixt werden, da er den Nutzer direkt blockiert.
