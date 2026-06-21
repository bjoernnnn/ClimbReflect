# TODO – Watch-Design: Badge-Timer + Platznutzung + größere Buttons

**Branch:** `dev` @ `1515dbb`
**Art:** Layout-/Design-Feinschliff. Watch-Layout am besten am Gerät iterieren – unten stehen
konkrete Startwerte, die Björn dann nachjustiert.

---

## TEIL 1 – Aktive Badge: orange, nur Timer

Aktuell: gelb (`WatchTheme.gold`) + Icon `stop.circle.fill` + „läuft". Gewünscht: **orange**,
**nur der Timer** (kein Icon, kein „läuft").

In `attemptToggleBadge` den `.active`-Zweig ersetzen:

```swift
        if case .active(let startTime) = workoutManager.attemptState {
            TimelineView(.periodic(from: startTime, by: 1)) { _ in
                Text(formatDuration(Date().timeIntervalSince(startTime)))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(Color.orange.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            // unverändert: normale Versuche-Badge
            statBadge(value: "\(workoutManager.attempts.count)",
                      label: "Versuche", icon: "figure.climbing",
                      color: WatchTheme.textSecond)
        }
```

> `.orange` = System-Orange. Falls ein Theme-Token bevorzugt wird, bitte ein echtes Orange
> anlegen (nicht `WatchTheme.gold`, das ist gelb).

---

## TEIL 2 – statsPage: Platz besser nutzen, Timer links/oben

**Hinweis vorab:** Die System-Uhrzeit (oben rechts) lässt sich **nicht** ausblenden – Apple
erlaubt das nicht (die Watch ist ein Zeitmessgerät; Statusleiste ist in watchOS nicht
verbergbar). Lösung daher wie von dir vorgeschlagen: **Session-Timer nach links**, dann kann er
**nach oben**, ohne die Uhr rechts zu überschneiden.

### 2.1 Session-Timer (`elapsedView`) links ausrichten + hochrücken
In `statsPage`:
- den **oberen** `Spacer(minLength: 0)` (≈ Zeile 149) **entfernen**, damit der Inhalt höher
  startet.
- `elapsedView` links ausrichten, damit er die obere rechte Uhr nicht trifft:
```swift
            HStack {
                elapsedView
                    .foregroundStyle(workoutManager.isPaused ? WatchTheme.textTert : WatchTheme.accent)
                Spacer(minLength: 0)
            }
```
> Ergebnis: Timer sitzt oben links, Uhr bleibt oben rechts frei. Beim Test ggf. die obere
> Kante um 2–4 pt feinjustieren, dass nichts unter die Uhr rutscht.

### 2.2 Ränder mehr ausnutzen (alles etwas größer)
- `statsPage`: `.padding(.horizontal, 8)` → **`.padding(.horizontal, 3)`** (breitere Elemente).
- `VStack(spacing: 8)` → **`spacing: 6`** (etwas kompakter, mehr Platz pro Element).
- Badges (`statBadge`) etwas größer: in `statBadge` `value`-Font 16 → **18**,
  `.padding(.vertical, 8)` → **10**.
- `vitalsRow`-Zellen profitieren automatisch von der größeren Breite (horizontales Padding
  reduziert).

> Das ist bewusst grob – bitte am Gerät schauen und Werte nachziehen. Ziel: weniger Leerrand,
> Anzeigen/Buttons füllen die Fläche.

---

## TEIL 3 – Klassifizier-Seite (AttemptLogView): größere Buttons

Ziel: die 6 Ergebnis-Buttons (Flash/Onsight/Rotpunkt/Top/Versuch/Abbruch) deutlich größer.
Dafür den Grad-Bereich kompakter machen.

### 3.1 Grad kompakter (Platz für Buttons gewinnen)
Aktuell nimmt das Grad-Wheel 60 pt. Zwei Optionen – **Option A bevorzugt**:

**Option A (empfohlen): Grad über die Digital Crown statt Wheel.** Eine kompakte einzeilige
Anzeige des aktuellen Grades, per Krone scrollbar (Muster wie in `SessionEndQuestionnaireView`,
die schon `digitalCrownRotation` nutzt). Spart ~40 pt Höhe:
```swift
            Text(gradeSystem.grades[gradeIndex])
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .focusable(true)
                .digitalCrownRotation(
                    Binding(get: { Double(gradeIndex) },
                            set: { gradeIndex = min(max(Int($0.rounded()), 0), gradeSystem.grades.count - 1) }),
                    from: 0, through: Double(gradeSystem.grades.count - 1), by: 1,
                    sensitivity: .low, isContinuous: false)
```

**Option B (minimal): Wheel niedriger.** `.frame(height: 60)` → **`.frame(height: 42)`**.

### 3.2 Ergebnis-Buttons größer
Im `LazyVGrid`-Button-Label:
- Button-Höhe: `.padding(.vertical, 9)` → **`.padding(.vertical, 14)`**.
- Außenränder nutzen: in `AttemptLogView.body` `.padding(.horizontal, 7)` → **`3`**;
  `columns`-Spacing 5 → **6**.
- Schrift/Icon größer: Label-Text `size: 10` → **12**, Icon `size: 12` → **15**, Icon-`frame`
  width 14 → **18**.
- Optional: `Spacer()` zwischen Grad-Bereich und Grid entfernen, falls einer den Platz frisst,
  damit die Buttons den vollen Rest füllen.

> Mit Option A werden die Buttons am größten. Bitte am Gerät prüfen, dass alle 6 ohne Scrollen
> auf den Screen passen; sonst Button-Höhe leicht reduzieren.

---

## TEIL 4 – CLAUDE.md
- **S25 – System-Uhrzeit/Statusleiste ist in watchOS nicht ausblendbar** (Apple: Watch ist
  Zeitmessgerät). Inhalte oben **links** platzieren, um die Uhr oben rechts nicht zu
  überschneiden. (VideoPlayer-Hack zum Ausblenden bewusst vermeiden – fragil.)

---

## Reihenfolge
1. TEIL 1 (Badge orange + nur Timer) – schnell.
2. TEIL 2 (Platznutzung) – am Gerät iterieren.
3. TEIL 3 (Klassifizier-Buttons) – Option A bevorzugt.
4. TEIL 4 (CLAUDE.md) mitnehmen.

> Reine Layout-Werte sind Startpunkte – nach dem ersten Build am Gerät anschauen und nachziehen.
> Wenn du möchtest, skizziere ich dir vorab ein einfaches Layout-Bild der neuen statsPage /
> Klassifizier-Seite, damit wir die Anordnung vor dem Bauen abstimmen.
