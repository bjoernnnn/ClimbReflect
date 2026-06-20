# TODO – Memory-Leak isolieren & fixen (Issue 2, finale Eingrenzung)

**Branch:** `dev` (Achtung: Breadcrumb-Änderungen sind **lokal**, `origin/dev` steht noch auf
`e732675` – bitte committen + pushen, sonst lese ich beim nächsten Mal wieder veralteten Code.)

## Bestätigter Befund (aus watchDiagnostics, Session 17:55–18:42)

Eine Session enthält beide Bedingungen kontrolliert:

- **17:55–18:21 (25 min, vor dem ersten Versuch): flach bei 71–72 MB.**
- **18:21:06 erster `ascentTracking start` (2 Versuche gebankt) → ab hier linear ~10 MB/min:**
  82 → 100 → 122 → 150 → 211 → 253 MB.
- **18:41:40 `app launch #5 mem=16MB`** = Jetsam-Kill bei ~254 MB. Recovery: `ascents=2`.

Deckt sich exakt mit deinem Test-Vergleich: **ohne** Versuche kein Leak (App blieb),
**mit** Versuchen Leak → Hintergrund.

## Zwei am selben Moment ausgelöste Verdächtige

Beim **ersten gebankten Versuch** kippen gleichzeitig zwei Dinge:

1. **Verschachteltes TabView / `historyPage` (PRIMÄR, mechanisch plausibel).**
   `sessionInfoPage` ist ein `TabView(.verticalPage)` *innerhalb* des äußeren `.page`-TabView.
   `attempts.isEmpty == false` fügt `historyPage` hinzu → innere Seitenzahl **1 → 2**. In
   `statsPage` tickt `elapsedView` als `TimelineView(.periodic(by: 1))` jede Sekunde.
   ~10 MB/min ÷ 60 Ticks ≈ ~170 KB/Tick → passt zu einem pro-Render nicht freigegebenen
   UIHostingController eines verschachtelten Pagers. Die `Δ`-Einbrüche (−16 MB) sehen nach
   View-Recycling aus.

2. **Altimeter-Ascent-Pfad (SEKUNDÄR, unwahrscheinlich).**
   `startAscentTracking()` setzt `ascentBaseAltitude`. Der „aktiv"-Zweig in `handleAltitude`
   macht aber nur Skalar-Vergleiche – **keine Allokation**. Das Leck kann hier rein semantisch
   kaum entstehen. Der Altimeter läuft zudem schon ab Session-Start (Speicher flach).

> Beide kippen exakt beim ersten Bank → aus dem Log allein nicht trennbar. **Ein**
> Isolationstest trennt sie.

---

## SCHRITT 1 – Isolationstest L-A (innere `historyPage` raus)

Ziel: prüfen, ob das verschachtelte TabView die Quelle ist. **Minimaler, reversibler Eingriff.**

In `LiveSessionView.swift`, in `sessionInfoPage`, den `historyPage`-Zweig temporär entfernen:

```swift
private var sessionInfoPage: some View {
    TabView {
        statsPage
            .overlay {
                if workoutManager.attemptState == .awaitingResult {
                    quickResultOverlay
                }
            }
        // TEST L-A: historyPage temporär deaktiviert
        // if !workoutManager.attempts.isEmpty {
        //     historyPage
        // }
    }
    .tabViewStyle(.verticalPage)
    .background(WatchTheme.bg)
    .sheet(item: $selectedAttempt) { attempt in
        AscentDetailView(attempt: attempt) {
            workoutManager.removeAttempt(id: attempt.id)
        }
    }
}
```

**Test:** Session starten, 2–3 Versuche banken, ~10 min ruhig sitzen, Speicher im Diagnose-Log
beobachten (`Δ`-Werte).

- **Speicher bleibt flach (Δ≈0)** → **verschachteltes TabView bestätigt** → weiter mit Fix F-A.
- **Speicher steigt weiter** → TabView ist es nicht → weiter mit Schritt 2 (L-B Altimeter).

---

## SCHRITT 2 – Isolationstest L-B (nur falls L-A flach blieb NICHT zutraf)

Altimeter-Ascent-Pfad stilllegen, Banken aber erlauben. In `WorkoutManager`:
- in `handleActionButton` `.active`-Case: `Task { await altimeter.startAscentTracking() }`
  auskommentieren
- in `quickBank` und `bankAttempt`: `await altimeter.startAscentTracking()` auskommentieren
  (die `stopAscentTracking()`-Zeile, die `gain` liefert, **bleibt** – liefert dann 0)

**Test** wie oben.
- flach → Altimeter bestätigt → Fix F-B.
- steigt weiter → Quelle liegt woanders (dann melden, wir bisektieren die Attempt-Flow-Views
  weiter, z. B. `actionStateIndicator`/`quickResultOverlay`).

---

## FIX F-A – Verschachteltes TabView entschärfen (falls L-A bestätigt)

> **Rücksprache vor Umsetzung**, da es die Live-Session-Navigation betrifft.

Optionen, von minimal nach gründlich:

1. **Statische Seitenzahl:** `historyPage` **immer** in das innere TabView aufnehmen (nicht
   bedingt), und bei leerer Liste einen Platzhalter („Noch keine Versuche") zeigen. Damit
   wechselt die Seitenzahl nie 1↔2 – das ist vermutlich der eigentliche Auslöser.

   ```swift
   TabView {
       statsPage.overlay { … }
       historyPage   // immer vorhanden; historyPage zeigt bei leerer Liste einen Hinweis
   }
   .tabViewStyle(.verticalPage)
   ```

2. **Verschachtelung auflösen:** Verlauf nicht als zweite vertikale Pager-Seite, sondern als
   eigener Tab im äußeren Pager oder als Sheet/`NavigationLink` öffnen. Kein Paging-TabView in
   Paging-TabView mehr.

3. **TimelineView entkoppeln:** Falls der 1-s-`TimelineView` im Pager der Treiber ist, die
   verstrichene Zeit stattdessen über den bestehenden 2-s-Timer als `@Published`-Wert anzeigen
   (kein `TimelineView` im verschachtelten Pager).

Nach dem Fix erneut ~15 min mit Versuchen testen → Speicher muss flach bleiben.

## FIX F-B – Altimeter-Subscription auf Versuchs-Fenster begrenzen (falls L-B bestätigt)

> **Rücksprache vor Umsetzung.** Auch unabhängig vom Leak sinnvoll (Strom).

- Relative-Altitude-Subscription **nur während eines aktiven Versuchs** laufen lassen:
  `startRelativeAltitudeUpdates` in `startAscentTracking()`, `stopRelativeAltitudeUpdates()` in
  `stopAscentTracking()`. `start()`/`stop()` abonnieren dann nicht mehr.
- **Auto-Re-Arm entfernen:** in `bankAttempt`/`quickBank` das erneute
  `startAscentTracking()` streichen. Scharfschalten nur in `handleActionButton` (`.idle →
  .active`).
- Base-Semantik beachten: bei frischer Subscription startet `relativeAltitude` bei ~0 →
  `ascentBaseAltitude = 0` setzen (statt `lastAltitude`).
- Per-Sample-`Task` im Handler vermeiden: serielle Queue (`maxConcurrentOperationCount = 1`)
  und den Handler ohne `Task { … }` in den Actor hüpfen lassen (oder `MainActor.assumeIsolated`),
  damit sich keine unstrukturierten Tasks stauen.

---

## Weiterhin offen (aus vorherigem TODO, noch nicht in `origin/dev`)

- **maxHF/Energie über Recovery (Teil B):** Streaming-Handler alle Samples auswerten,
  Akkumulatoren vor `execute` auf 0, `reattach` nur max/last als Anzeige-Seed. → macht jeden
  (Rest-)Neustart harmlos.
- **Defensiv:** `startStreamingHeartRate/Energy` stoppen vorhandene Query vor Neustart.
- Beides committen + nach `origin/dev` pushen.

## Reihenfolge

1. L-A testen (1 Build, ~10 min). Ergebnis in `FEHLERSUCHE.md` (Label L-A).
2. Bei Bestätigung: F-A (nach Rücksprache) → Re-Test.
3. Nur falls L-A negativ: L-B → ggf. F-B.
4. Teil B (maxHF) + Push nachziehen.
