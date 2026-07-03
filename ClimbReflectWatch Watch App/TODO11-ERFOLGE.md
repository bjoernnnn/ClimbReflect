# TODO11 – Erfolgssystem-Neuaufbau (Konzept: ERFOLGE-KONZEPT.md)

Basis: `dev` @ e5f6e02. Ein Task = ein Commit.
**Abhängigkeiten aus TODO10:** ER-2/ER-3 sauber erst nach RP-7 (ladderIndex,
für C1–C4) und RP-12 (Projekt-Relation, für E1). RP-5 (`isGraded`) wird von
C1–C4 vorausgesetzt. Reihenfolge: TODO10-Block-B vorziehen oder ER-3 die
betroffenen Definitionen (C*, E1) zunächst deaktiviert lassen.

---

## Phase 1 — Fundament

### ER-1: AchievementDefinition-Katalog + Engine-Gerüst (rein, testbar)
**Kontext:** Erfolge sind heute live abgeleitete Structs in `StatsEngine`
ohne Persistenz. Neues System: statischer Katalog + pure Engine.
**Dateien:** neu `Models/AchievementDefinition.swift`,
neu `Services/AchievementEngine.swift`, `ClimbReflectTests/AchievementEngineTests.swift`
**Aufgabe:**
1. `AchievementDefinition`: `id`, `category` (Enum A–G), `kind`
   (`.once`/`.tiered([Threshold])`/`.repeatable`), `title`, `criterionText`,
   `symbol`, `color`, disziplin-Variante wo nötig (C1–C4 je `boulder`/`route`).
   Katalog exakt nach Konzept-Tabelle (23 Definitionen).
2. `AchievementEngine.evaluate(sessions:existingUnlocks:) -> [PendingUnlock]`
   — implementiert zunächst Kategorien A, B, D1, F, G (keine RP-7-Abhängigkeit).
   `PendingUnlock`: definitionID, tier, date (aus auslösender Session),
   contextValue, sessionID.
3. `AchievementEngine.progress(for:definitionID:sessions:) -> (Double, String)`
   (Anteil + Rest-Text, z. B. „Noch 2 Sessions").
4. Unit-Tests pro implementierter Definition: gesperrt/knapp davor/Unlock,
   Stufenübergang, Wiederholbarkeit (B2 zweimal).
**Fertig-wenn:** Testsuite grün; Engine hat keinerlei UI-/SwiftData-Import
(nur Wert-Typen rein/raus).

### ER-2: AchievementUnlock-Modell + expliziter Schema-Eintrag
**Kontext:** Unlocks müssen persistiert werden (Datum, Stufe, Kontext).
SEC5-Lektion: Modelle explizit in den ModelContainer-Schema aufnehmen.
**Dateien:** neu `Models/AchievementUnlock.swift`, `ClimbReflectApp.swift`
(Schema), `Models/AppMigrationPlan.swift` (additiv, lightweight)
**Aufgabe:** `@Model AchievementUnlock`: `@Attribute(.unique) id: UUID`,
`definitionID: String`, `tier: Int?`, `unlockedAt: Date`,
`contextValue: String?`, `sessionID: UUID?`, `seenByUser: Bool = false`
(steuert Celebration-Queue). Schema + Migrationsplan ergänzen.
**Fertig-wenn:** App startet mit bestehender Datenbank fehlerfrei; Unlock
lässt sich einfügen, fetchen, überlebt Neustart.

### ER-3: AchievementService – zentraler Auswertungs-Trigger
**Kontext:** Ein Aufrufpunkt statt verstreuter Checks.
**Dateien:** neu `Services/AchievementService.swift`,
`Services/WatchSessionReceiver.swift`, `Views/ManualSessionView.swift`,
`Views/AddAscentView.swift`, `Views/SessionDetailView.swift` (Ascent-Edits)
**Aufgabe:**
1. `AchievementService.checkNow(context:)`: Sessions + Unlocks fetchen,
   Engine ausführen, neue Unlocks einfügen (`seenByUser = false`), speichern;
   Rückgabe `[AchievementUnlock]` für UI/Notification.
2. Aufrufe: nach `WatchSessionReceiver.insert` (inkl. Upsert-Pfad), nach
   manuellem Session-Save, nach Ascent-Anlage/-Edit.
3. Idempotenz: `.once`/`.tiered` prüfen gegen vorhandene definitionID+tier;
   `.repeatable` gegen (definitionID, sessionID bzw. contextValue) — kein
   Doppel-Unlock bei erneuter Auswertung.
**Fertig-wenn:** Zweimaliges `checkNow` hintereinander erzeugt keine
Duplikate; Watch-Sync einer Session mit 3 Flashes erzeugt genau einen
D1-Unlock mit korrekter sessionID.

### ER-4: Backfill-Migration über Bestandsdaten
**Kontext:** Historische Leistungen sollen mit echten Daten rückwirkend
freigeschaltet werden (Unlock-Datum = damaliges Session-Datum), sonst wirkt
das System am Tag 1 leer bzw. feiert Uraltes als neu.
**Dateien:** `Services/AchievementService.swift` (einmaliger Backfill),
`ClimbReflectApp.swift` (Aufruf, UserDefaults-Flag `achievementsBackfilledV1`)
**Aufgabe:** Beim ersten Start nach Update: Engine chronologisch über alle
Sessions laufen lassen, alle Unlocks mit `seenByUser = true` einfügen (keine
Celebration-Flut), Flag setzen.
**Fertig-wenn:** Bestandsdatenbank → Erfolge-Tab zeigt sofort korrekte
historische Unlocks mit plausiblen Daten; kein Celebration-Overlay beim
ersten Start.

---

## Phase 2 — Sichtbarkeit

### ER-5: Unlock-Celebration-Overlay + Haptik
**Kontext:** Kern des Konzepts — der Unlock-Moment (4.1).
**Dateien:** neu `Views/Components/AchievementUnlockOverlay.swift`,
Einbindung in Root (`ClimbReflectApp`/TabView-Container)
**Aufgabe:**
1. Beobachtet ungesehene Unlocks (`seenByUser == false`); zeigt bei
   App-Vordergrund Vollbild-Overlay: Icon-Spring-Einblendung,
   Kategorie-Farbe, Titel, contextValue-Untertitel, dezenter Gold-Partikel-
   Effekt (Canvas/TimelineView, kein Package), `UINotificationFeedbackGenerator
   (.success)`.
2. Mehrere Unlocks: Paging „1 von N"; „Weiter" markiert `seenByUser = true`.
**Fertig-wenn:** Session mit neuem Unlock syncen → Overlay erscheint genau
einmal, danach nie wieder für diesen Unlock.

### ER-6: Erfolge-Tab Neuaufbau (Katalog + Fortschritt)
**Kontext:** Horizontaler Streifen → vertikales, kategorisiertes Grid mit
Fortschrittsringen (Konzept 4.2 Punkt 3+4).
**Dateien:** `Views/AchievementsView.swift`,
neu `Views/Components/AchievementTile.swift`, `Views/Components/AchievementCard.swift`
(**löschen — tot**)
**Aufgabe:**
1. Sektionen A–G; Tile: freigeschaltet = farbig + Datum + „×N"/Stufenpunkte;
   gesperrt = Fortschrittsring (Engine.progress) + Prozent.
2. Detail-Sheet: Kriteriumstext, Fortschritt + Rest-Text, bei `.repeatable`
   Ereignis-Historie (Datum + contextValue) als Timeline-Liste.
3. Alte `StatsEngine.achievements`/`climbAchievements`-Ableitung aus der View
   entfernen (Engine ist Quelle); StatsEngine-Funktionen erst löschen, wenn
   Tests migriert sind (→ ER-10).
**Fertig-wenn:** Alle 23 Definitionen sichtbar, Fortschritt live korrekt,
PB-Historie (C1) zeigt alle Backfill-Ereignisse chronologisch.

### ER-7: „In Reichweite" + Bestmarken-Board
**Kontext:** Motivations-Hebel Nähe + „Leistung sehen" als Fakten (4.2 Punkt 1+2).
**Dateien:** `Views/AchievementsView.swift`, neu
`Views/Components/NextAchievementsCard.swift`, `Views/Components/PersonalBestsBoard.swift`
**Aufgabe:**
1. Bestmarken-Board oben: PB Boulder, PB Seil, bester Flash, längster Streak,
   gesendete Projekte — Werte aus Unlock-Historie bzw. Engine, jeweils mit Datum.
2. „In Reichweite": 3 gesperrte Definitionen mit höchstem Fortschritt ≥ 40 %,
   Karte mit Ring + Rest-Text.
**Fertig-wenn:** Board zeigt korrekte Bestwerte mit Datum; Reichweite-Karten
aktualisieren sich nach neuem Datenstand.

### ER-8: Integration Today / SessionDetail / WeeklyRecap
**Dateien:** `Views/TodayView.swift`, `Views/SessionDetailView.swift`,
`Views/WeeklyRecapView.swift`
**Aufgabe:** TodayView: „Nächster Erfolg"-Karte (höchster Fortschritt) mit
Mini-Ring → Link auf Erfolge-Tab. SessionDetail: Badge-Zeile „In dieser
Session freigeschaltet" (Unlocks mit passender `sessionID`). WeeklyRecap:
Zähler Unlocks der Woche.
**Fertig-wenn:** Session mit Unlock → Badge in der Detailansicht; Today zeigt
sinnvollen nächsten Erfolg.

### ER-9: Benachrichtigung bei Hintergrund-Unlock
**Kontext:** Watch-DTO kann ankommen, während die App im Hintergrund ist —
der Unlock-Moment darf nicht verpuffen.
**Dateien:** `Services/AchievementService.swift`, `Services/NotificationService.swift`
**Aufgabe:** `NotificationService.notifyUnlock(_:)` (Titel „🏆 Erfolg
freigeschaltet", Body Titel + contextValue); AchievementService ruft sie nur,
wenn App nicht aktiv (`UIApplication.shared.applicationState`). Respektiert
bestehendes `isEnabled`-Flag.
**Fertig-wenn:** Sync im Hintergrund mit neuem Unlock → lokale Notification;
im Vordergrund → nur Overlay, keine Notification.

### ER-10: Grad-/Projekt-Erfolge aktivieren + Tests migrieren
**Kontext:** C1–C4 (ladderIndex, RP-7), E1–E3 (Relation, RP-12), `isGraded`
(RP-5) — nach deren Umsetzung.
**Dateien:** `Services/AchievementEngine.swift`, `AchievementEngineTests.swift`,
`Models/Achievement.swift` (alte Ableitungen entfernen),
`ClimbReflectTests/StatsEngineTests.swift`
**Aufgabe:** Kategorien C und E in der Engine implementieren (disziplin-
getrennt, nur `isGraded`); alte `achievements`/`climbAchievements` aus
StatsEngine löschen; zugehörige Alt-Tests entfernen (Überschneidung mit RP-11
beachten — wer zuerst kommt, räumt auf); neue Tests: C1-PB-Sequenz über
Font↔V-Mix, C2-Sprung, E1 über Relation ohne projectName.
**Fertig-wenn:** Suite grün; PB-Unlock feuert korrekt bei V-Scale-gespeichertem
Ascent über Font-PB hinweg.

---

## Phase 3 — Langfristig (nur nach Freigabe)

### ER-L1: ⚠️ ABSTIMMEN → Watch-Rückkanal für Unlocks
Unlocks der beendeten Session in der Watch-Summary anzeigen (iPhone sendet
nach `insert` ein `sendMessage`/`transferUserInfo`-Ack mit Unlock-Titeln;
Summary wartet best-effort 2 s). Berührt Watch-Oberfläche und Timing des
End-Flows → nicht ohne Rücksprache.

### ER-L2: Jahresrückblick
Generierte Jahresseite (Tops, PB-Timeline, Streak-Rekord, Erfolge des Jahres)
— eigener Screen, Einstieg über Erfolge-Tab im Dezember/Januar.

### ER-L3: Widget „Nächster Erfolg"
WidgetKit-Extension, Ring + Titel; Datenzugriff über App Group + leichten
Snapshot (nicht SwiftData im Widget-Prozess).

### ER-L4: Share-Card
Erfolg als Bild exportieren (`ImageRenderer` über eine Share-View), ShareLink
im Detail-Sheet.

---

## ⚠️ ABSTIMMEN (vor Phase 1)

1. **Widerrufs-Politik:** Unlock bleibt bei Datenlöschung bestehen (Empfehlung)
   oder Re-Evaluation?
2. **Schwellen-Kalibrierung** Kategorie A/B (Konzept-Tabelle) — passen die
   Zahlen zu deinem Volumen?
3. **Zeitfenster** B3/G2: Kalendermonat/-jahr vs. rollierend.
4. **Reihenfolge:** TODO10 Block B (RP-5/7/12) vor ER-10 — oder ER-Phase 1+2
   parallel mit deaktivierten C/E-Definitionen starten?
