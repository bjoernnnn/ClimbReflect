# FORTSCHRITT-KONZEPT — Neuausrichtung der Auswertungen

**Stand der Analyse:** `dev` @ `5db6216` (Remote). Lokale, ungepushte Commits sind nicht berücksichtigt.

---

## 1. Warum ein Neuanfang

Der aktuelle Statistik-Tab ist ein vertikaler Scroll aus **13 unabhängigen Chart-Karten**
(`StatisticsView.swift`). Drei strukturelle Probleme:

1. **Falscher Fokus.** Fünf Karten drehen sich um Belastung/Zustand statt ums Klettern:
   Klettermin./Woche, RPE-Trend, ACWR/Load-Management, Form-Signal (Today), Fatigue
   (Session-Detail). Eine Trainingssteuerungs-App war nie das Ziel.
2. **Unehrliche oder wertlose Zahlen.** Antistyle/Terrain/Fokus/Bedingungen zeigen
   Send-Quoten schon ab **n = 1** (100 % oder 0 % nach einer einzigen Begehung).
   Fingerkraft-Trend rechnete mit fabriziertem Körpergewicht. Effizienz-Trend ist wegen
   `attempts = 1` (Watch) bereits deaktiviert. ACWR wurde mit RPE-Defaults gestopft.
3. **Keine Erzählung.** 13 gleichrangige Karten beantworten keine Frage. Ein Kletterer
   hat genau drei: *Wo stehe ich? Werde ich besser? Woran arbeite ich?*

Die **Erfassung bleibt unangetastet** (Watch, DTO, Modelle). Das Datenmodell ist gut —
nur die Verarbeitung und Darstellung wird neu gebaut.

---

## 2. Leitplanken (werden CLAUDE.md-Prinzipien S31/S32)

**S31 — Fortschritt statt Belastung.** Die Auswertung beantwortet Kletter-Fragen
(Grade, Sends, Stil, Konsistenz). Keine Belastungs-, Ermüdungs- oder
Steuerungsmetriken: kein ACWR, kein RPE-Chart, keine Minuten-Charts, keine
Deload-Empfehlungen, keine HF-Ermüdungsdeutung. RPE/HF werden weiter *erfasst*
(Session-Detail zeigt Rohwerte), aber nicht zu Trends verrechnet.

**S32 — Ehrliche Statistik oder gar keine.**
- Quoten (Send-Rate je Grad/Stil/Grifftyp) erscheinen erst ab **n ≥ 5** Begehungen,
  immer mit sichtbarer Stichprobengröße („12 Begehungen“). Darunter: Zeile ausblenden.
- Keine Metrik basiert auf `Ascent.attempts`, bis Route-Identität (TODO-EFFIZIENZ) steht.
- Nur `isGraded`-Begehungen in grad-basierten Auswertungen (S/RP-5 gilt weiter).
- Monate ohne Daten sind **Lücken** im Chart, nie interpolierte oder Null-Werte.
- Skalenübergreifend ausschließlich über `canonicalOrder`/`GradeConverter` (S30);
  Anzeige immer in der eingestellten Skala (`boulderScale`/`routeScale`).

**Strukturprinzip:** Boulder und Seil werden **nie in einer Grafik gemischt**. Ein
Disziplin-Umschalter am Seitenkopf filtert die gesamte Seite.

---

## 3. Informationsarchitektur — Tab „Fortschritt“

Der Tab „Statistik“ wird zu **„Fortschritt“** (Icon `chart.line.uptrend.xyaxis`).
Eine Seite, fünf Blöcke, eine Unterseite. Kein Karten-Friedhof.

```
┌──────────────────────────────────────────────┐
│  [ Boulder | Seil ]        (Segmented)       │
│  [ 3M | 6M | 1J | Alles ]  (Zeitraum)        │
├──────────────────────────────────────────────┤
│ ① LEVEL                                      │
│  ┌───────────────┐  ┌───────────────┐        │
│  │ Härtester Send│  │ Härtester     │        │
│  │      7A       │  │ Flash   6B+   │        │
│  │  12. Mai 2026 │  │  3. Apr 2026  │        │
│  └───────────────┘  └───────────────┘        │
│  Wohlfühl-Grad: 6B   (Send-Quote ≥ 60 %)     │
├──────────────────────────────────────────────┤
│ ② VERLAUF — härtester Grad je Monat          │
│   7A ┤            ●───●                      │
│   6C ┤      ●───●        (Send-Linie)        │
│   6B ┤●───●      ○···○   (Flash-Linie)       │
│      └─Jan──Feb──Mär──Apr──Mai──             │
├──────────────────────────────────────────────┤
│ ③ PYRAMIDE — Sends je Grad (zentriert)       │
│   7A        ▓▓                               │
│   6C+      ▓▓▓▓░░        ▓ Sends             │
│   6B     ▓▓▓▓▓▓▓▓░░      ░ Versuche o. Send  │
│   6A   ▓▓▓▓▓▓▓▓▓▓▓▓                          │
├──────────────────────────────────────────────┤
│ ④ VOLUMEN                                    │
│   Klettertage/Monat  ▂▄▆▃▅▇   (6 Mini-Bars)  │
│   Im Zeitraum: 84 Sends · 23 Klettertage     │
├──────────────────────────────────────────────┤
│ ⑤ → Stil & Limiter               (Unterseite)│
└──────────────────────────────────────────────┘
```

### ① Level — „Wo stehe ich?“
- **Härtester Send** und **Härtester Flash** (Boulder) bzw. **Härtester Flash/Onsight**
  (Seil, mit Stil-Badge) als zwei Kacheln mit Grad + Datum. Immer über die **gesamte
  Historie** (ein PB ist ein PB), unabhängig vom Zeitraum-Picker.
- **Wohlfühl-Grad**: höchster Grad, bei dem im gewählten Zeitraum die Send-Quote
  ≥ 60 % liegt (mind. 5 Begehungen auf diesem Grad). Eine Zeile, ein Grad.

### ② Verlauf — „Werde ich besser?“
- Stufen-/Punktlinien-Chart, **echte `Date`-X-Achse im Monatsraster** (behebt das
  Label-Chaos der kategorischen Wochen-Strings aus FB-7 endgültig).
- Zwei Serien: härtester **Send** je Monat, härtester **Flash** (Boulder) bzw.
  **Flash/Onsight** (Seil) je Monat. Y-Achse: `canonicalOrder`, Labels als Grad-Strings
  der Anzeige-Skala. Monate ohne Sends → Lücke.

### ③ Pyramide — „Trägt meine Basis?“
- Zentrierte Balken je Grad, absteigend sortiert. Voller Balken = Sends, dahinter
  transparent = Begehungen ohne Send desselben Grads.
- Disziplin-konvertierend wie heute (FB-Fix bleibt), zusätzlich Zeitraum-gefiltert.
- Erzählt, ob unter dem Top-Grad genug Substanz liegt oder ob es „kopflastig“ wird.

### ④ Volumen — kompakt, eine Karte
- **Klettertage je Monat** (unique Kalendertage mit ≥ 1 Session der gewählten
  Disziplin) als 6-Monats-Mini-Balken — Konsistenz sichtbar, ohne Minuten-Zählerei.
- Zwei Kennzahlen für den gewählten Zeitraum: **Sends** · **Klettertage**.
- Bewusst diszipliniert klein. Keine Minuten, keine Kalorien, kein Streak-Druck.

### ⑤ Stil & Limiter — Unterseite (NavigationLink)
- Send-Quote je **Wandwinkel / Grifftyp / Kletterart**, sortiert schwächste zuerst,
  **nur Zeilen mit n ≥ 5**, jede Zeile mit „(n Begehungen)“. Zeitraum-gefiltert.
- **Limiter-Häufigkeit** aus den Session-Reflexionen (Anzahl Nennungen im Zeitraum).
- Absichtlich von der Hauptseite runter: wer analysieren will, findet es — die
  Hauptseite bleibt Fortschritt.

---

## 4. Exakte Metrik-Definitionen

| Metrik | Definition |
|---|---|
| Send | `Ascent.result == .top` |
| Disziplin-Filter | `gradeSystem.isBoulder` des Ascents (Boulder: Fb/V · Seil: French/UIAA) |
| Härtester Send | max `canonicalOrder` über Sends mit `isGraded`; bei Gleichstand frühestes Datum („zuerst erreicht“); Anzeige via `GradeConverter.display` |
| Härtester Flash (Boulder) | wie oben, zusätzlich `style == .flash` |
| Härtester Flash/Onsight (Seil) | wie oben, `style ∈ {flash, onsight}`; Badge zeigt den Stil des Bestwerts |
| Wohlfühl-Grad | höchster Grad g (Anzeige-Skala) mit Begehungen(g) ≥ 5 und Sends(g)/Begehungen(g) ≥ 0.6 im Zeitraum; Begehung = jeder Ascent (top/attempt/quit), `isGraded` |
| Verlaufspunkt | je Kalendermonat: max `canonicalOrder` der Sends bzw. Flash/Onsight-Sends; kein Ascent → kein Punkt |
| Pyramiden-Balken | je Anzeige-Grad: (Sends, Begehungen ohne Send) im Zeitraum, `isGraded`, disziplin-konvertiert |
| Klettertag | Kalendertag (`startOfDay`) mit ≥ 1 Session der gewählten Disziplin (`isClimbing`, `sessionType` passend) |
| Stil-Quote | Sends/Begehungen je Tag-Ausprägung, nur n ≥ 5, Zeitraum-gefiltert |
| Limiter-Zähler | Anzahl Sessions im Zeitraum, deren `limiters` den Limiter enthalten |

Schwellwerte (60 % Wohlfühl-Quote, n ≥ 5) sind als Konstanten in der Engine
definiert — an einer Stelle änderbar.

---

## 5. Was entfällt (mit Begründung)

| Karte / Engine | Grund |
|---|---|
| `LoadManagementView` + `trainingLoad` (ACWR) | Belastungssteuerung — explizit unerwünscht; Historie mit RPE-Defaults ohnehin fragwürdig |
| `RPETrendView` + `rpeHistory` | Belastungs-Chart; RPE bleibt als Rohwert im Session-Detail |
| `FormSignalView` + `formSignal` (Today) | Deload-/Technik-Empfehlungen = Trainingssteuerung |
| `SessionFatigueView` (Session-Detail) | HF-Ermüdungsdeutung = Belastung |
| `ProgressChartView` + `weeklyMinutes` | Minuten sind kein Kletter-Fortschritt |
| `FingerStrengthTrendView` + `fingerStrengthTrend` | fabriziertes Körpergewicht verletzt S32; siehe „Später“ |
| `EfficiencyTrendView` + `efficiencyTrend` | bereits deaktiviert (attempts=1); kommt erst mit Route-Identität wieder |
| `TerrainHeatmapView`, `FocusPerformanceView`, `OutdoorConditionsView` + Engines | Korrelations-Karten ohne Mindest-n; Terrain-Inhalt geht sauberer in „Stil & Limiter“ auf |
| `SessionTypeChartView` + `sessionTypeDistribution` | Deko ohne Frage dahinter; Verteilung sieht man in der Session-Liste |
| `WeeklyRecapView` + `currentWeekRecap` | Überladung; Kern-Infos stecken in Volumen + Session-Liste; siehe „Später“ |
| Today: `trainingWeaknessCard` + `trainingWeakness` | Coaching-Karte; Limiter-Info lebt in „Stil & Limiter“ |
| `StartInsightCarousel` + `startCards` | tote Datei — wird nirgends eingebunden |
| `GradeProgressView`, `GradePyramidView`, `StatisticsView` | ersetzt durch Verlauf-Chart, neue Pyramide, `FortschrittView` |

**Bleibt unverändert:** Erfassung komplett (Watch/DTO/Modelle), `GradeConverter` +
`canonicalOrder` (S30), Erfolge-System (`climbAchievements`, läuft parallel als
ER-Projekt), Session-Detail-Insights ohne Fatigue (Zeit-Donut, Timeline, Rohwerte),
Projekte-Tab, `ChartPeriodPicker` (wird wiederverwendet), Today-Hero-Trophäen
(künftig aus der neuen Engine gespeist).

---

## 6. Technischer Schnitt

- **Neue Datei `Models/ProgressEngine.swift`**: alle Berechnungen aus Abschnitt 4 als
  pure static functions über `[ClimbSession]` — vollständig unit-testbar
  (`ProgressEngineTests.swift`). Ein `Discipline`-Enum (boulder/rope) kapselt den
  Filter und die Ziel-Anzeige-Skala.
- **`StatsEngine` schrumpft** auf Erfolge (`climbAchievements`, `achievements`,
  benötigte Helfer wie `sendStats`) und Session-Insights (`insights`,
  `sessionTimeline`). Alles andere wird mit den Karten gelöscht — inklusive Tests.
- **Reihenfolge: erst bauen, dann abreißen.** Die App bleibt nach jedem Commit
  lauffähig; der Altbestand fällt erst, wenn `FortschrittView` ihn ersetzt hat.

---

## 7. ⚠️ ABSTIMMEN (nicht blockierend — Default steht)

1. **Fingerkraft/Hangboard:** Default = ersatzlos raus. *Optional später:* eigene
   Trainings-Unterseite mit echtem Körpergewicht aus HealthKit (nie geschätzt).
2. **Wochenrückblick als Share-Karte:** Default = raus. *Optional später:* teilbare
   „Monats-Karte“ im neuen Look (PB + Pyramiden-Ausschnitt) als eigenes Feature.
3. **Schwellwerte** (Wohlfühl-Quote 60 %, Mindest-n 5): von mir gesetzt, zentral
   änderbar — Einspruch jederzeit möglich.

## 8. Später (bewusst nicht in v1)

- Pyramiden-Vergleich Zeitraum vs. Vorzeitraum (Geist-Kontur)
- Effizienz je Route nach Route-Identität B (TODO-EFFIZIENZ)
- Outdoor-Auswertungen, sobald genug Outdoor-Daten existieren (n ≥ 5 greift dann von allein)
- Teilbare Monats-Karte (siehe Abstimmen-Punkt 2)
