# ClimbReflect – Detaillierte Umsetzung (Runde 2 nach echtem Test)

Arbeitsplan für Claude Code. Pfade relativ zu:
- **iOS:** `ClimbReflect/ClimbReflect/ClimbReflect/`
- **Watch:** `ClimbReflectWatch Watch App/`

Format je Punkt: *Datei(en) · Ursache/Status · Aufgabe · Fertig wenn*. Reihenfolge:
erst die schnellen, eigenständigen Fixes (A), dann Modelländerungen (B), dann das größere
Skalen-Feature (C). Bei Modelländerungen SwiftData-Migration beachten (im Dev notfalls App
neu installieren).

---

## A · watchOS

### A1 – RPE per Digital Crone wählbar
- *Datei:* `Views/SessionEndQuestionnaireView.swift` (`rpeStep`).
- *Status:* RPE ist eine Reihe von Tap-Buttons 1–10, keine Krone.
- *Aufgabe:* Krone-gesteuerte Auswahl ergänzen. Großen Wert mittig anzeigen, per Krone
  scrollen, Haptik bei jedem Schritt:
  ```swift
  @State private var rpeValue: Double = 6
  // im rpeStep, große Zahl + Farbskala:
  Text("\(Int(rpeValue))")
      .font(.system(size: 44, weight: .bold, design: .rounded))
      .foregroundStyle(rpeColor(Int(rpeValue)))
      .focusable(true)
      .digitalCrownRotation($rpeValue, from: 1, through: 10, by: 1,
                            sensitivity: .low, isContinuous: false,
                            isHapticFeedbackEnabled: true)
  // beim Weiter: rpe = Int(rpeValue)
  ```
  Die 1–10-Reihe darf als schmaler visueller Indikator bleiben (zeigt aktuellen Wert), ist
  aber nicht mehr die primäre Eingabe.
- *Fertig wenn:* RPE lässt sich flüssig mit der Krone einstellen, mit Haptik, und der Wert
  landet im DTO.

### A2 – Kletterhöhe pro Begehung zuverlässig erfassen
- *Dateien:* `Services/AltimeterService.swift`, `Services/WorkoutManager.swift`.
- *Status:* `altitudeGain` wird über `start/stopAscentTracking()` gemessen, aber nur über
  summierte positive Deltas — bei wackligem Signal ungenau, und beim manuellen „+Versuch"
  ist die Klammer unsauber.
- *Aufgabe:* Pro Versuch **Netto-Höhe = Maximalhöhe − Basishöhe** messen (statt Summe der
  Deltas). In `AltimeterService` einen `ascentMaxAltitude` mitführen; `stopAscentTracking()`
  gibt `max(0, ascentMax − ascentBase)` zurück. Sicherstellen, dass **jeder** Versuchspfad
  (Action Button, Auto-Erkennung, manueller „+Versuch") `startAscentTracking()` beim Beginn
  und `stopAscentTracking()` beim Banken aufruft.
- *Fertig wenn:* Eine geseilte Begehung zeigt eine plausible Höhe; Summe stimmt mit
  `totalGain` überein.

### A3 – Höhenmeter statt kcal anzeigen
- *Datei:* `Views/LiveSessionView.swift` (`vitalsRow`, ggf. `trainingInfoPage`).
- *Aufgabe:* Im Klettermodus die kcal-Zelle durch **Höhenmeter gesamt** ersetzen
  (`workoutManager.altimeter.totalGain`, gerundet, Einheit „m", Icon `arrow.up.forward`).
  kcal darf im Trainingsmodus bleiben (dort ist Energie relevanter).
- *Fertig wenn:* Während einer Klettersession stehen die gesammelten Höhenmeter statt kcal.

### A4 – Begehungen als eigene „zweite Seite" unter der Session (Wetter-App-Muster)
- *Datei:* `Views/LiveSessionView.swift` (`sessionInfoPage`).
- *Status (Kernproblem, mehrfach gemeldet):* Stats und Verlauf liegen in **einer** ScrollView
  mit `.scrollTargetBehavior(.viewAligned)`; die Begehungen erscheinen direkt unter den Stats,
  kein sauberer Seitenwechsel.
- *Aufgabe:* `sessionInfoPage` als **vertikal blätterndes** `TabView` umbauen — genau das
  erzeugt den vom Nutzer gewünschten Punkt-Indikator **rechts** und den klaren Seitenwechsel:
  ```swift
  TabView {
      statsPage          // bisheriger Stats-Block (Timer, Vitals, Versuche/Tops)
      historyPage        // Liste der Begehungen (ascentRow)
  }
  .tabViewStyle(.verticalPage)   // Punkte rechts, "Wetter-App"-Blättern
  ```
  Den bisherigen GeometryReader/`scrollTargetLayout`/`viewAligned`-Mechanismus entfernen.
  `statsPage` füllt Seite 1, `historyPage` ist Seite 2 (nur per Wischen erreichbar). Falls
  keine Begehungen vorhanden: nur Seite 1 zeigen (kein zweiter Punkt).
- *Fertig wenn:* Auf der Session-Seite sieht man unten/rechts den zweiten Seitenpunkt; erst
  Wischen nach unten zeigt die Begehungen — nicht direkt unter den Stats.

### A5 – App-internen Timer kompakter (Platz gewinnen)
- *Datei:* `Views/LiveSessionView.swift`.
- *Hinweis:* Die **System-Uhrzeit** (oben rechts) kann nicht ausgeblendet werden (watchOS-
  Sperre). Stattdessen den großen `elapsedFormatted`-Timer kleiner setzen (z. B. `.title3`
  statt `.title`) bzw. enger anordnen, um mehr Inhalt sichtbar zu machen.
- *Fertig wenn:* Mehr nutzbarer Platz auf der Session-Seite, Timer weiter gut lesbar.

---

## B · iOS

### B1 – „Daten aus Redpoint" entfernen / quellen-korrekt benennen
- *Datei:* `Views/SessionDetailView.swift` (`sessionHeader`, `redpointCard`).
- *Status:* Der Vitalwerte-Block heißt fix „Daten aus Redpoint" und das Header-Label „Redpoint"
  hängt an `source == .healthKit` — wirkt aber auch bei Watch-Sessions falsch, da die App
  eigenständig ist.
- *Aufgabe:* „Redpoint" aus der UI entfernen. Vitalwerte-Karte in **„Vitalwerte"** umbenennen
  und immer zeigen, wenn HF/Energie vorhanden sind (egal welche Quelle). Quelle als dezenten
  Untertitel: `.watch` → „Apple Watch", `.healthKit` → „Apple Health", `.manual` → nichts.
  Im Header das „Redpoint"-Label entsprechend ersetzen.
- *Fertig wenn:* Eine Watch-Session zeigt „Vitalwerte" + „Apple Watch", nie „Redpoint".

### B2 – Bestehende Redpoint-Dubletten beim Sync ersetzen (Begehungen sichtbar machen)
- *Datei:* `Services/WatchSessionReceiver.swift` (`insert(dto:)`).
- *Status:* Kommt eine Watch-Session mit `workoutUUID`, die schon als `.healthKit`-Session
  (ohne Begehungen) existiert, wird sie verworfen → der Nutzer sieht die alte Dublette ohne
  Begehungen.
- *Aufgabe:* Vor dem Insert prüfen, ob eine Session mit gleicher `workoutUUID` existiert. Wenn
  ja und deren `source == .healthKit` → **alte löschen** und die Watch-Version (mit Begehungen)
  einfügen. So „gewinnt" immer die reichhaltigere Watch-Session.
- *Fertig wenn:* Nach dem Sync ist die Session als Watch-Session mit allen Begehungen sichtbar,
  keine leere Redpoint-Dublette mehr.

### B3 – Begehungen in der Session anzeigen (verifizieren)
- *Datei:* `Views/SessionDetailView.swift` (`ascentsCard`).
- *Aufgabe:* Nach B2 prüfen, dass `session.ascents` befüllt sind und in der Liste erscheinen
  (inkl. Grad, Ergebnis, ggf. Höhe). Falls leer trotz Sync: Mapping in
  `WatchSessionReceiver.insert` gegen `AscentDTO` gegenchecken.
- *Fertig wenn:* Alle auf der Watch erfassten Begehungen erscheinen in der iOS-Session.

### B4 – Abstand + Snap-Scrolling in der Session entfernen
- *Datei:* `Views/SessionDetailView.swift` (`body`, ~Zeile 24–41).
- *Status:* `overviewSection.containerRelativeFrame(.vertical)` erzeugt den großen Leerraum,
  `.scrollTargetLayout()` + `.scrollTargetBehavior(.paging)` das Snap-Scrolling.
- *Aufgabe:* Beides entfernen. Einfache, sauber gestapelte Darstellung:
  ```swift
  ScrollView {
      VStack(alignment: .leading, spacing: 16) {
          overviewSection      // ohne containerRelativeFrame
          ascentsSection
          reflectionCard
          // … weitere Sektionen
      }
      .padding(.horizontal)    // kein scrollTargetLayout
  }
  // kein .scrollTargetBehavior
  ```
- *Fertig wenn:* Vitalwerte, Begehungen, Tagebuch etc. liegen ohne Lücke und ohne Einrasten
  direkt untereinander.

### B5 – Alle Auswahlfelder nicht scrollbar
- *Datei:* `Views/SessionDetailView.swift` (`typePicker`, `techniqueFocusPicker`).
- *Status:* „Art der Session" und „Technik-Fokus" nutzen `ScrollView(.horizontal)`; die
  „Limitierenden Faktoren" sind ein umbrechendes `LazyVGrid` (nicht scrollbar) — das ist das
  gewünschte Verhalten für alle.
- *Aufgabe:* `typePicker` und `techniqueFocusPicker` von horizontaler ScrollView auf ein
  umbrechendes `LazyVGrid` (z. B. `[GridItem(.adaptive(minimum: 92), spacing: 8)]`) umstellen —
  identisch zum Limiter-Picker. Keine ScrollViews mehr in diesen Feldern.
- *Fertig wenn:* Alle drei Auswahlbereiche brechen um und sind nicht scrollbar.

### B6 – Technik-Fokus: Mehrfachauswahl
- *Dateien:* `Models/ClimbSession.swift`, `Views/SessionDetailView.swift`, alle Nutzungen von
  `techniqueFocus` (StatsEngine, TrainingView/Weakness, Watch-DTO-Mapping falls betroffen).
- *Status:* `techniqueFocusRaw: String?` (einzeln).
- *Aufgabe:* Auf Mehrfachauswahl umstellen: `techniqueFocusesRaw: [String] = []` +
  Accessor `var techniqueFocuses: [TechniqueFocus] { techniqueFocusesRaw.compactMap(...) }`.
  Picker als Multi-Select (toggeln wie Limiter). `focusRating` bleibt als eine Gesamt-
  Selbstbewertung der Session. Alle Lesestellen anpassen. **SwiftData-Migration:** additives
  neues Feld; das alte `techniqueFocusRaw` entweder migrieren oder im Dev verwerfen.
- *Fertig wenn:* Mehrere Technik-Fokusse pro Session wählbar und persistiert.

### B7 – RPE-Verlauf: Kurve geglättet → gerade Linien
- *Datei:* `Views/Components/RPETrendView.swift`.
- *Status:* `AreaMark` und `LineMark` nutzen `.interpolationMethod(.catmullRom)` → wellige,
  überschwingende Kurve (sieht fehlerhaft aus).
- *Aufgabe:* Beide auf `.interpolationMethod(.linear)` umstellen (gerade Verbindungen zwischen
  den Punkten). PointMarks beibehalten.
- *Fertig wenn:* Der Verlauf ist eine klare Linie zwischen den Messpunkten, kein Schwingen.

### B8 – Kletter-Erfolge: Erklärung beim Antippen
- *Dateien:* `Models/Achievement.swift` (`ClimbAchievement`, `Achievement`),
  `Views/DashboardView.swift` (`climbAchievementsRow`).
- *Status:* Erfolge haben `title`/`subtitle`, aber keine ausführliche Erklärung; nicht antippbar.
- *Aufgabe:* Feld `explanation: String` zu `ClimbAchievement` (und `Achievement`) hinzufügen
  und je Erfolg befüllen (z. B. „Du hast 3 Boulder in einer Session geflasht — im ersten
  Versuch ohne Vorwissen getoppt."). Erfolg antippbar machen → `.sheet`/`.popover` mit
  Icon, Titel und `explanation`, plus Status (freigeschaltet / Fortschritt).
- *Fertig wenn:* Tippen auf einen Erfolg erklärt verständlich, warum man ihn (nicht) hat.

### B9 – Drei Kacheln vertikal bündig
- *Dateien:* `Views/Components/StatTile.swift` (`statRow` nutzt es).
- *Status:* Tiles gleich groß, aber Label unterschiedlich lang („Diese Woche" vs. „Streak")
  → Inhalte sitzen auf unterschiedlicher Höhe.
- *Aufgabe:* In `StatTile` für das Label eine **feste Höhe / reservierten 2-Zeilen-Platz**
  setzen (`.lineLimit(2, reservesSpace: true)`), damit Icon, Wert und Label in allen drei
  Kacheln exakt auf gleicher Höhe liegen.
- *Fertig wenn:* Icon-, Wert- und Label-Zeilen der drei Kacheln sind bündig.

### B10 – Begrüßung durch Logo/Name ersetzen
- *Datei:* `Views/DashboardView.swift` (`header`).
- *Aufgabe:* „Guten Abend 👋" + „Bereit für den nächsten Zug?" entfernen. Stattdessen das
  App-Icon/Logo (klein) neben dem Schriftzug **„ClimbReflect"** (Theme-Akzent, `design: .rounded`).
- *Fertig wenn:* Oben steht Logo/Name statt Tageszeit-Begrüßung.

### B11 – Live-Banner: jede Sekunde aktualisieren (ohne Watch-Akku-Last) + Versuche entfernen
- *Dateien:* `Views/Components/LiveSessionBanner.swift`, `Models/WatchLiveStatus.swift`,
  `WorkoutManager.broadcastLiveStatus()` (Watch).
- *Status:* Banner zeigt die alle 5 s gesendete Zeit; zeigt zusätzlich Versuche.
- *Aufgabe:*
  1. `WatchLiveStatus` um `startedAt: Date` (Session-Start) erweitern; die Watch sendet
     weiterhin nur alle 5 s **bzw. bei Statuswechsel** (kein Mehraufwand für die Watch).
  2. Im Banner die Zeit lokal pro Sekunde rendern via `TimelineView(.periodic(from: .now, by: 1))`
     und `Date().timeIntervalSince(status.startedAt)` (bei Pause eingefroren auf
     `status.elapsedSeconds`). → 1-Sekunden-Anzeige **ohne** zusätzliche Watch-Funklast.
  3. Die `attemptCount`-Anzeige im Banner entfernen.
- *Fertig wenn:* Banner zählt sekündlich, Watch-Akku unbeeinflusst, keine Versuche-Anzeige.

---

## C · Übergreifend: Skala in den Einstellungen + Umrechnung überall

### C1 – Globale Anzeige-Skala in die Einstellungen (nicht auf der Startseite)
- *Dateien:* `Views/SettingsView.swift`, `Views/Components/GradePyramidView.swift`.
- *Status:* Die Skala-Auswahl sitzt als Picker **in der Grad-Pyramide** auf der Startseite.
- *Aufgabe:* Zwei globale Einstellungen anlegen (selten geändert):
  `@AppStorage("boulderScale")` (Fb/V-Scale) und `@AppStorage("routeScale")` (French/UIAA),
  als neue Settings-Section „Grad-Skala". Den System-Picker aus `GradePyramidView` **entfernen**;
  die Pyramide nutzt die globale Skala.
- *Fertig wenn:* Skala wird nur in den Einstellungen geändert; Startseite hat keinen Skala-Picker.

### C2 – Grad-Umrechnung (verlustfrei) überall anwenden
- *Dateien:* neu `Models/GradeConverter.swift`; Nutzung in `GradePyramidView`,
  Hero-Trophäe „Bester Rotpunkt" (`DashboardView.heroTrophyCard`), `AscentRowView`,
  Watch (`AttemptLogView`-Default + `ascentRow`-Anzeige).
- *Hintergrund:* Jede Begehung speichert **ihren eigenen** Grad + Grad-System (verlustfrei).
  Die Umrechnung passiert nur fürs **Anzeigen**.
- *Aufgabe:* `GradeConverter` mit zwei Leitern bauen — eine **Boulder**-Leiter (Fb ↔ V-Scale)
  und eine **Route**-Leiter (French ↔ UIAA) — über einen gemeinsamen Index pro Disziplin.
  Funktion `display(grade:in:as:)`: Quellgrad → Index → Zielskala. Boulder- und Route-Skalen
  werden **nicht** ineinander umgerechnet (verschiedene Disziplinen). Überall, wo ein Grad
  angezeigt wird, in die passende globale Anzeige-Skala umrechnen.
- *Fertig wenn:* Wechsel der Skala in den Einstellungen rechnet „Bester Rotpunkt", Pyramide,
  Begehungen (iOS) und die Watch-Anzeige korrekt um — **ohne** dass gespeicherte Daten sich
  ändern; Zurückwechseln zeigt wieder die Originaldarstellung. Kein Fehler.

### C3 – Pyramide: Info-Button mit Erklärung
- *Datei:* `Views/Components/GradePyramidView.swift`.
- *Aufgabe:* Kleines „i"-Icon → kurze Erklärung: „Zeigt, wie viele Routen/Boulder du je Grad
  getoppt hast (×N) und wie viele Versuche offen blieben (+N). Eine breite Basis = solides
  Volumen, eine schmale Spitze = dein aktuelles Limit."
- *Fertig wenn:* Nutzer kann die Pyramide in der App nachlesen.

---

## Reihenfolge-Empfehlung
1. **A1, A3, A5, B1, B4, B5, B7, B9, B10, B11** – schnelle, isolierte Fixes.
2. **A4** (Watch-Zweitseite) – wichtig, aber eigenes Testing am Gerät.
3. **B2/B3** (Sync-Dubletten/Begehungen) – zusammen testen.
4. **A2** (Höhe pro Versuch) – mit A3 gegentesten.
5. **B6** (Multi-Fokus) und **C1–C3** (Skala/Umrechnung) – Modell-/Feature-Arbeit, am Ende.

Nach jeder Gruppe bauen + auf echtem Gerät gegentesten. Bei Unklarheit Rücksprache.
