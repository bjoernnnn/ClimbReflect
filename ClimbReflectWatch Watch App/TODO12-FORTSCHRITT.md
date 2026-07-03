# TODO12-FORTSCHRITT — Auswertungen neu: Fortschritt statt Belastung

Grundlage: **FORTSCHRITT-KONZEPT.md** (liegt bei, Abschnitte 2–5 sind bindend).
Analyse-Stand: `dev` @ `5db6216`. Ein Task = ein Commit, jeweils unabhängig testbar.
Reihenfolge einhalten: **Block A (Engine) → B (UI) → C (Abriss) → D (Doku)** —
die App bleibt nach jedem Commit lauffähig, Altbestand fällt erst nach Ersatz.

**Pfad-Legende:**
- `iOS/` = `ClimbReflect/ClimbReflect/ClimbReflect/`
- `Tests/` = `ClimbReflectTests/`

Konstanten aus dem Konzept (zentral in der Engine definieren):
`comfortSendQuote = 0.6`, `minSampleSize = 5`.

---

## Block A — ProgressEngine (reine Berechnungen, testbar)

### FO-1 · ProgressEngine-Grundgerüst + Bestleistungen
**Kontext:** Neue, von `StatsEngine` getrennte Engine für den Fortschritt-Tab.
Ein `Discipline`-Enum kapselt Boulder/Seil-Filter und Ziel-Anzeige-Skala; alle
Grad-Vergleiche laufen über `canonicalOrder` (S30), Anzeige über
`GradeConverter.display`. Bestleistungen gelten über die gesamte Historie.
**Dateien:** `iOS/Models/ProgressEngine.swift` (neu), `Tests/ProgressEngineTests.swift` (neu)
**Aufgabe:**
- `enum Discipline { case boulder, rope }` mit `matches(_ ascent:)`
  (via `gradeSystem.isBoulder`) und `displaySystem` (aus `@AppStorage`-Keys
  `boulderScale`/`routeScale`, analog `GradeConverter.displaySystem`).
- `struct PersonalBest { grade: String; system: GradeSystem; date: Date; style: AscentStyle? }`
- `static func personalBests(_ sessions: [ClimbSession], discipline: Discipline)
  -> (send: PersonalBest?, flash: PersonalBest?)` — Send: max `canonicalOrder`
  über `result == .top && isGraded`; Flash: Boulder `style == .flash`, Seil
  `style ∈ {flash, onsight}` (Badge-Stil = Stil des Bestwerts). Gleichstand →
  frühestes Datum. Anzeige-Grad bereits konvertiert zurückgeben.
- Tests: gemischte Skalen (Fb+V bzw. French+UIAA), Gleichstand-Datum,
  `"?"`-Ascents ausgeschlossen, leere Historie → nil.
**Fertig, wenn:** Tests grün; keine bestehende Datei angefasst außer Test-Target.

### FO-2 · Verlauf: härtester Grad je Monat
**Kontext:** Ersetzt `maxGradeTrend` (kategorische Labels, FB-7-Altlast) durch ein
Date-basiertes Monatsraster. Monate ohne Sends sind Lücken — keine Nullen,
keine Interpolation (S32).
**Dateien:** `iOS/Models/ProgressEngine.swift`, `Tests/ProgressEngineTests.swift`
**Aufgabe:**
- `struct TimelinePoint { month: Date; sendOrder: Int?; flashOrder: Int? }`
  (month = 1. des Monats, `startOfMonth`).
- `static func gradeTimeline(_ sessions:, discipline:, monthsBack: Int?) -> [TimelinePoint]`
  — `monthsBack == nil` ⇒ „Alles“ (ab erstem Ascent der Disziplin). Je Monat max
  `canonicalOrder` der Sends bzw. Flash/Onsight-Sends; Monate ganz ohne Wert
  fehlen im Array (Chart rendert Lücke).
- Helfer `static func gradeLabel(forOrder:discipline:) -> String` für die Y-Achse
  (canonicalIndex → Grad-String der Anzeige-Skala).
- Tests: Monatsgrenzen (letzter/erster Tag), Lücken-Monat fehlt, Flash-Serie ⊆ Send-Serie.
**Fertig, wenn:** Tests grün.

### FO-3 · Pyramide: Zeitraum + Disziplin
**Kontext:** Die disziplin-konvertierende Logik aus `StatsEngine.gradePyramid`
ist nach den FB-Fixes korrekt und zieht um — ergänzt um Zeitraumfilter und
eine Send/Nicht-Send-Trennung je Grad.
**Dateien:** `iOS/Models/ProgressEngine.swift`, `Tests/ProgressEngineTests.swift`
**Aufgabe:**
- `struct PyramidRow { grade: String; sends: Int; failedTries: Int; sortOrder: Int }`
  (`failedTries` = Begehungen ohne Send desselben Anzeige-Grads).
- `static func pyramid(_ sessions:, discipline:, monthsBack: Int?) -> [PyramidRow]` —
  Logik von `gradePyramid` übernehmen (Konvertierung ins Anzeige-System,
  `isGraded`-Filter), plus Datumsfenster. Sortierung absteigend. `StatsEngine`
  in diesem Task noch **nicht** anfassen (Abriss ist FO-15).
- Tests: V-Scale-Ascent landet im Fb-Balken, Zeitraumgrenze, `"?"` fällt raus.
**Fertig, wenn:** Tests grün.

### FO-4 · Wohlfühl-Grad
**Kontext:** Eine ehrliche „Comfort-Zone“-Zahl: höchster Grad mit belastbarer
Send-Quote. Begehung = jeder gebankte Ascent (top/attempt/quit) — bewusst ohne
`attempts`-Feld (Watch-Limitierung, S32).
**Dateien:** `iOS/Models/ProgressEngine.swift`, `Tests/ProgressEngineTests.swift`
**Aufgabe:**
- `static func comfortGrade(_ sessions:, discipline:, monthsBack: Int?) -> String?` —
  je Anzeige-Grad: Quote = Sends/Begehungen; Kandidaten nur mit Begehungen ≥
  `minSampleSize`; Ergebnis = höchster Kandidat mit Quote ≥ `comfortSendQuote`;
  sonst nil (UI blendet Zeile aus).
- Tests: n=4 auf hohem Grad wird ignoriert, exakt 60 % zählt, nil-Fall.
**Fertig, wenn:** Tests grün.

### FO-5 · Klettertage & Zeitraum-Kennzahlen
**Kontext:** Konsistenz über Kalendertage statt Minuten. Disziplin-gefiltert,
weil die ganze Seite disziplin-gefiltert ist (Label in der UI macht das explizit,
z. B. „Bouldertage“).
**Dateien:** `iOS/Models/ProgressEngine.swift`, `Tests/ProgressEngineTests.swift`
**Aufgabe:**
- `static func climbDaysPerMonth(_ sessions:, discipline:, monthsBack: Int = 6)
  -> [(month: Date, days: Int)]` — unique `startOfDay` mit ≥ 1 Session der
  Disziplin (Boulder: `sessionType == .boulder`; Seil: `lead/topRope/autoBelay`);
  Monate ohne Tage = 0 (hier sind Nullen korrekt: „0 Tage geklettert“ ist eine
  echte Aussage, anders als beim Grad-Verlauf).
- `static func periodTotals(_ sessions:, discipline:, monthsBack: Int?)
  -> (sends: Int, climbDays: Int)`
- Tests: 2 Sessions am selben Tag = 1 Tag; Boulder+Seil am selben Tag zählen je
  Disziplin getrennt; leerer Monat = 0.
**Fertig, wenn:** Tests grün.

### FO-6 · Stil-Quoten & Limiter (mit Mindest-n)
**Kontext:** Ersetzt `antistyleRates`/`terrainSendRates` — heute liefern beide
Quoten ab n=1. Neu: hartes `minSampleSize`, Stichprobe wird mitgeliefert und
in der UI angezeigt.
**Dateien:** `iOS/Models/ProgressEngine.swift`, `Tests/ProgressEngineTests.swift`
**Aufgabe:**
- `struct StyleRate { label: String; category: String; sendRate: Double; sample: Int }`
- `static func styleRates(_ sessions:, discipline:, monthsBack: Int?) -> [StyleRate]` —
  Kategorien Wandwinkel/Grifftyp/Kletterart wie bisher, aber nur Gruppen mit
  `sample ≥ minSampleSize`; Sortierung schwächste zuerst.
- `static func limiterCounts(_ sessions:, monthsBack: Int?) -> [(limiter: Limiter, count: Int)]`
  — Sessions (Klettern) im Zeitraum, absteigend nach Anzahl (disziplin-übergreifend:
  Limiter hängen an der Session, nicht am Grad).
- Tests: Gruppe mit n=4 fehlt, n=5 erscheint; Limiter-Zählung über Zeitraumgrenze.
**Fertig, wenn:** Tests grün.

---

## Block B — Neuer Tab „Fortschritt“ (UI)

### FO-7 · FortschrittView-Gerüst + Level-Block
**Kontext:** Ersetzt inhaltlich die `StatisticsView`. Alte View bleibt bis FO-15
im Projekt (auskommentierter Tab entfällt — Umschalten erfolgt hier direkt).
**Dateien:** `iOS/Views/FortschrittView.swift` (neu),
`iOS/Views/Components/LevelHeaderView.swift` (neu), `iOS/Views/DashboardView.swift`
**Aufgabe:**
- `FortschrittView`: `MountainBackground`, Segmented Control **Boulder | Seil**
  (`@AppStorage("progressDiscipline")` für Persistenz), Zeitraum-Picker
  **3M | 6M | 1J | Alles** (bestehenden `ChartPeriodPicker` erweitern oder
  Variante daneben — nicht duplizieren), Empty-State wie bisher.
- `LevelHeaderView`: zwei PB-Kacheln (Grad groß, Datum klein, bei Seil-Flash
  Stil-Badge Flash/Onsight) aus `ProgressEngine.personalBests` + Wohlfühl-Grad-Zeile
  (ausgeblendet bei nil). PB-Kacheln ignorieren den Zeitraum-Picker (Konzept ①).
- `DashboardView`: Tab-Eintrag → `FortschrittView`, Label „Fortschritt“,
  Icon `chart.line.uptrend.xyaxis`.
**Fertig, wenn:** Tab zeigt Umschalter, Picker, Level-Block mit echten Daten;
Disziplin-Wechsel aktualisiert die Kacheln; Statistik-Altbestand nicht mehr erreichbar.

### FO-8 · Verlaufs-Chart
**Kontext:** Herzstück „Werde ich besser?“. Swift Charts mit echter Date-Achse —
kein kategorisches Label-Gedränge mehr.
**Dateien:** `iOS/Views/Components/GradeTimelineChart.swift` (neu),
`iOS/Views/FortschrittView.swift`
**Aufgabe:**
- `LineMark`+`PointMark` (Interpolation `.stepEnd` oder `.monotone` — Stufe
  bevorzugt, Grade sind diskret) für Send-Serie; zweite, dezente Serie für
  Flash/Onsight. Lücken via `sendOrder == nil` nicht zeichnen.
- X: `.dateTime.month(.abbreviated)`; Y: `AxisValueLabel` über
  `ProgressEngine.gradeLabel(forOrder:discipline:)`, nur belegte Orders ±1 als Ticks.
- Legende klein (Send / Flash bzw. Flash·Onsight). Einbau unter dem Level-Block.
**Fertig, wenn:** Chart reagiert auf Disziplin+Zeitraum; Monate ohne Sends zeigen
Lücken; Y-Labels sind Grade der eingestellten Skala.

### FO-9 · Pyramiden-Chart (zentriert)
**Kontext:** Ersetzt `GradePyramidView` visuell und inhaltlich: zentrierte
Pyramidenform, Sends voll, Nicht-Send-Begehungen als transparente Verlängerung.
**Dateien:** `iOS/Views/Components/PyramidChart.swift` (neu),
`iOS/Views/FortschrittView.swift`
**Aufgabe:**
- Eigenes Layout (HStack/GeometryReader) statt `Chart`: je Zeile Grad-Label links,
  zentrierter Balken (Breite ∝ sends bzw. sends+failedTries, Maßstab über
  Zeilen-Maximum), Zahlen am Balkenende („12 · 5“ = Sends · offene Versuche).
- Datenquelle `ProgressEngine.pyramid`; Zeitraum + Disziplin vom Seitenkopf.
- Leerer Zustand: „Noch keine bewerteten Begehungen im Zeitraum.“
**Fertig, wenn:** Pyramide zentriert, korrekt sortiert, reagiert auf beide Filter;
alte `GradePyramidView` wird nicht mehr referenziert.

### FO-10 · Volumen-Karte
**Kontext:** Konsistenz kompakt, bewusst klein (Konzept ④).
**Dateien:** `iOS/Views/Components/ClimbDaysCard.swift` (neu),
`iOS/Views/FortschrittView.swift`
**Aufgabe:**
- Mini-`BarMark`-Chart (`climbDaysPerMonth`, 6 Monate, Date-X-Achse) + Zeile
  „`{sends}` Sends · `{climbDays}` Klettertage“ aus `periodTotals` für den
  gewählten Zeitraum. Titel disziplin-abhängig („Bouldertage“/„Seiltage“).
**Fertig, wenn:** Karte unter der Pyramide, reagiert auf beide Filter.

### FO-11 · Unterseite „Stil & Limiter“
**Kontext:** Analyse on demand — hält die Hauptseite frei (Konzept ⑤).
**Dateien:** `iOS/Views/StyleProfileView.swift` (neu), `iOS/Views/FortschrittView.swift`
**Aufgabe:**
- `NavigationLink`-Karte am Seitenende („Stil & Limiter“ + chevron).
- `StyleProfileView`: drei Sektionen (Wandwinkel/Grifftyp/Kletterart) mit
  Quote-Balken, Prozent und „(n Begehungen)“ je Zeile; darunter Limiter-Liste
  mit Zähler. Hinweiszeile, wenn Sektionen mangels n ≥ 5 leer sind
  („Noch zu wenige getaggte Begehungen für belastbare Quoten.“).
  Disziplin + Zeitraum werden von der Hauptseite übergeben.
**Fertig, wenn:** Unterseite erreichbar, zeigt nur Zeilen mit n ≥ 5 inkl. n.

### FO-12 · Today-Hero auf ProgressEngine umstellen
**Kontext:** `TodayView` berechnet `heroBoulder`/`heroRoute` heute inline — künftig
eine Quelle der Wahrheit für Bestleistungen.
**Dateien:** `iOS/Views/TodayView.swift`
**Aufgabe:** Inline-Berechnungen durch `ProgressEngine.personalBests(.boulder/.rope).send`
ersetzen; Anzeige unverändert (Grad in Anzeige-Skala kommt jetzt aus der Engine).
**Fertig, wenn:** Trophäen-Zeile zeigt identische Werte wie der Level-Block im
Fortschritt-Tab.

---

## Block C — Abriss (erst nach Block B!)

### FO-13 · Belastungs-Auswertungen entfernen
**Kontext:** Kern der Neuausrichtung (S31). RPE/HF bleiben erfasst und als
Rohwerte im Session-Detail sichtbar — nur die Deutungs-/Trend-Schicht fällt.
**Dateien (löschen):** `iOS/Views/Components/LoadManagementView.swift`,
`iOS/Views/Components/RPETrendView.swift`, `iOS/Views/Components/FormSignalView.swift`,
`iOS/Views/Components/SessionFatigueView.swift`
**Dateien (ändern):** `iOS/Views/TodayView.swift` (FormSignal-Einbindung + `formSignal`-Property),
`iOS/Views/SessionDetailView.swift` (Fatigue-Einbindung),
`iOS/Models/Achievement.swift` (`trainingLoad`, `rpeHistory`, `formSignal`,
`RPEPoint` + zugehörige Structs), `Tests/StatsEngineTests.swift` (zugehörige Tests)
**Aufgabe:** Views löschen, Einbindungen entfernen, Engine-Funktionen + Tests
entfernen. Vorher per Suche sicherstellen, dass keine weiteren Referenzen
existieren (auch Previews).
**Fertig, wenn:** Projekt kompiliert, verbleibende Tests grün, keine
ACWR/RPE/Form/Fatigue-UI mehr erreichbar.

### FO-14 · Statistik-Altbestand entfernen
**Kontext:** Der Rest des alten Statistik-Tabs. Achtung: `sessionsThisWeek`
(Today-Kachel) hängt an `weeklyMinutes` — zuerst entkoppeln.
**Dateien (löschen):** `iOS/Views/StatisticsView.swift`,
`iOS/Views/Components/ProgressChartView.swift`, `iOS/Views/Components/GradeProgressView.swift`,
`iOS/Views/Components/GradePyramidView.swift`, `iOS/Views/Components/EfficiencyTrendView.swift`,
`iOS/Views/Components/TerrainHeatmapView.swift`, `iOS/Views/Components/FocusPerformanceView.swift`,
`iOS/Views/Components/OutdoorConditionsView.swift`, `iOS/Views/Components/SessionTypeChartView.swift`,
`iOS/Views/Components/FingerStrengthTrendView.swift`, `iOS/Views/WeeklyRecapView.swift`,
`iOS/Views/Components/StartInsightCarousel.swift` (tote Datei, wird nirgends eingebunden)
**Dateien (ändern):** `iOS/Views/TodayView.swift` (`trainingWeaknessCard` entfernen;
`sessionsThisWeek`-Kachel auf direkte Wochen-Zählung in `ProgressEngine` umstellen),
`iOS/Models/Achievement.swift` (`weeklyMinutes`, `maxGradeTrend`, `efficiencyTrend`,
`terrainSendRates`, `focusVsPerformance`, `outdoorConditionRates`,
`sessionTypeDistribution`, `fingerStrengthTrend`, `currentWeekRecap`, `climbingDays`,
`startCards`, `trainingWeakness`, `antistyleRates`, `gradePyramid` + zugehörige
Structs — **vorher grep**: was noch von Erfolgen/Insights gebraucht wird, bleibt),
`Tests/StatsEngineTests.swift`
**Aufgabe:** Reihenfolge: (1) `ProgressEngine.sessionsThisWeek(discipline:)` bzw.
klettersession-basierte Wochenzählung ergänzen + Today umstellen, (2) Views löschen,
(3) Engine-Funktionen nach Referenz-Grep löschen, (4) Tests bereinigen.
`AntistyleRadarView.swift` + `LimiterFrequencyView.swift` ebenfalls löschen
(ersetzt durch `StyleProfileView`). `ChartPeriodPicker` bleibt.
**Fertig, wenn:** Projekt kompiliert, Tests grün, kein toter Code
(`grep` auf alle gelöschten Symbole = 0 Treffer).

### FO-15 · StatsEngine konsolidieren
**Kontext:** Nach FO-13/14 bleibt `StatsEngine` als Achievement-/Insights-Engine.
Klare Trennung zu `ProgressEngine` festhalten.
**Dateien:** `iOS/Models/Achievement.swift`, `Tests/StatsEngineTests.swift`,
`Tests/ProgressEngineTests.swift`
**Aufgabe:** Verbleibende `StatsEngine`-Funktionen sichten. Bleiben:
`climbAchievements`, `achievements`, `insights`, `sessionTimeline`, `weekStreak`,
`climbWeekStreak` (Today-Streak-Kachel **und** intern von den Erfolgen genutzt,
Achievement.swift:733). Löschen: `sendStats` — hat Stand `5db6216` keinen einzigen
Aufrufer (grep-validiert); vor dem Löschen erneut greppen. Kopfkommentar:
„StatsEngine = Erfolge & Session-Insights; Fortschritt-Auswertungen leben in
ProgressEngine.“ Doppelte Helfer (Disziplin-Filter o. ä.) in eine Stelle ziehen.
Tests entsprechend sortieren.
**Fertig, wenn:** Beide Engines überschneidungsfrei, alle Tests grün.

---

## Block D — Doku

### FO-16 · CLAUDE.md: S31 + S32
**Kontext:** Leitplanken dauerhaft festhalten (Konzept Abschnitt 2), damit künftige
Auswertungs-Ideen daran gemessen werden.
**Dateien:** `ClimbReflectWatch Watch App/CLAUDE.md`
**Aufgabe:** **S31 — Fortschritt statt Belastung** und **S32 — Ehrliche Statistik
oder gar keine** (inkl. Mindest-n, Lücken statt Nullen, kein `attempts`-Feld bis
Route-Identität) als Prinzipien ergänzen; kurzer Verweis auf FORTSCHRITT-KONZEPT.md.
**Fertig, wenn:** Prinzipien dokumentiert, Nummerierung fortlaufend.

---

## ⚠️ ABSTIMMEN (Defaults stehen, Veto jederzeit)

| # | Punkt | Default |
|---|---|---|
| 1 | Fingerkraft/Hangboard-Auswertung | raus (FO-14); später optional mit echtem HealthKit-Körpergewicht |
| 2 | Wochenrückblick-Share-Karte | raus (FO-14); später optional als „Monats-Karte“ im neuen Look |
| 3 | Schwellwerte `comfortSendQuote = 0.6`, `minSampleSize = 5` | so umsetzen, zentral änderbar |

## Hinweise für Claude Code

- Vor Start: `git pull` auf `dev` — Analyse basiert auf `5db6216`; lokale
  ungepushte Commits vorher pushen, sonst droht Stale-Code-Analyse.
- iOS-Pfad ist dreifach verschachtelt (siehe Legende); Watch-Pfad enthält
  Leerzeichen → in Shell-Kommandos quoten.
- Neue Dateien dem iOS-App-Target zuordnen; Test-Dateien dem Test-Target.
- Erfolge-Tab (`AchievementsView`, ER-Projekt) in diesem TODO **nicht** anfassen.
