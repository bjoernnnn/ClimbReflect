# TODO15 – Feedback-Runde (Live-Anzeige, Grad, Sync, Diagnose) + CloudKit

**Branch:** `dev` · **Stand-Basis:** `8f9839c` (lokal = remote verifiziert)
**Format:** eine Aufgabe = ein Commit, App muss nach jedem Commit kompilieren.
**Referenzen:** CLAUDE.md – S16, **S26** (Live Activity), S28, **S34** (Erfolge-Widerrufs-Politik),
FB-2 (Grad-Vorbelegung), SH-14/SH-15/W-1 (Watch-Sync-Cache).

> **Kurzer Rahmen zur Analyse:** Ich habe alle Punkte im Code gegengeprüft. Zwei Punkte sind
> **keine simplen Bugs**, sondern kollidieren mit bestehenden Grundsätzen und brauchen deine
> Entscheidung, bevor umgesetzt wird: **ER-1** (Erfolg bleibt nach Löschen = S34-Design) und
> **CK-1** (CloudKit = Schema-Migration). Beide sind unten als **⚠️ ABSTIMMEN** markiert. Der Rest
> ist direkt umsetzbar.

---

## Reihenfolge / Blöcke

- **A – Sofort-Fixes:** LA-1, CH-1, ER-2 (klein, risikoarm)
- **B – Live-Steuerung:** LA-2 (Banner-Buttons), LA-3 (Sperrbildschirm) ⚠️ teils ABSTIMMEN
- **C – Grad:** GR-1 (Vorbelegung), GR-2 (Korrigierbarkeit), GR-3 (iPhone-Default)
- **D – Watch-Sync:** PS-1 (gelöschte Projekte)
- **E – Diagnose:** DG-1
- **F – ABSTIMMEN:** ER-1 (Erfolge löschen), CK-1 (CloudKit)

Neue Task-Präfixe (kollidieren nicht mit bestehenden): **LA-** Live Activity, **CH-** Chart,
**ER-** Erfolge, **GR-** Grad, **PS-** Projekt-Sync, **DG-** Diagnose, **CK-** CloudKit.

---

## A – Sofort-Fixes

### LA-1 · In-App-Live-Banner entschlacken

**Kontext**
Screenshot zeigt den In-App-Banner (nicht die Live Activity). Aktuell steht dort
„**Vorstieg** auf der Watch" plus HF (79 bpm) und kcal. Gewünscht: nur die Trainingsart, keine
HF/kcal. Das ist der `LiveSessionBanner`, **nicht** das Widget.

**Dateien**
`ClimbReflect/ClimbReflect/ClimbReflect/Views/Components/LiveSessionBanner.swift`

**Aufgabe**
1. Label von `"\(sessionLabel) auf der Watch"` → nur `sessionLabel` (z. B. „Vorstieg").
2. Den `HStack` mit HF-`Label` (`heart.fill`) und kcal-`Label` (`flame.fill`) **entfernen**.
   `status.heartRate` / `status.activeEnergyKcal` werden im Banner nicht mehr gelesen.
3. Icon-Logik unverändert (Watch/Pause). Layout kompakt halten (Titel + Zeit + Buttons).

**Fertig-wenn**
Banner zeigt nur „Vorstieg" (bzw. Bouldern/Toprope/…) + Zeit + Pause/Beenden. Keine HF, kein kcal.

---

### CH-1 · „Versuche pro Session"-Chart: X-Achse lesbar

**Kontext**
Screenshot „Rote Linie": Die X-Achsen-Labels überlappen zu einer unleserlichen Schrift. Ursache
gefunden: `AxisMarks(values: .stride(by: .day))` erzeugt für **jeden Tag** über die gesamte
Projekt-Zeitspanne (im Screenshot ~Aug→Jul) ein Label → hunderte übereinander.

**Dateien**
`ClimbReflect/ClimbReflect/ClimbReflect/Views/ProjectDetailView.swift` (Block `progressChart`, ~Z.211)

**Aufgabe**
1. `.stride(by: .day)` durch eine **adaptive** Achse ersetzen — nur wenige, gut verteilte Marken:
   ```swift
   .chartXAxis {
       AxisMarks(values: .automatic(desiredCount: 4)) { value in
           AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.3))
           AxisValueLabel(format: .dateTime.day().month(.twoDigits))
               .foregroundStyle(Theme.textTertiary)
       }
   }
   ```
2. Zusätzlich robust gegen sehr kurze/sehr lange Zeiträume: `desiredCount` fest auf 4–5 lassen
   (Charts verteilt selbst sinnvoll). **Kein** manuelles `.stride`.
3. Die Balken bleiben `unit: .day`. Wenn die Zeitspanne groß und die Sessions vereinzelt sind
   (wie im Screenshot), ist das ok – nur die **Labels** dürfen nicht mehr pro Tag stehen.

**Fertig-wenn**
Bei einem Projekt über mehrere Monate sind nur ~4 lesbare Datums-Labels sichtbar, keine
Überlappung. Kurze Projekte (wenige Tage) zeigen weiterhin sinnvolle Marken.

---

### ER-2 · Medallion ragt in den Titel (Detail-Sheet)

**Kontext**
Screenshot „Erfolge"-Detail: Der große Ring/die Aura des Medallions überlagert die Überschrift
„Neue Bestmarke". Ursache: Im Detail-Sheet wird das Medallion mit `size: 96` gezeigt; ab `size ≥ 72`
rendert `AchievementMedallion` einen **Glow mit Frame `size * 1.7` (≈ 163 pt)**, der über den
96-pt-Layout-Footprint **hinausragt**. Der `VStack(spacing: 18)` platziert den Titel aber nur 18 pt
darunter → Aura/Ring bluten in den Text.

**Dateien**
`ClimbReflect/ClimbReflect/ClimbReflect/Views/AchievementDetailSheet.swift` (Block `medallionWithAura`, ~Z.53)
ggf. `…/Views/Components/AchievementMedallion.swift`

**Aufgabe**
1. Für die Aura im Layout **Platz reservieren**, statt sie überlaufen zu lassen. Konkret in
   `medallionWithAura` einen festen Rahmen setzen, der die Aura einschließt, z. B.:
   ```swift
   private var medallionWithAura: some View {
       AchievementMedallion(symbol: isSecret ? "questionmark" : data.definition.symbol,
                            state: medallionState, size: 96)
           .frame(width: 96 * 1.7, height: 96 * 1.7)   // Aura-Footprint reservieren
           .padding(.bottom, 4)
   }
   ```
   (Damit „schiebt" die Aura den Titel nicht mehr; sie liegt in ihrem eigenen Kasten.)
2. **Alternative/zusätzlich**, falls die Aura optisch zu groß wirkt: in `AchievementMedallion`
   den Glow-`endRadius` reduzieren (`size * 0.6` statt `0.75`) und/oder Glow-Frame auf `size * 1.4`.
   Nur EINE der beiden Stellen ändern, nicht doppelt kompensieren.
3. Danach visuell prüfen: In Detail-Sheet **und** Unlock-Overlay (nutzt große Medallions) darf der
   Ring den Text nicht mehr berühren. Tiles (size 56) und Today-Karte (size 44) haben **keinen**
   Glow (`size ≥ 72`-Gate) → dort ist nichts zu tun, aber gegenprüfen, dass sie unverändert aussehen.

**Fertig-wenn**
Bronze/Silber/Gold/Diamant-Detail zeigt Ring + Aura klar **über** dem Titel, ohne Überlappung.

---

## B – Live-Steuerung

### LA-2 · Banner-Buttons (Pause/Beenden) zuverlässig machen

**Kontext**
Der iPhone-Banner sendet `["watchCommand": "pause"/"resume"/"end"]`. Die Watch empfängt das in
`SyncService` und ruft `onCommand?(…)`. **Aber**: `onCommand` wird nur in
`LiveSessionView.onAppear` gesetzt — also nur, wenn genau diese View gerade erschienen ist. Zeigt
die Uhr eine andere View (End-Flow, Auswahl) oder wurde die Closure überschrieben, verpufft der
Befehl. Zusätzlich ist `sendMessage` nur bei **erreichbarer** Uhr live; sonst greift
`transferUserInfo` (verzögert) → wirkt wie „geht nicht".

**Dateien**
`ClimbReflectWatch Watch App/ClimbReflectWatchApp.swift` (oder `WorkoutManager.init`)
`ClimbReflectWatch Watch App/Views/LiveSessionView.swift` (Wiring entfernen)
`ClimbReflectWatch Watch App/Services/SyncService.swift` (Diagnose-Log)
`ClimbReflect/ClimbReflect/ClimbReflect/Views/Components/LiveSessionBanner.swift` (Feedback)

**Aufgabe**
1. `onCommand`-Wiring **zentral** einmalig registrieren, nicht in einer View. `WorkoutManager` ist
   ein Singleton (`WorkoutManager.shared`) → z. B. am Ende von `WorkoutManager.init()` oder in
   `ClimbReflectWatchApp.init`:
   ```swift
   SyncService.shared.onCommand = { cmd in
       Task { @MainActor in
           DiagnosticLog.shared.log("cmd empfangen: \(cmd) (isRunning=\(WorkoutManager.shared.isRunning))")
           switch cmd {
           case "pause":  WorkoutManager.shared.pauseWorkout()
           case "resume": WorkoutManager.shared.resumeWorkout()
           case "end":    _ = await WorkoutManager.shared.endWorkout()
           default: break
           }
       }
   }
   ```
   Das alte `onCommand`-Setzen in `LiveSessionView.onAppear` **entfernen** (Doppelregistrierung
   vermeiden).
2. In `SyncService` beim Empfang (beide Pfade: `didReceiveMessage` **und** `didReceiveUserInfo`)
   ein Diagnose-Log schreiben (`sync: cmd '<x>' via message/userInfo`). So ist im Fehlerfall
   nachvollziehbar, ob der Befehl ankam.
3. Guards prüfen: `pauseWorkout`/`resumeWorkout`/`endWorkout` müssen bei „falschem" State sauber
   nichts tun (z. B. `end` wenn schon beendet → S4 idempotent). Kein Ghost-Befehl.
4. iPhone-Feedback: Wenn `!reachable` (nur `transferUserInfo`), im Banner kurz signalisieren, dass
   der Befehl **gepuffert** ist (z. B. Button kurz deaktivieren + Spinner, oder kleiner Hinweis
   „wird an die Uhr gesendet…"), damit ein verzögerter Befehl nicht wie „kaputt" wirkt. Ehrliches
   Feedback statt stiller Nicht-Reaktion (Grundsatz 6).

**Hinweis (ehrliche Grenze):** Fernsteuerung iPhone→Watch ist bei **nicht erreichbarer** Uhr
(Display aus) systembedingt nicht Echtzeit. Ziel ist maximale Zuverlässigkeit + sichtbares
Feedback, nicht 0-ms-Latenz.

**Fertig-wenn**
Pause/Resume/Beenden vom Banner wirken zuverlässig, solange die Uhr erreichbar ist; bei nicht
erreichbarer Uhr gibt der Banner sichtbares Feedback; Diagnose-Log zeigt empfangene Befehle.

---

### LA-3 · Sperrbildschirm-Live-Activity ⚠️ ABSTIMMEN (Grenzen S26)

**Kontext**
Der Sperrbildschirm-Inhalt existiert bereits (`LockScreenView` im Widget) und zeigt **korrekt** nur
**Trainingsart + Zeit** (kein HF/kcal) – inhaltlich schon so, wie du es willst. Das eigentliche
Problem ist, dass die Live Activity **oft gar nicht erscheint**. Grund ist **S26**:
`Activity.request()` läuft nur im **Vordergrund**. Startet die Session auf der Uhr, wacht das iPhone
nur im Hintergrund auf → Start schlägt still fehl. Es gibt bereits `retryIfNeeded()` bei
`scenePhase == .active`. Heißt praktisch: **Die Live Activity erscheint erst, wenn die iPhone-App
einmal in den Vordergrund kommt.** Bleibt das iPhone gesperrt, erscheint sie nie.

Ein zuverlässiger Hintergrund-Start ginge nur über **Push-to-Start (APNs)** → braucht Server.
Das widerspricht der Local-first-Architektur (Supabase bewusst verworfen).

**⚠️ ABSTIMMUNG nötig — bitte wählen:**

- **Option A (empfohlen, ohne Server):** Grenze akzeptieren + transparent machen. Beim
  Session-Start (Watch) das iPhone so früh wie möglich zum Vordergrund-Retry bringen; zusätzlich im
  iPhone-Banner einen dezenten Hinweis „Sperrbildschirm-Anzeige aktiv, sobald die App einmal offen
  war". Kein neuer Serverbedarf. **Interaktive Buttons (Pause/Beenden) auf dem Sperrbildschirm:
  vorerst nicht**, weil App-Intents im Widget-Prozess kein zuverlässiges `WCSession` zur Uhr haben
  (hohe Komplexität, fragile Zuverlässigkeit). Sperrbildschirm bleibt Anzeige (Typ + Zeit +
  Pausiert-Status), Steuerung über den In-App-Banner (LA-2).

- **Option B (mit Server):** Push-to-Start via APNs einführen → Live Activity erscheint zuverlässig
  auch bei gesperrtem iPhone, inkl. späterer interaktiver Buttons. **Bricht Local-first** und ist
  ein eigenes, größeres Projekt.

**Wenn Option A:** (Aufgabe erst nach deiner Zusage)
1. `LockScreenView` unverändert lassen (Typ + Zeit passt bereits). Optional Feinschliff, damit es
   näher an Apples Workout-Look kommt (linksbündig Icon + Titel, rechts große monospaced Zeit).
2. `retryIfNeeded()` zusätzlich an einen frühen App-Trigger hängen (z. B. beim Empfang des
   Watch-Live-Status im Hintergrund `lastStatus` puffern – ist schon so – und beim ersten
   Vordergrund sofort starten; ist vorhanden). Prüfen, dass `endActivity()` sauber aufräumt.
3. Dezenter Hinweis im Banner (s. o.).

**Fertig-wenn (Option A)**
Sobald die iPhone-App einmal im Vordergrund war, erscheint eine saubere Sperrbildschirm-Anzeige
mit Trainingsart + Zeit; der Start-Mechanismus und seine Grenze sind dokumentiert.

---

## C – Grad

### GR-1 · Projekt-Grad zuverlässig vorbelegen (statt 7a)

**Kontext**
„Beim Klassifizieren steht immer 7a, egal ob mein Projekt 6a ist." Ursache gefunden:
- Die Watch belegt den Grad über **FB-2** aus `workoutManager.selectedProject?.grade` vor. Fehlt
  der, greift der Fallback `gradeIndex = gradeSystem.grades.count / 2`. Bei der **French-Leiter**
  (18 Einträge) ist Index 9 = **„7a"**. → Das ist die „immer 7a"-Quelle.
- `selectedProject?.grade` kommt vom iPhone-Push und wird dort aus **`targetGradeRaw`** befüllt.
  Viele Projekte haben aber **keinen Ziel-Grad** gesetzt — die im Screenshot sichtbare „6A+" ist der
  **erreichte** Grad (aus den Begehungen), nicht `targetGradeRaw`. Ohne Ziel-Grad → `grade = nil`
  → Fallback → 7a.

**Fix-Idee:** Der Watch immer einen **sinnvollen Projekt-Grad** mitgeben (Ziel-Grad **oder**
abgeleiteter Grad aus den Begehungen) und den 7a-Fallback entschärfen.

**Dateien**
`ClimbReflect/ClimbReflect/ClimbReflect/Models/Project.swift` (abgeleiteter Grad)
`ClimbReflect/ClimbReflect/ClimbReflect/Services/WatchSessionReceiver.swift` (Push-Payload)
`ClimbReflectWatch Watch App/Views/AttemptLogView.swift` (Fallback)
ggf. `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`

**Aufgabe**
1. In `Project` einen **repräsentativen Grad** ableiten (rein lesend), z. B.:
   ```swift
   /// Bevorzugt Ziel-Grad; sonst der schwerste getoppte Grad; sonst der schwerste versuchte.
   var representativeGradeRaw: String? {
       if let t = targetGradeRaw { return t }
       let topped = ascents.filter { $0.result == .top }
       let pool = topped.isEmpty ? ascents : topped
       return pool.max(by: { $0.canonicalOrder < $1.canonicalOrder })?.gradeRaw
   }
   var representativeGradeSystemRaw: String? {
       gradeSystemRaw ?? ascents.first?.gradeSystemRaw
   }
   ```
   (`canonicalOrder` gem. S30 skalenübergreifend korrekt.)
2. Im Push (`pushProjectsToWatch`) **statt** `targetGradeRaw` den `representativeGradeRaw`
   mitsenden (Key `"grade"`), analog `representativeGradeSystemRaw` (Key `"gradeSystem"`). Damit
   hat die Watch immer etwas Sinnvolles, sobald das Projekt Begehungen ODER einen Ziel-Grad hat.
3. In `AttemptLogView.onAppear` den Fallback von `count / 2` (=7a) auf einen **neutraleren**
   Startwert ändern, der nur greift, wenn wirklich **kein** Projekt/Grad vorliegt — z. B. der
   niedrigste plausible Grad der Disziplin oder ein Session-basierter Default. Wichtig: **nicht**
   die Mitte der French-Leiter. Vorschlag: Index auf den ersten „6er"-Grad der jeweiligen Leiter
   oder schlicht `0`, damit ein Fehlwert offensichtlich zu niedrig statt „glaubwürdig 7a" ist.
4. Sicherstellen, dass `prefillFromProject()` matcht: `gradeSystem.grades.firstIndex(of: grade)`
   scheitert, wenn das gepushte `grade` nicht exakt in der Leiter steht (Groß/Klein, „+", Skala).
   Ggf. vor dem `firstIndex` normalisieren (gleiche Schreibweise wie in `grades`).

**Fertig-wenn**
Projekt „6a" ausgewählt → Klassifizieren startet auf 6a (nicht 7a). Projekt mit Ziel-Grad → Ziel-Grad.
Projekt ohne Ziel-Grad aber mit Begehungen → dessen schwerster getoppter Grad. Ohne Projekt → klar
erkennbarer neutraler Startwert, nicht 7a.

---

### GR-2 · Grad nachträglich korrigierbar — auch aus dem Projekt

**Kontext**
„…führt zu fehlerhaften Einträgen welche man nicht korrigieren kann." Das Editieren gibt es bereits
(`EditAscentAssociationsSheet`: System/Grad/Ergebnis/Stil/Projekt/Schuh), aber es ist **nur aus der
`SessionDetailView`** erreichbar (Z.517). Aus dem **Projekt** heraus (Screenshot „Rote Linie") gibt
es keinen Weg zum Grad einer Begehung → wirkt „nicht korrigierbar".

**Dateien**
`ClimbReflect/ClimbReflect/ClimbReflect/Views/ProjectDetailView.swift`
(nutzt bestehendes `EditAscentAssociationsSheet`)

**Aufgabe**
1. Im Projekt-Detail die Begehungen antippbar machen → öffnet `EditAscentAssociationsSheet(ascent:)`
   (dasselbe Sheet wie in `SessionDetailView`, kein neues bauen).
2. Nach dem Speichern die Projekt-Statistik/Charts aktualisieren (SwiftData-`@Query` tut das
   i. d. R. automatisch; prüfen, dass „Versuche pro Session" und die Kopfzeile mitgehen).
3. Kein neuer Grad-Default hier — nur Bearbeiten des vorhandenen Werts.

**Fertig-wenn**
Aus dem Projekt lässt sich jede Begehung antippen und ihr Grad (+ Ergebnis/Stil) korrigieren; die
Anzeige aktualisiert sich.

---

### GR-3 · iPhone-Manuell-Add: Default = Projekt-Grad (optional, klein)

**Kontext**
`AddAscentView` hat `preselectedProject`, setzt aber beim Skalenwechsel
`selectedGrade = grades[min(8, count-1)]` (French Index 8 = „6c+"). Wird eine Begehung **aus einem
Projekt** hinzugefügt, sollte der Projekt-Grad vorbelegt sein — konsistent zu GR-1.

**Dateien**
`ClimbReflect/ClimbReflect/ClimbReflect/Views/AddAscentView.swift`

**Aufgabe**
1. Wenn `preselectedProject` gesetzt ist: `gradeSystem` + `selectedGrade` initial aus
   `project.representativeGradeRaw`/`…SystemRaw` (GR-1) vorbelegen (in `.onAppear`/`init`).
2. Fallback ohne Projekt unverändert lassen.

**Fertig-wenn**
Begehung aus einem Projekt hinzufügen belegt den Grad mit dem Projekt-Grad vor.

---

## D – Watch-Sync

### PS-1 · Gelöschte Projekte verschwinden auf der Watch

**Kontext**
„Auf der Uhr kann ich Projekte auswählen, die ich auf dem Handy schon gelöscht hatte." Der
Löschpfad ist eigentlich korrekt (`context.delete` → `save` → `pushProjectsToWatch()`), und die
Watch **ersetzt** `knownProjects` beim Kontext-Empfang. Zwei belegte Schwachstellen:
1. **Cache-Guard:** `saveListCache()` schreibt nur bei **nicht-leerer** Liste
   (`if !knownProjects.isEmpty`). Löscht du das **letzte** Projekt, wird `knownProjects = []`, aber
   der Cache behält die **alte** Liste. Beim nächsten Watch-Start lädt `loadListCache()` die alte
   Liste → gelöschtes Projekt ist zurück.
2. **`selectedProject` wird nicht bereinigt:** Ist das aktuell gewählte Projekt nicht mehr in
   `knownProjects`, bleibt es trotzdem als `selectedProject` aktiv (und in UserDefaults persistiert)
   → man kann gegen ein gelöschtes Projekt banken.

**Dateien**
`ClimbReflectWatch Watch App/Services/SyncService.swift`
`ClimbReflectWatch Watch App/Services/WorkoutManager.swift`

**Aufgabe**
1. `saveListCache()` so ändern, dass **auch leere** Listen persistiert werden (Guard entfernen bzw.
   immer schreiben). Damit kann der Cache keine gelöschten Projekte „konservieren". Beim Encode von
   `[]` sauber `[]` speichern.
2. In `applyContext`: Ein **vorhandener** `projectList`-Key (auch leer) ersetzt die Liste
   vollständig (ist so). Sicherstellen, dass ein leeres Array wirklich als „keine Projekte" ankommt
   und nicht der `else if names`-Zweig fälschlich greift.
3. Nach jedem `applyContext` / jeder `knownProjects`-Änderung: **`selectedProject` abgleichen** —
   wenn dessen `id` nicht mehr in `knownProjects` liegt, `selectedProject = nil` setzen
   (und die UserDefaults-Keys via bestehender Persist-Logik löschen). Analog optional für
   `selectedShoe`/`knownShoes` (S28), falls dasselbe Muster.
4. Diagnose-Log: `sync: projects=<n> (selected bereinigt: ja/nein)`.

**Fertig-wenn**
Projekt auf dem iPhone löschen → nach Sync (oder Watch-Neustart) ist es auf der Uhr **weg**, auch
wenn es das letzte war; ein gelöschtes, zuvor gewähltes Projekt wird als Auswahl automatisch
zurückgesetzt.

---

## E – Diagnose

### DG-1 · Diagnose-Log auf der Watch standardmäßig ausgeblendet

**Kontext**
„Im Normalbetrieb keine Diagnose auf der Uhr; im Fehlerfall aktivierbar." Aktuell ist der Einstieg
**immer sichtbar**: `SportSelectionView` zeigt dauerhaft einen `NavigationLink → DiagnosticView`.
Die Log-Infrastruktur (`DiagnosticLog.isEnabled`, `isVerbose`) existiert bereits.

**Kleiner Abstimmpunkt — Re-Aktivierungs-Mechanismus.** Ich empfehle den **iPhone-Schalter**
(sauber, auffindbar, hält die Uhr schlank, passt zu „iPhone = Source of Truth"):

- **Empfohlen:** Toggle „Diagnose auf der Uhr anzeigen" in den iPhone-`SettingsView` → per bestehenden
  Sync-Kanal an die Watch pushen. Watch blendet den Diagnose-Einstieg nur ein, wenn aktiv. Default: aus.
- Alternative (ohne iPhone-Abhängigkeit): verstecktes Gesture auf der Watch (z. B. Long-Press auf die
  „Klettern"-Überschrift) schaltet den Einstieg frei. Weniger auffindbar.

> Wenn dir die iPhone-Variante recht ist, setze ich unten diese um. Sag kurz Bescheid, falls du
> lieber das Gesture willst.

**Dateien**
`ClimbReflectWatch Watch App/Views/SportSelectionView.swift`
`ClimbReflectWatch Watch App/Services/SyncService.swift` (Flag empfangen)
`ClimbReflect/ClimbReflect/ClimbReflect/Views/SettingsView.swift` (Toggle)
`ClimbReflect/ClimbReflect/ClimbReflect/Services/WatchSessionReceiver.swift` (Flag pushen)

**Aufgabe (iPhone-Variante)**
1. iPhone: `@AppStorage("watchDiagnosticsVisible") = false` + Toggle in `SettingsView`
   („Diagnose auf der Uhr anzeigen"). Beim Umschalten in den Watch-Kontext-Push aufnehmen
   (`updateApplicationContext` + `transferUserInfo`-Fallback, wie Projekte/Schuhe).
2. Watch: Flag in `SyncService` empfangen + persistieren (analog Listen-Cache); `@Published var
   diagnosticsVisible`.
3. `SportSelectionView`: den Diagnose-`NavigationLink` nur zeigen, wenn `diagnosticsVisible == true`.
   Default aus → im Normalbetrieb kein Diagnose-Eintrag.
4. Log-Sammlung selbst (`isEnabled`) davon **entkoppelt** lassen (kann intern weiterlaufen), nur die
   **Sichtbarkeit** wird geschaltet. Optional: `isEnabled` an dasselbe Flag koppeln, falls du gar
   keine Sammlung im Normalbetrieb willst — bitte kurz sagen, was dir lieber ist.

**Fertig-wenn**
Standardmäßig kein Diagnose-Einstieg auf der Uhr; nach Aktivieren des iPhone-Toggles erscheint er
und die `DiagnosticView` ist erreichbar.

---

## F – ⚠️ ABSTIMMEN (nicht ohne Zusage umsetzen)

### ER-1 · Erfolg bleibt nach Löschen des Test-Trainings — **ist S34-Design**

**Kontext / warum das keine simple Bugfix-Aufgabe ist**
Genau dieses Verhalten ist in **CLAUDE.md S34** festgeschrieben:
> „Einmal freigeschaltet bleibt freigeschaltet, auch wenn die auslösenden Daten später gelöscht
> werden (Widerrufs-Politik)."

Das war eine bewusste Entscheidung gegen die alte Architektur (W1: „löschbare Vergangenheit").
`AchievementUnlock` wird persistiert; `AchievementService.checkNow` **fügt nur hinzu**, es gibt
keinen Widerruf. Dein Fall (Test-Training → Erfolg → Training gelöscht → Erfolg bleibt) ist also
**das dokumentierte Verhalten**, kein Zufalls-Bug.

Dein eigentliches Problem ist der **Test-Ablauf**: Testdaten hinterlassen dauerhafte „Geister-
Erfolge". Es gibt eine Spannung zu „Ehrliche Daten": Bei **Grad-Bestmarken** ist ein Erfolg „neuer
Höchstgrad 7a", dessen einzige 7a-Begehung gelöscht wurde, inhaltlich fragwürdig (Statistik zeigt
dann 6a+, Erfolg behauptet 7a).

**Optionen — bitte wählen:**

- **Option A (empfohlen, hält S34):** Ein **Entwickler-/Wartungs-Reset**
  „Erfolge neu berechnen" (in `SettingsView`, ggf. nur `#if DEBUG` oder hinter Bestätigung):
  löscht alle `AchievementUnlock` und ruft danach `backfillIfNeeded`/`checkNow` erneut auf den
  **aktuellen** Datenbestand. Ergebnis: nach dem Testen genau die Erfolge, die die echten Daten
  hergeben — ohne die Produktions-Politik aufzuweichen. Klein, risikoarm.

- **Option B (Politik ändern, nicht empfohlen):** Bei jedem `checkNow` zusätzlich **widerrufen**,
  wenn die Grundlage weggefallen ist (mind. für daten-abgeleitete Erfolge wie Grad-Bestmarken).
  Bricht S34 teilweise; braucht klare Regeln, welche Erfolge widerrufbar sind (Ereignis-Erfolge wie
  „Erster Send" vs. rein abgeleitete). Größer, mehr Testfläche.

- **Option C:** **Test-Flag** an `ClimbSession` („Testeinheit"): solche Sessions fließen **nie** in
  die Erfolgs-Auswertung. Sauber fürs Testen, aber neues Feld + überall berücksichtigen.

**Meine Empfehlung:** **A** — löst dein reales Problem (Test-Aufräumen) vollständig, ohne die
hart erarbeitete S34-Politik zu kippen. Sag, welche Option, dann schreibe ich die konkreten Schritte.

---

### CK-1 · CloudKit-Sync (Pfad 1) — **Schema-Migration, kein Schalter**

**Kontext**
„Und cloud bitte." Aktuell: `ModelConfiguration(isStoredInMemoryOnly: false)`, **kein**
`cloudKitDatabase` → rein lokal. Pfad 1 (SwiftData `cloudKitDatabase: .private`) ist auf der
Roadmap, aber „einschalten" allein crasht bzw. verliert Daten, weil das Schema mehrere
**CloudKit-Inkompatibilitäten** hat. Verifiziert im Code:

- **`@Attribute(.unique) var id: UUID` in 7 Modellen** (`ClimbSession, Ascent, Project,
  ProjectMedia, AchievementUnlock, Shoe, TrainingExercise`). CloudKit unterstützt **keine**
  Unique-Constraints → **alle müssen entfernt** werden. Dedupe (z. B. `watchSessionID`-Upsert) muss
  App-seitig bleiben/geprüft werden.
- **Nicht-optionale Properties ohne Default** (z. B. `Ascent.gradeSystemRaw/gradeRaw/resultRaw:
  String`, `attempts: Int`, `date/createdAt: Date`). CloudKit verlangt: jedes Attribut **optional
  oder mit Default**. → Für alle betroffenen Felder Defaults setzen (`= ""`, `= 0`, `= .now`) oder
  optional machen.
- **Relationen:** `.cascade`/`.nullify` sind ok; To-many haben Defaults (`= []`), To-one sind
  optional → passt grundsätzlich.
- **`@Attribute(.externalStorage) photoData`**: unter CloudKit als CKAsset ok, aber Größen/Sync-
  Verhalten testen.
- **Entitlements/Capabilities** (iCloud-Container `iCloud.de.dreselbjoern.ClimbReflect`, CloudKit,
  Background Modes „Remote notifications") für **iOS- und Watch-Target**.
- **Bestandsdaten:** Migration eines vorhandenen lokalen Stores in einen CloudKit-fähigen Store —
  Datenverlust-Risiko. Braucht versioniertes Schema + Sicherung vor Migration (Grundsatz 2).

**Das ist genau die Kategorie „größere Architekturänderung → vorher Rücksprache".** Ich setze das
**nicht** blind um. Vorgeschlagener Phasenplan (jede Phase = eigener Commit, App bleibt lauffähig):

1. **CK-P0 (Vorbereitung, ohne Aktivierung):** Schema CloudKit-tauglich machen — alle `.unique`
   entfernen, Defaults ergänzen — **ohne** `cloudKitDatabase`. Danach lokal weiterhin lauffähig +
   Migration testen (Bestandsdaten bleiben). Das ist die risikoärmste erste Hälfte.
2. **CK-P1 (Capabilities):** iCloud/CloudKit-Entitlements + Background Modes für beide Targets,
   iCloud-Container anlegen.
3. **CK-P2 (Aktivierung hinter Flag):** `ModelConfiguration(..., cloudKitDatabase: .private(...))`,
   zunächst in DEBUG/hinter Setting, mit Sicherung des lokalen Stores vor erstem Start.
4. **CK-P3 (Verifikation):** Zwei-Geräte-Test (iPhone↔iPhone/iPad), Watch-Verhalten, Konflikt-/
   Offline-Fälle; erst dann Default an.

**⚠️ Bitte bestätige,** ob ich mit **CK-P0** (reine Schema-Umbauten, noch kein CloudKit aktiv)
starten soll — das ist der sichere Einstieg und blockiert nichts. Aktivierung (P2) erst nach
weiterer Abstimmung. Vor CK-P0 kläre bitte auch: Apple-Developer-Account mit iCloud-Container
verfügbar? (nötig ab P1).

---

## Nach Umsetzung – CLAUDE.md pflegen

- Neue Erkenntnisse/Grundsätze als `S…` ergänzen (z. B. Banner-`onCommand` zentral statt View-Level;
  Watch-Cache muss leere Listen persistieren; French-Leiter-Mitte = 7a als Default-Falle).
- ER-1/CK-1: gewählte Optionen dokumentieren.
- Task-IDs (LA-/CH-/ER-/GR-/PS-/DG-/CK-) als vergeben vermerken.
