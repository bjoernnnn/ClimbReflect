# TODO13 – Erfolgssystem „Gipfelmarken" (Konzept: ERFOLGE-KONZEPT-V2.md)

Basis: `main` @ `0306575` (v1.0.0). Ein Task = ein Commit.
**Ersetzt TODO11-ERFOLGE.md und ERFOLGE-KONZEPT.md (V1)** — beide sind nie implementiert worden
und werden in EP-12 archiviert. Katalog, Wertigkeiten, Choreografie und alle Begründungen stehen im
Konzept-Dokument; dieses TODO ist die Umsetzungsreihenfolge.

**Verbindliche Regeln aus dem Konzept (gelten für jeden Task):**
- Animationen ausschließlich über `transform` (scale/offset/rotation) + `opacity`; kein Layout-Shift;
  Partikel-Budget 24; TimelineViews nach der Choreografie stoppen (S3/S19).
- `@AppStorage("achievementEffectsEnabled")` (default `true`), `@AppStorage("achievementSoundEnabled")`
  (default `false`), `accessibilityReduceMotion` wird immer zusätzlich respektiert.
- Grade nur über `canonicalOrder` vergleichen (S30), nur `isGraded` (RP-5), Zeit über
  `activeSeconds` (RP-3), Unlock bleibt bei Datenlöschung bestehen (historisches Ereignis).
- UI-Strings Deutsch, `Theme`-Farben, bestehender `card()`-Stil.

---

## Phase 0 — ⚠️ ABSTIMMEN (beantwortet 2026-07-11)

1. **Schwellen:** übernehmen wie im Konzept (`big_day` = 20, `climb_days_year` = 50,
   Stunden-Leiter [10,25,50,100,250]) — keine Anpassung.
2. **`grade_leap`:** ≥ 2 kanonische Stufen (wie im Konzept).
3. **Sound:** Toggle wird gebaut (UI + `@AppStorage`), bleibt aber ohne Asset/Hook —
   kein `.caf` vorhanden, Claude Code kann keine Audiodateien erzeugen. Nachrüstbar,
   sobald ein Asset existiert.
4. **`discipline_trio`:** 3 von 4 Disziplinen (wie im Konzept).

**Zusatzbefunde beim Gegenlesen (nicht Teil der ABSTIMMEN-Fragen, aber notiert):**
- `S33` in CLAUDE.md ist bereits belegt (TODO13-MOTIVATION/MO-14) → EP-12 nutzt **S34**.
- `AppMigrationPlan.swift` (V1…V9) ist toter Code — `ClimbReflectApp.swift` initialisiert
  den `ModelContainer` ohne `migrationPlan:`-Parameter. EP-2 erweitert die Kette trotzdem
  um V10 (Konsistenz der Historie), das bestehende Migrations-Setup bleibt aber weiterhin
  ungenutzt — kein Regressions-Risiko dieser Arbeit, aber ein latentes Problem für künftige
  nicht-additive Schema-Änderungen.

---

## Phase 1 — Fundament (rein, testbar, ohne UI)

### EP-1: AchievementDefinition-Katalog + AchievementEngine (pure) + Tests
**Kontext:** Erfolge sind heute live abgeleitete Structs in `StatsEngine` (Models/Achievement.swift)
ohne Persistenz. Neues Fundament nach ProgressEngine-Muster: statischer Katalog + pure Engine.
**Dateien:** neu `Models/AchievementDefinition.swift`, neu `Services/AchievementEngine.swift`,
neu `ClimbReflectTests/AchievementEngineTests.swift`
**Aufgabe:**
1. `AchievementDefinition` (struct, statischer Katalog `AchievementDefinition.all`):
   ```swift
   enum AchievementCategory: String, CaseIterable { case anfaenge, konsistenz, schwierigkeit, stil, ausdauer, projekte, momente }
   enum AchievementMaterial: String { case bronze, silber, gold, diamant }
   enum CelebrationLevel { case full, quiet }
   struct AchievementTier { let threshold: Int; let name: String?; let material: AchievementMaterial }
   enum AchievementKind { case once(AchievementMaterial); case tiered([AchievementTier]); case repeatable(AchievementMaterial) }
   struct AchievementDefinition: Identifiable {
       let id: String
       let category: AchievementCategory
       let kind: AchievementKind
       let title: String
       let criterion: String       // Detail-Sheet-Text
       let symbol: String          // SF Symbol
       let isHidden: Bool
       let celebration: CelebrationLevel
   }
   ```
   Katalog exakt nach Konzept Abschnitt 5 (28 Definitionen, Materialien/Feier je Tabelle).
   Grad-Schwellen (`grade_boulder`/`grade_route`) zur Laufzeit über
   `GradeConverter.canonicalIndex(grade:system:)` aus den Referenz-Skalen (Fb bzw. French) ableiten —
   keine hartkodierten Indizes.
2. `AchievementEngine` (enum, rein funktional — kein SwiftData-/UI-Import):
   ```swift
   struct PendingUnlock: Equatable { let definitionID: String; let tier: Int?; let date: Date; let contextValue: String?; let sessionID: UUID? }
   struct ExistingUnlockKey: Hashable { let definitionID: String; let tier: Int?; let contextValue: String?; let sessionID: UUID? }
   struct AchievementProgress { let fraction: Double; let current: Int; let target: Int; let remainingText: String }
   static func evaluate(sessions: [ClimbSession], projects: [Project], existing: Set<ExistingUnlockKey>) -> [PendingUnlock]
   static func progress(for definitionID: String, sessions: [ClimbSession], projects: [Project]) -> AchievementProgress?
   ```
   - Unlock-Datum = Datum der auslösenden Session/Begehung (Backfill historisch korrekt).
   - Idempotenz über `existing` (once → id · tiered → id+tier · repeatable → id+sessionID bzw.
     id+contextValue, z. B. PB-Grad, Projektname, Jahreszahl).
   - `progress` liefert bei tiered den Fortschritt zur **nächsten** Stufe; für hidden und
     repeatable ohne sinnvolle Skala `nil`.
   - Disziplin-Trennung für PB/Meilensteine über `GradeSystem.isBoulder`; Stunden über
     `activeSeconds` nur für `isClimbing`; Höhenmeter = Summe `Ascent.altitudeGain`.
3. Tests je Definition mindestens: gesperrt / knapp davor / Unlock; Stufenübergang; Wiederholbarkeit
   (PB-Sequenz über Font↔V-Mix via canonicalOrder; `climb_days_year` zwei Jahre; `project_persistent`
   zwei Projekte). Doppel-Evaluate erzeugt keine neuen PendingUnlocks.
**Fertig-wenn:** Testsuite grün; Engine kompiliert ohne SwiftUI/SwiftData-Import; alle 28
Definitionen im Katalog mit Symbol + Material.

### EP-2: AchievementUnlock-Modell + Schema V10 (explizit!)
**Kontext:** Unlocks müssen persistiert werden. SEC5-Lektion: Modelle **explizit** in den
ModelContainer aufnehmen — `ClimbReflectApp.init` listet die Model-Typen direkt.
**Dateien:** neu `Models/AchievementUnlock.swift`, `Models/AppMigrationPlan.swift` (V9→V10,
lightweight), `ClimbReflectApp.swift`
**Aufgabe:**
```swift
@Model final class AchievementUnlock {
    @Attribute(.unique) var id: UUID
    var definitionID: String
    var tier: Int?
    var unlockedAt: Date
    var contextValue: String?
    var sessionID: UUID?
    var seenByUser: Bool
    init(...) { ... seenByUser: Bool = false ... }
}
```
`SchemaV10` + `v9ToV10` (lightweight) ergänzen; `AchievementUnlock.self` in **beide**
`ModelContainer(for:)`-Aufrufe in `ClimbReflectApp.init` aufnehmen.
**Fertig-wenn:** App startet mit Bestandsdatenbank fehlerfrei; Unlock lässt sich einfügen, fetchen,
überlebt Neustart.

### EP-3: AchievementService — ein zentraler Trigger
**Kontext:** Ein Aufrufpunkt statt verstreuter Checks; liefert neue Unlocks für die Celebration-Queue.
**Dateien:** neu `Services/AchievementService.swift`, `Services/WatchSessionReceiver.swift`,
`Views/ManualSessionView.swift`, `Views/AddAscentView.swift`, `Views/SessionDetailView.swift`,
`Views/ProjectDetailView.swift`
**Aufgabe:**
1. `@MainActor AchievementService.shared.checkNow(context:) -> [AchievementUnlock]`:
   Sessions + Projekte + Unlocks fetchen, `AchievementEngine.evaluate` ausführen, neue Unlocks mit
   `seenByUser = false` einfügen, speichern, Ergebnis zurückgeben.
2. Aufrufe ergänzen: nach `WatchSessionReceiver.insert` (inkl. Upsert-Pfad), nach manuellem
   Session-Save, nach Ascent-Anlage/-Edit/-Löschung, nach Projekt-Statuswechsel
   (senden/aufgeben in `ProjectDetailView`).
3. Kein Doppel-Unlock bei erneuter Auswertung (Keys aus EP-1).
**Fertig-wenn:** Zweimaliges `checkNow` nacheinander erzeugt keine Duplikate; Watch-Sync einer
Session mit 3 Flashes erzeugt genau einen `flash_day`-Unlock mit korrekter `sessionID`.

### EP-4: Backfill über Bestandsdaten (Endowed Progress, L2)
**Kontext:** Historische Leistungen werden rückwirkend freigeschaltet (Datum = damalige Session),
sonst wirkt das System am Tag 1 leer bzw. feiert Uraltes als neu.
**Dateien:** `Services/AchievementService.swift`, `ClimbReflectApp.swift`
**Aufgabe:** Beim ersten Start nach Update (UserDefaults-Flag `achievementsBackfilledV2`):
`checkNow` laufen lassen, **alle** dabei erzeugten Unlocks sofort `seenByUser = true` setzen
(keine Celebration-Flut), Flag setzen. Debug-only: Konsolen-Preview der Backfill-Unlocks
(Kalibrierungshilfe für Phase 0 Frage 1).
**Fertig-wenn:** Bestandsdatenbank → Erfolge zeigen sofort korrekte historische Unlocks mit
plausiblen Daten; kein Overlay beim ersten Start.

---

## Phase 2 — Erscheinungsbild & der Moment

### EP-5: Design-Bausteine — Theme-Erweiterung, Medaillon, Ringe
**Kontext:** Signatur-Element „Gipfelmarke" (Konzept 6.1–6.3). Referenz-Mockup:
`achievement-mockup.html` (Design-Tokens, Zustände, Choreografie dort 1:1 sichtbar).
**Dateien:** neu `Theme/Theme+Achievements.swift`, neu `Views/Components/AchievementMedallion.swift`
**Aufgabe:**
1. `Theme+Achievements.swift`: Farben bronze/bronzeDeep/silver/silverDeep/diamond/diamondDeep
   (Hex aus Konzept 6.2) + `material(_:) -> AngularGradient` ([deep, hell, deep], metallisch dezent).
2. `AchievementMedallion(definition:state:size:)` mit `state = .locked(progress: Double?)
   / .unlocked(material:)`:
   - Plakette: Kreis `bgElevated`, darüber der **Grat** (dezente diagonale Polyline, ~8 % Weiß,
     `Path` einmalig, skaliert mit `size`).
   - Unlocked: Materialring (`stroke` 2.5 pt AngularGradient) + Symbol in Materialfarbe.
   - Locked: Symbol `textTertiary`; wenn `progress != nil`: Fortschrittsring `Theme.accent` 3 pt
     via `Circle().trim(from: 0, to: progress)` (rotiert −90°), Hintergrund-Ring `surfaceStroke`.
   - Kein Schatten-Gestöber: genau ein weicher Material-Glow (statischer RadialGradient, opacity
     0.25) hinter unlocked-Medaillons ≥ 72 pt (Detail/Overlay), sonst keiner.
3. Preview mit allen 4 Materialien + locked 0 %/60 %/95 %.
**Fertig-wenn:** Previews zeigen alle Zustände pixelstabil in 3 Größen (44/56/96 pt); keine
Layout-Sprünge zwischen den Zuständen (fixe Frames).

### EP-6: Erfolge-Tab Neuaufbau (Sammlung, In Reichweite, Grid, Detail)
**Kontext:** Horizontaler Streifen → vertikale Premium-Sammlung (Konzept 6.4). Alte Ableitungen
bleiben vorerst intakt (Abbau in EP-12).
**Dateien:** `Views/AchievementsView.swift` (Neuaufbau), neu `Views/Components/AchievementTile.swift`,
neu `Views/Components/NextAchievementsCard.swift`, neu `Views/AchievementDetailSheet.swift`
**Aufgabe:**
1. Datenfluss: `@Query` auf `AchievementUnlock` + Sessions/Projekte; ViewData pro Definition
   (unlocked?, Material/Stufe, Datum, Count, Progress) einmal pro Render berechnen.
2. Aufbau: Header „Sammlung `X von 28`" (Rounded-Zahl) + dünner Gesamtbalken → „In Reichweite"
   (max. 3 gesperrte, Fortschritt ≥ 0.5, absteigend; ausblenden wenn leer) → Kategorie-Chips
   (Filter, horizontal) → `LazyVGrid` 2 Spalten mit `AchievementTile`.
3. `AchievementTile`: bestehender `card()`-Stil, Medaillon 56 pt, Titel 2-zeilig, Statuszeile
   (unlocked: Datum bzw. „×N" · tiered: Stufenpunkte, gefüllt in Materialfarbe · locked: Rest-Text
   aus `AchievementEngine.progress`). Hidden + locked: „???" + „Geheimer Erfolg". **Kein**
   Deckkraft-Schleier über gesperrten Karten.
4. `AchievementDetailSheet` (`presentationDetents([.medium, .large])`): Medaillon 96 pt mit Aura,
   Material-Chip, Kriterium, Fortschritt + Rest-Text, Unlock-Datum; bei repeatable Ereignis-Timeline
   (Datum + contextValue, chronologisch — PB-Historie!). Hidden + locked: nur Geheim-Hinweis.
5. Beta-Bibliothek-Link bleibt unten erhalten.
**Fertig-wenn:** Alle 28 Definitionen sichtbar und filterbar; Fortschritt live korrekt; PB-Historie
zeigt Backfill-Ereignisse chronologisch; Scroll flüssig (LazyVGrid, keine per-Zellen-Engine-Läufe).

### EP-7: Unlock-Overlay — Choreografie, Partikel, Haptik
**Kontext:** Der Kern des Konzepts (Abschnitt 7 + 8). Vollbild-Moment für `.full`-Unlocks.
**Dateien:** neu `Views/Components/AchievementUnlockOverlay.swift`,
neu `Views/Components/ParticleBurstView.swift`, `Views/DashboardView.swift` (oberste ZStack-Ebene)
**Aufgabe:**
1. Queue: DashboardView beobachtet ungesehene `.full`-Unlocks (`seenByUser == false`); Overlay als
   oberste Ebene über der TabView (kein Layout-Shift). Pager „1 von N", „Weiter" setzt
   `seenByUser = true`; letzter → Overlay schließt.
2. Choreografie exakt nach Konzept-Tabelle (Zeiten/Kurven), Skizze:
   ```swift
   // Nur transform + opacity. Kein animierter Blur, kein Layout.
   @State private var appear = false
   ZStack {
       Color.black.opacity(appear ? 0.55 : 0).ignoresSafeArea()          // Backdrop
       RadialGlow(material: material)                                     // vorgebauter Gradient
           .opacity(appear ? 0.35 : 0).scaleEffect(appear ? 1.15 : 0.8)
       ParticleBurstView(material: material, fire: appear)                // 24 Partikel, 1×
       AchievementMedallion(...)                                          // Ring-trim animiert intern
           .scaleEffect(appear ? 1 : 0.6).opacity(appear ? 1 : 0)
           .animation(.spring(response: 0.45, dampingFraction: 0.7), value: appear)
       VStack { Text(title).font(.system(.title2, design: .rounded).bold()); Text(subtitle) }
           .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 8)
           .animation(.easeOut(duration: 0.3).delay(0.35), value: appear)
   }
   .onAppear { haptic.prepare(); appear = true; haptic.notificationOccurred(.success) }
   ```
3. `ParticleBurstView`: `Canvas` in `TimelineView(.animation)`; beim Feuern 24 Bahnen vorberechnen
   (Winkel, Tempo, Spin, Lebensdauer 0.9–1.2 s); zeichnen nur via `context.translateBy/scaleBy` +
   `opacity`; nach 1.4 s State auf idle → TimelineView per `if` entfernen (kein Dauer-Ticker, S3/S19).
   Optional `.drawingGroup()` auf der Effektebene, falls Instruments Hitches zeigt.
4. Grat-Glanz: schmale weiße Gradient-Bahn, −45° rotiert, per `offset` einmal über die Plakette
   (300 ms, delay 0.3), danach opacity 0.
5. Reduziert (Effekte-Toggle aus ODER `accessibilityReduceMotion`): reiner Crossfade
   (Backdrop+Medaillon opacity), keine Partikel/kein Glanz/keine Skalierung; Haptik bleibt.
6. Sound: nur wenn `achievementSoundEnabled` && Asset vorhanden (Phase-0-Frage 3), kurzer Tick beim
   Medaillon-Apex.
**Fertig-wenn:** Session mit neuem `.full`-Unlock syncen → Overlay erscheint genau einmal, nie
wieder für diesen Unlock; Instruments: 0 Hitches während der Choreografie auf dem Zielgerät;
Reduce-Motion-Variante verifiziert.

### EP-8: Quiet-Unlock-Toast
**Kontext:** `.quiet`-Erfolge (flash_day, big_day) feiern leise (L7) — kein Vollbild.
**Dateien:** neu `Views/Components/AchievementToast.swift`, `Views/DashboardView.swift`
**Aufgabe:** Kapsel oben (Mini-Medaillon 28 pt + Titel), slide-in per offset/opacity (Spring),
2.5 s sichtbar, `UIImpactFeedbackGenerator(.light)`, markiert `seenByUser = true` beim Ausblenden.
Mehrere quiet-Unlocks nacheinander (Queue), nie gleichzeitig mit dem Vollbild-Overlay (Overlay hat
Vorrang, Toast danach). Respektiert Effekte-Toggle/ReduceMotion (dann statisches Ein-/Ausblenden).
**Fertig-wenn:** `flash_day`-Unlock → Toast einmalig, kein Overlay; parallel eingehender
`.full`-Unlock verdrängt den Toast nicht dauerhaft (Reihenfolge Overlay → Toast).

### EP-9: Einstellungen → Animationen
**Kontext:** Konzept Abschnitt 9; vollständige Deaktivierbarkeit ist Teil der Performance-Zusage.
**Dateien:** `Views/SettingsView.swift`
**Aufgabe:** Neue Section „Animationen" (zwischen „Grad-Skala" und „Daten"):
Toggle „Achievement-Effekte" (`achievementEffectsEnabled`, default an), Toggle „Sound bei Erfolgen"
(`achievementSoundEnabled`, default aus; disabled + Hinweis, solange kein Asset — Phase-0-Frage 3),
Footer-Text aus dem Konzept. Bestehende Optik der Sections (listRowBackground `Theme.surface`).
**Fertig-wenn:** Toggles persistieren; Overlay/Toast reagieren sofort (reduzierte Variante) ohne
App-Neustart.

### EP-10: Integration Today + Session-Detail
**Kontext:** Goal-Gradient auf dem Homescreen; Sessions erzählen ihre Unlocks (Konzept 10).
**Dateien:** `Views/TodayView.swift`, `Views/SessionDetailView.swift`,
`Views/Components/NextAchievementsCard.swift` (Wiederverwendung)
**Aufgabe:** TodayView: kompakte „Nächster Erfolg"-Karte (höchster Fortschritt < 100 %, Mini-Ring +
Rest-Text) unter der Stat-Row; Tap → Erfolge-Tab (TabView-Selection via `@AppStorage` oder Binding
hochziehen — kleinste saubere Lösung wählen). SessionDetail: Zeile „In dieser Session
freigeschaltet" mit Mini-Medaillons (Unlocks mit passender `sessionID`), nur wenn vorhanden.
**Fertig-wenn:** Session mit Unlock → Badge-Zeile im Detail; Today zeigt sinnvollen nächsten Erfolg
und verschwindet bei 28/28.

### EP-11: Benachrichtigung bei Hintergrund-Unlock
**Kontext:** Watch-DTO kann im Hintergrund ankommen — der Moment darf nicht verpuffen (Konzept 10).
**Dateien:** `Services/NotificationService.swift`, `Services/AchievementService.swift`
**Aufgabe:** `NotificationService.notifyUnlock(title:subtitle:)` („Erfolg freigeschaltet" + Titel +
contextValue); `AchievementService` ruft sie nur bei `UIApplication.shared.applicationState != .active`
und nur für `.full`-Unlocks; respektiert `isEnabled`. Im Vordergrund ausschließlich Overlay.
**Fertig-wenn:** Sync im Hintergrund mit neuem Unlock → genau eine lokale Notification; im
Vordergrund keine.

### EP-12: Alt-Code-Abbau + Tests migrieren + Doku
**Kontext:** Engine ist jetzt die einzige Quelle; W8 abbauen.
**Dateien:** `Models/Achievement.swift`, `Views/Components/AchievementCard.swift` (**löschen — tot**),
`ClimbReflectTests/StatsEngineTests.swift`, `CLAUDE.md`,
`ERFOLGE-KONZEPT.md` + `TODO11-ERFOLGE.md` (löschen oder nach `docs/archive/` verschieben)
**Aufgabe:** `StatsEngine.achievements`/`climbAchievements` + `Achievement`-/`ClimbAchievement`-Structs
entfernen (weekStreak/insights/sessionTimeline bleiben!); betroffene Alt-Tests entfernen, Streak-Tests
behalten; `AchievementCard.swift` löschen; CLAUDE.md: neuen Grundsatz **S33** ergänzen („Erfolge sind
persistierte Ereignisse aus der AchievementEngine; Feiern nur transform/opacity, abschaltbar,
ReduceMotion respektiert; keine wöchentlich wiederkehrenden Erfolge") + Projektstruktur-Absatz
aktualisieren; V1-Dokumente archivieren.
**Fertig-wenn:** Suite grün; `grep -r "climbAchievements"` leer; App baut ohne Warnungen zu toten
Symbolen.

---

## Phase 3 — Langfristig (nur nach Freigabe)

### EP-L1: ⚠️ ABSTIMMEN → Watch-Rückkanal für Unlocks
Unlocks der beendeten Session in der Watch-Summary (iPhone → Ack via `transferUserInfo`). Berührt
den heiligen End-Flow (S4/S21) → nicht ohne Rücksprache.

### EP-L2: Jahresrückblick (nutzt Unlock-Historie + ProgressEngine)
### EP-L3: Widget „Nächster Erfolg" (App Group + Snapshot, kein SwiftData im Widget-Prozess)
### EP-L4: Share-Card (`ImageRenderer` über eine Share-View, ShareLink im Detail-Sheet)
### EP-L5: Multipitch-Erfolge — **erst** wenn `Ascent` ein Seillängen-Feld bekommt (S6: keine erfundenen Daten)
