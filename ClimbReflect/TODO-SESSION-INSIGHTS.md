# TODO – Session-Insights · Standort · Schuh-Tracking (+ Konsolidierung)

**Branch:** `dev` (Repo-Stand `origin/dev` @ `cdacb9a`, 21.06.2026)
**Pfade:** iOS `ClimbReflect/ClimbReflect/ClimbReflect/`, Watch `ClimbReflectWatch Watch App/`
**Format:** Eine Aufgabe = ein Commit. Jeder Block: *Kontext / Dateien / Aufgabe / Fertig-wenn*.

> **Zweck:** Ersetzt **alle** alten `TODO-*.md`-Listen (Teil 0 = Erledigt/Offen-Abgleich, Teil 3 =
> Löschliste). `CLAUDE.md` bleibt erhalten und wird ergänzt.
> **Push-Hinweis:** Basiert auf `origin/dev` @ `cdacb9a`. Lokale ungepushte Commits ggf. zuerst pushen.

---

## Teil 0 — Abgleich: erledigt / offen

### ✅ Erledigt auf `dev`
Memory-Leak (S16/S19/S22), Recovery-Härtung (S14/S17/S18/S21), Diagnose-Export, Action-Flow
(S24: Badge-Toggle + Doppeltipp, Versuchdauer + max. Höhe pro Versuch), Watch-Design-Feinschliff,
Action Button (S23, `StartSessionIntent`), iPhone Live Activity Vordergrund-Retry (S26),
Projekte-Feature (echte `Project ↔ [Ascent]`-Relation, Migration, Pinning, Projekt-Detail),
4-Tab-Dashboard. **Watch-Projekt-Picker funktioniert** (vom Nutzer bestätigt — kein offener Punkt mehr).

### 🔶 Offen (in Teil 2 als Tasks)
- **O-2** Grad-Skalen aus einer Quelle (`Enums.GradeSystem` vs `GradeConverter` divergieren).
- **O-3** Geräte-Verifikation (Action Button am Ultra zuweisen; Live Activity erscheint nach Vordergrund).
- **O-4** Kleinkram: HealthKit-Fehlertext; `WatchSessionDTO` echte Entdoppelung (Xcode-GUI);
  Blackscreen am Sessionende nur beobachten.

### 🟢 Neu in dieser Runde
**Teil 1** Session-Insights (Tortendiagramm + Kennzahlen), **Teil 1B** Standort anzeigen **+
nachtragbar machen**, **Teil 1C** Schuh-Tracking (neues Feature, spiegelt die Projekt-Architektur).

---

## Teil 1 — Session-Insights

**Ziel:** In der Session-Detailansicht sehen, wie sich die Hallenzeit aufteilt (aktiv geklettert vs.
Pause) plus ein paar aussagekräftige Kennzahlen.

**Ehrliche Datengrundlage:** Aktive Kletterzeit = Summe der **gemessenen** `Ascent.durationSeconds`
(aus dem Watch-Start/Stopp-Flow). Pause = `session.durationSeconds − aktiv`. Liegen keine
Versuchdauern vor (manuelle/ältere Sessions), wird **nicht geschätzt** → entweder dezenter Hinweis
„dazu gibt es keine Daten" **oder** Diagramm ausblenden. **Entschieden (Björn): Hinweis-Text;
Ausblenden als triviale Alternative ok.** Keine Fake-Werte (S6).

### SI-1 — `StatsEngine.insights(for:)` (reine Funktion + Tests)
- *Kontext:* Berechnung gehört in die rein funktionale `StatsEngine`, nicht in die View.
- *Dateien:* `Models/Achievement.swift` (enthält `enum StatsEngine`), `ClimbReflectTests/StatsEngineTests.swift`
- *Aufgabe:*
  ```swift
  struct SessionInsights {
      let totalSeconds: Double
      let activeSeconds: Double                 // Σ ascent.durationSeconds, geklemmt ≤ total
      var pauseSeconds: Double { max(0, totalSeconds - activeSeconds) }
      var activeShare: Double { totalSeconds > 0 ? activeSeconds / totalSeconds : 0 }
      let hasAttemptTimes: Bool
      let avgAttemptSeconds: Double?
      let longestAttemptSeconds: Double?
      let sendsPerHour: Double?                 // Tops / (total/3600)
      let load: Int?                            // sRPE = RPE × Minuten
      let successRate: Double?                  // Tops / Begehungen
      let attemptsPerSend: Double?              // Ø attempts über Tops
      let hardestTopGrade: String?             // höchster getoppter Grad (sortOrder)
  }
  static func insights(for session: ClimbSession) -> SessionInsights { /* siehe Vorgabe */ }
  ```
  Logik: getimte Versuche = `ascents.compactMap(\.durationSeconds).filter { $0 > 0 }`; `active =
  min(Σ, total)`; `tops = ascents.filter { $0.result == .top }`; `load = perceivedEffort.map {
  Int(Double($0) * total/60) }`; `hardestTopGrade` über `Ascent.sortOrder`.
- *Fertig-wenn:* Tests grün für: keine Zeiten → `hasAttemptTimes == false`; Σ > total → geklemmt;
  RPE 7 × 60 min → `load == 420`; 3 Tops / 90 min → `sendsPerHour == 2`.

### SI-2 — Tortendiagramm „Zeitaufteilung" (`SectorMark`, iOS 17)
- *Kontext:* Das gewünschte Diagramm. iOS-Target 17.0 → `SectorMark` verfügbar; noch kein Pie im Projekt.
- *Dateien:* neu `Views/Components/SessionTimeDonut.swift`; Einbindung `Views/SessionDetailView.swift`
- *Aufgabe:* Donut (innerRadius `.ratio(0.62)`) mit zwei Sektoren — „Aktiv geklettert"
  (`Theme.accent`) und „Pause / nicht geklettert" (`Theme.bgElevated`); Zentrums-Overlay
  `\(Int(activeShare*100))% aktiv`; rechts Legende mit Minuten. In `SessionDetailView` **nach**
  `overviewSection` einsetzen:
  ```swift
  let insights = StatsEngine.insights(for: session)
  if session.isClimbing && insights.hasAttemptTimes {
      SessionTimeDonut(insights: insights)
  } else if session.isClimbing && session.durationSeconds > 0 {
      Text("Zur Zeitaufteilung gibt es für diese Session keine Daten – Aktivzeit wird nur bei "
         + "Watch-Sessions mit Start/Stopp pro Versuch gemessen.")
          .font(.caption).foregroundStyle(Theme.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading).card()
  }
  ```
- *Fertig-wenn:* Watch-Session mit Zeiten → korrekter Donut; manuelle Session → Hinweis;
  Training-Session → nichts; `#Preview` rendert.

### SI-3 — Kennzahlen-Kacheln in der Übersicht
- *Dateien:* `Views/SessionDetailView.swift` (nutzt vorhandenes `metricTile`)
- *Aufgabe:* Kacheln ergänzen, jeweils nur wenn Wert vorhanden: **Aktivzeit** (`figure.climbing`,
  accent), **Ø Versuch** (`timer`, accent2), **Belastung** = sRPE (`gauge.medium`, gold, Untertitel
  „RPE × Min"), **Erfolgsquote** (`percent`), **Höchster Grad** (`trophy`). `metricCount`-Grid-Branching
  hochzählen.
- *Fertig-wenn:* Reiche Watch-Session zeigt die Kacheln; bei fehlenden Daten verschwinden sie sauber.

### SI-6 — CLAUDE.md
- *Aufgabe:* **S27 – Aktivzeit ist gemessen, nie geschätzt.** Zeitaufteilung nur aus
  `Ascent.durationSeconds`; ohne Daten Hinweis/ausblenden (S6). Kennzahlen leben in
  `StatsEngine.insights(for:)`.

---

## Teil 1B — Standort (Halle/Outdoor): anzeigen **und** nachtragbar machen

> **Befund:** `gymName`/`outdoor` lassen sich aktuell **nur** beim manuellen Anlegen
> (`ManualSessionView`) setzen. Watch-Sessions haben nie einen Standort, und **nachträglich
> bearbeiten geht nirgends.** Daher zwei Tasks.

### ST-1 — Standort im Session-Header anzeigen
- *Dateien:* `Views/SessionDetailView.swift` (`sessionHeader`)
- *Aufgabe:* Standort-Chip neben Dauer/Quelle: `outdoor → Label("Outdoor", systemImage:
  "mountain.2.fill")`, sonst `gymName.map { Label($0, systemImage: "building.2.fill") }`. Beides leer → nichts.
- *Fertig-wenn:* Sessions mit Halle/Outdoor zeigen den Standort; ohne Angabe unverändert.

### ST-2 — Standort in der Detailansicht **anlegen/nachtragen** (Lückenschluss)
- *Kontext:* Damit man Watch-Sessions (und vergessene manuelle) den Standort nachträglich geben/ändern kann.
- *Dateien:* `Views/SessionDetailView.swift` (kleiner Editor, z. B. im/über dem Header oder als Sheet)
- *Aufgabe:* Editierbarer Standort: `Toggle` „Outdoor" (bindet `session.outdoor`) und `TextField`
  „Halle" (bindet `session.gymName`, leer → `nil`), nur sichtbar wenn nicht outdoor. **Komfort:**
  bereits benutzte Hallennamen als Quick-Pick-Chips anbieten (aus
  `@Query` distinct `gymName` aller Sessions) → vermeidet Tippfehler ohne neue Entität.
  `session.updatedAt = .now` bei Änderung.
- *Fertig-wenn:* Eine Watch-Session ohne Standort kann auf dem iPhone eine Halle bzw. Outdoor
  bekommen; Änderung bleibt nach Neustart erhalten; bestehende Quick-Picks funktionieren.
> *Optional/später:* echte `Location`-Entität (1:n zu Sessions) statt Freitext — erst wenn eine
> Standort-Übersicht/Statistik gewünscht ist. Jetzt bewusst Freitext, um Scope klein zu halten.

---

## Teil 1C — NEU: Schuh-Tracking

**Ziel (Björn):** Auf dem iPhone Schuhe **anlegen** (nur Name + Alter als Monat/Jahr = „seit wann
getragen"). Bei der **gleichen Auswahl wie beim Projekt** (Watch-Live-Selektor **und** iPhone)
einen angelegten Schuh wählen. Der **aktuell gewählte Schuh** wird — wie das Projekt — beim Banken
auf den Versuch geschnappt; **mitten in der Session wechselbar** (gilt dann für alle folgenden
Ascents, beliebig oft zurückwechselbar). **Anlegen nur iPhone** (Source of Truth), **Auswählen auf
der Uhr oder nachträglich auf dem iPhone.** Erstmal nur Felder + Auswahl; Auswertung („Zeit pro
Schuh") kommt später (Datengrundlage entsteht hier).

**Architektur:** spiegelt das Projekt-Subsystem 1:1 (`Project`→`Shoe`, `Ascent.project`→`Ascent.shoe`,
`projectName/ID`→`shoeName/ID`, `selectedProject`→`selectedShoe`, `knownProjects`→`knownShoes`,
`ProjectInfo`→`ShoeInfo`). Einziger bewusster Unterschied: **kein Auto-Anlegen** beim Empfang
(iPhone bleibt alleinige Anlage-Quelle).

### SH-1 — Datenmodell: `Shoe` + `Ascent.shoe`-Relation + Migration
- *Dateien:* neu `Models/Shoe.swift`; `Models/Ascent.swift`; `Models/AppMigrationPlan.swift`
- *Aufgabe:*
  ```swift
  @Model final class Shoe {
      @Attribute(.unique) var id: UUID
      var name: String
      var startMonth: Int        // 1…12  (Beginn des Tragens)
      var startYear: Int
      var isRetired: Bool = false   // optional: „nicht mehr aktiv"
      var createdAt: Date
      @Relationship(deleteRule: .nullify, inverse: \Ascent.shoe) var ascents: [Ascent] = []
      var startDate: Date { Calendar.current.date(from: DateComponents(year: startYear, month: startMonth, day: 1)) ?? createdAt }
      init(name: String, startMonth: Int, startYear: Int) {
          self.id = UUID(); self.name = name
          self.startMonth = startMonth; self.startYear = startYear; self.createdAt = .now
      }
  }
  ```
  In `Ascent`: `var shoe: Shoe?` (echte Relation) + `var shoeName: String?` (Cache, analog
  `projectName` — für DTO/Anzeige-Fallback). In `AppMigrationPlan`: **SchemaV3** mit `Shoe.self` in
  der Models-Liste + lightweight `MigrationStage` `v2ToV3` (rein additiv).
- *Fertig-wenn:* App migriert eine bestehende DB verlustfrei auf V3; `Shoe` + `Ascent.shoe` existieren.

### SH-2 — iPhone: Schuhe verwalten (anlegen/bearbeiten/löschen)
- *Dateien:* neu `Views/ShoesView.swift`; Einstieg in `Views/SettingsView.swift` (Zeile „Schuhe verwalten")
- *Aufgabe:* Liste aller `Shoe` (`@Query(sort: \Shoe.startYear, order: .reverse)`); „+" legt einen
  Schuh an (TextField Name + zwei Picker Monat/Jahr); Zeile editierbar; Swipe-to-delete
  (`deleteRule: .nullify` → Ascents behalten `shoeName`-Cache, verlieren nur die Relation). Anzeige
  z. B. „Solution Comp · seit 03/2025".
- *Fertig-wenn:* Schuhe lassen sich auf dem iPhone anlegen, umbenennen, im Datum ändern und löschen;
  Löschen entfernt keine Begehungen.

### SH-3 — iPhone: Schuh-Auswahl in `AddAscentView` (gleiches Menü wie Projekt)
- *Dateien:* `Views/AddAscentView.swift`
- *Aufgabe:* Analog zu `projectChip(...)` einen **Schuh-Chip-Picker** ergänzen: `@Query` Schuhe,
  `@State selectedShoe: Shoe?`, Chips „Keiner" + alle aktiven Schuhe. Beim Speichern
  `ascent.shoe = selectedShoe` und `ascent.shoeName = selectedShoe?.name`. (Anlegen bleibt in
  `ShoesView` — hier nur auswählen.)
- *Fertig-wenn:* Beim Hinzufügen einer Begehung kann ein Schuh gewählt werden; er wird gespeichert
  und in `AscentRowView` (SH-10) angezeigt.

### SH-4 — iPhone: Schuh (+ Projekt) **nachträglich** an einer Begehung ändern
- *Kontext:* „Auswählen … auch nachträglich auf dem iPhone." Aktuell sind Ascents nicht editierbar.
- *Dateien:* neu `Views/EditAscentAssociationsSheet.swift` (schlank); `Views/SessionDetailView.swift`
  (`AscentRowView` antippbar machen)
- *Aufgabe:* Tap auf eine Begehung öffnet ein Sheet mit **Schuh-Chip-Picker + Projekt-Chip-Picker**
  (nur diese beiden Zuordnungen, kein voller Edit). Speichern setzt `ascent.shoe`/`shoeName` und
  `ascent.project`/`projectName`.
- *Fertig-wenn:* Eine bestehende Begehung (auch von der Watch) kann auf dem iPhone nachträglich
  einem Schuh und/oder Projekt zugeordnet/umgeordnet werden.

### SH-5 — DTO: `shoeName` + `shoeID` (iOS **und** Watch synchron halten)
- *Dateien:* `Models/WatchSessionDTO.swift` (iOS) **und** `ClimbReflectWatch Watch App/Models/WatchSessionDTO.swift`
- *Aufgabe:* In `AscentDTO` ergänzen: `let shoeName: String?` und `let shoeID: UUID?` (beide Kopien
  müssen identisch bleiben — optionale Felder → alte DTOs dekodieren weiter). `WatchAttempt.toDTO()`
  / `init(fromDTO:)` entsprechend erweitern.
- *Fertig-wenn:* Beide DTO-Dateien strukturell identisch; Build grün auf beiden Targets.

### SH-6 — Watch: `ShoeInfo` + `knownShoes`-Sync (Sender iPhone, Empfang Watch)
- *Dateien:* `ClimbReflectWatch Watch App/Services/SyncService.swift`;
  `ClimbReflect/.../Services/WatchSessionReceiver.swift` (`pushProjectsToWatch`)
- *Aufgabe:* `struct ShoeInfo: Identifiable, Hashable { let id: String; let name: String }` (analog
  `ProjectInfo`). iPhone-Sender: beim `updateApplicationContext` zusätzlich
  `"shoeList": [["id","name"]]` + `knownShoesKey: [names]` **genau im Muster der Projekte** mitsenden
  (aktive, nicht-retired Schuhe). Watch `SyncService`: `@Published var knownShoes: [ShoeInfo]` aus
  dem Context lesen (gleiche Dual-Key-Logik wie `knownProjects`).
- *Fertig-wenn:* Auf dem iPhone angelegte Schuhe erscheinen auf der Watch in `knownShoes`; ein neuer
  Schuh ist nach kurzer Zeit auf der Uhr verfügbar.

### SH-7 — Watch: `selectedShoe` (persistiert) + Snapshot auf Versuch + Recovery
- *Dateien:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`;
  `…/Models/WatchAttempt.swift`; `…/Services/PendingSessionStore.swift`
- *Aufgabe:* `@Published var selectedShoe: ShoeInfo?` mit `didSet`-Persist in UserDefaults (analog
  `selectedProject`, P2-8). `WatchAttempt.shoeInfo: ShoeInfo?` als Snapshot beim Banken
  (`bankAttempt(...)` übergibt `shoeInfo: selectedShoe`). `toDTO()` schreibt `shoeName/shoeID`,
  `init(fromDTO:)` liest sie. In `PendingSessionStore` den `selectedShoe` mit-snapshotten und in
  `reattach()` wiederherstellen. In `finishSession()` `selectedShoe = nil`.
- *Fertig-wenn:* Wechselt man mitten in der Session den Schuh, tragen **nur die danach gebankten**
  Versuche den neuen Schuh; Zurückwechseln funktioniert; App-Neustart/Recovery behält die Auswahl.

### SH-8 — Watch: Schuh-Selektor im **selben Menü** wie der Projekt-Selektor
- *Dateien:* `ClimbReflectWatch Watch App/Views/LiveSessionView.swift`
- *Aufgabe:* Dort, wo `knownProjects` ausgewählt wird (Projekt-Selektor, ~Z. 174/538), einen
  **zweiten, gleich aufgebauten Schuh-Selektor** ergänzen (Liste `knownShoes`, „Keiner" + Schuhe,
  Auswahl setzt `workoutManager.selectedShoe`). Aktiver Schuh als kleines Label/Chip sichtbar (wie
  das aktive Projekt).
- *Fertig-wenn:* In derselben Auswahl-Ansicht lassen sich Projekt **und** Schuh setzen/wechseln; der
  aktive Schuh ist während der Session sichtbar.

### SH-9 — iPhone-Empfang: `shoeID/shoeName` → `Shoe` mappen (**kein** Auto-Anlegen)
- *Dateien:* `ClimbReflect/.../Services/WatchSessionReceiver.swift` (`insert`)
- *Aufgabe:* Analog zur Projekt-Verlinkung, aber strenger: `if let sid = ascentDTO.shoeID {
  ascent.shoe = allShoes.first { $0.id == sid } }` sonst per `shoeName` case-insensitive/trimmed
  matchen. **Bei unbekannter ID/Name: `ascent.shoe = nil` lassen** und `shoeName` als Cache behalten
  — **niemals** einen Schuh neu anlegen (Anlage nur iPhone). `allShoes` einmal vorab fetchen.
- *Fertig-wenn:* Ein auf der Watch gewählter Schuh landet am bestehenden iPhone-Schuh; eine
  unbekannte Auswahl erzeugt keinen Geister-Schuh, der Name bleibt als Cache erhalten.

### SH-10 — Anzeige + CLAUDE.md
- *Dateien:* `Views/Components/AscentRowView.swift`; `Views/SessionDetailView.swift`; `CLAUDE.md`
- *Aufgabe:* In `AscentRowView` ein dezentes Schuh-Label (`shoe.symbol`/„shoe.fill" + Name) zeigen,
  wenn gesetzt. **S28 – Schuh spiegelt die Projekt-Architektur:** iPhone = Source of Truth (Anlage
  nur dort), Auswahl auf Watch via `knownShoes`/`selectedShoe`, Snapshot beim Banken, Empfang ohne
  Auto-Anlegen. `deleteRule: .nullify` (Schuh löschen lässt Begehungen unberührt).
- *Fertig-wenn:* Begehungen zeigen ihren Schuh; S28 steht in `CLAUDE.md`.

---

## Teil 2 — Restliche offene Punkte (aus Altlisten)

### O-2 — Grad-Skalen aus einer Quelle
- *Dateien:* `Models/Enums.swift`, `Models/GradeConverter.swift`
- *Aufgabe:* Kanonische Leiter pro Disziplin als Source of Truth; Picker + Converter daraus ableiten;
  echte Mehrdeutigkeiten als „~"/Bereich kennzeichnen.
- *Fertig-wenn:* Anzeige-Skala umschalten ist im Round-Trip verlustfrei.

### O-3 — Geräte-Verifikation (Checkliste, kein Code)
- Action Button am Watch Ultra zuweisen → Druck startet Session.
- Live Activity: Watch-Session starten → iPhone entsperren → Lock-Screen-Timer erscheint/aktualisiert.
  Sonst `LiveActivityController`-Log + Embedding/`ClimbActivityAttributes` prüfen.
- *Fertig-wenn:* Beide bestätigt oder Restproblem als neuer Task notiert.

### O-4 — Kleinkram (optional)
HealthKit-Fehlertext (Permission vs. „keine Workouts" + Button zu Einstellungen);
`WatchSessionDTO` echte Entdoppelung (geteilte Target-Membership, Xcode-GUI);
Blackscreen am Sessionende nur beobachten.

---

## Teil 3 — Aufräumen: alte Listen löschen

Nach Übernahme **dieser** Datei können alle alten `TODO-*.md` weg. **Behalten:** `CLAUDE.md`,
`ClimbReflect/ClimbReflect-README.md`.

```bash
cd "ClimbReflectWatch Watch App"
git rm \
  "TODO-ACTIONBUTTON-UND-LIVEACTIVITY.md" \
  "TODO-DIAGNOSE-EXPORT-MAXHR.md" \
  "TODO-GESAMT-LEAK-UND-RECOVERY.md" \
  "TODO-LEAK-ATTEMPTLOGVIEW-PLUS-FLOW.md" \
  "TODO-LEAK-ISOLATION.md" \
  "TODO-LEAK-LOKALISIEREN.md" \
  "TODO-Recovery-HRStats.md" \
  "TODO-VERSUCHE-BADGE-TOGGLE.md" \
  "TODO-WATCH-DESIGN-FEINSCHLIFF.md" \
  "TODO-ZWEITE-SEITE-UND-ACTION-FLOW.md"
cd ..
git add "ClimbReflectWatch Watch App/TODO-SESSION-INSIGHTS.md"
git commit -m "docs: TODO-Listen konsolidiert → Session-Insights/Standort/Schuh (Altlisten entfernt)"
```

> Auf `main` liegen außerdem ältere `TODO.md`, `TODO6.md`, `TODO-Projects.md` (Stand vor `dev`).
> Bei einem späteren `main`-Update mit `dev` dort ebenfalls aufräumen.

---

## Reihenfolge
1. **Session-Insights:** SI-1 → SI-2 → SI-3 → SI-6.
2. **Standort:** ST-1 → ST-2.
3. **Schuh (Datengrundlage zuerst):** SH-1 → SH-5 → SH-2 → SH-3 → SH-9 → SH-6 → SH-7 → SH-8 →
   SH-4 → SH-10.
   *(Modell + DTO zuerst, dann iPhone-Anlage/Auswahl, dann Watch-Sync/Selektor, zuletzt
   Nachtrag-Sheet + Anzeige.)*
4. **Offen:** O-2/O-3/O-4 nach Bedarf.
5. **Teil 3** Aufräumen.
