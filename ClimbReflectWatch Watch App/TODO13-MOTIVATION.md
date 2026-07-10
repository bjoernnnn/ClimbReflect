# TODO13 – Motivations-Layer · Fassung 2 (umsetzungsreif)

**Basis:** `dev` @ `af06c56`. Ein Task = ein Commit, App nach jedem Commit
kompilierbar. Alles iPhone-seitig — **keine Watch-Änderungen**.
Schnitt wie TODO12: erst Engine (rein, testbar), dann UI, dann Doku.
Diese Fassung ersetzt die Analyse-Fassung; die verhaltenswissenschaftliche
Begründung steckt jetzt als 🧠-Abschnitt in jedem Task. ID-Mapping alt→neu am
Ende des Dokuments.

---

## 0. Planungs-Konsens des Teams (💻 Dev · 🎨 UX · 🧠 Psychologie)

Sechs Entscheidungen aus der gemeinsamen Planung, die mehrere Tasks prägen:

1. **🧠→💻 Determinismus statt Zufall.** Alles, was „gelegentlich" erscheint
   (Damals-Karte), rotiert deterministisch pro Kalenderwoche — nie zufällig pro
   Öffnen. Zufall pro Öffnen wäre variable Belohnung ohne Leistungsbezug
   (Slot-Machine-Checking, verstößt gegen S33) und ist zudem nicht testbar.
2. **💻→🎨 „Alles"-Zeitraum neutralisiert Erst-Sends.** Über die Gesamthistorie
   ist *jeder* je gesendete Grad trivial ein „Erst-Send" — die Highlights-Zeile
   wäre reines Rauschen. Konsequenz: `periodHighlights` liefert bei
   `monthsBack == nil` bewusst keine Erst-Sends, die UI zeigt die Zeile nur bei
   endlichem Zeitraum.
3. **🎨 Neuigkeit ist eine Zeile, kein Block.** Der Fortschritt-Tab behält seine
   ruhige Hierarchie (Level → Verlauf → Pyramide → Volumen). Highlights werden
   Chips in einer einzigen Zeile, „Nächste Stufe" eine Textzeile im Level-Block —
   keine neuen Karten-Typen, die um Aufmerksamkeit konkurrieren.
4. **🧠 Feier-Monopol bleibt bei TODO11.** TODO13 führt **keine** neuen Haptiken,
   Partikel oder Overlays ein. Der eine Feier-Kanal (ER-5-Overlay) darf nicht
   durch viele kleine Konfetti-Momente entwertet werden — Belohnungs-Inflation
   stumpft ab (Habituation). TODO13 macht Fortschritt *sichtbar*, TODO11
   *feiert* ihn.
5. **💻 Engine-Trennung bleibt strikt.** Grad-/Zeitraum-Analytik →
   `ProgressEngine` (Highlights, Nächste Stufe, Monatsdaten). Rückblick ohne
   Grad-Analytik → `StatsEngine` (Damals-Auswahl, Rekord-Streak). Jede neue
   Funktion ist rein (`calendar`/`now` injizierbar) und hat Tests im Stil der
   bestehenden Suiten (fester `timeIntervalSince1970`-Bezug).
6. **🎨 Ein Copy-Deck.** Alle neuen UI-Strings stehen in Abschnitt 5 — Claude
   Code übernimmt sie wörtlich, damit Ton und Du-Form konsistent bleiben.

**Festgezogene Abstimmungspunkte** (per Freigabe „Ich vertraue auf deine
Empfehlungen"): Nächste Stufe basiert auf dem **historischen Höchst-Send** ·
Streak-Kachel = **Variante B** (Streak + unverlierbarer Rekord) ·
**Monatsrückblick wird gebaut** (in-App, monatlich, ohne Share) · Damals-Karte
am **Fuß des Fortschritt-Tabs** · Empfohlene Gesamt-Reihenfolge: TODO11
Phase 1+2 möglichst vor oder parallel zu Phase 2 dieses Blocks (harte
Abhängigkeit besteht nicht; nur MO-13 hat eine optionale Erfolgs-Zeile).

**Abhängigkeiten innerhalb des Blocks:**
MO-2→MO-7 · MO-3→MO-8 · MO-4→MO-9 · MO-5→MO-10 · MO-2+MO-6→MO-13 ·
MO-11/MO-12 unabhängig · MO-1 und MO-14 unabhängig (Doku).
Phase 1 ist untereinander parallelisierbar.

---

## Phase 0 — Vorarbeit (Doku)

### MO-1: TODO11-Rebase auf aktuellen Codestand
**Kontext:** TODO11 entstand vor TODO12 und referenziert Gelöschtes/Veraltetes:
`WeeklyRecapView` (in FO-14 entfernt, betrifft ER-8), „ladderIndex/RP-7" (heute
`canonicalOrder` + `GradeConverter`), StatsEngine-Altlasten (teils in FO-15
konsolidiert). S32-Konflikt: `persistent` („Projekt mit ≥10 **Versuchen**",
ERFOLGE-KONZEPT Z. 61) summiert das unzuverlässige `attempts`-Feld — ebenso der
heutige `project_done`-Erfolg.
**Dateien:** `ClimbReflectWatch Watch App/TODO11-ERFOLGE.md`,
`ClimbReflectWatch Watch App/ERFOLGE-KONZEPT.md`
**Aufgabe:** (a) ER-Abhängigkeiten als erfüllt markieren
(canonicalOrder/Projekt-Relation/isGraded existieren), (b) ER-8 ohne
WeeklyRecap formulieren, (c) `persistent`-Kriterium umstellen auf **Anzahl
verknüpfter Ascent-Datensätze über ≥ 2 Sessions** (jeder geloggte Ascent ist
ein realer Versuch — ehrlich ohne `attempts`-Feld), (d) `ascents_count`
entsprechend schärfen, (e) Querverweis auf S33 (MO-14).
**Fertig-wenn:** TODO11 referenziert nur existierende Symbole/Views; kein
Kriterium nutzt das `attempts`-Feld.

---

## Phase 1 — Engine (rein, testbar, ohne UI)

### MO-2: `ProgressEngine.periodHighlights` — Erst-Sends + Zeitraum-Bestwert
**🧠** Datenbasis des Neuigkeits-Hebels (Belohnungsvorhersagefehler): Ein
„Erst-Send" ist das ehrlichste Neuheits-Signal des Bestands — vollständig aus
der Historie ableitbar, ohne Persistenz, ohne Prognose.
**Dateien:** `Models/ProgressEngine.swift`,
`ClimbReflectTests/ProgressEngineTests.swift`
**💻 Aufgabe:**
1. Neue Typen (im `ProgressEngine`-Namensraum):
   ```swift
   struct FirstSend: Equatable, Identifiable {
       let grade: String   // Anzeige-Skala
       let order: Int      // canonical, für Sortierung
       let date: Date      // frühester Send überhaupt
       var id: String { grade }
   }
   struct Highlights: Equatable {
       let firstSends: [FirstSend]      // absteigend nach order
       let hardestSend: PersonalBest?   // härtester Send IM Zeitraum
       let isAllTimeBest: Bool          // == historischer PB?
   }
   static func periodHighlights(_ sessions: [ClimbSession],
                                discipline: Discipline, monthsBack: Int?,
                                calendar: Calendar = .current,
                                now: Date = Date()) -> Highlights
   ```
2. Logik: Tops (`isGraded`, Disziplin) der **gesamten Historie** nach
   Anzeige-Grad gruppieren (Konvertierung wie `pyramid`), je Grad das früheste
   Datum bestimmen. `firstSends` = Grade, deren frühestes Datum ≥ Cutoff liegt.
   `monthsBack == nil` ⇒ `firstSends = []` (Konsens-Punkt 2, im Doc-Kommentar
   begründen). `hardestSend` über `hardest()` auf zeitraum-gefilterten Tops;
   `isAllTimeBest` = dessen `canonicalOrder` == Maximum der Gesamthistorie.
3. Tests: Erst-Send innerhalb/außerhalb des Zeitraums; Skalen-Mix (V-Scale-Send
   nach Font-Historie desselben kanonischen Grads ist **kein** Erst-Send);
   `monthsBack == nil` ⇒ leer; `isAllTimeBest` wahr/falsch; leere Historie.
**Fertig-wenn:** Suite grün; Funktion rein; kein UI-/SwiftData-Import.

### MO-3: `PersonalBest.order` + `nextGrade`-Helfer
**🧠** Grundlage des Goal-Gradient-Hebels: die nächste Leiterstufe über dem
Höchst-Send benennen können.
**Dateien:** `Models/ProgressEngine.swift`,
`ClimbReflectTests/ProgressEngineTests.swift`
**💻 Aufgabe:**
1. `PersonalBest` additiv um `let order: Int` (canonicalOrder der Begehung)
   erweitern; Befüllung in `pb(_:discipline:)`. Aufrufer (`LevelHeaderView`,
   `TodayView`, MO-2) kompilieren unverändert.
2. ```swift
   /// Anzeige-Grad der kanonischen Stufe direkt über `order`;
   /// nil am Leiter-Ende (gradeLabel liefert dort "").
   static func nextGrade(afterOrder order: Int,
                         discipline: Discipline) -> String?
   ```
   Implementierung über `gradeLabel(forOrder: order + 1, discipline:)`,
   Leerstring → nil.
3. Tests: Mittlere Stufe liefert Nachfolger in der Anzeige-Skala (inkl.
   V-Scale-Anzeige bei Font-Referenz); letzter Leiter-Eintrag → nil.
**Fertig-wenn:** Suite grün; bestehende PB-Tests unverändert grün.

### MO-4: Stil-Gruppen unter der Schwelle + Wohlfühl-Kandidat
**🧠** Endowed-Progress-Effekt: „3 von 5" motiviert stärker als eine Wand —
ohne eine einzige Quote unter n = 5 zu zeigen (S32 bleibt unberührt: es wird
ausschließlich die Stichprobe transportiert, nie eine Rate).
**Dateien:** `Models/ProgressEngine.swift`,
`ClimbReflectTests/ProgressEngineTests.swift`
**💻 Aufgabe:**
1. ```swift
   struct PendingStyle: Equatable, Identifiable {
       let label: String
       let category: String        // wie StyleRate
       let sample: Int             // 1 ≤ sample < minSampleSize
       var id: String { "\(category)_\(label)" }
   }
   static func stylePendingGroups(...gleiche Signatur wie styleRates...)
       -> [PendingStyle]
   ```
   Gleiche Gruppierung wie `styleRates`, aber Gruppen mit
   `1 ≤ n < minSampleSize`; **kein** sendRate-Feld (bewusst nicht berechenbar
   machen). Sortierung: sample absteigend (die nächstgelegenen zuerst).
2. ```swift
   /// Kandidat, wenn comfortGrade nil: Pyramiden-Zeile mit 1 ≤ total < 5,
   /// max nach (total, dann sortOrder). Nur Stichprobe, keine Quote.
   static func comfortCandidate(_ sessions:..., discipline:, monthsBack:,
                                calendar:, now:) -> (grade: String, sample: Int)?
   ```
3. Tests: n = 4 erscheint in pending und nicht in rates; n = 5 wandert um;
   Kandidat-Priorität (total vor Grad-Höhe); nil bei leerem Bestand.
**Fertig-wenn:** Suite grün; `styleRates`-Verhalten byte-identisch.

### MO-5: `StatsEngine.bestWeekStreak` — unverlierbarer Rekord
**🧠** Verlustaversion entschärfen: Der Rekord ist Besitz, der bleibt — die
Anzeige darf nach einer Pause nie auf eine nackte Null kollabieren.
**Dateien:** `Models/Achievement.swift` (StatsEngine),
`ClimbReflectTests/StatsEngineTests.swift`
**💻 Aufgabe:**
1. ```swift
   /// Längster Kletter-Wochen-Streak der Gesamthistorie (Montag-Wochen).
   static func bestClimbWeekStreak(_ sessions: [ClimbSession],
                                   calendar: Calendar = .current) -> Int
   ```
   Implementierung unabhängig von `weeklyMinutes` (dessen 26-Wochen-Fenster
   reicht nicht): Menge der Wochen-Startdaten aller Kletter-Sessions bilden
   (`firstWeekday = 2`), sortieren, längsten Lauf aufeinanderfolgender Wochen
   zählen.
2. Tests: Historie mit Lücke (4-2-Muster → 4); einzelne Woche → 1; leer → 0;
   Jahreswechsel-Lauf (KW 52 → KW 1 bleibt ein Lauf — über Datums-, nicht
   KW-Arithmetik vergleichen).
**Fertig-wenn:** Suite grün; `weekStreak`/`climbWeekStreak` unverändert.

### MO-6: `ProgressEngine.monthRecap` — Monatsdaten für den Rückblick
**🧠** Fresh-Start-Effekt: Monatsbeginn ist eine natürliche Landmarke. Die
Engine liefert nur Fakten; ob gezeigt wird, entscheidet die UI (MO-13) — und
bei leerem Vormonat wird **nichts** gezeigt (keine Null-Bilanz, S33).
**Dateien:** `Models/ProgressEngine.swift`,
`ClimbReflectTests/ProgressEngineTests.swift`
**💻 Aufgabe:**
1. ```swift
   struct MonthRecap: Equatable {
       struct DisciplineRecap: Equatable {
           let climbDays: Int
           let sends: Int
           let hardestGrade: String?   // Anzeige-Skala
           let firstSendCount: Int     // Erst-Sends im Monat (Logik MO-2)
       }
       let month: Date                 // 1. des Monats
       let boulder: DisciplineRecap
       let rope: DisciplineRecap
       var isEmpty: Bool { boulder.climbDays == 0 && rope.climbDays == 0 }
   }
   static func monthRecap(_ sessions: [ClimbSession], month: Date,
                          calendar: Calendar = .current) -> MonthRecap
   ```
2. Monatsfenster `[startOfMonth, +1 Monat)`; Klettertage wie
   `climbDaysPerMonth` (eindeutige Tage, disziplin-gefiltert); Sends = Tops der
   Disziplin im Fenster; `hardestGrade` display-konvertiert; `firstSendCount`
   über die Erst-Send-Logik aus MO-2 (Gesamthistorie als Referenz, Fenster =
   Monat) — Logik als privaten Helfer teilen, nicht duplizieren.
3. Tests: Monatsgrenzen exklusiv; Disziplin-Trennung; Erst-Send-Zählung mit
   Vorgeschichte; `isEmpty` bei Monat ohne Kletter-Session.
**Fertig-wenn:** Suite grün; keine Kopplung an UserDefaults/UI.

---

## Phase 2 — UI

*Gemeinsame 🎨-Regeln: bestehende Bausteine wiederverwenden (`.card()`,
`Theme`-Tokens, Capsule-Chips wie in `readOnlyChip`/`LevelHeaderView`). Keine
neuen Farben, keine Animation über `.easeInOut(0.15)`-Standard hinaus, keine
Haptik (Konsens-Punkt 4). Alle Strings aus dem Copy-Deck (Abschnitt 5).*

### MO-7: `PeriodHighlightsRow` im Fortschritt-Tab
**🧠** Beantwortet beim Öffnen zuerst „Was ist **neu**?", bevor der
Zustandsbericht beginnt — die Zeile existiert nur, wenn es echte Neuigkeit
gibt (nie ein leerer Rahmen, nie eine Ausrede).
**Dateien:** neu `Views/Components/PeriodHighlightsRow.swift`,
`Views/FortschrittView.swift`
**🎨 Spezifikation:** Eine horizontale Chip-Zeile zwischen Zeitraum-Picker und
`LevelHeaderView`. Chips im Stil der bestehenden Capsule-Badges:
`font(.caption2.weight(.semibold))`, `padding(.horizontal, 8).padding(.vertical, 4)`.
Erst-Send-Chip: Symbol `sparkles` + „7A erstmals", Tint `Theme.accent`
(Capsule `accent.opacity(0.12)`, Text `accent`). Maximal 3 Chips, Überhang als
„+N"-Chip (neutral, `bgElevated`/`textSecondary`). PB-Chip (nur wenn
`isAllTimeBest` **und** PB-Datum im Zeitraum): Symbol `trophy.fill` +
„Bestleistung 7A+", Gold-Tint analog `Theme.gold.opacity(0.12)`. Chips
scrollen nicht — bei Überbreite greift „+N".
**💻 Aufgabe:**
1. View mit Props `highlights: ProgressEngine.Highlights`. Sichtbar nur, wenn
   `!firstSends.isEmpty || (isAllTimeBest && hardestSend != nil)`.
2. `FortschrittView`: `highlights`-Computed (analog Nachbarn), Einbau **nur bei
   `period != .all`** (Konsens-Punkt 2); PB-Datum-im-Zeitraum-Check in der View
   (Vergleich `hardestSend.date >= cutoff` entfällt — `hardestSend` ist bereits
   zeitraum-gefiltert, also genügt `isAllTimeBest`).
3. Disziplin-/Zeitraum-Wechsel aktualisiert ohne Animations-Sprünge
   (`.animation(nil)` bzw. Standard-Transition belassen).
**Fertig-wenn:** Zeitraum mit Erst-Sends zeigt Chips (max 3 + „+N"); Zeitraum
ohne Neuigkeit zeigt nichts; „Alles" zeigt nie die Zeile; PB im Zeitraum
erzeugt den Gold-Chip.

### MO-8: „Nächste Stufe" im Level-Block
**🧠** Goal-Gradient: Nähe sichtbar machen — mit echten Zahlen, ohne
Aufforderung, ohne Countdown, ohne Prognose. Invariante: Auf der Stufe über dem
historischen PB kann es per Definition nur Begehungen **ohne** Send geben —
die Zeile zeigt also nie eine widersprüchliche „schon gesendet"-Zahl.
**Dateien:** `Views/Components/LevelHeaderView.swift`,
`Views/FortschrittView.swift`
**🎨 Spezifikation:** Eine Zeile direkt unter der Wohlfühl-Grad-Zeile, gleicher
Aufbau: Symbol `arrow.up.forward.circle` (`Theme.accent2`, `.caption`), Text
`subheadline`: „Nächste Stufe **7A**" (Grad `textPrimary` bold, Rest
`textSecondary`), darunter kein zweiter Absatz — der Zusatz hängt in derselben
Zeile: „ · 4 Begehungen" bzw. „ · noch unversucht" (`textTertiary`). Kein
Fortschrittsbalken (der würde eine Quote suggerieren).
**💻 Aufgabe:**
1. `LevelHeaderView` um Props `nextGrade: String?` und
   `nextGradeTries: Int` erweitern; Zeile rendert nur bei `nextGrade != nil`.
2. `FortschrittView` berechnet: `nextGrade =
   bests.send.flatMap { ProgressEngine.nextGrade(afterOrder: $0.order, discipline:) }`;
   `nextGradeTries` = `failedTries` der `pyramidRows`-Zeile mit
   `grade == nextGrade` (String-Match, Zeile fehlt ⇒ 0). Zahlen folgen damit
   dem gewählten Zeitraum (festgezogener Default: Basis = historischer PB,
   Zählung = Zeitraum).
3. Ohne Send-PB (keine Tops) erscheint keine Zeile; am Leiter-Ende ebenfalls
   nicht.
**Fertig-wenn:** PB 6C+ und drei 7A-Begehungen ohne Send im Zeitraum →
„Nächste Stufe 7A · 3 Begehungen"; nach 7A-Send rückt die Zeile auf 7A+ vor;
ohne Daten der Stufe → „noch unversucht".

### MO-9: Endowed Progress in Stil-Profil + Wohlfühl-Kandidat
**🧠** Die n=5-Schwelle wird vom unsichtbaren Ausschluss zum sichtbaren
Mini-Ziel. Es erscheint ausschließlich die Stichprobe („3/5") — nie eine Rate.
**Dateien:** `Views/StyleProfileView.swift`,
`Views/Components/LevelHeaderView.swift` (bzw. `FortschrittView`)
**🎨 Spezifikation:** StyleProfile: unterhalb der Quoten-Sektionen eine ruhige
Sektion „Bald sichtbar" (`headline` wie Nachbarn): je Zeile Label
(`subheadline`, `textPrimary`) + rechts „3/5" (`caption.monospacedDigit()`,
`textTertiary`) + darunter dieselbe 6-pt-Capsule wie `rateRow`, aber Füllung
`Theme.textTertiary.opacity(0.35)` und Breite `sample/minSampleSize` — die
Farbabweichung von Accent-Mint signalisiert „noch keine Aussage".
Wohlfühl-Zeile im Level-Block, wenn `comfortGrade == nil` und Kandidat
existiert: gedimmtes `checkmark.seal` (`textTertiary`) + Copy-Deck-Zeile
„Wohlfühl-Grad ab 5 Begehungen je Grad — 6B: 4/5" (`caption`, `textTertiary`).
**💻 Aufgabe:**
1. StyleProfileView: `pending`-Computed über `stylePendingGroups`; Sektion nur
   bei nicht-leerem Ergebnis. Der bisherige Komplett-Leertext erscheint nur
   noch, wenn `rates` **und** `pending` leer sind.
2. Level-Block: `comfortCandidate`-Computed in `FortschrittView`, als optionale
   Props an `LevelHeaderView` (rendert Kandidat-Zeile nur, wenn `comfortGrade`
   nil und Kandidat vorhanden).
**Fertig-wenn:** Gruppe mit n = 3 zeigt „3/5" ohne jeden Prozentwert; ab n = 5
wandert sie in die Quoten; fehlender Wohlfühl-Grad zeigt den Kandidaten; mit
Wohlfühl-Grad verschwindet die Kandidat-Zeile.

### MO-10: Streak-Kachel mit unverlierbarem Rekord (Variante B)
**🧠** Der laufende Streak bleibt (er ist ehrlich), aber der Rekord steht
dauerhaft daneben — nach einer Pause liest sich die Kachel als „Rekord: 9 Wo."
statt als Bestrafung. Kein rotes Wording, kein „gerissen".
**Dateien:** `Views/Components/StatTile.swift`, `Views/TodayView.swift`
**🎨 Spezifikation:** `StatTile` erhält optionales `detail: String?` als vierte
Zeile (`caption2`, `textTertiary`, `lineLimit(1)`), Default nil — Nachbar-Kacheln
bleiben pixel-identisch (Höhenangleich existiert bereits über
`maxHeight: .infinity`). Streak-Kachel: `detail = "Rekord: 9 Wo."`.
**💻 Aufgabe:**
1. `StatTile`-Erweiterung additiv (Default-Parameter, kein Call-Site-Bruch).
2. `TodayView.statRow`: `bestClimbWeekStreak` berechnen; `detail` nur setzen,
   wenn Rekord ≥ 2 (bei 0/1 trägt die Zeile nichts).
**Fertig-wenn:** Simulierte 3-Wochen-Pause → Kachel zeigt Streak 0 **und**
„Rekord: N Wo."; Rekord < 2 → keine Detail-Zeile; Sessions-/Wochen-Kacheln
unverändert.

### MO-11: `IntentFollowUpCard` — Vorsatz-Schleife auf „Heute"
**🧠** Implementation Intentions (Gollwitzer): Der Vorsatz wirkt, wenn er beim
nächsten Cue wieder erscheint. Der Zeigarnik-Effekt hält die offene Absicht von
selbst interessant. Kein Abhaken, keine Bewertung, keine Notification — nach
der nächsten Session verschwindet die Karte wortlos (keine Schuld-Mechanik,
S33).
**Dateien:** neu `Views/Components/IntentFollowUpCard.swift`,
`Views/TodayView.swift`
**🎨 Spezifikation:** Karte im `.card()`-Stil zwischen `heroTrophyRow` und
`statRow`. Aufbau: Label-Zeile `quote.opening`-Symbol (`Theme.accent2`) +
„Dein Fokus fürs nächste Mal" (`caption.weight(.semibold)`, `textSecondary`,
uppercased wie die PB-Kacheln-Titel); darunter das Zitat (`subheadline`,
`textPrimary`, max. 3 Zeilen, kein Kursiv — Kursiv liest sich als App-Stimme,
das hier ist Björns eigene); Fußzeile Session-Datum relativ („vor 3 Tagen",
`caption2`, `textTertiary`) + Chevron rechts.
**💻 Aufgabe:**
1. Anzeige-Regel (bewusst simpel, in `TodayView` als Computed): jüngste
   Kletter-Session (`sessions.first(where: \.isClimbing)`) hat nicht-leeres
   `improveNext` ⇒ Karte mit dieser Session; sonst keine Karte. (Damit
   verschwindet der Vorsatz automatisch, sobald eine neuere Kletter-Session —
   mit oder ohne eigenen Vorsatz — existiert.)
2. Karte als `NavigationLink` → `SessionDetailView(session:)`,
   `buttonStyle(.plain)`.
3. Relativdatum über `RelativeDateTimeFormatter`/`.formatted(.relative(...))`.
**Fertig-wenn:** Session mit `improveNext` speichern → Karte erscheint; neue
Kletter-Session anlegen → Karte weg; leeres/fehlendes `improveNext` → keine
Karte; Tap öffnet die Quell-Session.

### MO-12: `ThrowbackCard` — „Damals" am Fuß des Fortschritt-Tabs
**🧠** Kompetenz-Feedback aus der eigenen Stimme: eine Reflexion von vor ≥ 90
Tagen macht Distanz erlebbar, die kein Chart transportiert. Deterministische
Wochen-Rotation (Konsens-Punkt 1) — mehrfaches Öffnen zeigt dieselbe Karte,
kein Checking-Anreiz. Reines Zitat, keine Deutung.
**Dateien:** `Models/Achievement.swift` (StatsEngine),
neu `Views/Components/ThrowbackCard.swift`, `Views/FortschrittView.swift`,
`ClimbReflectTests/StatsEngineTests.swift`
**💻 Aufgabe:**
1. Auswahl in der StatsEngine (Rückblick-Logik gehört per Engine-Split hierher):
   ```swift
   /// Deterministische Wochen-Rotation über geeignete Sessions
   /// (Kletter-Session, ≥ 90 Tage alt, learned oder hardestPart nicht leer).
   /// Index = (yearForWeekOfYear · 100 + weekOfYear) mod Anzahl.
   static func throwbackSession(_ sessions: [ClimbSession],
                                calendar: Calendar = .current,
                                now: Date = Date()) -> ClimbSession?
   ```
   Kandidaten aufsteigend nach Datum sortieren (stabiler Index). Tests: < 90
   Tage ausgeschlossen; leere Texte ausgeschlossen; gleiche Woche ⇒ gleiche
   Session; Folgewoche ⇒ Rotation.
2. Karte: Label `clock.arrow.circlepath` + „Damals" + Relativdatum („vor 5
   Monaten"); Zitat = `learned`, Fallback `hardestPart` (`subheadline`,
   `textPrimary`, max. 4 Zeilen); `NavigationLink` → SessionDetail.
3. Einbau in `FortschrittView` unter `styleLink`; keine Karte ohne Kandidat.
**🎨** Bewusst der ruhigste Ort der Seite (nach allen Zahlen) — die Karte ist
ein Nachklang, kein Attention-Grabber. Gleicher `.card()`-Stil, kein Akzentrand.
**Fertig-wenn:** Engine-Tests grün; mit altem Bestand erscheint wöchentlich
rotierend genau ein Zitat; ohne geeignete Sessions erscheint nichts.

### MO-13: `MonthRecapCard` — „Dein Juni" auf „Heute"
**🧠** Fresh-Start-Effekt + Peak-End auf Monatsebene: einmal pro Monat ein
faktenbasierter Rückblick, dann Ruhe. Erscheint nie bei leerem Vormonat (keine
Null-Bilanz), genau einmal (kein Re-Engagement-Loop), ohne Share, ohne
Notification.
**Dateien:** neu `Views/Components/MonthRecapCard.swift`, `Views/TodayView.swift`
**🎨 Spezifikation:** Karte direkt unter dem `LiveSessionBanner`-Slot (vor der
Hero-Reihe — sie ist selten und darf dann oben stehen). Kopf: `calendar`-Symbol
in Gold-Kreis (Stil wie `pinnedProjectsCard`-Icon) + Titel „Dein Juni"
(`headline`) + X-Button rechts (`xmark`, `caption`, `textTertiary`). Inhalt: je
Disziplin mit `climbDays > 0` eine Zeile (`subheadline`): „Bouldern — 9 Tage ·
31 Sends · härtester 6C" und, falls `firstSendCount > 0`, angehängt „ · 2 Grade
erstmals" (`Theme.accent`). Kein Chart, keine Partikel; das Gold sitzt nur im
Icon.
**💻 Aufgabe:**
1. Sichtbarkeits-Regel in `TodayView`: aktueller Tag ≤ 7. des Monats **und**
   `monthRecap(sessions, month: Vormonat)` nicht `isEmpty` **und**
   UserDefaults-Flag `monthRecapSeen-YYYY-MM` (Vormonat) nicht gesetzt.
2. X-Button setzt das Flag (`@AppStorage` ungeeignet wegen dynamischen Keys —
   direkter `UserDefaults`-Zugriff, Key-Format dokumentieren). Karte
   verschwindet mit Standard-Transition.
3. Monatsname lokalisiert über `month.formatted(.dateTime.month(.wide))`.
4. Optionaler Nachtrag (nur falls TODO11 bereits umgesetzt ist): Zeile
   „N Erfolge freigeschaltet" aus `AchievementUnlock`-Fetch des Monats —
   als auskommentierter, markierter Block vorbereiten, nicht aktivieren.
**Fertig-wenn:** Monatswechsel mit Vormonatsdaten → Karte erscheint, Dismiss
persistiert über App-Neustart; Vormonat ohne Klettertag → keine Karte; ab dem
8. des Monats erscheint sie auch ungesehen nicht mehr.

---

## Phase 3 — Doku

### MO-14: Prinzip S33 + Konzept-Nachtrag
**Dateien:** `ClimbReflectWatch Watch App/CLAUDE.md`,
`ClimbReflectWatch Watch App/FORTSCHRITT-KONZEPT.md`
**Aufgabe:** In CLAUDE.md aufnehmen:
> **S33 – Motivation ohne Manipulation.** Gefeiert werden ausschließlich echte,
> aus den Daten belegte Ereignisse (Erst-Send, PB, Unlock, Comeback) — genau
> einmal, im Moment ihres Entstehens (Feier-Kanal: TODO11/ER-5, sonst keiner).
> Keine Schuld-Mechanik: kein „Du warst lange nicht klettern", kein bestrafender
> Streak-Reset als alleinige Anzeige (Rekord steht daneben), keine
> Engagement-Notifications ohne Ereignis. Keine variable Belohnung ohne
> Leistungsbezug (rotierende Inhalte deterministisch pro Woche), keine
> Punkte-/XP-Ökonomie (Overjustification). Nähe zu Zielen mit echten Zahlen,
> nie mit Prognosen; Leerzustände zeigen Fortschritt zur Schwelle (n/5) statt
> Quoten darunter.

FORTSCHRITT-KONZEPT um Abschnitt „Motivations-Layer (TODO13)" ergänzen: die
drei Quellen (Veränderung / Nähe / Momente), Verweis auf TODO11 für die
Ereignis-Ebene, Anti-Pattern-Liste (Tages-Streaks · Guilt-Push ·
Login-Belohnungen · Fremdvergleich im Fortschritt-Tab · KI-Motivationssprüche ·
`attempts`-basierte Kennzahlen).
**Fertig-wenn:** S33 im Prinzipien-Block; Konzept konsistent zu MO-2…MO-13.

---

## 5. Copy-Deck (wörtlich übernehmen)

| Ort | String |
|---|---|
| Highlights-Chip Erst-Send | `<Grad> erstmals` |
| Highlights-Chip Überhang | `+<N>` |
| Highlights-Chip PB | `Bestleistung <Grad>` |
| Nächste Stufe | `Nächste Stufe <Grad> · <N> Begehungen` / `Nächste Stufe <Grad> · noch unversucht` (N = 1: `1 Begehung`) |
| Stil-Profil Sektion | `Bald sichtbar` |
| Stil-Profil Zeile | `<Label>` + `<n>/5` |
| Wohlfühl-Kandidat | `Wohlfühl-Grad ab 5 Begehungen je Grad — <Grad>: <n>/5` |
| Streak-Detail | `Rekord: <N> Wo.` |
| Vorsatz-Karte Titel | `DEIN FOKUS FÜRS NÄCHSTE MAL` |
| Damals-Karte Titel | `Damals` (+ Relativdatum, z. B. `vor 5 Monaten`) |
| Monatsrückblick Titel | `Dein <Monatsname>` |
| Monatsrückblick Zeile | `Bouldern — <T> Tage · <S> Sends · härtester <Grad>` (+ optional ` · <N> Grade erstmals`; Seil analog `Seil — …`) |

Ton-Regeln: Du-Form, keine Ausrufezeichen außer in bestehenden
Erfolgs-Texten, keine Imperative („Geh klettern!"), keine Bewertungen
(„leider", „nur").

## 6. ID-Mapping zur Analyse-Fassung

v1 MO-1→MO-1 · MO-2→MO-11 · MO-3→MO-12 · MO-4→MO-2 · MO-5→MO-7 ·
MO-6→MO-3+MO-8 · MO-7→MO-4+MO-9 · MO-8→MO-5+MO-10 · MO-9→MO-6+MO-13 ·
MO-10→MO-14.

## 7. Bewusst außerhalb dieses Blocks

Kein Belastungs-/Erholungs-Coaching (S31, auch nicht als „Fürsorge") · keine
Watch-Änderungen (Watch-Rückkanal bleibt ER-L1, Rücksprache) · keine neuen
Notification-Typen (Ereignis-Notification nur TODO11/ER-9) · keine
Haptik/Partikel (Feier-Monopol TODO11/ER-5) · Projekt-Kachel auf „Heute"
summiert weiter das unzuverlässige `attempts`-Feld — gehört zur
Route-Identitäts-Baustelle (MO-1 entschärft nur das Erfolgs-Kriterium).
