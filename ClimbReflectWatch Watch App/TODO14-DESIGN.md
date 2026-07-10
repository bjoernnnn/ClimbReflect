# TODO14 – Design-Reparatur Fortschritt-Tab + Watch-Triage

**Basis:** `dev` @ `e669b06`. Ein Task = ein Commit, App nach jedem Commit
kompilierbar. Anlass: Screenshot vom 10.07. — die MO-7/MO-8-Umsetzung folgt der
TODO13-Spec, aber die Spec war ein Design-Fehler (Chips brechen bei deutschen
Wortlängen um, vier Pills konkurrieren mit dem Level-Block, drei schwebende
Zeilen ohne Anker, doppelte Monats-Labels im Chart).

**Design-Leitsatz für diesen Block:** *Neuigkeit wohnt in den Elementen, nicht
über ihnen.* Kein Element auf der Seite darf umbrechen; Gold existiert pro
Screen-Bereich genau einmal; jede Zeile hat eine feste Icon-Spalte.

---

## 0. ⚠️ VORAB — Watch-Regression (blockiert, braucht Input)

**Befund:** `origin/dev` enthält zwischen `af06c56` und `e669b06` **keine**
Watch-Swift-Änderungen (nur `.md`-Dateien). Projekt-/Schuh-Auswahl und
Klassifikations-Flow sind im Remote-Stand vorhanden (`LiveSessionView`,
`AttemptLogView`, `WorkoutManager`). Die beobachtete Regression (kein Projekt,
kein Schuh, Klassifizierung als Popup) stammt aus **lokalen, ungepushten
Änderungen**.

**W-1: Triage nach Push.** Sobald der lokale Stand gepusht ist (oder
`git log origin/dev..HEAD --oneline` + `git status` vorliegen): betroffene
Commits identifizieren, gegen die Kern-Flow-Regel prüfen (Start → Versuch →
Klassifikation → Ende → Projekt/Schuh, keine Änderung ohne Rücksprache),
Rollback- bzw. Reparatur-Tasks formulieren. **Bis dahin keine weiteren
Claude-Code-Läufe auf dem Watch-Target.**

---

## 1. Ziel-Layout (nachher)

```
┌──────────────────────────────────────────────┐
│ [ Boulder | Seil ]              [3M 6M 1J ∞] │  ← eine Kopfzeile
├──────────────────────────────────────────────┤
│ ┌─────────────────╥╥┐  ┌───────────────┐     │
│ │ HÖCHSTER SEND NEU║│  │ FLASH/ONSIGHT │     │  ← Gold-Rand + NEU-Badge
│ │ 6a+              ║│  │ 5c  [Flash]   │     │    an der Kachel selbst
│ │ Jun 2026         ║│  │ Jun 2026      │     │
│ └─────────────────╨╨┘  └───────────────┘     │
│ ┌──────────────────────────────────────────┐ │
│ │ ✓  Wohlfühl-Grad        5c               │ │  ← EINE Fakten-Karte,
│ │ ↗  Nächste Stufe        6b · unversucht  │ │    feste Icon-Spalte,
│ │ ✦  Erstmals gesendet    6a+ · 5c · 5b    │ │    einheitliche Farben
│ └──────────────────────────────────────────┘ │
│ ┌ Grad-Verlauf ────────────────────────────┐ │
│ │ (Fläche unter Send-Linie, Achse = Monate)│ │
└──────────────────────────────────────────────┘
```

Die Chip-Reihe existiert nicht mehr. `ProgressEngine` bleibt unverändert —
alle Tasks sind reine View-Arbeit.

---

## 2. Tasks

### DS-1: Kopfzeile verdichten
**Kontext:** Heute drei Zeilen mit drei Ausrichtungen (Nav-Titel zentriert,
Disziplin zentriert, Zeitraum rechts) — ~50 pt Verlust und unruhiger Einstieg.
**Dateien:** `Views/FortschrittView.swift`
**Aufgabe:** Disziplin-Picker und Zeitraum-Picker in **eine** `HStack`-Zeile:
Disziplin führend, `Spacer()`, Zeitraum. Die separate Zeitraum-Zeile entfällt.
Beide Picker unverändert (Komponenten bleiben).
**Fertig-wenn:** Kopf = genau eine Kontrollzeile unter dem Nav-Titel; kein
Element zentriert außer dem Nav-Titel.

### DS-2: Chip-Reihe raus, PB-Feier in die Send-Kachel
**Kontext:** Kern der Reparatur. Die Bestleistung wird dort gefeiert, wo der
Wert steht — wie die `heroCard` auf „Heute" (Gold-Stroke) es bereits vormacht.
**Dateien:** `Views/Components/LevelHeaderView.swift`,
`Views/FortschrittView.swift`, `Views/Components/PeriodHighlightsRow.swift`
(**löschen**)
**Aufgabe:**
1. `LevelHeaderView` erhält `var celebratesSend: Bool = false` (true ⇔
   `highlights.isAllTimeBest && hardestSend != nil`, berechnet in
   `FortschrittView` — Engine unverändert).
2. Send-Kachel bei `celebratesSend`: Overlay-Stroke
   `Theme.gold.opacity(0.35), lineWidth: 1` auf dem bestehenden
   `RoundedRectangle(cornerRadius: 16)` **plus** Badge oben rechts in der
   Kachel: Text `NEU` (`caption2.weight(.bold)`, `Theme.bg` auf Capsule
   `Theme.goldGradient`, `padding(.horizontal, 6).padding(.vertical, 2)`),
   platziert via `overlay(alignment: .topTrailing)` mit 10 pt Einzug. Kein
   weiteres Gold in der Kachel (Grad bleibt `textPrimary`).
3. `PeriodHighlightsRow.swift` löschen; Einbindung + `highlights`-Chip-Aufruf
   aus `FortschrittView` entfernen (die `highlights`-Computed bleibt für DS-3).
**Fertig-wenn:** Kein Capsule-Chip mehr über dem Level-Block; PB im Zeitraum ⇒
Gold-Rand + NEU-Badge an der Send-Kachel; ohne PB im Zeitraum ist die Kachel
pixel-identisch zu vorher; Projekt kompiliert ohne `PeriodHighlightsRow`.

### DS-3: Fakten-Karte (Wohlfühl · Nächste Stufe · Erstmals)
**Kontext:** Drei frei schwebende Zeilen mit drei Icon-Farben wirken
unfertig. Sie werden eine zusammenhängende flache Karte mit festem Raster.
**Dateien:** `Views/Components/LevelHeaderView.swift`
**Aufgabe:**
1. Container: `VStack(spacing: 0)` mit Zeilen à `padding(.vertical, 10)`,
   getrennt durch `Divider().overlay(Theme.surfaceStroke)`, gesamt in
   `RoundedRectangle(cornerRadius: 16).fill(Theme.bgElevated)` mit
   `padding(.horizontal, 14)` — gleiche Optik wie `styleLink`.
2. Zeilen-Raster: Icon in fester Spalte `frame(width: 22)` (`caption`-Größe),
   dann Label (`subheadline`, `Theme.textSecondary`), `Spacer()`, Wert rechts
   (`subheadline.weight(.semibold)`, `textPrimary`, `lineLimit(1)`,
   `minimumScaleFactor(0.8)`). **Alle Icons `Theme.accent`** — die
   Blau/Grau-Mischung entfällt (`checkmark.seal.fill`, `arrow.up.forward`,
   `sparkles`).
3. Zeileninhalte:
   – `Wohlfühl-Grad` → `5c` (bzw. Kandidat-Fassung: Label
   `Wohlfühl-Grad`, Wert `6B · 4/5` mit gedimmtem Icon `checkmark.seal`,
   `textTertiary` — der Erklärsatz „ab 5 Begehungen je Grad" wandert als
   `caption2`-Fußnote unter die Karte, nur im Kandidat-Fall).
   – `Nächste Stufe` → `6b · unversucht` bzw. `6b · 3 Begehungen`
   (Kurzform ohne „noch", damit die Zeile nie skalieren muss).
   – `Erstmals gesendet` → `6a+ · 5c · 5b` (max. 3 Grade nach `order`
   absteigend, Überhang ` +2`; Zeile nur bei nicht-leeren `firstSends` und
   `period != .all` — Regel aus MO-7 wandert hierher).
4. Zeilen ohne Daten entfallen einzeln; Karte entfällt komplett, wenn keine
   Zeile Daten hat.
**Fertig-wenn:** Screenshot-Kriterium: keine Zeile bricht um (Test mit
`7A+ · 7A · 6C+` und Kandidat-Fall); Icon-Spalte bündig über alle Zeilen;
genau eine Karte, keine Einzel-Zeilen mehr im `VStack` der Seite.

### DS-4: Grad-Verlauf-Chart reparieren
**Kontext:** `AxisMarks(values: .automatic(desiredCount: 4))` erzeugt
Sub-Monats-Ticks, die alle mit dem Monatsnamen beschriftet werden — daher
„Jun Jun Jun Jul Jul". Bei spärlichen Daten hängt zudem eine kurze Linie in
einer großen leeren Karte.
**Dateien:** `Views/Components/GradeTimelineChart.swift`
**Aufgabe:**
1. X-Achse: `AxisMarks(values: .stride(by: .month))`, Label
   `.dateTime.month(.abbreviated)`; bei > 8 Monaten im Datenbereich
   `.stride(by: .month, count: 2)` (einfacher Umschalter über
   `points.count`).
2. Unter jedem Send-Segment eine `AreaMark` (gleiche x/y, gleiche Serie,
   `interpolationMethod(.stepEnd)`, Füllung `LinearGradient` von
   `Theme.gold.opacity(0.16)` nach `.clear`, top→bottom) — Linie und Punkte
   unverändert darüber.
3. `PointMark`-`symbolSize` 28 → 40; Flash-Serie unverändert (gestrichelt).
4. Chart-Höhe 150 → 140.
**Fertig-wenn:** Achse zeigt jeden Monat genau einmal; Fläche endet an
Segmentgrenzen (keine Interpolation über Lücken — S32); Screenshot mit den
3M-Daten aus dem Report zeigt keine doppelten Labels.

### DS-5: Preview-Galerie als Abnahme-Netz
**Kontext:** Der Chip-Bruch wäre in einer Preview mit realistischen deutschen
Strings sofort sichtbar gewesen. Das darf nicht wieder ungesehen durchrutschen.
**Dateien:** `Views/FortschrittView.swift`, `Models/MockData.swift`
**Aufgabe:** Drei `#Preview`-Varianten für `FortschrittView` über
MockData-Szenarien: **voll** (PB im Zeitraum, 3+ Erst-Sends, Kandidat aktiv,
12 Monate Verlauf), **spärlich** (2 Sessions, 1 Erst-Send, kein Wohlfühl-Grad),
**leer**. MockData um die dafür nötigen Seeds ergänzen (deterministisch,
keine Zufallsdaten).
**Fertig-wenn:** Alle drei Previews rendern ohne Umbrüche/Überläufe; die
Szenarien decken jede Zeile der Fakten-Karte in beiden Zuständen ab.

---

## 3. ⚠️ ABSTIMMEN

1. **Tiefer Redesign-Block?** DS-1–DS-4 reparieren die akuten Brüche. Wenn das
   Grundgefühl der Seite („sah vorher schon nicht gut aus") danach immer noch
   nicht stimmt, schlage ich einen eigenen Visual-Block vor: 2–3 komplette
   Gestaltungsrichtungen (Typo-Hierarchie, Kartenstil, Hintergrund,
   Chart-Sprache) als lauffähige Preview-Varianten zum Durchschalten — Auswahl
   am Gerät statt am Konzeptpapier. Sag Bescheid, dann bereite ich die
   Richtungen vor.
2. **W-1** startet, sobald der lokale Watch-Stand gepusht ist bzw.
   `git log origin/dev..HEAD --oneline` + `git status` vorliegen.

## 4. Unverändert / außerhalb

`ProgressEngine`/`StatsEngine` bleiben unangetastet (reine View-Reparatur);
MO-10–MO-13 (Today-Karten, Streak-Rekord, Monatsrückblick) sind nicht Teil
dieses Blocks — falls dort dieselben Layout-Probleme auffallen, bitte
Screenshot, dann ergänze ich DS-Tasks; S31/S32/S33 gelten fort.
