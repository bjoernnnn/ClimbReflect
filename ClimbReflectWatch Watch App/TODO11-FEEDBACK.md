# TODO11 – Nutzer-Feedback: Projekte-Grade, Ascent-Editing, Klettertage, Statistik-Fixes

Audit-Basis: `origin/dev` @ e5f6e02. ⚠️ **Screenshots zeigen Features (z. B.
Boulder/Seil-Umschalter der Pyramide), die in diesem Stand nicht existieren →
es gibt lokale, ungepushte Commits. Vor Abarbeitung: lokalen Stand pushen;
Claude Code verifiziert jede Datei-/Zeilenangabe gegen den aktuellen Stand
und passt an, statt blind zu patchen. Bereits lokal Erledigtes überspringen.**

Ein Task = ein Commit.

---

## Block A – Projekte & Begehungen

### FB-1: Projekt-Grad als Stammdatum – Editor + Anzeige
**Kontext:** `Project.gradeSystemRaw` und `Project.targetGradeRaw` existieren,
werden aber nirgends geschrieben (grep `targetGradeRaw =` → 0 Treffer in Views).
Anzeige-Stellen (ProjectDetailView:134, ProjectsView:183) laufen daher ins Leere.
Der Grad eines Projekts ist fix — er gehört ans Projekt, nicht an jeden Versuch.
**Dateien:** `Views/ProjectDetailView.swift`, ggf. Projekt-Anlage-Sheet
(in ProjectsView), `Models/Project.swift`
**Aufgabe:**
1. Beim Anlegen und in der Projekt-Detailansicht: Picker Grad-System
   (disziplinabhängig Boulder/Seil) + Grad; schreibt `gradeSystemRaw`/
   `targetGradeRaw`.
2. Grad prominent im Projekt-Header und in der Projektliste anzeigen
   (über `GradeConverter.display`).
3. Bestehende Projekte ohne Grad: Hinweis-Chip „Grad festlegen" in der
   Detailansicht.
**Fertig-wenn:** Projekt „Rote Linie" mit French 7a anlegen → Grad erscheint
in Liste + Detail; Wert überlebt App-Neustart.

### FB-2: Projekt-Grad an die Watch syncen und beim Klassifizieren vorbelegen
**Kontext:** `ProjectInfo` trägt nur id+name (`SyncService.swift`,
`WatchSessionReceiver.pushProjectsToWatch`). Beim Klassifizieren eines
Projektversuchs muss der Grad jedes Mal neu gekurbelt werden; Quick-Bank-
Versuche auf Projekten bleiben ungegradet, obwohl der Grad bekannt ist.
**Dateien:** `WatchSessionReceiver.swift` (projectList-Dict),
`SyncService.swift` (ProjectInfo, applyContext), `WorkoutManager.swift`
(quickBank, persistSelectedProject), `Views/AttemptLogView.swift`
**Aufgabe:**
1. projectList-Dict um `"grade"` und `"gradeSystem"` erweitern; `ProjectInfo`
   um `grade: String?`, `gradeSystem: String?`; applyContext mappt durch
   (fehlende Keys → nil, alte Kontexte dekodieren weiter).
2. AttemptLogView: ist ein Projekt mit Grad aktiv → `gradeIndex` auf den
   Projekt-Grad setzen und das System des Projekts verwenden (statt
   Session-Default); Nutzer kann per Crown weiterhin abweichen.
3. `quickBank()`: aktives Projekt mit Grad → `grade` + `gradeSystem` vom
   Projekt übernehmen (kein „?"-/Unbewertet-Fall mehr für Projektversuche).
4. `persistSelectedProject`/Snapshot um die zwei Felder ergänzen (Recovery).
**Fertig-wenn:** Projekt mit Grad 7A wählen → Klassifizieren-Screen startet
auf 7A; Quick-Bank erzeugt Ascent mit Grad 7A/korrektem System auf dem iPhone.

### FB-3: Vollwertiger Ascent-Editor (Grad, System, Ergebnis, Stil, Versuche)
**Kontext:** `EditAscentAssociationsSheet` kann nur Projekt + Schuh. Ein beim
Banken vergessener/falscher Grad ist aktuell dauerhaft — für eine Tracking-App
mit „Datenkorrektheit zuerst" das größte Loch der Begehungs-Pflege.
**Dateien:** `Views/EditAscentAssociationsSheet.swift` (erweitern und ggf. in
`EditAscentSheet` umbenennen), Aufrufstelle in `SessionDetailView.swift`
**Aufgabe:**
1. Sektionen ergänzen: Grad-System-Picker (disziplinkonsistent), Grad-Picker,
   Ergebnis (Top/Versuch/Aufgegeben), Stil (nur bei Top), Versuche-Stepper.
2. Ungegradete Ascents („Unbewertet", vgl. RP-5) prominent editierbar machen:
   Badge in der Row tappt direkt in den Editor.
3. `session.updatedAt = .now` beim Speichern.
**Fertig-wenn:** Ungegradeter Watch-Ascent lässt sich nachträglich auf 6B/Top/
Flash korrigieren und erscheint danach korrekt in Pyramide + Trends.

### FB-4: AscentRow-Layout reparieren (Zeilenumbruch-Chaos)
**Kontext:** Screenshot: „1 Ver-such", „2:5 9", vertikal zerquetschter
Projekt-Chip. Ursache: Metrik-HStack (Versuche-Text + Timer + Höhenmeter +
Projekt-Chip) in einer Zeile, rechts fressen Foto-Thumbnail + redundantes
Ergebnis-Label die Breite → SwiftUI quetscht und bricht zeichenweise um.
**Dateien:** `Views/Components/AscentRowView.swift`
**Aufgabe:**
1. Trailing-Ergebnis-Text entfernen (Icon links codiert das Ergebnis bereits;
   Farbe bleibt). Foto-Thumbnail bleibt trailing.
2. Zeilenstruktur: Z1 Grad + System-Badge + Stil-Chip · Z2 Metriken
   (Versuche, Timer, Höhenmeter) mit `lineLimit(1)` + `fixedSize(horizontal:
   false, vertical: true)` vermeiden — stattdessen `lineLimit(1)` +
   `minimumScaleFactor(0.8)` · Z3 Projekt-Chip (eigene Zeile, analog
   SH-10-Schuh-Zeile, `lineLimit(1)` + truncation) · Z4 Schuh-Chip wie gehabt.
3. Mit langem Projektnamen („Red Chili Voltage 2") + Timer + BPM-freier
   Variante auf iPhone-mini-Breite gegentesten (Preview mit 320 pt).
**Fertig-wenn:** Kein Wort- oder Zeichenumbruch mehr in der Begehungsliste
bei den Screenshot-Daten; Preview mit Extremwerten sauber.

---

## Block B – Session-Semantik

### FB-5: ⚠️ ABSTIMMEN → Kennzahl „Klettertage" statt Session-Zählung für Konsistenz-Metriken
**Kontext:** Bouldern + Seil am selben Tag = 2 ClimbSessions. Wochen-Streak ist
wochenbasiert (korrekt), aber „Diese Woche"-Karte, WeekRecap und Erfolge zählen
Session-Objekte → ein Hallenbesuch wirkt doppelt.
**Empfehlung:** `StatsEngine.climbingDays(_:in:)` = eindeutige Kalendertage mit
≥1 Klettersession. Verwenden in: StartCards „Diese Woche" („2 Sessions · 1 Tag"
oder nur Tage — Entscheidung), WeekRecap.sessions → zusätzlich `days`,
Erfolgs-Bedingungen die Häufigkeit messen. Session-Zählung bleibt in
Typ-Verteilung/Listen unberührt. Streak-Definition unverändert (Wochen).
**Dateien:** `Models/Achievement.swift` (StatsEngine), `Views/Components/
StartInsightCarousel.swift`, `Views/WeeklyRecapView.swift`
**Fertig-wenn (nach Entscheidung):** Boulder- + Seilsession am selben Tag →
„Diese Woche" zeigt 1 Klettertag; Unit-Test für climbingDays über
Tagesgrenze/Zeitzone.

### FB-6: Reflexions-Editor an Session-Typ anpassen
**Kontext:** `SessionDetailView` (Reflexions-Sektion ~Z. 590 ff.) zeigt
techniqueFocusPicker + focusRatingPicker (und kletterbezogene Placeholder)
bedingungslos — bei Hangboard-/Krafttraining unpassend.
**Dateien:** `Views/SessionDetailView.swift`
**Aufgabe:**
1. `techniqueFocusPicker` und `focusRatingPicker` nur bei
   `session.isClimbing`.
2. Training behält: typePicker, rpePicker, limiterPicker (= Zielkapazität,
   Beschriftung dort auf „Trainiert" o. ä. schärfen), Freitextfelder mit
   trainingsneutralen Placeholdern („z. B. Max-Hangs erstmals 10 mm…").
3. `hasReflection`-Bedingung (~Z. 772) entsprechend mitziehen.
**Fertig-wenn:** Training-Session zeigt keine Technik-/Fokus-Picker;
Klettersession unverändert vollständig.

---

## Block C – Statistik-Fixes

### FB-7: Fortschritt-Chart – Datums-Achse statt KW-String-Kategorien
**Kontext:** `ProgressChartView` nutzt `point.label` („KW 21") als kategorische
x-Achse → Swift Charts rendert alle 8 Labels ohne Ausdünnung
(„KW 21KW 22KW 23…", Screenshot).
**Dateien:** `Views/Components/ProgressChartView.swift`,
ggf. `WeeklyPoint.label` (Achievement.swift)
**Aufgabe:**
1. `BarMark(x: .value("Woche", point.weekStart, unit: .weekOfYear), …)`.
2. `AxisMarks(values: .automatic(desiredCount: 4))` mit Label „dd.MM."
   (de_DE) — konsistent zum Trainingsbelastungs-Chart.
3. Header-Summe „538 Min" um Zeitraum ergänzen („letzte 8 Wochen"), damit
   die Zahl einordbar ist.
**Fertig-wenn:** 8-Wochen-Ansicht zeigt 3–4 lesbare, eindeutig zuordenbare
Achsen-Labels; kein Label-Überlauf auf iPhone mini.

### FB-8: Effizienz-Trend aus dem Statistik-Tab nehmen (bis Route-Identität umgesetzt)
**Kontext:** Watch-Ascents haben systembedingt `attempts = 1` → „Ø Versuche
bis Top" zeigt faktisch falsche Werte (Screenshot: Linie 3→1 ohne Aussage);
Flash-Rate hängt am manuellen Flag. Verstößt gegen „keine fabrizierten/
irreführenden Werte". Der Rewrite ist in TODO-EFFIZIENZ.md spezifiziert.
**Dateien:** `Views/StatisticsView.swift`
**Aufgabe:** `EfficiencyTrendView` aus dem Tab entfernen (Datei + Engine-Code
behalten; ein `// EFF: reaktivieren nach TODO-EFFIZIENZ` an der Stelle).
Kein Feature-Flag, keine halbe Anzeige.
**Fertig-wenn:** Karte erscheint nicht mehr; Build grün; Kommentar-Marker
vorhanden.

### FB-9: Trainingsbelastung – ACWR-Formel + Darstellung (setzt RP-9 um)
**Kontext:** Screenshot bestätigt alle RP-9-Artefakte: Anfangswochen mit
ACWR ≈ 2,0 (rote Balken/Linie) sind Fenster-Artefakte der 4W/8W-Formel;
`perceivedEffort ?? 5` erfindet Last; Linie ist konstant rot gefärbt, während
Punktfarben grün melden; Schwellen-Labels 1,5/1,3/0,8 überlappen.
Entscheidung lt. Björn-Feedback: Standard-Formel.
**Dateien:** `Models/Achievement.swift` (trainingLoad),
`Views/Components/LoadManagementView.swift`, `ClimbReflectTests/`
**Aufgabe:**
1. Engine: akut = Last der Einzelwoche, chronisch = rollierender Ø der
   letzten 4 Wochen (inkl. aktueller); `acwr = nil` solange < 4 Wochen
   Historie; Historie intern auf 12 Wochen erweitern, damit die 8W-Ansicht
   vorn valide ACWR-Werte hat. Sessions ohne RPE fließen NICHT in die Last
   (kein Default-5); Wochen ohne RPE-Sessions = Last 0.
2. View: Liniensegmente neutral (Theme.textTertiary o. ä.), nur PointMarks
   nach Zone einfärben; Balkenfarbe nach ACWR der eigenen Woche (nil → accent);
   y-Achse ACWR fix 0…2 mit RuleMarks 0,8/1,3/1,5 und versetzten Labels;
   Wochen ohne ACWR ohne Punkt.
3. Unit-Tests: konstante Last → ACWR = 1,0; Verdopplung in Woche 5 →
   ACWR ≈ 1,6 (Zone rot geprüft); Wochen 1–3 → nil.
**Fertig-wenn:** Tests grün; mit Björns realen Daten keine roten
Anfangs-Artefakte mehr; Legende, Punkt- und Balkenfarben widerspruchsfrei.

---

## ⚠️ ABSTIMMEN
1. **FB-5 – Klettertage:** „2 Sessions · 1 Tag" (beides zeigen) oder nur
   Tage zählen? Gilt die Kennzahl auch für Trainings-Sessions oder nur
   Klettern?
2. **Watch-Grad-Vorauswahl (kein eigener Task angelegt):** (A) Erzwungene
   Grad-Wahl vor dem Banken (Outcome-Buttons erst nach Crown-Interaktion
   aktiv — kostet Zeit bei jedem Versuch) oder (B) Status quo + FB-2-
   Projektvorbelegung + FB-3-Editor als Reparaturpfad (Empfehlung: B).
3. **FB-8:** Einverstanden, dass die Effizienz-Karte komplett verschwindet
   bis zum EFF-Rewrite? Alternative wäre nur Flash-Rate zu zeigen — die ist
   aber ebenfalls flag-abhängig, daher nicht empfohlen.

## Abhängigkeiten / Hinweise
- FB-2 setzt FB-1 voraus; FB-3 profitiert von RP-5 (Unbewertet-Badge).
- FB-9 ersetzt/erledigt RP-9 aus TODO10 (dort als erledigt markieren).
- Punkt „ohne Uhr trainieren" (Feedback 2): bereits abgedeckt — manuelle
  Sessions haben keinen Donut; der neue Abdeckungs-Hinweis kommt in einem
  Mini-Zusatz zu FB-3? Nein: eigener Punkt →

### FB-10: Zeit-Donut nur bei ausreichender Zeit-Abdeckung, Abdeckung ausweisen
**Kontext:** `insights.activeShare` wertet ungetimte Ascents implizit als
Pause → nachträglich klassifizierte Versuche drücken den Aktiv-Anteil
fälschlich. `SessionInsights` kennt die Abdeckung bisher nicht.
**Dateien:** `Models/Achievement.swift` (insights), `Views/Components/
SessionTimeDonut.swift`, `Views/SessionDetailView.swift` (insightsSection)
**Aufgabe:**
1. `SessionInsights` um `timedAscentCount` + `ascentCount` erweitern.
2. Donut nur zeigen wenn `timedAscentCount == ascentCount` (volle Abdeckung);
   sonst statt Donut die Metrik-Kacheln + Hinweiszeile „Aktivzeit aus X von
   Y Versuchen erfasst — Zeitaufteilung dafür ausgeblendet".
3. „Aktivzeit"-Kachel bleibt (ehrliche Teilsumme), Beschriftung
   „Aktivzeit (erfasst)".
**Fertig-wenn:** Session mit 3 getimten + 2 ungetimten Ascents zeigt keinen
Donut, aber den Hinweis; Session mit voller Abdeckung unverändert.
