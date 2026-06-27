# TODO – Analytics-Ausbau · Start-Widget · Training · Schuh-Verfeinerung

**Branch:** `dev` (Stand `origin/dev` @ `cdacb9a`)
**Pfade:** iOS `ClimbReflect/ClimbReflect/ClimbReflect/`, Watch `ClimbReflectWatch Watch App/`
**Format:** Eine Aufgabe = ein Commit. Block: *Kontext / Dateien / Aufgabe / Fertig-wenn*.

### Leitplanken (gelten für die ganze Runde)
- **Watch unangetastet.** Einzige Watch-Änderung ist der **bereits abgestimmte Schuh-Selektor**
  (gleiche Auswahl wie Projekt). Kernschleife *Start → Versuch → klassifizieren → Ende* bleibt
  exakt wie sie ist. Jede weitere Watch-Idee ist **⚠️ ABSTIMMEN**, nicht einfach umsetzen.
- **Training-Erfassung: iPhone-only** (Vorgabe). Watch-Beteiligung nur nach Rücksprache.
- **Konvention:** Jede neue Auswertung ist eine **reine `StatsEngine`-Funktion + Test**
  (`Models/Achievement.swift`, `ClimbReflectTests/StatsEngineTests.swift`); die Charts sind
  Components und hängen im **Statistik-Tab** (`StatisticsView`), sofern nicht anders genannt;
  Zeitraum über den vorhandenen `ChartPeriodPicker`.
- **Migrationen additiv** in einer gemeinsamen neuen Schema-Stufe bündeln (lightweight), aufbauend
  auf der für `Shoe` geplanten Stufe.

---

# Gruppe 1 — Auswertungen aus vorhandenen Daten

## A1 — Versuche-bis-Top & Flash-Quote im Zeitverlauf  *(war #1)*
**Ziel & Darstellung.** Die *Lernkurve* zeigen: werde ich auf einem Grad effizienter? Im
Statistik-Tab ein Liniendiagramm über die Zeit (Monat) mit zwei Reihen: **Ø Versuche bis Top**
(über getoppte Begehungen) und **Flash-Quote** (%). Optionaler Grad-Filter. Sinkende Versuche-bis-Top
= echter Fortschritt, den die Pyramide nicht zeigt.

**Umsetzung**
- *A1.1 — StatsEngine.* `efficiencyTrend(_ sessions:, period:) -> [EfficiencyPoint]` mit
  `EfficiencyPoint{ periodStart: Date, avgAttemptsToTop: Double?, flashRate: Double, sampleCount: Int }`.
  Flash = `style == .flash` bzw. `attempts == 1 && result == .top` (entscheiden, dokumentieren).
  *Fertig-wenn:* Tests für leere Perioden, reine-Fail-Perioden, korrekte Mittelung.
- *A1.2 — View.* `Views/Components/EfficiencyTrendView.swift` (Charts `LineMark`, zwei Serien,
  zweite Achse für %), Einbindung in `StatisticsView` mit `ChartPeriodPicker`.
  *Fertig-wenn:* Diagramm rendert mit echten Daten + `#Preview`; leere Perioden brechen nicht.

## A2 — Send-Rate-Heatmap: Wandwinkel × Grifftyp  *(war #2)*
**Ziel & Darstellung.** Den *echten Antistyle nach Terrain* auf einen Blick. Kleine Matrix/Heatmap
im Statistik-Tab: Zeilen = `WallAngle`, Spalten = `HoldType`, Zellfarbe = Erfolgsquote (rot→grün),
Zelltext = Quote % + n. Zellen ohne Daten ausgegraut. Liefert konkrete Trainingsrichtung
(„Sloper am Überhang 20 %"). Ergänzt den Stil-Radar um die *Terrain*-Dimension.

**Umsetzung**
- *A2.1 — StatsEngine.* `terrainSendRates(_ sessions:) -> TerrainGrid` mit pro (WallAngle, HoldType)
  `(rate: Double, count: Int)`; nur Begehungen mit **beiden** Tags. *Fertig-wenn:* Tests für
  Zählung/Quote inkl. leerer Zellen.
- *A2.2 — View.* `Views/Components/TerrainHeatmapView.swift` (`Grid`/`LazyVGrid`, Farbinterpolation
  accent↔danger), in `StatisticsView`. *Fertig-wenn:* Heatmap rendert; bei zu wenig getaggten Daten
  dezenter Hinweis statt leerer Matrix.

## A3 — Ermüdungskurve innerhalb der Session  *(war #3)*
**Ziel & Darstellung.** Sehen, *wann die Leistung kippt*. In der **Session-Detailansicht** eine
kleine Timeline: X = Minuten seit Sessionstart (`ascent.date − session.date`), Punkte = Begehungen,
Farbe nach Ergebnis (top/attempt/quit); optional Linie „kumulierte Sends". Beantwortet „wie lange
bin ich wirklich stark?" und ob das Hardest-Projekt zu spät kommt.

**Umsetzung**
- *A3.1 — StatsEngine.* `sessionTimeline(_ session:) -> [TimelinePoint]` mit
  `TimelinePoint{ minuteOffset: Double, result: AscentResult, gradeLabel: String }`, sortiert.
  *Fertig-wenn:* Tests für Offset-Berechnung + Sortierung.
- *A3.2 — View.* `Views/Components/SessionFatigueView.swift` (`PointMark` + optional `LineMark`),
  in `SessionDetailView` nach dem `SessionTimeDonut`. Nur ab ≥ 4 Begehungen mit Zeitstempel.
  *Fertig-wenn:* Bei reicher Watch-Session sichtbar, sonst ausgeblendet.

## A4 — Grad-Konsolidierung & Max-Grad-Trend  *(war #4)*
**Ziel & Darstellung.** Den Unterschied zwischen *„einmal geschafft"* und *„beherrscht"* zeigen.
Statistik-Tab: (a) **Max-Grad-Linie** (Boulder/Route getrennt) über Monate; (b)
**Konsolidierung** je Grad — Anzahl Sends mit Schwellenmarkierung „solide ab X Sends". Die
ehrlichste „Ich werde besser"-Aussage.

**Umsetzung**
- *A4.1 — StatsEngine.* `maxGradeTrend(_ sessions:, discipline:) -> [GradeTrendPoint]` (Monat →
  höchster getoppter `sortOrder` + Label) und `gradeConsolidation(_ sessions:, discipline:) ->
  [(gradeLabel, sendCount)]`. *Fertig-wenn:* Tests inkl. Disziplin-Trennung über `sortOrder`.
- *A4.2 — View.* `Views/Components/GradeProgressView.swift` (LineMark + Schwellenlinie), Disziplin-
  Umschalter; in `StatisticsView` (ggf. unter der bestehenden Pyramide). *Fertig-wenn:* rendert,
  Umschalter funktioniert.

---

# Gruppe 2 — Wenig neue Daten, viel Erkenntnis

## A5 — Belastungssteuerung (ACWR)  *(war #5)*
**Ziel & Darstellung.** Über-/Unterlastung erkennen. Statistik-Tab-Karte: **Wochenlast-Balken**
(sRPE = Σ RPE×Minuten je Woche) + **ACWR-Wert** (akute 7-Tage-Last / chronische 28-Tage-
Wochenlast) mit Ampel: grün 0.8–1.3, gelb < 0.8 oder 1.3–1.5, rot > 1.5. Kurzer, **neutraler**
Hinweistext.
> Hinweis: ACWR ist eine bekannte **Heuristik** zur Trainingslast, **keine medizinische Beratung**.
> Im Text bewusst ohne Versprechen/Diagnose formulieren.

**Umsetzung**
- *A5.1 — StatsEngine.* `trainingLoad(_ sessions:) -> LoadSummary{ weeklyLoads:[(weekStart, load)],
  acute7d, chronic28dWeekly, acwr: Double? }`, `load = RPE × durationMinutes` (Sessions ohne RPE
  zählen 0 oder werden ausgewiesen). *Fertig-wenn:* Tests für Wochenbucketing + ACWR-Formel + nil
  bei zu wenig Historie.
- *A5.2 — View.* `Views/Components/LoadManagementView.swift` (BarMark + Ampel-Gauge + Hinweistext),
  in `StatisticsView`. *Fertig-wenn:* rendert; bei < 4 Wochen Historie „noch zu wenig Daten".

## A6 — Körpergewicht aus HealthKit → Kontext & Basis  *(war #6)*
**Ziel & Darstellung.** Gewichts-**Verlauf** als Kontext für Form (und später Basis für
Hangboard-Last in % Körpergewicht). Dezente Trendlinie, **read-only** aus Apple Health, **opt-in**.
> Wichtig (Wohlbefinden): **keine Zielgewichte, keine Bewertung, kein Ernährungs-/Kalorienbezug,
> keine „Ideal"-Werte** — ausschließlich ein neutraler Verlauf. Feature in den Einstellungen
> abschaltbar; nichts davon erscheint, wenn der Nutzer es nicht aktiviert.

**Umsetzung**
- *A6.1 — Service.* `RedpointHealthService`: `bodyMass` zur read-Authorization ergänzen;
  `latestBodyMass() async -> Double?` und `bodyMassHistory(days:) async -> [(Date, Double)]`.
  *Fertig-wenn:* liefert Werte bei vorhandenen Health-Daten, sonst leer/`nil`, ohne Fehler.
- *A6.2 — View + Toggle.* Opt-in-Schalter in `SettingsView`; `Views/Components/BodyMassTrendView.swift`
  (neutrale Linie, keine Zielwerte). *Fertig-wenn:* nur bei aktivem Opt-in sichtbar; sauber leer
  ohne Daten.

## A7 — `focusRating` aktivieren → Fokus vs. Leistung  *(war #8)*
**Ziel & Darstellung.** Den *Kopf-Faktor* sichtbar machen. Das bereits vorhandene (bisher
ungenutzte) `focusRating` 1–5 im **iPhone-Reflexionsfragebogen** erfassen; im Statistik-Tab Fokus
gegen Send-Rate stellen. (Bewusst **nicht** auf der Watch — keine Watch-Änderung.)

**Umsetzung**
- *A7.1 — Eingabe.* Im iPhone-Reflexions-/Fragebogen-View ein 1–5-Fokus-Rating ergänzen (schreibt
  `session.focusRating`). *Fertig-wenn:* Wert wird gespeichert und bleibt erhalten.
- *A7.2 — Auswertung.* `StatsEngine.focusVsPerformance(_ sessions:)` + kleine Karte
  (Fokus-Stufe → Ø Send-Rate). *Fertig-wenn:* rendert ab genügend bewerteten Sessions, sonst Hinweis.

## A8 — Outdoor-Bedingungen  *(war #9)*
**Ziel & Darstellung.** Die *besten Send-Bedingungen* erkennen. An Outdoor-Sessions optionale Felder
(grobe **Conditions**: schlecht/ok/gut; optional Temperatur). Statistik: Send-Quote nach Bedingung.

**Umsetzung**
- *A8.1 — Modell.* `ClimbSession`: `conditionsRaw: String?` (enum `Conditions{poor, ok, good}`),
  `temperatureC: Double?`. Additiv migrieren. *Fertig-wenn:* Felder vorhanden, Migration verlustfrei.
- *A8.2 — Eingabe.* In `ManualSessionView` und im Standort-Editor (ST-2) nur bei `outdoor == true`
  einblenden. *Fertig-wenn:* nur für Outdoor sichtbar, Werte speichern.
- *A8.3 — Auswertung.* `StatsEngine.outdoorConditionRates(_ sessions:)` + kleine Karte.
  *Fertig-wenn:* rendert ab genügend Outdoor-Sessions.

---

# Gruppe 3 — Start-Widget (NEU, abgestimmt)

## W1 — Swipebares Insight-/Tipp-Widget auf der Startseite
**Ziel & Darstellung.** Ganz oben auf der Startseite (`TodayView`) ein **horizontal swipebares**
Karten-Widget mit **3–4 Karten** — ein Mix aus **Information und Tipp**, das man nach rechts wischt:
z. B. (1) Wochen-Recap, (2) ein aktueller **Erfolg**, (3) ein **Trainings-Tipp** (aus Antistyle/
Limiter/Terrain-Schwäche), (4) ein **Form-/Last-Hinweis** (Streak / ACWR). Eine Karte sichtbar,
Seiten-Dots, kompakt. iPhone-only.

**Umsetzung**
- *W1.1 — StatsEngine.* `startCards(_ sessions:, weakness:, load:) -> [StartCard]` mit
  `StartCard{ kind, icon: String, title, body, tone }`. Quellen wiederverwenden:
  `currentWeekRecap`, `climbAchievements`, `trainingWeakness`/`antistyleRates`/`terrainSendRates`,
  `formSignal`/`trainingLoad`. Wählt 3–4 *relevante* Karten mit Fallbacks bei wenig Daten
  (z. B. Onboarding-Tipp). *Fertig-wenn:* liefert immer ≥ 1 sinnvolle Karte, auch bei leerer Historie.
- *W1.2 — View.* `Views/Components/StartInsightCarousel.swift` (`TabView` + `.tabViewStyle(.page)`,
  feste Höhe), **oben in `TodayView`** direkt nach `header` (vor/um `heroTrophyRow`). *Fertig-wenn:*
  3–4 Karten wischbar mit Dots; bricht bei einer Karte nicht; `#Preview`.

---

# Gruppe 4 — Training (NEU)  *(war #10, iPhone-only)*

**Ziel & Darstellung.** Training-Sessions inhaltlich erfassen statt nur „Typ = Training": Übungen
wie **Hangboard-Maximalhang** (Kantengröße + Zusatzlast), **Repeaters**, **Klimmzüge**, **Core**,
**Campus**. Daraus die **Fingerkraft-Progression** (stärkster Performance-Prädiktor): Last bzw.
Last/kg Körpergewicht über die Zeit. **Erfassung ausschließlich auf dem iPhone** (übersichtliche
Formulareingabe); die Watch bleibt unverändert.

**Umsetzung**
- *T1 — Datenmodell.* Neu `Models/TrainingExercise.swift`:
  `enum TrainingKind{ hangboardMaxHang, repeaters, pullUps, core, campus, other }`;
  `@Model TrainingSet{ id, kindRaw, edgeMM: Int?, addedWeightKg: Double?, reps: Int?,
  durationSeconds: Double?, note: String?, order: Int, session: ClimbSession? }`. Relation an
  `ClimbSession` (`@Relationship(deleteRule: .cascade) var trainingSets: [TrainingSet]`). Additiv
  migrieren. *Fertig-wenn:* Migration verlustfrei; Training-Session kann Sets halten.
- *T2 — iPhone-Eingabe.* Für Sessions mit `sessionType == .training` eine Trainings-Sektion
  (in `SessionDetailView` oder neu `Views/TrainingDetailView.swift`): Sätze hinzufügen/bearbeiten/
  löschen je `TrainingKind` mit den passenden Feldern (Hangboard: Kante + Zusatzlast + Dauer;
  Klimmzüge: Reps + Zusatzlast …). *Fertig-wenn:* Sätze lassen sich auf dem iPhone erfassen und
  bleiben erhalten.
- *T3 — StatsEngine.* `fingerStrengthTrend(_ sessions:, bodyMass:) -> [StrengthPoint]`: bestes
  `hangboardMaxHang`-Gesamtgewicht (Zusatzlast + optional Körpergewicht aus A6) je Datum/Kantengröße;
  analog `pullUpMax`. *Fertig-wenn:* Tests für Bestwert-Auswahl + optionale Körpergewichts-Normierung.
- *T4 — View.* `Views/Components/FingerStrengthTrendView.swift` (LineMark, optional je Kantengröße),
  Platzierung im Statistik-Tab (oder eigener „Training"-Abschnitt). *Fertig-wenn:* rendert mit echten
  Trainingsdaten; sauber leer ohne.
- *T5 — ⚠️ ABSTIMMEN (nicht umsetzen).* Watch-Beteiligung am Training? **Default: nein.** Falls je
  gewünscht, nur eine minimale „Übung abhaken"-Geste — erst nach Rücksprache, separater Plan.
- *T6 — CLAUDE.md.* **S29 – Training wird nur auf dem iPhone erfasst** (Watch unverändert);
  Fingerkraft-Progression lebt rein funktional in `StatsEngine.fingerStrengthTrend`.

---

# Schuh-Verfeinerung (ergänzt/ersetzt Teile der SH-Tasks in TODO-SESSION-INSIGHTS.md)

> Diese Regeln gehen den entsprechenden SH-Tasks **vor**. Bitte beim Umsetzen der SH-Tasks
> berücksichtigen (betroffen: SH-1, SH-2, SH-3, SH-7, SH-8, SH-9).

## SH-A — Nie „kein Schuh": immer genau einer aktiv
**Ziel.** In der Auswahl (Watch wie iPhone) gibt es **kein „Keiner"**. Hat der Nutzer keine eigenen
Schuhe angelegt, ist ein eingebauter Standard **„Eigener Schuh"** aktiv; legt er eigene an, wird
daraus gewählt — aber immer ist genau einer gesetzt.

**Umsetzung**
- *SH-A1 — Modell/Seed (ergänzt SH-1).* `Shoe.isBuiltInDefault: Bool = false`. Beim ersten Start/
  Migration genau **einen** Schuh „Eigener Schuh" mit `isBuiltInDefault = true` seeden (nicht
  löschbar; Name editierbar). *Fertig-wenn:* nach Migration existiert immer mind. dieser Schuh.
- *SH-A2 — Auswahl (ersetzt „Keiner" in SH-3/SH-8).* Picker (iPhone-`AddAscentView`, Watch-Selektor)
  zeigen **kein „Keiner"** mehr; `selectedShoe` ist nie `nil`. *Fertig-wenn:* es lässt sich kein
  Zustand „kein Schuh" herstellen.
- *SH-A3 — Empfang (ergänzt SH-9).* Kommt vom Watch-DTO keine gültige Schuh-ID, wird der
  **„Eigener Schuh"** zugeordnet (statt `nil`). *Fertig-wenn:* jede Begehung hat einen Schuh.

## SH-B — Standard-Schuh je Kletterart (Mehrfachauswahl)
**Ziel.** Beim Anlegen/Bearbeiten eines Schuhs zuordnen, für welche **Kletterarten** er der
Standard ist — z. B. neuer Scarpa = Standard für **Vorstieg (lead) und Toprope** (Mehrfachauswahl
aus boulder/lead/topRope/autoBelay). Beim Sessionstart bzw. Klassifizieren wird der Standard-Schuh
des aktuellen Typs **vorausgewählt**; gibt es keinen, „Eigener Schuh".

**Umsetzung**
- *SH-B1 — Modell (ergänzt SH-1).* `Shoe.defaultForTypesRaw: [String]` (SessionType-rawValues, ohne
  `training`). *Fertig-wenn:* Feld vorhanden, additiv migriert.
- *SH-B2 — Verwaltung (ergänzt SH-2).* In `ShoesView` Mehrfachauswahl „Standard für: Boulder /
  Vorstieg / Toprope / Auto-Belay". **Ein Typ hat genau einen Standard** — Zuweisung entzieht den
  Typ automatisch anderen Schuhen. *Fertig-wenn:* Zuordnung speichert; kein Typ doppelt belegt.
- *SH-B3 — Vorauswahl (ergänzt SH-7).* Bei Sessionstart/erstem Versuch eines Typs `selectedShoe` =
  Standard-Schuh dieses Typs, sonst „Eigener Schuh"; manuelles Umschalten bleibt jederzeit möglich
  (Snapshot-Verhalten wie gehabt). *Fertig-wenn:* z. B. Vorstieg-Session startet mit dem
  Vorstieg-Standardschuh, ohne dass man wählt.

---

## Reihenfolge (Vorschlag)
1. **Schnelle Wins aus Daten:** A1, A2, A4 → A5 (ACWR).
2. **Start-Widget:** W1 (nutzt u. a. A5/Weakness).
3. **Wenig neue Daten:** A7 (focusRating), A8 (Conditions), A6 (Körpergewicht, opt-in).
4. **Session-intern:** A3 (Ermüdungskurve).
5. **Training:** T1 → T2 → T3 → T4 → T6 (T5 nur Rücksprache).
6. **Schuh-Verfeinerung** zusammen mit den SH-Tasks umsetzen (SH-A vor SH-B).
