# TODO10 – Release-Feinschliff: Datenkorrektheit, End-Flow, Darstellung

Audit-Basis: `dev` @ e5f6e02 (2026-07-01). Ein Task = ein Commit.
Prioritätsreihenfolge: RP-1 → RP-5 (Datenverlust/Datenkorrektheit) vor allem anderen.
Der Action-Button-Bridge-Komplex (TODO-ACTIONBUTTON-ASCENT.md) bleibt unberührt.

---

## Block A – Datenerfassung (kritisch)

### RP-1: Session-DTO sofort beim Beenden senden (Datenverlust-Fix)
**Kontext:** Das DTO wird erst nach dem Fragebogen-„Fertig" gesendet
(`SessionEndFlowView` → `onComplete`). `endWorkout()` hat davor bereits
`finishSession()` aufgerufen und `PendingSessionStore.clear()` ausgeführt.
Terminiert watchOS die App zwischen Beenden und „Fertig", ist die Session
inkl. aller Begehungen unwiederbringlich verloren (nur `pendingSummaryDTO`
im RAM). Der iPhone-Upsert-Pfad (`WatchSessionReceiver.insert`, Match über
`watchSessionID`) ist für nachträgliche Anreicherung bereits gebaut.
**Dateien:** `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`,
`ClimbReflectWatch Watch App/Views/SessionEndFlowView.swift`
**Aufgabe:**
1. In `endWorkout()` direkt nach dem Bau des DTO: `SyncService.shared.send(dto:)`
   (Basis-DTO ohne Fragebogen).
2. `SessionEndFlowView` sendet nach dem Fragebogen weiterhin das angereicherte
   DTO — der Upsert aktualisiert dann RPE/Fokus auf der bestehenden Session.
3. `PendingSessionStore.clear()` aus `finishSession()` erst ausführen, nachdem
   das Basis-DTO an `SyncService` übergeben wurde (Reihenfolge prüfen; send()
   ist synchron queuing, das genügt).
**Fertig-wenn:** Session beenden, Watch-App vor dem Fragebogen force-killen →
Session mit allen Ascents erscheint trotzdem auf dem iPhone. Fragebogen
normal abschließen → keine Duplikat-Session, RPE ist gesetzt.

### RP-2: Fragebogen-Antworten „Zustand" + „Schwerpunkt" persistieren; Training-Ziel nicht mehr überschreiben
**Kontext:** `withQuestionnaire()` setzt `focusRaw: focus?.rawValue` und
überschreibt damit das in `endWorkout()` gesetzte `trainingTarget?.rawValue`
— bei Training ist `focus` immer nil (skipFocus) → Zielkapazität geht verloren,
der Limiter-Mapping-Pfad im Receiver ist toter Code. `energyRaw` wird auf dem
iPhone komplett verworfen (kein Feld auf `ClimbSession`), Klettersession-Fokus
(power/endurance/technique/project/casual) ebenfalls.
**Dateien:** `ClimbReflectWatch Watch App/Models/WatchSessionDTO.swift`,
`ClimbReflect/.../Models/ClimbSession.swift`,
`ClimbReflect/.../Models/WatchSessionDTO.swift` (iPhone-Kopie identisch halten!),
`ClimbReflect/.../Services/WatchSessionReceiver.swift`,
`ClimbReflect/.../Views/SessionDetailView.swift`
**Aufgabe:**
1. `withQuestionnaire`: `focusRaw: focus?.rawValue ?? self.focusRaw`.
2. `ClimbSession` um zwei optionale Felder erweitern: `sessionFocusRaw: String?`
   (WatchSessionFocus-Werte) und `energyRaw: String?` (fresh/normal/tired).
   Lightweight-Migration prüfen (nur additive optionale Felder → V-Schema ok).
3. Receiver: bei Klettersessions `dto.focusRaw` → `sessionFocusRaw`,
   `dto.energyRaw` → `energyRaw`; Upsert-Pfad ebenso anreichern.
   Training-Pfad (focusRaw → Limiter) bleibt wie gehabt.
4. SessionDetailView: beide Werte in der Reflexions-Sektion anzeigen (read-only
   Chips reichen).
**Fertig-wenn:** Training mit Zielkapazität beenden → Limiter auf der iPhone-
Session gesetzt. Klettersession mit Schwerpunkt „Kraft" + Zustand „Müde"
beenden → beide Werte sichtbar in der Session-Detailansicht.

### RP-3: ⚠️ ABSTIMMEN → Session-Dauer einheitlich definieren (Netto vs. Brutto)
**Kontext:** `endWorkout()` speichert `endDate − startDate` OHNE Pausenabzug.
`currentElapsed()` (Live-Anzeige) und `finalizeUnrecoverableSession()` ziehen
`accumulatedPaused` ab. `durationSeconds` speist sRPE-Last, ACWR, sendsPerHour,
Aktivzeit-Klammer — die Definition muss überall identisch sein.
**Empfehlung:** Netto (Pausen abgezogen) als `durationSeconds`; entspricht der
Live-Anzeige und der Trainingslast-Semantik. Optional zusätzlich
`pausedSeconds: Double = 0` am DTO/Modell für spätere Auswertungen.
**Dateien:** `WorkoutManager.swift` (`endWorkout`), ggf. DTO + `ClimbSession`
**Aufgabe (nach Entscheidung):** In `endWorkout()` analog `currentElapsed()`
rechnen: `endDate − start − accumulatedPaused` (laufende Pause via
`pauseStartedAt` berücksichtigen, falls im Pausenzustand beendet wird).
**Fertig-wenn:** Session mit 2 Min Pause: Watch-Summary, iPhone-Session und
Live-Anzeige zeigen dieselbe Dauer (±1 s).

### RP-4: quickBank – Grad-System aus Session-Typ; toten watchGradeSystem-Key entfernen
**Kontext:** Der UserDefaults-Key `watchGradeSystem` wird nirgends geschrieben.
In `quickBank()` greift `string(forKey:) ?? "fontainebleau"` → der Fallback
`?? sessionType.defaultGradeSystem` feuert nie → Quick-Bank-Ascents in
Seil-Sessions werden mit Boulder-System gespeichert. Außerdem toter Ternary
`style: result == .top ? nil : nil`. `AttemptLogView` referenziert denselben
toten Key (Kommentar „kommt aus App-Einstellungen" ist falsch).
**Dateien:** `WorkoutManager.swift`, `Views/AttemptLogView.swift`
**Aufgabe:**
1. `quickBank()`: `gradeSystem: sessionType.defaultGradeSystem`, UserDefaults-
   Zugriff entfernen; `style: nil` explizit.
2. `AttemptLogView`: `@AppStorage("watchGradeSystem")` entfernen,
   `gradeSystem = workoutManager.sessionType.defaultGradeSystem`; Kommentar
   korrigieren.
**Fertig-wenn:** Quick-Bank in einer Vorstieg-Session erzeugt Ascent mit
`gradeSystemRaw == "french"`; grep nach `watchGradeSystem` liefert 0 Treffer.

### RP-5: Ungegradete Ascents nicht als Grad „?" persistieren
**Kontext:** Receiver: `grade: ascentDTO.gradeRaw ?? "?"` → „?" wird echter
Grad mit `sortOrder 0`, taucht als Balken in der Pyramide auf und verschmutzt
gradbasierte Auswertungen dauerhaft.
**Dateien:** `WatchSessionReceiver.swift`, `StatsEngine` (Achievement.swift),
`Views/Components/GradePyramidView.swift`, `Views/Components/AscentRowView.swift`,
ggf. `EditAscentAssociationsSheet.swift`
**Aufgabe:**
1. Sentinel beibehalten, aber zentralisieren: `Ascent.ungraded = "?"` +
   Convenience `var isGraded: Bool { gradeRaw != Self.ungraded }`
   (gradeRaw optional zu machen wäre die sauberere Migration — nur nach
   Rücksprache; Sentinel + Filter ist der risikoarme Weg vor Release).
2. `gradePyramid`, `maxGradeTrend`, `heroBoulder/heroRoute`-Pendants,
   `hardestTopGrade`, `currentWeekRecap` filtern `isGraded`.
3. AscentRow zeigt für ungegradete Ascents „Unbewertet"-Badge statt „?";
   Grad-Nachtragen über den bestehenden Editor bleibt der Fix-Pfad.
**Fertig-wenn:** Quick-Bank-Session ohne Grade syncen → Pyramide zeigt keinen
„?"-Balken, Session-Liste zeigt „Unbewertet", nach Grad-Nachtrag erscheint
der Ascent normal in allen Charts.

### RP-6: heartRateAtBanking übertragen und persistieren
**Kontext:** Wird auf der Watch erfasst und angezeigt, aber `toDTO()` lässt es
weg → geht bei jedem Sync verloren. Entweder vollständig machen oder streichen;
Empfehlung: vollständig machen (wertvolle Metrik, z. B. HF vs. Erfolgsquote).
**Dateien:** beide `WatchSessionDTO.swift` (Watch + iPhone synchron!),
`WatchAttempt.swift` (`toDTO`, `init(fromDTO:)`), `Ascent.swift`,
`WatchSessionReceiver.swift`, `SessionDetailView.swift` (Ascent-Zeile)
**Aufgabe:** `heartRateAtBanking: Double?` in AscentDTO (optional → alte DTOs
dekodieren weiter), `Ascent.heartRateAtBanking: Double?` ergänzen, Receiver
mappt durch, Anzeige in der Ascent-Detailzeile analog Watch.
**Fertig-wenn:** Watch-Session mit HF-Snapshot syncen → Wert am Ascent auf dem
iPhone sichtbar; alte Sessions ohne Feld laden fehlerfrei.

---

## Block B – Auswertungs-Korrektheit

### RP-7: Grad-Vergleiche nur pro Disziplin, über normalisierten Leiter-Index
**Kontext:** `Ascent.sortOrder` ist der Index in der jeweiligen System-Liste.
Vergleiche über Systeme hinweg (Font vs. V, French vs. UIAA, Boulder vs. Seil)
sind bedeutungslos. Betroffen: `maxGradeTrend` (mischt alles in eine Linie),
`currentWeekRecap.newPB`, `formSignal` (Plateau), `insights.hardestTopGrade`,
`climbAchievements.maxGrade`.
**Dateien:** `Models/GradeConverter.swift`, `Models/Achievement.swift`
(StatsEngine), `Views/Components/GradeProgressView.swift`
**Aufgabe:**
1. GradeConverter um `static func ladderIndex(grade:system:) -> Int?` erweitern
   (Index in boulderFb/boulderV bzw. routeFrench/routeUIAA) und
   `enum Discipline { boulder, route }` + `GradeSystem.discipline`.
2. StatsEngine: alle Max-/Vergleichslogik pro Disziplin rechnen und über
   `ladderIndex` vergleichen; unbekannter Grad (`nil`) wird ausgeschlossen
   statt still 0.
3. `maxGradeTrend` liefert getrennte Serien für Boulder und Seil;
   GradeProgressView zeigt zwei Linien (oder Umschalter) statt einer gemischten.
4. `newPB`/`hardestTopGrade`: Vergleich nur innerhalb derselben Disziplin.
**Fertig-wenn:** Testdaten mit Font-6C-Top und French-6a-Top im selben Monat:
Trend zeigt beide getrennt korrekt; kein PB-Badge durch System-Wechsel;
Unit-Tests für `ladderIndex`-Vergleich Font↔V und French↔UIAA grün.

### RP-8: Grad-Pyramide & Konsolidierung nach Disziplin statt gespeichertem System
**Kontext:** `gradePyramid(sessions, system: boulderScale)` filtert nach dem
gespeicherten System. Watch speichert immer Font → bei Anzeige-Einstellung
V-Scale ist die Pyramide leer. Seil-Ascents erscheinen nie; `routeScale` in
GradePyramidView ist deklariert aber ungenutzt.
**Dateien:** `Achievement.swift` (StatsEngine.gradePyramid),
`GradePyramidView.swift`, `GradeProgressView.swift`
**Aufgabe:**
1. `gradePyramid` auf Disziplin umstellen: Ascents der Disziplin sammeln,
   Grade via `GradeConverter.convert` ins Anzeige-System mappen, dann gruppieren
   (nicht konvertierbare/ungegradete ausschließen, vgl. RP-5).
2. GradePyramidView: Segmented-Umschalter Boulder | Seil; nutzt boulderScale
   bzw. routeScale als Zielsystem.
3. GradeProgressView-Konsolidierung identisch umstellen.
**Fertig-wenn:** Anzeige-Skala V-Scale → Pyramide zeigt Font-gespeicherte
Ascents als V-Grade; Umschalter Seil zeigt French/UIAA-Ascents; keine leere
Pyramide bei vorhandenen Daten.

### RP-9: ⚠️ ABSTIMMEN → ACWR-Formel korrigieren, keinen RPE-Default erfinden
**Kontext:** `trainingLoad` rechnet akut = Ø 4 Wochen, chronisch = Ø 8 Wochen
(Standard: akut = 1 Woche, chronisch = Ø 4 Wochen). Signal ist so stark
gedämpft, dass die 1.2/1.5-Schwellen praktisch nie anschlagen. Zusätzlich:
`perceivedEffort ?? 5` erfindet RPE für Sessions ohne Wert („No fabricated
data"), und die erste Fensterswoche hat konstruktionsbedingt ACWR = 1.0.
**Empfehlung:** akut = aktuelle Woche, chronisch = rollierender 4-Wochen-Ø;
Sessions ohne RPE aus der Last ausschließen (oder nur Minuten-basiert zählen
— Entscheidung); ACWR erst ab 4 Wochen Historie anzeigen (`nil` davor).
**Dateien:** `Achievement.swift` (StatsEngine.trainingLoad),
`LoadManagementView.swift` (Legende/Schwellen-Text prüfen)
**Fertig-wenn:** Unit-Test: konstante Last 4 Wochen, dann Verdopplung →
ACWR ≈ 2.0 in der Spitzenwoche; Sessions ohne RPE verändern die Last nicht;
erste 3 Wochen zeigen kein ACWR.

### RP-10: Fingerkraft-Trend ohne erfundenes Körpergewicht
**Kontext:** `fingerStrengthTrend(sessions)` → `bodyMass ?? 70` erzeugt falsche
Absolutwerte für alle ≠ 70 kg; die View übergibt nie ein Körpergewicht.
**Dateien:** `Achievement.swift`, `FingerStrengthTrendView.swift`,
`SettingsView.swift`
**Aufgabe:** `@AppStorage("bodyWeightKg")`-Einstellung (optional, Double) in
Settings; View reicht sie durch. Ohne Einstellung: nur `addedWeightKg` plotten
und Achse als „Zusatzgewicht (kg)" beschriften — kein Default-Körpergewicht.
**Fertig-wenn:** Ohne Einstellung zeigt der Chart Zusatzgewicht; mit
Einstellung 82 kg und +10 kg-Hang liegt der Punkt bei 92 kg.

### RP-11: Veraltete Achievement-Tests reparieren (Suite muss grün sein)
**Kontext:** `StatsEngineTests` prüft IDs `five`, `marathon`, `versatile`,
die in `achievements(for:)` nicht mehr existieren (nur `first`, `streak`)
→ mind. 3 Tests schlagen fehl; die Suite taugt so nicht als Regressionsnetz.
**Dateien:** `ClimbReflectTests/StatsEngineTests.swift`
**Aufgabe:** Tote Tests entfernen; stattdessen Tests für `streak`-Achievement
(3/4 Wochen gesperrt, 4 Wochen entsperrt) und 2–3 `climbAchievements`-Fälle
(triple_flash, flash_rate) ergänzen. Ideal: hier direkt Regressionstests für
RP-3 (Dauer), RP-7 (ladderIndex) und RP-9 (ACWR) andocken.
**Fertig-wenn:** Gesamte Testsuite grün in Xcode.

### RP-12: „Hartnäckig"-Achievement auf Projekt-Relation umstellen
**Kontext:** `climbAchievements.projectSent` matcht über `projectName`-String
— verletzt „Relationen statt Strings"; Ascents mit Relation aber ohne
Name-Cache werden nie gezählt.
**Dateien:** `Achievement.swift`
**Aufgabe:** Über `a.project` gruppieren (Fallback projectName nur für
Alt-Daten ohne Relation); Versuchssumme über die Ascents des Projekts.
**Fertig-wenn:** Projekt mit 5+ Versuchen über Relation (ohne projectName)
schaltet das Achievement frei.

---

## Block C – Flüssigkeit / End-Flow

### RP-13: „Speichern…"-Zustand beim Beenden (Kern-UX-Fix)
**Kontext:** Nach „Beenden" laufen in `endWorkout()` drei HealthKit-Roundtrips
(`addSamples`, `endCollection`, `finishWorkout`), zusammen typ. 2–5 s. In
dieser Zeit keinerlei UI-Reaktion; der Timer ist bereits invalidiert → die
Uhr friert ein → wirkt aufgehangen, Nutzer drückt mehrfach.
**Dateien:** `WorkoutManager.swift`, `Views/LiveSessionView.swift`
**Aufgabe:**
1. `@Published var isEnding = false`; in `endWorkout()` als ALLERERSTE Zeile
   nach dem Guard: `isEnding = true` + `WKInterfaceDevice.current().play(.stop)`
   (Haptik von hinten nach vorn ziehen). In `finishSession()` zurücksetzen.
2. `LiveSessionView`: bei `isEnding` Vollbild-Overlay (`ProgressView` +
   „Session wird gespeichert…", WatchTheme.bg, deckend) über der TabView;
   `allowsHitTesting(false)` auf den Inhalt darunter.
3. Beide Beenden-Dialoge (Klettern/Training) und der iPhone-„end"-Befehl
   laufen automatisch durch denselben Zustand.
4. `discardWorkout()` ist schnell (kein finishWorkout-await) — kein Overlay nötig.
**Fertig-wenn:** „Beenden" tippen → Overlay erscheint < 100 ms, Haptik sofort,
kein zweiter Tap möglich; nach HK-Abschluss erscheint der Fragebogen wie bisher.

### RP-14: Statistik-Tab lazy rendern
**Kontext:** 14 Chart-Karten in einem `VStack` in `ScrollView` → alle Karten
inkl. StatsEngine-Berechnungen rendern beim ersten Frame; skaliert schlecht
mit wachsender Session-Zahl.
**Dateien:** `Views/StatisticsView.swift`
**Aufgabe:** `VStack` → `LazyVStack(alignment: .leading, spacing: 24)`.
Sichtprüfung: Karten mit `@State`-Periodenwahl behalten ihren State beim
Scrollen (LazyVStack recycled nicht wie List — ok).
**Fertig-wenn:** Tab-Wechsel auf Statistik bei 100+ Sessions ohne spürbaren
Hänger; alle Karten funktionieren unverändert.

---

## Block D – Darstellung

### RP-15: iPhone-Live-Banner – Pausenzeit korrekt, Beenden mit Rückfrage
**Kontext:** `liveElapsedFormatted()` rechnet ab `startedAt` ohne Pausenabzug
→ nach jeder Pause divergieren Watch- und iPhone-Zeit dauerhaft. Der
Stop-Button beendet ohne Bestätigung (destruktiv, ein Fehl-Tipp).
**Dateien:** `Models/WatchLiveStatus.swift` (beide Seiten!),
`Views/Components/LiveSessionBanner.swift`, `WorkoutManager.broadcastLiveStatus`
**Aufgabe:**
1. `WatchLiveStatus` um `accumulatedPausedSeconds: Double = 0` erweitern
   (optional decodierbar); Watch sendet `accumulatedPaused` mit.
2. Banner: `Date().timeIntervalSince(startedAt) − accumulatedPausedSeconds`.
3. Stop-Button → `confirmationDialog("Session auf der Watch beenden?")`.
**Fertig-wenn:** 1 Min pausieren, fortsetzen → Watch und Banner zeigen
identische Zeit; Stop fragt nach.

### RP-16: GradeProgressView – doppelten Perioden-Picker entfernen, Periode konsistent anwenden
**Kontext:** Zwei `ChartPeriodPicker` auf dasselbe Binding in einer Karte
(Header + Konsolidierungs-Zeile); der Trend-Chart ignoriert die Periode
(fix 6 Monate), die Konsolidierung nutzt sie → wirkt defekt.
**Dateien:** `Views/Components/GradeProgressView.swift`
**Aufgabe:** Picker nur im Karten-Header; `maxGradeTrend`-Monatszahl aus der
Periode ableiten (4W→2, 3M→3… oder Periode auf beide Sektionen anwenden —
kleinste konsistente Lösung wählen).
**Fertig-wenn:** Genau ein Picker; Wechsel der Periode verändert Trend UND
Konsolidierung nachvollziehbar.

### RP-17: Grad-Anzeige app-weit über GradeConverter.display
**Kontext:** Nur TodayView, GradePyramidView, AscentRowView konvertieren ins
Anzeige-System. Roh-Grade erscheinen in: SessionDetailView („Top-Grad"),
WeeklyRecapView (Höchstgrad), GradeProgressView (Annotationen/Chips),
BetaLibraryView → gemischte Skalen bei V-Scale/UIAA-Nutzern.
**Dateien:** die vier genannten Views
**Aufgabe:** Alle Grad-Ausgaben durch `GradeConverter.display(grade:storedIn:)`
leiten (System des Ascents als `storedIn`). WeeklyRecap-System-Label auf das
Anzeige-System umstellen.
**Fertig-wenn:** Anzeige-Skala V-Scale: keine Font-Grade mehr sichtbar
(Suchdurchlauf durch alle Screens mit Testdaten).

### RP-18: UIAA-Konverter-Leiter um „III" ergänzen; Kleinkram
**Kontext:** `GradeSystem.uiaa.grades` enthält „III", die Konverter-Leiter
beginnt bei „IV" → display() fällt still auf Rohwert zurück. Außerdem 3×
`print()` statt `DiagnosticLog` in `LiveActivityController`.
**Dateien:** `Models/GradeConverter.swift`, `Services/LiveActivityController.swift`
**Aufgabe:** Leitern vorn um ein Stufenpaar erweitern („3+"/„III" — Mapping
kurz verifizieren) ODER „III" bewusst als nicht konvertierbar dokumentieren
und aus `grades` entfernen (⚠️ Mini-ABSTIMMEN, Alt-Daten!). prints ersetzen.
**Fertig-wenn:** Keine still fehlschlagende Konvertierung für wählbare Grade;
keine print()-Aufrufe mehr in Services.

### RP-19: Tote Erfassungsreste aufräumen
**Kontext:** `WatchAttempt.note` wird nie gesetzt (keine Watch-UI);
Kommentar-Leichen aus RP-4.
**Dateien:** `WatchAttempt.swift`
**Aufgabe:** `note` aus WatchAttempt entfernen (AscentDTO-Feld existiert
nicht — nichts zu migrieren) ODER als bewusst reserviert kommentieren.
**Fertig-wenn:** Kein ungenutztes Feld ohne Begründungskommentar im
Watch-Modell.

---

## ⚠️ ABSTIMMEN (vor Umsetzung der markierten Tasks)

1. **RP-3 – Dauer-Definition:** Netto (Empfehlung) oder Brutto? Zusätzlich
   `pausedSeconds` persistieren?
2. **RP-9 – ACWR:** Standard-Formel 1W/4W übernehmen? Sessions ohne RPE:
   ausschließen oder minutenbasiert zählen?
3. **RP-18 – UIAA „III":** Leiter erweitern oder Grad entfernen?
4. **Statistik-Tab-Diät (kein Task angelegt):** Antistyle-Radar und
   Terrain-Heatmap werten dieselbe Datenbasis aus; Radar wäre der
   Streich-Kandidat. Alternativ Gruppierung der 14 Karten in Sektionen
   (Leistung / Belastung / Stil / Kontext). Nur auf Zuruf.
5. **RP-5 – Langfristig:** `gradeRaw` optional machen (saubere Migration)
   statt „?"-Sentinel — nach CloudKit-Pfad-1-Entscheidung sinnvoll zu bündeln.

## Bekannte, hier NICHT erneut aufgenommene Punkte
- Action-Button-Bridge (TODO-ACTIONBUTTON-ASCENT.md)
- `efficiencyTrend`-Nonkonformanz avgAttemptsToTop/flashRate
  (Route-Identität B beschlossen, Umsetzung separater Block) — Hinweis:
  RP-4/RP-5 reduzieren die Verzerrung, lösen sie aber nicht.
- SEC1–SEC6 (TODO8-SECURITY.md)
