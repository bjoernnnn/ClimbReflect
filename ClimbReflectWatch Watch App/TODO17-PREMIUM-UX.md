# TODO17 – Premium-UX (aus Usability-Review)

> **Ablage im Repo:** `ClimbReflectWatch Watch App/TODO17-PREMIUM-UX.md` (wie TODO13–15).
> **Referenz:** `ClimbReflect-Usability-Review.md` (Begründungen, Befunde F1–F8, Kapitel 3–8).
> **Basis:** `origin/dev` @ `2d0b6fc`. Vor Start `git fetch` und prüfen, ob `dev` weiter ist. Falls ja, jede Aufgabe vor Umsetzung gegen den aktuellen Code verifizieren.

---

## 0. Regeln für die ausführende KI

1. **Branch:** `feature/premium-ux` von `dev`. Am Ende PR/Merge nach `dev`.
2. **Eine Aufgabe = ein Commit.** Commit-Format wie bisher: `fix(scope): VT-1 – Kurzbeschreibung` bzw. `feat(...)`, `refactor(...)`, `docs(...)`.
3. **Nach jedem Commit:** Scheme `ClimbReflect` (iOS) und Scheme `ClimbReflectWatch Watch App` bauen, `ClimbReflectTests` grün. Keine Warnungen neu einführen.
4. **Reihenfolge einhalten:** VT → DZ → TX → EF → FS → HM → WT → AX → DOC. Spätere Blöcke setzen auf Tokens/Komponenten früherer Blöcke auf.
5. **Pfade:** iOS-Code liegt unter `ClimbReflect/ClimbReflect/ClimbReflect/`, Watch unter `ClimbReflectWatch Watch App/` (Leerzeichen quoten). Das Projekt nutzt synchronisierte Ordnergruppen: neue Dateien im richtigen Ordner werden automatisch Teil des Targets, **pbxproj nicht manuell für Dateien anfassen** (Ausnahme DZ-1: Build-Setting).
6. **Deployment-Target iOS 17.0.** Nur APIs ≤ iOS 17 verwenden (`sensoryFeedback`, `contentTransition(.numericText())`, `symbolEffect`, `ContentUnavailableView`, `scrollPosition(id:)`, `scrollTargetBehavior`, `scrollTransition`, `contentMargins` sind erlaubt). Kein `#available` für iOS 18+-APIs einbauen.
7. **Keine neuen Abhängigkeiten.** Keine SwiftData-Schemaänderung (kein neues Attribut, kein neues Model). Persistente UI-Zustände nur über `UserDefaults`/`@AppStorage`.
8. **S-Prinzipien aus `CLAUDE.md` gelten uneingeschränkt**, besonders S31 (Fortschritt statt Belastung), S32 (ehrliche Statistik, kein `attempts`-basierter Wert), S33 (ein Feier-Kanal, keine Schuld-Mechanik), S34 (Erfolge persistiert, Effekte abschaltbar, Reduce Motion), S37 (kein plausibel wirkender Default).
9. **Code-Stil:** minimal, lesbar, keine Erklär-Kommentare für Offensichtliches, keine auskommentierten Altreste. Nicht mehr genutzte Views/Funktionen **löschen**. Kommentare nur mit Aufgaben-ID, wenn eine Entscheidung nicht aus dem Code hervorgeht.
10. **UI-Strings Deutsch**, Glossar aus TX-1 verbindlich ab dem Commit TX-1.
11. **Previews:** Jede neu gebaute oder stark umgebaute View bekommt `#Preview`-Varianten „Voll", „Spärlich", „Leer" (MockData-Szenarien nutzen, analog `FortschrittView`). Sie ersetzen in diesem TODO den Mockup-Schritt (Björn hat die Gestaltung explizit an die Spezifikation delegiert). Jede Preview muss bei Dynamic Type `.xxxLarge` und iPhone-SE-Breite (375 pt) ohne abgeschnittene Kerninhalte rendern.
12. **Watch:** Nur die in Block WT genannten Änderungen. Kein Eingriff in Session-Start, Pause/Ende, Action Button, Sync oder Live-Tab-Struktur.

---

## 1. Getroffene Entscheidungen

Diese Punkte waren im Review offen. Sie sind hiermit entschieden und nicht erneut abzustimmen.

| ID | Entscheidung | Begründung |
|---|---|---|
| E1 | `MountainBackground` wird **vollständig entfernt** und gelöscht. Ersatz: `AppBackground` (fast schwarz + sehr weicher Accent-Glow oben). | Größtes „Billig"-Signal; konkurriert mit Daten. |
| E2 | Dark Mode bleibt einzig. Gesetzt **einmal** über `UIUserInterfaceStyle = Dark` (Build-Setting), nicht mehr per View. | Robust auch für Sheets, weniger Code. |
| E3 | **Ein** Feier-Kanal (S33): `CelebrationOverlay` in `AddAscentView` wird gelöscht. PB/Erst-Top/Projekt-Top werden bereits über Erfolge (`pb_boulder`, `pb_route`, `first_top`, `grade_*`, `project_first_send`) gefeiert. Speichern = Haptik + sofort schließen. | S33 verbietet zweiten Kanal; beendet 1,4-s-Blockade. |
| E4 | Grad-Vorbelegung iPhone: Projekt → letzte Begehung dieser Session (gleiche Disziplin) → letzte Begehung der Disziplin überhaupt → **niedrigster Grad** der Anzeige-Skala. | Echte Grundlage statt Mitte (S37). |
| E5 | Grad-Vorbelegung Watch: letzte Begehung dieser Session (gleiches System) → Projekt → Index 0. | Spart Kronen-Rasten, bleibt S37-konform. |
| E6 | Beim Erfassen gibt es **keinen vorausgewählten Ergebnis-Wert**; „Sichern" ist deaktiviert, bis ein Ergebnis gewählt ist. | Verhindert still falsche Tops. |
| E7 | Ergebnis-Buttons je Disziplin. Boulder: Flash · Top · Versuch. Seil: Onsight · Flash · Rotpunkt · Versuch. „Abgebrochen" und Stil „Projekt" nur unter „Details". | Onsight ist beim Bouldern unüblich; weniger Fehltipps. |
| E8 | Glossar: **Top** (erfolgreiche Begehung, auch statt „Send"), **Versuch** (Begehung ohne Top), **Begehung** (jeder Eintrag), **Abgebrochen** (Ergebnis `quit`), Projektstatus **Geschafft** / **Aufgegeben**, **Klettertag**, **Reflexion** (statt „Tagebuch"). | Beendet drei Bedeutungen von „Versuch". |
| E9 | Beta-Bibliothek wandert in den **Projekte-Tab** (Toolbar). Schuhe bleiben in den Einstellungen, Abschnitt „Ausrüstung" wird nach oben verschoben. | Beta gehört zu Projekten, Schuhe sind selten bearbeitete Konfiguration. |
| E10 | Tabs bleiben: Heute · Fortschritt · Projekte · Erfolge. Alle vier mit **Large Title**. Detail-Views und Sheets inline. | iOS-Standard. |
| E11 | Heute: Stat-Kacheln (`Sessions`, `Streak`, `Diese Woche`) und `NextAchievementsCard` entfallen. Ersatz: **Level-Hero** mit PB → nächster Stufe, bis zu 3 Meilensteinen und einer Streak-Zeile. | Ein Ort für Status quo + nächste Ziele. |
| E12 | Meilensteine im Hero: nächste Grad-Stufe, Wohlfühl-Grad-Kandidat (n/5), bester Erfolgs-Fortschritt **nur aus Kategorien** `schwierigkeit`, `stil`, `projekte`, `ausdauer` (nicht `konsistenz`, nicht `momente`, nicht versteckt). | Kein Engagement-Nudge (S33), Fokus auf Können. |
| E13 | Ring-Darstellung nur, wo `current/target` echte Zählung ist (Wohlfühl n/5, Erfolge). Nächste Grad-Stufe bekommt **keinen** Ring. | S32: keine Schein-Quote. |
| E14 | Session-Recap als Sheet auf dem iPhone **nur für neu empfangene Watch-Sessions**, erscheint nach allen offenen Erfolgs-Overlays. Keine Animation, keine Partikel – Zusammenfassung, keine Feier. Zusätzlich jederzeit über das Menü im Session-Detail aufrufbar. | Bündelt den emotionalen Moment, S33-konform. |
| E15 | „Begehung aus Projekt": Button im Projekt-Detail → Auswahl aus passenden Sessions der letzten 3 Tage oder „Neue Session". | Löst toten Code GR-3. |
| E16 | Projekt-Chart „Versuche pro Session" wird durch eine **Klettertag-Zeitleiste** ersetzt (ein Punkt pro Tag, Top-Tag gold). | S32-konform, erzählt Hartnäckigkeit. |
| E17 | Reminder für manuelle Sessions nur, wenn der Erinnerungszeitpunkt (Sessionbeginn + 2 h) in der Zukunft liegt. | Keine Push während man gerade nachträgt. |
| E18 | RPE-Farben ohne Rot: eine Accent-Intensitätsskala. | Harte Session ist kein Fehler. |

---

## Block VT · Vertrauen (Funktionsfehler)

### VT-1 · Begehung löschen & bearbeiten zuverlässig machen

**Kontext:** `.swipeActions` wirkt nur in `List`. In `ProjectDetailView.attemptTimeline` steckt es in `VStack` und ist wirkungslos. `EditAscentAssociationsSheet` hat keinen Löschen-Weg und kein „Abbrechen". Begehungen sind am iPhone aktuell nicht löschbar (Review F1, F8).

**Dateien:** `Views/EditAscentAssociationsSheet.swift`, `Views/ProjectDetailView.swift`, `Views/SessionDetailView.swift`

**Aufgabe:**
1. `EditAscentAssociationsSheet`:
   - `ToolbarItem(.topBarLeading)`: `Button("Abbrechen") { dismiss() }`.
   - Letzte Form-Section: `Button("Begehung löschen", role: .destructive)` → `confirmationDialog("Begehung löschen?", titleVisibility: .visible)` mit Message „Die Begehung wird aus Statistik und Projekt entfernt. Freigeschaltete Erfolge bleiben erhalten." → `context.delete(ascent)`, `try? context.save()`, `dismiss()`.
   - Sheet mit `.interactiveDismissDisabled(hasChanges)`, wobei `hasChanges` lokale Werte gegen die geladenen vergleicht.
2. `ProjectDetailView.attemptTimeline`: `.swipeActions` entfernen. Stattdessen auf der Zeile `.contextMenu { Button("Bearbeiten") { editedAscent = ascent }; Button("Löschen", role: .destructive) { pendingDeleteAscent = ascent } }` mit eigenem `confirmationDialog`. Bestehende `deleteAscent(_:)` wiederverwenden, sie muss `try? context.save()` aufrufen.
3. `SessionDetailView.ascentsCard`: Variable `editedShoe` in `editedAscent` umbenennen. Gleiches `.contextMenu` wie oben ergänzen.

**Fertig wenn:** Begehung lässt sich im Session-Detail und im Projekt-Detail per Tap → Sheet → „Begehung löschen" und per Long-Press → „Löschen" entfernen. Pyramide und PBs aktualisieren sich. Kein `.swipeActions` außerhalb einer `List` im iOS-Target (`grep -rn swipeActions` prüfen).

---

### VT-2 · Projektliste: Kontextmenü statt totem Swipe, Duplikat-Feedback

**Kontext:** `ProjectsView` nutzt `.swipeActions` in `ScrollView` (wirkungslos). Doppelte Projektnamen werden in `createProject` still verworfen.

**Dateien:** `Views/ProjectsView.swift`

**Aufgabe:**
1. Alle vier `.swipeActions`-Blöcke entfernen. `projectRow` bekommt einmalig `.contextMenu`:
   - Anpinnen / Anpinnen aufheben (`project.isPinned.toggle()`, save, `pushProjectsToWatch()`), nur für aktive Projekte.
   - `Divider()`
   - Löschen (destructive) → `confirmationDialog` („Projekt löschen?", Message wie in `ProjectDetailView`).
2. `createProject`: Bei vorhandenem Namen `@State duplicateName: String?` setzen → `.alert("Projekt existiert bereits", isPresented:)` mit Message „„\(name)" ist schon in deiner Liste." und Button „OK".

**Fertig wenn:** Long-Press auf ein Projekt zeigt Anpinnen/Löschen, Löschen fragt nach. Doppelter Name zeigt Alert. Kein `swipeActions` mehr in der Datei.

---

### VT-3 · Speichern ohne Duplikate, zweiten Feier-Kanal entfernen

**Kontext:** Doppel-Tipp auf „Speichern" während der 1,4-s-Feier legt die Begehung doppelt an (F2). `CelebrationOverlay` ist ein zweiter Feier-Kanal (verstößt gegen S33, E3).

**Dateien:** `Views/AddAscentView.swift`

**Aufgabe:**
1. `@State private var isSaving = false`. `save()` beginnt mit `guard !isSaving else { return }; isSaving = true`. Speichern-Button `.disabled(isSaving)`.
2. `showCelebration`, das Overlay im `ZStack` und `struct CelebrationOverlay` löschen.
3. Nach `context.save()` und `AchievementService.shared.checkNow`: bei Top `UINotificationFeedbackGenerator().notificationOccurred(.success)`, sonst `UIImpactFeedbackGenerator(style: .light).impactOccurred()`, dann sofort `dismiss()`. (Wird in HM-1 auf `sensoryFeedback` umgestellt.)
4. Toten Block `if result == .top, let project = selectedProject { _ = project }` entfernen.

**Fertig wenn:** Schnelles Doppel-Tippen erzeugt genau eine Begehung. `CelebrationOverlay` existiert nicht mehr (`grep`). Erfolgs-Overlays erscheinen wie bisher über `DashboardView`.

---

### VT-4 · Grad-Vorbelegung mit echter Grundlage

**Kontext:** `AddAscentView` startet immer mit Fb 6A, auch in Seil-Sessions (F4). Entscheidung E4.

**Dateien:** neu `Models/GradeDefaults.swift`, `Views/AddAscentView.swift`, neu `ClimbReflectTests/GradeDefaultsTests.swift`

**Aufgabe:**
1. Reine Funktion:

```swift
enum GradeDefaults {
    static func discipline(for type: SessionType) -> ProgressEngine.Discipline {
        switch type {
        case .lead, .topRope, .autoBelay: .rope
        default: .boulder
        }
    }

    /// E4: Projekt → letzte Begehung der Session → letzte Begehung der Disziplin → niedrigster Grad (S37).
    static func initial(session: ClimbSession, project: Project?,
                        allSessions: [ClimbSession]) -> (system: GradeSystem, grade: String) {
        let discipline = discipline(for: session.sessionType)
        let target = discipline.displaySystem

        func converted(_ raw: String, _ system: GradeSystem) -> (GradeSystem, String)? {
            GradeConverter.convert(grade: raw, from: system, to: target).map { (target, $0) }
        }

        if let project, let raw = project.representativeGradeRaw,
           let sysRaw = project.representativeGradeSystemRaw, let sys = GradeSystem(rawValue: sysRaw),
           sys.isBoulder == discipline.isBoulder, let r = converted(raw, sys) { return r }

        let latest: ([Ascent]) -> Ascent? = { ascents in
            ascents.filter { $0.isGraded && discipline.matches($0) }
                   .max { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
        }
        if let a = latest(session.ascents), let r = converted(a.gradeRaw, a.gradeSystem) { return r }
        if let a = latest(allSessions.flatMap(\.ascents)), let r = converted(a.gradeRaw, a.gradeSystem) { return r }

        return (target, target.grades.first ?? Ascent.ungraded)
    }
}
```

   Signatur von `GradeConverter.convert` vor Verwendung prüfen und ggf. anpassen.
2. `AddAscentView`: `@Query` auf alle `ClimbSession` ergänzen. `onAppear` ersetzt die bisherige Vorbelegung (GR-3-Block und `min(8, …)`-Fallback) durch `GradeDefaults.initial(...)`. Auch im `onChange(of: gradeSystem)` statt `min(8, …)` den ersten Grad nehmen.
3. Tests (Swift Testing oder XCTest, wie in `ProgressEngineTests`): Projekt gewinnt · Session-Begehung gewinnt vor Historie · Historie greift bei leerer Session · Seil-Session ohne Daten → French, niedrigster Grad · Boulder-Projekt in Seil-Session wird ignoriert · Anzeige-Skala V-Scale wird respektiert (`boulderScale`-Default in Test explizit setzen und wieder zurücksetzen).

**Fertig wenn:** Neue Begehung in einer Vorstieg-Session startet in French. Die zweite Begehung einer Session startet auf dem Grad der ersten. Tests grün.

---

### VT-5 · Manuelle Session: keine Leiche, keine falsche Push

**Kontext:** `ManualSessionView.save()` persistiert sofort. Im Detail gibt es kein „Verwerfen". Reminder feuert 30 s später auch für nachgetragene Sessions (F5, E17).

**Dateien:** `Services/NotificationService.swift`, `Views/SessionDetailView.swift`

**Aufgabe:**
1. `scheduleReflectionReminder(for:)`: `let fireDate = session.date.addingTimeInterval(2 * 3600); guard fireDate > .now else { return }`. `max(30, …)` entfällt, Delay ist `fireDate.timeIntervalSinceNow`.
2. `SessionDetailView`: berechnete Property `isPristine` = keine Ascents, keine TrainingSets, `reflectionCompleted == false`, alle Reflexionsfelder `nil`.
   Wenn `onFertig != nil && isPristine`: `ToolbarItem(.topBarLeading)` `Button("Verwerfen", role: .destructive)` → `NotificationService.shared.cancelReminder(for: session.id)`, `context.delete(session)`, `try? context.save()`, `onFertig?()`.
   Zusätzlich im bisherigen Delete-Dialog `cancelReminder` aufrufen und `try? context.save()` ergänzen.

**Fertig wenn:** Session für gestern nachtragen erzeugt keine Notification. Neue leere Session zeigt „Verwerfen" und hinterlässt nach Tipp keinen Eintrag in „Letzte Sessions".

---

### VT-6 · Keine `attempts`-Werte mehr anzeigen (S32), angepinnte Projekte tappbar

**Kontext:** Heute-Karte, Projektliste, Projekt-Header und Projekt-Chart summieren `Ascent.attempts` – S32 verbietet das bis zur Route Identity. Angepinnte Projekte auf Heute sind nicht tappbar (F6).

**Dateien:** `Views/TodayView.swift`, `Views/ProjectsView.swift`, `Views/ProjectDetailView.swift`, `Models/Project.swift`

**Aufgabe:**
1. `TodayView.pinnedProjectsCard`: Jede Zeile in `NavigationLink(value:)` bzw. `NavigationLink(destination: ProjectDetailView(project:))`, `.buttonStyle(.plain)`, Chevron rechts. Untertitel statt Versuchen: `"\(project.distinctDays) Klettertag(e)"`, bei 0: „Noch nicht geklettert".
2. `ProjectsView.projectRow`: Zeile „N Versuche · M Tage" ersetzen durch `"\(project.ascents.count) Begehung(en) · \(project.distinctDays) Tag(e)"`.
3. `ProjectDetailView.headerCard`: Pills zu **Tage · Begehungen · Tops**. `attempts`-Summe entfernen.
4. `ProjectDetailView`: `progressChart`, `attemptHistory`, `AttemptPoint` löschen (Ersatz folgt in FS-6).
5. `Project.totalAttempts` löschen, wenn danach ungenutzt (`grep`).
6. Einzelne Rohwerte pro Begehung in `AscentRowView` („N Versuche bis zum Top") bleiben erlaubt.

**Fertig wenn:** `grep -rn "\.attempts" Views/` zeigt nur noch `AscentRowView` und Eingabe-Stepper. Angepinntes Projekt auf Heute öffnet das Detail.

---

### VT-7 · Debug-Container vollständig

**Kontext:** Fallback-Container im Debug-Zweig registriert `AchievementUnlock` nicht (F8).

**Dateien:** `ClimbReflectApp.swift`

**Aufgabe:** Beide `ModelContainer(for:)`-Aufrufe über **eine** Konstante `static let models: [any PersistentModel.Type] = [...]` bzw. `Schema([...])` speisen, sodass Liste nicht auseinanderlaufen kann. Inhalt identisch zur Release-Liste.

**Fertig wenn:** Beide Aufrufe nutzen dieselbe Liste. App startet in Debug nach manuellem Store-Löschen ohne Crash im Erfolge-Tab.

---

### VT-8 · Begehung direkt aus dem Projekt erfassen

**Kontext:** `AddAscentView.preselectedProject` wird nirgends übergeben (F3). Entscheidung E15.

**Dateien:** `Views/ProjectDetailView.swift`, `Views/ManualSessionView.swift`, `Views/SessionDetailView.swift`

**Aufgabe:**
1. `ProjectDetailView`: Unter `headerCard` ein primärer Button „Begehung erfassen" (`.buttonStyle(.borderedProminent)`, volle Breite, `.controlSize(.large)`), nur wenn Projekt nicht aufgegeben.
2. Tap → `confirmationDialog("Zu welcher Session?")`:
   - Kandidaten: Klettersessions der letzten 3 Kalendertage, deren Disziplin zum Projekt passt (`GradeDefaults.discipline(for:)` vs. `project.gradeSystem?.isBoulder`; ohne Projekt-System alle Klettersessions), neueste zuerst, max. 3. Label: `"\(type.label) · \(relativer Tag)"` („heute", „gestern", Wochentag).
   - `Button("Neue Session …")`.
   - Abbrechen.
3. Kandidat gewählt → Sheet `AddAscentView(session:, preselectedProject: project)`.
4. „Neue Session …" → Sheet `ManualSessionView(preselectedProject: project)`:
   - `ManualSessionView` bekommt `var preselectedProject: Project? = nil`. Session-Typ-Vorbelegung: Seil-Projekt → `.lead`, sonst `.boulder`.
   - Navigation nach „Weiter" an `SessionDetailView(session:, onFertig:, autoAddAscentProject: preselectedProject)`.
   - `SessionDetailView` bekommt `var autoAddAscentProject: Project? = nil`. Ist es gesetzt, öffnet `.task` einmalig das `AddAscentView`-Sheet mit diesem Projekt (`@State didAutoOpen`).
   - `AddAscentView`-Sheet in `SessionDetailView` generell auf `sheet(item:)` mit einem kleinen `AddAscentRequest: Identifiable { let project: Project? }` umstellen.

**Fertig wenn:** Aus einem Projekt heraus lässt sich in ≤ 3 Taps eine Begehung erfassen. Grad ist mit Projekt-Grad vorbelegt, Projekt ist ausgewählt.

---

## Block DZ · Designsystem

### DZ-1 · Dark Mode zentral

**Kontext:** `.preferredColorScheme(.dark)` steht 22-mal in Views (E2).

**Dateien:** `ClimbReflect.xcodeproj/project.pbxproj` (nur Build-Setting), alle iOS-Views mit `preferredColorScheme`

**Aufgabe:**
1. In beiden Build-Konfigurationen (Debug/Release) des iOS-App-Targets (dort, wo `INFOPLIST_KEY_UILaunchScreen_Generation = YES;` steht) `INFOPLIST_KEY_UIUserInterfaceStyle = Dark;` ergänzen. Watch-Target und Widget-Extension nicht anfassen.
2. Alle `.preferredColorScheme(.dark)` im iOS-App-Target entfernen, auch in `#Preview`s nicht erneut setzen (Previews übernehmen das Info.plist-Setting nicht zwingend → in Previews ausnahmsweise `.preferredColorScheme(.dark)` erlaubt).

**Fertig wenn:** `grep -rn preferredColorScheme` im iOS-Code (ohne `#Preview`-Blöcke) leer. App und alle Sheets erscheinen dunkel, auch wenn das System hell ist.

---

### DZ-2 · Theme-Tokens & AppBackground

**Kontext:** 11 Eckenradien, nur 4 `.continuous`; kaum unterscheidbare Text-Stufen; Karten mit Kontur; Bergsilhouette (E1). Review Kap. 3.

**Dateien:** `Theme/Theme.swift`, neu `Theme/AppBackground.swift`, `Background/MountainBackground.swift` (löschen), alle Nutzer von `MountainBackground`

**Aufgabe:**
1. `Theme.swift` neu strukturieren:

```swift
enum Theme {
    // Flächen
    static let bg            = Color(hex: 0x0A0C10)
    static let surface       = Color(hex: 0x15181E)   // Karten
    static let surfaceRaised = Color(hex: 0x1D2128)   // Elemente in Karten, Chips, Buttons
    static let separator     = Color.white.opacity(0.08)

    // Text – deutlich getrennte Stufen
    static let textPrimary   = Color(hex: 0xF4F6F8)
    static let textSecondary = Color(hex: 0x9BA3AE)
    static let textTertiary  = Color(hex: 0x5F6772)

    // Bedeutung
    static let accent  = Color(hex: 0x37E29A)   // interaktiv, „du"
    static let accent2 = Color(hex: 0x29B6F6)   // nur zweite Chart-Serie
    static let gold    = Color(hex: 0xF5C451)   // ausschließlich Erreichtes
    static let danger  = Color(hex: 0xFF6B6B)   // ausschließlich destruktiv

    static var goldGradient: LinearGradient { … unverändert … }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let card: CGFloat = 20
    }

    enum Typo {
        static let metricHero = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let metric     = Font.system(.title2, design: .rounded).weight(.semibold)
        static let section    = Font.title3.weight(.semibold)
        static let cardTitle  = Font.headline
        static let label      = Font.footnote.weight(.medium)
    }
}

extension Shape where Self == RoundedRectangle {
    static func theme(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
```

   `CardModifier`: `padding` Default 16, Hintergrund `.theme(Theme.Radius.card)` mit `Theme.surface`, **kein** Stroke. Neuer Modifier `.inset()` = `padding(14)` + `surfaceRaised` + `Radius.medium`.
   `surfaceStroke`, `bgElevated`, `accentGradient` entfernen. Nutzer umstellen: `bgElevated` → `surfaceRaised`; `surfaceStroke` für Divider → `separator`, für Konturen → entfernen; `accentGradient` → `Theme.accent` (Ausnahme: Sammlungs-Balken in `AchievementsView` darf `LinearGradient([accent, accent2])` inline behalten). `Theme+Achievements.swift` nicht verändern, außer Kompilierfehler durch entfernte Tokens.
2. `AppBackground`:

```swift
struct AppBackground: View {
    var body: some View {
        Theme.bg
            .overlay(alignment: .top) {
                RadialGradient(colors: [Theme.accent.opacity(0.07), .clear],
                               center: .top, startRadius: 0, endRadius: 380)
                    .frame(height: 380)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}
```

3. Überall `ZStack { MountainBackground(); content }` ersetzen durch `content.background { AppBackground() }`. In Sheets/Forms: `.scrollContentBackground(.hidden).background(Theme.bg)`. Glow nur auf den vier Tab-Root-Views; Detail-Views und Sheets nur `Theme.bg`.
4. `Background/MountainBackground.swift` und leeren Ordner löschen.
5. Chart-Farben: `ClimbDaysCard`, `GradeTimelineChart`, `PyramidChart` – Balken/Linien `Theme.accent`, Grid `Theme.separator`, Achsenlabels `Theme.textTertiary`.

**Fertig wenn:** Kein `MountainBackground`, `surfaceStroke`, `bgElevated`, `accentGradient` mehr im iOS-Code. Kein `RoundedRectangle(cornerRadius:` ohne `style: .continuous` außer in `AchievementMedallion`/`AchievementUnlockOverlay`/`ParticleBurstView`. Build grün.

---

### DZ-3 · Schriftgrößen & Radien vereinheitlichen

**Kontext:** 43 × `.system(size:)`, gemischte Rollen für „große Zahl", Uppercase-Micro-Labels.

**Dateien:** alle iOS-Views laut `grep -rn "\.system(size:" Views`. Ausgenommen: `AchievementMedallion`, `AchievementUnlockOverlay`, `ParticleBurstView`, `AchievementToast` (Artwork, skaliert über `size`-Parameter).

**Aufgabe:**
1. Ersetzen nach Rolle:
   - große Kennzahl (PB, Hero) → `Theme.Typo.metricHero`
   - Kennzahl in Kachel/Pill → `Theme.Typo.metric`
   - SF Symbols in Zeilen-Icons → `.font(.body)` bzw. `.imageScale(.medium)`; in 44-pt-Kreisen `.font(.title3)`
   - Chevron → `.font(.footnote.weight(.semibold))`, `Theme.textTertiary`
   - Empty-State-Icons entfallen durch DZ-7
2. Alle `Text(x.uppercased())` + `caption2` Eyebrow-Labels → `Text(x)` mit `Theme.Typo.label`, `Theme.textSecondary`.
3. Alle Zahlen-`Text` bekommen `.monospacedDigit()`.
4. Alle `cornerRadius:`-Werte auf `Theme.Radius` mappen: 3/4/6/7/8/10 → `small`, 12/14/16 → `medium`, 20 → `card`. Capsules bleiben Capsules.

**Fertig wenn:** `grep -rn "\.system(size:" ClimbReflect/ClimbReflect/ClimbReflect/Views` liefert nur die ausgenommenen Dateien. `grep -rn "uppercased()" Views` leer (außer Watch). Previews bei `.xxxLarge` lesbar.

---

### DZ-4 · Navigation nach iOS-Standard

**Kontext:** Heute ohne Titel mit Marken-Schriftzug, alle Tabs inline, Toolbar-Material ausgeblendet, „+" links (Review 3.5, E10).

**Dateien:** `Views/TodayView.swift`, `Views/FortschrittView.swift`, `Views/ProjectsView.swift`, `Views/AchievementsView.swift`, `Views/DashboardView.swift`, alle Views mit `toolbarBackground(.hidden`

**Aufgabe:**
1. Alle `.toolbarBackground(.hidden, for: .navigationBar)` im iOS-Code entfernen.
2. Tab-Roots: `.navigationBarTitleDisplayMode(.large)`. Titel: „Heute", „Fortschritt", „Projekte", „Erfolge".
3. `TodayView`: `header` (App-Icon + „ClimbReflect") löschen. Als erstes Element im Scroll-Content: `Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))` in `Theme.Typo.label`/`textSecondary`.
4. `TodayView`-Toolbar: `ToolbarItemGroup(placement: .topBarTrailing)` mit zuerst Einstellungen (`gearshape`), dann „+" (`plus`, `.fontWeight(.semibold)`). Kein Leading-Item.
5. `ProjectsView` hat eigenen `NavigationStack` im `DashboardView`; `FortschrittView`/`AchievementsView`/`TodayView` erzeugen ihn intern – vereinheitlichen: alle vier Tab-Views ohne eigenen `NavigationStack`, `DashboardView` wickelt jede in `NavigationStack`. `.tint(Theme.accent)` bleibt am `TabView`.

**Fertig wenn:** Alle vier Tabs zeigen große Titel, die beim Scrollen in die Leiste schrumpfen und Material bekommen. Heute hat keinen Schriftzug mehr.

---

### DZ-5 · Native Segment-Picker im Fortschritt

**Kontext:** Eigene Pill-Picker mit ~22 pt Trefferfläche (Review 3.5).

**Dateien:** `Views/Components/ProgressControls.swift`, `Views/FortschrittView.swift`, `Views/Components/ChartPeriodPicker.swift`, `Views/Components/DisciplinePicker.swift`

**Aufgabe:**
1. `ProgressDisciplinePicker` und `ProgressPeriodPicker` durch `Picker(…, selection:) { ForEach … }.pickerStyle(.segmented)` ersetzen (Struct-Namen und Bindings behalten).
2. `FortschrittView`: Kopf als `VStack(spacing: 10)`: Zeile 1 Disziplin (volle Breite), Zeile 2 Zeitraum (volle Breite, nur wenn `hasData`).
3. `ChartPeriodPicker.swift` und `DisciplinePicker.swift` löschen, falls ungenutzt (aktuell keine Aufrufer).
4. `UISegmentedControl.appearance()` **nicht** anfassen.

**Fertig wenn:** Beide Picker sind System-Segmented-Controls. Die zwei Komponenten-Dateien sind gelöscht.

---

### DZ-6 · Informationsarchitektur

**Kontext:** Beta-Bibliothek im Erfolge-Tab, Ausrüstung weit unten in Einstellungen (E9).

**Dateien:** `Views/AchievementsView.swift`, `Views/ProjectsView.swift`, `Views/SettingsView.swift`

**Aufgabe:**
1. `AchievementsView`: `betaLibraryLink` samt Aufruf löschen.
2. `ProjectsView`-Toolbar: `ToolbarItemGroup(.topBarTrailing)`: `NavigationLink { BetaLibraryView() } label: { Image(systemName: "books.vertical") }` mit `.accessibilityLabel("Beta-Bibliothek")`, danach „+".
3. `SettingsView`: Section „Ausrüstung" an die erste Stelle. Section „Entwicklung" an die letzte Stelle vor „Version", Header in „Support & Diagnose" umbenennen.

**Fertig wenn:** Beta-Bibliothek nur noch über Projekte erreichbar. Einstellungen beginnen mit Ausrüstung.

---

### DZ-7 · Leere Zustände mit `ContentUnavailableView`

**Kontext:** Vier verschiedene selbstgebaute Empty-States, teils irreführender Text („importiere aus Apple Health" auf manuellem Button).

**Dateien:** `Views/TodayView.swift`, `Views/FortschrittView.swift`, `Views/ProjectsView.swift`, `Views/SessionDetailView.swift`

**Aufgabe:**
- Heute (keine Sessions):
  `ContentUnavailableView { Label("Deine erste Session", systemImage: "applewatch") } description: { Text("Starte eine Session auf der Apple Watch – sie erscheint danach automatisch hier.") } actions: { Button("Session nachtragen") { showAddSession = true }.buttonStyle(.bordered) }`
- Fortschritt (keine Daten der Disziplin): Titel „Noch kein Fortschritt", Symbol `chart.line.uptrend.xyaxis`, Beschreibung „Sobald du \(Boulder/Seil)-Begehungen erfasst, siehst du hier, wo du stehst."
- Projekte: Titel „Keine Projekte", Symbol `target`, Beschreibung „Ein Projekt ist ein Boulder oder eine Route, an der du dranbleiben willst.", Action „Projekt anlegen" (`.borderedProminent`).
- Session-Detail, keine Begehungen: großer Button statt Text: `Button { add } label: { Label("Erste Begehung erfassen", systemImage: "plus") .frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)`.

**Fertig wenn:** Keine selbstgebauten Empty-VStacks mehr in diesen Dateien. Previews „Leer" zeigen die neuen Zustände.

---

## Block TX · Texte & Terminologie

### TX-1 · Glossar anwenden

**Kontext:** „Versuch" hat drei Bedeutungen, „Send"/„Top"/„Gesendet" gemischt, Drittanbieter-Name „Redpoint" in UI (Review Kap. 7, E8).

**Dateien:** iOS-Views, `Models/Enums.swift`, `Services/RedpointHealthService.swift` (nur Strings), `Views/Components/LevelHeaderView.swift`, `Views/Components/ClimbDaysCard.swift`, `Views/ProjectsView.swift`, `Views/ProjectDetailView.swift`, `Views/SettingsView.swift`, `Views/SessionDetailView.swift`, `Views/AddAscentView.swift`

**Aufgabe (nur sichtbare Strings, keine Rawvalues, keine Persistenz-Keys):**

| Alt | Neu |
|---|---|
| „Höchster Send" | „Höchster Top" |
| „Sends" / „\(n) Sends" | „Tops" |
| „Erstmals gesendet" | „Erste Tops" |
| „Gesendet ✓" (Section) | „Geschafft" |
| „Gesendet \(Datum)" | „Geschafft am \(Datum)" |
| Projektstatus-Label „Gesendet" | „Geschafft" |
| `AscentResult.quit.label` „Aufgegeben" | „Abgebrochen" |
| „Keins" (Projekt-Chip) | „Kein Projekt" |
| „Mein Tagebuch" | „Reflexion" |
| „Apple Health / Redpoint" (Alert-Titel, Section-Text, Fehlertexte) | „Apple Health" |
| Session-Detail „\(n) Versuch(e)" als Anzahl Nicht-Tops | bleibt „Versuche" (korrekte Bedeutung) |

Außerdem `redpointCard` in `SessionDetailView` → `healthCard` umbenennen. `RedpointHealthService` bleibt als Typname (keine Churn).

**Fertig wenn:** `grep -rni "send\b\|sends\|gesendet\|redpoint" Views/` findet keine sichtbaren Strings mehr (Typ-/Variablennamen erlaubt). `Rotpunkt` bleibt als Stil-Label.

---

### TX-2 · Mikro-Copy im Fortschritt und bei Erfolgen

**Kontext:** „6B · 3/5" ist kryptisch, „unversucht" klingt wie Defizit, Prozentwerte abstrakt.

**Dateien:** `Views/Components/LevelHeaderView.swift`, `Views/AchievementsView.swift`

**Aufgabe:**
1. Wohlfühl-Kandidat Wert: `"\(grade) · noch \(min - sample)"`; Fußnote: „Wohlfühl-Grad wird ab \(min) Begehungen in einem Grad eingeschätzt."
2. Nächste Stufe: `nextGradeTries == 0` → `"\(grade) · noch nicht versucht"`, sonst `"\(grade) · \(n) Begehung(en)"`.
3. `AchievementsView.inReachSection`: Prozent-Text rechts entfernen, `remainingText` als Untertitel behalten (bereits vorhanden), Medaillon-Ring zeigt Fortschritt.

**Fertig wenn:** Keine Prozentangabe mehr in `inReachSection`. LevelHeader-Texte wie angegeben (wird in FS-5 in `MilestoneRow` überführt – Texte dort übernehmen).

---

## Block EF · Erfassen

### EF-1 · Komponenten `GradeRuler` und `OutcomePicker`

**Kontext:** Wheel-Picker im Form wirkt klobig; Ergebnis/Stil sind zwei getrennte Picker (Review 5.1, E6, E7).

**Dateien:** neu `Views/Components/GradeRuler.swift`, neu `Views/Components/OutcomePicker.swift`, neu `Models/AscentOutcome.swift`

**Aufgabe:**
1. `AscentOutcome`:

```swift
struct AscentOutcome: Hashable, Identifiable {
    let result: AscentResult
    let style: AscentStyle?
    var id: String { result.rawValue + (style?.rawValue ?? "") }

    var label: String { style?.label ?? result.label }
    var symbol: String { style?.symbol ?? result.symbol }

    static func quick(for discipline: ProgressEngine.Discipline) -> [AscentOutcome] {
        discipline.isBoulder
            ? [.init(result: .top, style: .flash), .init(result: .top, style: nil), .init(result: .attempt, style: nil)]
            : [.init(result: .top, style: .onsight), .init(result: .top, style: .flash),
               .init(result: .top, style: .redpoint), .init(result: .attempt, style: nil)]
    }
}
```

2. `GradeRuler(grades: [String], selection: Binding<String>)`:
   - `GeometryReader` → horizontale `ScrollView(showsIndicators: false)` mit `LazyHStack(spacing: 0)`, Item-Breite 64 pt, `.scrollTargetLayout()`, `.scrollTargetBehavior(.viewAligned)`, `.scrollPosition(id:)` gebunden an `selection` (Optional-Brücke), `.contentMargins(.horizontal, (width - 64) / 2, for: .scrollContent)`.
   - Item: `Text(grade)` in `Theme.Typo.metric`; `.scrollTransition(.interactive) { content, phase in content.opacity(phase.isIdentity ? 1 : 0.35).scaleEffect(phase.isIdentity ? 1 : 0.8) }`.
   - Tap auf Item → `withAnimation(.snappy) { selection = grade }`.
   - Zentrierte Markierung: dünne `Capsule` 2 × 18 pt in `Theme.accent` unter der Mitte.
   - Höhe 64 pt. `.sensoryFeedback(.selection, trigger: selection)`.
   - `accessibilityElement(children: .ignore)`, `.accessibilityLabel("Grad")`, `.accessibilityValue(selection)`, `.accessibilityAdjustableAction` (increment/decrement Index).
3. `OutcomePicker(options: [AscentOutcome], selection: Binding<AscentOutcome?>)`:
   - `LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: options.count))`.
   - Button: `VStack(spacing: 6) { Image(systemName:).font(.title3); Text(label).font(.subheadline.weight(.semibold)) }`, `.frame(maxWidth: .infinity, minHeight: 72)`, Hintergrund `.theme(Theme.Radius.medium)` in `surfaceRaised`, ausgewählt: Füllung `Theme.accent` (bei Flash/Onsight `Theme.gold`), Text/Icon `Theme.bg`.
   - `.sensoryFeedback(.impact(weight: .light), trigger: selection)`.
   - `.accessibilityAddTraits(isSelected ? .isSelected : [])`.
4. Previews für beide Komponenten (Boulder- und Seil-Leiter).

**Fertig wenn:** Beide Komponenten rendern in Previews, Ruler rastet auf Grade ein und bindet in beide Richtungen.

---

### EF-2 · `AddAscentView` als Quick-Log

**Kontext:** 7 gleichgewichtete Form-Sections (Review 5.1).

**Dateien:** `Views/AddAscentView.swift`

**Aufgabe:** View neu aufbauen (Speicherlogik, Projekt-/Schuh-/Foto-Handling fachlich unverändert übernehmen):

1. Container: `NavigationStack { ScrollView { VStack(spacing: 24) { … } .padding(20) } .background(Theme.bg) }`, Titel „Begehung", inline.
2. **Grad-Block** (zentriert):
   - `Text(selectedGrade)` in `Theme.Typo.metricHero`, `.contentTransition(.interpolate)`.
   - `Text(gradeSystem.label)` klein, `textTertiary`.
   - `GradeRuler(grades: gradeSystem.grades, selection: $selectedGrade)`.
   - „Zuletzt"-Chips: bis zu 4 unterschiedliche Grade aus `session.ascents` gleicher Disziplin, neueste zuerst; `Capsule`-Chips in `surfaceRaised`, Tap setzt Grad. Ausblenden wenn leer.
3. **Ergebnis:** `OutcomePicker(options: AscentOutcome.quick(for: discipline), selection: $outcome)`; `@State outcome: AscentOutcome?` = `nil` (E6). `discipline` aus `gradeSystem.isBoulder`.
4. **Projekt-Zeile** als `.inset()`-Fläche: `Menu` mit `Picker(selection: $selectedProject)` („Kein Projekt" + aktive Projekte) und `Button("Neues Projekt …")` → `.alert("Neues Projekt", isPresented:) { TextField("Name", text: $newProjectName); Button("Anlegen") { createAndSelectProject() }; Button("Abbrechen", role: .cancel) {} }`. Label: `target`-Symbol, Projektname oder „Kein Projekt", Chevron.
5. **Details** `DisclosureGroup("Details", isExpanded: $showDetails)` in `.card()`, zu Beginn zugeklappt. Inhalt in dieser Reihenfolge:
   - Grad-System `Picker(.menu)`
   - Ergebnis vollständig: `Picker("Ergebnis")` über alle `AscentResult`, bei Top `Picker("Stil")` inkl. `.project` – beide schreiben in `outcome`
   - `Stepper("Versuche: \(attempts)")`
   - Stil-Tags (bestehende `tagRow`)
   - Set/Sektion `TextField`
   - Schuh `Picker(.menu)` inkl. „Kein Schuh"
   - Foto (bestehender `PhotosPicker`-Block)
   - Notiz `TextField(axis: .vertical).lineLimit(3...6)` statt `TextEditor`+Placeholder-Hack
   - Footer-Satz „Projekt einmal wählen – …" entfällt.
6. **Toolbar:** Leading „Abbrechen", Trailing „Sichern" (`.fontWeight(.semibold)`, `.disabled(outcome == nil || isSaving)`).
7. **Bottom-Bar** `safeAreaInset(edge: .bottom)` mit `.background(.bar)`:
   - `Button("Sichern & nächste") { save(keepOpen: true) }` `.buttonStyle(.bordered)`, volle Breite, `.controlSize(.large)`, gleiche Disabled-Regel.
   - Darüber, nur nach einem `keepOpen`-Save sichtbar: `Label("\(grade) · \(outcome.label) gesichert", systemImage: "checkmark.circle.fill")` in `Theme.accent`, blendet nach 2 s aus; daneben `Text("\(session.ascents.count) in dieser Session")` mit `.contentTransition(.numericText())`.
8. `save(keepOpen:)`: wie VT-3; bei `keepOpen` statt `dismiss()`: `outcome = nil`, `note = ""`, `photoData = nil`, `selectedPhoto = nil`, Stil-Tags `nil`, `attempts = 1`, `isSaving = false`. Grad, System, Projekt, Schuh, Set bleiben.
9. `.presentationDragIndicator(.visible)`; `.interactiveDismissDisabled(outcome != nil)`.

**Fertig wenn:** Eine Begehung ist mit 2 Gesten (Grad wischen, Ergebnis tippen) + „Sichern" erfasst. Zehn Begehungen hintereinander ohne Sheet-Wechsel möglich. Keine `Form` mehr in der Datei. Previews Boulder/Seil/mit Projekt.

---

### EF-3 · `EditAscentAssociationsSheet` angleichen

**Kontext:** Konsistenz zum neuen Erfassen.

**Dateien:** `Views/EditAscentAssociationsSheet.swift`

**Aufgabe:** Wheel-Picker durch `GradeRuler` ersetzen, Ergebnis/Stil durch `OutcomePicker` (Optionen: `AscentOutcome.quick(for:)`; ist der gespeicherte Wert nicht darin enthalten, z. B. `quit` oder `.project`, die Option zusätzlich anhängen). Löschen/Abbrechen aus VT-1 bleiben. Layout wie EF-2 Grad-Block + Ergebnis + restliche Felder in `DisclosureGroup("Details", isExpanded: $showDetails)` mit `@State showDetails = true` (beim Bearbeiten aufgeklappt).

**Fertig wenn:** Bearbeiten sieht aus wie Erfassen. Speichern schreibt Grad/System/Ergebnis/Stil/Versuche/Projekt/Schuh wie bisher.

---

### EF-4 · „Neue Session" straffen

**Kontext:** Session-Typ als 5 Listenzeilen, Dauer-Stepper in 5-min-Schritten, Halle als reiner Freitext (Review 5.2).

**Dateien:** `Views/ManualSessionView.swift`, neu `Views/Components/SessionTypeGrid.swift`

**Aufgabe:**
1. `SessionTypeGrid(selection: Binding<SessionType>)`: `LazyVGrid` 3 Spalten, Kachel `VStack { Image(systemName: type.symbol).font(.title3); Text(type.label).font(.caption.weight(.semibold)) }`, `minHeight: 64`, ausgewählt `Theme.accent`-Füllung. `.sensoryFeedback(.selection, trigger: selection)`. Ohne `.unknown`.
2. `ManualSessionView`: erste Section nutzt `SessionTypeGrid` (Row mit `.listRowInsets(EdgeInsets())` + `.listRowBackground(Color.clear)`).
3. Dauer: Standard 90 min, Stepper `step: 15`, Bereich `15...480`. Darunter Chips „1 h", „1,5 h", „2 h", „2,5 h", „3 h". Anzeige `Duration.seconds(…).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))`.
4. Halle: unter dem `TextField` horizontale Chips der bekannten Hallennamen (gleiche Logik wie `SessionDetailView.knownGymNames` – in eine statische Funktion `ClimbSession.knownGymNames(_ sessions:)` in `Models/ClimbSession.swift` verschieben und an beiden Stellen nutzen), max. 5, gefiltert nach eingegebenem Präfix (case-insensitive).
5. Titel „Session nachtragen". Button „Weiter" bleibt.

**Fertig wenn:** Session-Typ-Auswahl auf ≤ 1/4 Bildschirmhöhe. 2 h Dauer in 1 Tap. Bekannte Halle in 1 Tap.

---

### EF-5 · Session-Detail entflechten, Reflexion zweistufig

**Kontext:** Doppelte Kurzstatistik, Session-Typ im Tagebuch, 7 Eingaben in einer Karte, RPE in Rot (Review 5.3, E18).

**Dateien:** `Views/SessionDetailView.swift`

**Aufgabe:**
1. Toolbar trailing: statt einzelnem Mülleimer ein `Menu` (`ellipsis.circle`):
   - `Picker("Art der Session", selection: sessionTypeBinding)` (ohne `.unknown`) – setzt `sessionTypeRaw` + `updatedAt`
   - `Button("Zusammenfassung", systemImage: "sparkles")` (Aktion kommt in FS-7, bis dahin weglassen)
   - `Divider()`
   - `Button("Session löschen", role: .destructive)`
   Bei `onFertig != nil` zusätzlich weiterhin „Fertig"-Button.
2. `typePicker` aus `reflectionCard` entfernen und löschen.
3. Kurzstatistik unter `sessionHeader` (Tops/Versuche) löschen; die Zeile unter der Begehungsliste bleibt.
4. `reflectionCard` aufteilen:
   - **`quickCheckCard`** (`.card()`): Titel „Kurz-Check", Watch-Chips (falls vorhanden), `rpePicker`, `limiterPicker`.
   - **`reflectionCard`** (`.card()`): Titel „Reflexion" mit `Image(systemName: session.reflectionCompleted ? "checkmark.seal.fill" : "checkmark.seal")` rechts (gold wenn erledigt). Inhalt: `techniqueFocusPicker`, `focusRatingPicker` (nur `isClimbing`), drei Textfelder.
   - Sind alle drei Textfelder leer und Technik/Fokus nicht gesetzt: Karte zeigt nur Titel + Untertitel „Was hast du gelernt, was war schwer, was nimmst du mit?" + `Button("Reflexion schreiben") { withAnimation(.snappy) { reflectionExpanded = true } }` (`.bordered`). Sonst voll aufgeklappt.
5. `reflectionField`: `TextEditor`+Placeholder-Hack durch `TextField(placeholder, text:, axis: .vertical).lineLimit(2...8)` in `.inset()` ersetzen. `.onChange` bleibt.
6. `rpeColor(_:)`: `Theme.accent.opacity(0.35 + Double(rpe) * 0.065)` – keine Gold/Rot-Stufen.
7. `.scrollDismissesKeyboard(.interactively)` am `ScrollView`. Toolbar `ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { focused = nil } }` mit `@FocusState`.

**Fertig wenn:** Session-Detail zeigt in dieser Reihenfolge: Header · Health-Karte · Erfolge dieser Session · (Training) · Begehungen · Kurz-Check · Reflexion. Kein Session-Typ-Grid im Scroll-Content. Kein Rot außerhalb destruktiver Aktionen.

---

## Block FS · Fortschritt spüren

### FS-1 · `ProgressEngine.milestones`

**Kontext:** Nächste Stufe, Wohlfühl-Kandidat und Erfolge leben an vier Orten (Review 6.1, E12, E13).

**Dateien:** `Models/ProgressEngine.swift`, `ClimbReflectTests/ProgressEngineTests.swift`

**Aufgabe:**

```swift
struct Milestone: Equatable, Identifiable {
    enum Kind: Equatable { case nextGrade, comfortGrade }
    let kind: Kind
    let title: String        // "Nächste Stufe", "Wohlfühl-Grad"
    let value: String        // "7A", "6B"
    let detail: String       // "noch nicht versucht" | "2 Begehungen" | "noch 2"
    let current: Int?        // nur comfortGrade
    let target: Int?         // nur comfortGrade
    var id: Kind { kind }
}

/// Status-quo-nahe Kletter-Meilensteine einer Disziplin. Zählungen, keine Quoten (S32).
static func milestones(_ sessions: [ClimbSession], discipline: Discipline,
                       monthsBack: Int? = 6, calendar: Calendar = .current,
                       now: Date = Date()) -> [Milestone]
```

- `nextGrade`: aus `personalBests(...).send` + `nextGrade(afterOrder:)`; Begehungen des nächsten Grads aus `pyramid(... monthsBack:)` (`failedTries`). Ohne Send kein Eintrag.
- `comfortGrade`: nur wenn `comfortGrade(...)` nil und `comfortCandidate(...)` vorhanden → `current = sample`, `target = minSampleSize`, `detail = "noch \(target - current)"`.
- Reihenfolge: nextGrade, comfortGrade.
- Tests: kein Send → leer · Send ohne Folgegrad-Begehungen → „noch nicht versucht" · Kandidat 3/5 → current 3, target 5 · vorhandener Wohlfühl-Grad → kein comfort-Eintrag · Leiter-Ende → kein nextGrade.

**Fertig wenn:** Tests grün, keine View-Änderung in diesem Commit.

---

### FS-2 · Komponenten `MilestoneRow` und `ProgressRing`

**Dateien:** neu `Views/Components/MilestoneRow.swift`, neu `Views/Components/ProgressRing.swift`

**Aufgabe:**
1. `ProgressRing(current: Int, target: Int, size: CGFloat = 28)`: Hintergrundkreis `Theme.surfaceRaised` Linienbreite `size * 0.14`, Vordergrund `trim(0, fraction)` in `Theme.accent`, `rotationEffect(-90°)`, `lineCap: .round`. `.animation(.snappy, value: current)`. A11y: `accessibilityValue("\(current) von \(target)")`.
2. `MilestoneRow(icon: String, title: String, value: String, detail: String, current: Int?, target: Int?)`:
   `HStack(spacing: 12)`: links bei `current/target` ein `ProgressRing`, sonst ein 28-pt-Kreis `surfaceRaised` mit `icon` in `Theme.accent`. Mitte `VStack(alignment: .leading)`: `title` (`Theme.Typo.label`, secondary), darunter `value` (`.headline`, primary, monospacedDigit). Rechts `detail` (`.subheadline`, secondary). `accessibilityElement(children: .combine)`.
3. Convenience-Inits: `init(_ m: ProgressEngine.Milestone)` (Icon `arrow.up.forward` bzw. `checkmark.seal`) und `init(achievement: AchievementViewData)` (Icon = `definition.symbol`, title „Erfolg", value `definition.title`, detail `progress.remainingText` ohne führendes „Noch " → „noch …" kleingeschrieben, current/target aus `progress`).

**Fertig wenn:** Previews mit allen drei Arten.

---

### FS-3 · Level-Hero auf Heute

**Kontext:** E11, E12. Review 6.1.

**Dateien:** neu `Views/Components/LevelHeroCard.swift`, `Views/TodayView.swift`, `Views/Components/StatTile.swift`, `Views/Components/NextAchievementsCard.swift`

**Aufgabe:**
1. `LevelHeroCard(sessions:, projects:, unlocks:, onOpenProgress: (ProgressEngine.Discipline) -> Void)`:
   - **Disziplin:** die der jüngsten Klettersession (`GradeDefaults.discipline(for:)`), Fallback `.boulder`.
   - **Kopfzeile:** `Text(discipline == .boulder ? "Bouldern" : "Seil")` (label/secondary) + rechts `Image(systemName: "chevron.right")`.
   - **Hauptzeile:** `HStack(alignment: .firstTextBaseline)`: PB-Grad in `Theme.Typo.metricHero` (`Theme.gold`, `.contentTransition(.numericText())`), dann `Image(systemName: "arrow.right")` tertiary, dann nächster Grad in `Theme.Typo.metric` secondary. Darunter „Höchster Top · \(Monat Jahr)". Ohne PB: `—` + „Noch kein Top".
   - **Meilensteine:** `ProgressEngine.milestones(... monthsBack: 6)` + höchstens **ein** Erfolg: `AchievementViewModel.build(...)` gefiltert auf `!isUnlocked`, `!definition.isHidden`, `progress.fraction` in (0, 1), Kategorie ∈ {schwierigkeit, stil, projekte, ausdauer}, max nach `fraction`. Max. 3 `MilestoneRow`s, getrennt durch `Divider().overlay(Theme.separator)`. `nextGrade` wird hier **nicht** als Row gezeigt (steht schon in der Hauptzeile) – nur `comfortGrade` + Erfolg.
   - **Fußzeile** (nur wenn Streak ≥ 1): `Label("\(streak) Woche(n) in Folge", systemImage: "flame.fill")` + bei `best > streak` „· Rekord \(best)". Farben: Icon accent, Text secondary.
   - **Zweite Disziplin kompakt** (falls PB vorhanden): eine Zeile „Seil · 6c+" bzw. „Bouldern · 6B" tertiary unter der Fußzeile.
   - Ganze Karte `.card()`, als `Button` → `onOpenProgress(discipline)`, `.buttonStyle(.plain)`, `accessibilityHint("Öffnet Fortschritt")`.
2. `TodayView`: `heroTrophyRow`, `heroCard`, `statRow`, `nextAchievement`-Button entfernen. Reihenfolge im Content: Datum · LiveSessionBanner · MonthRecapCard · `LevelHeroCard` (nur wenn es mindestens eine Klettersession gibt) · IntentFollowUpCard · angepinnte Projekte · Letzte Sessions.
   `onOpenProgress`: `UserDefaults progressDiscipline = discipline.rawValue`; `selectedTabIndex = 1`.
3. `StatTile.swift` und `NextAchievementsCard.swift` löschen, wenn danach ungenutzt.

**Fertig wenn:** Heute zeigt oben „6C → 7A", darunter bis zu zwei Meilenstein-Zeilen und die Streak-Zeile. Tap öffnet Fortschritt in der richtigen Disziplin. Previews Voll/Spärlich/Leer.

---

### FS-4 · `SessionRow` zeigt Fortschritt statt Aufwand

**Kontext:** Zeile zeigt Dauer und RPE statt härtestem Top (Review 6.2).

**Dateien:** `Views/Components/SessionRow.swift`

**Aufgabe:**
- Links 44-pt-Kachel (`.theme(Radius.medium)`, `surfaceRaised`) mit Typ-Symbol; bei `!reflectionCompleted && isClimbing` kleiner 8-pt-Punkt `Theme.accent` oben rechts (`overlay(alignment: .topTrailing)`), Text „Reflexion offen" entfällt.
- Mitte: Zeile 1 `"\(type.label)"` + bei `gymName` „ · \(gymName)" bzw. „ · Outdoor" (`lineLimit(1)`). Zeile 2: Datum (bestehendes Format) + bei Klettersession mit Begehungen „ · \(tops) Tops" + „ · \(Dauer)".
- Rechts: härtester Top der Session (`ProgressEngine.hardest` auf Tops, Anzeige via `GradeConverter.display`) in `Theme.Typo.metric`, `textPrimary`. Ohne Top: nichts. Training: nichts.
- `DateFormatter` durch `session.date.formatted(.dateTime.weekday(.abbreviated).day().month(.twoDigits))` ersetzen.
- `accessibilityElement(children: .combine)`.

**Fertig wenn:** Session-Liste auf Heute und in „Alle Sessions" zeigt härtesten Grad rechts.

---

### FS-5 · Fortschritt-Tab mit Leitfragen und Meilensteinen

**Kontext:** Gleichartige Karten ohne Führung (Review 6.4).

**Dateien:** `Views/FortschrittView.swift`, `Views/Components/LevelHeaderView.swift`, `Views/Components/MonthRecapCard.swift`, `Views/StyleProfileView.swift` (nur lesen)

**Aufgabe:**
1. Content in drei Abschnitte mit `Text(…).font(Theme.Typo.section)` als Überschrift:
   - **„Wo stehe ich?"** → `LevelHeaderView`
   - **„Werde ich besser?"** → `GradeTimelineChart`, `PyramidChart`
   - **„Trägt die Basis?"** → `ClimbDaysCard`, Stil-Link, Monatsrückblick Vormonat
   - danach `ThrowbackCard` ohne Überschrift
2. `LevelHeaderView.factCard`: `FactRow`-Struktur durch `MilestoneRow` ersetzen. Wohlfühl-Grad (erreicht) als `MilestoneRow(icon: "checkmark.seal.fill", title: "Wohlfühl-Grad", value: grade, detail: "", current: nil, target: nil)`; Kandidat und nächste Stufe über `ProgressEngine.milestones(... monthsBack: period.monthsBack)` (FortschrittView reicht sie herein, Parameter `nextGrade`/`nextGradeTries`/`comfortCandidate` entfallen). „Erste Tops" bleibt als eigene Row (Icon `sparkles`).
3. Stil-Link: zweite Zeile unter „Stil & Limiter": häufigster Limiter im Zeitraum aus `ProgressEngine.limiterCounts` → „Häufigster Limiter: \(label)"; ohne Daten weglassen.
4. `MonthRecapCard` bekommt `var onDismiss: (() -> Void)? = nil`; X-Button nur wenn gesetzt. Im Fortschritt-Tab den Vormonat **ohne** Dismiss zeigen, wenn nicht leer (nur Disziplin-unabhängig, wie auf Heute).
5. Beim Wechsel von Disziplin/Zeitraum: Inhalt mit `.animation(.snappy, value: disciplineRaw)` und `.animation(.snappy, value: period)`.

**Fertig wenn:** Drei sichtbare Leitfragen. Keine `FactRow` mehr. Monatsrückblick auch nach Tag 7 im Fortschritt sichtbar.

---

### FS-6 · Projekt als Erzählung: Klettertag-Zeitleiste

**Kontext:** E16. Review 6.5.

**Dateien:** neu `Views/Components/ProjectDayTimeline.swift`, `Views/ProjectDetailView.swift`, `Views/ProjectsView.swift`

**Aufgabe:**
1. `ProjectDayTimeline(project:)`: Tage = sortierte `startOfDay` aller Begehungen. Top-Tag = erster Tag mit `result == .top`.
   - Horizontale `ScrollView` mit `HStack(spacing: 0)`: pro Tag ein Kreis 14 pt (`Theme.surfaceRaised`, Stroke accent 1.5) verbunden durch 2-pt-Linien (`Theme.separator`); Top-Tag: 22 pt gefüllt `Theme.gold` mit `checkmark` `Theme.bg`.
   - Unter jedem Punkt „Tag n"; unter erstem und letztem zusätzlich Datum kurz.
   - `.defaultScrollAnchor(.trailing)`.
   - Kopf: „Tag \(count) am Projekt" bzw. bei Top „Geschafft an Tag \(index)" (gold).
   - Nur anzeigen ab 1 Tag.
2. `ProjectDetailView`: Timeline direkt unter Header + „Begehung erfassen"-Button (VT-8) einsetzen.
3. `ProjectsView.projectRow` für Status „Geschafft": Icon-Kreis `Theme.gold.opacity(0.15)` + `trophy.fill` in `Theme.gold`; Aufgegeben: Zeile `.opacity(0.6)`.

**Fertig wenn:** Projekt-Detail zeigt Tages-Zeitleiste. Geschaffte Projekte sind in der Liste gold.

---

### FS-7 · Session-Recap nach Watch-Session

**Kontext:** E14. Review 6.3. Kein zweiter Feier-Kanal (S33): statisch, keine Partikel, keine Sounds.

**Dateien:** `Models/ProgressEngine.swift`, `ClimbReflectTests/ProgressEngineTests.swift`, `Services/WatchSessionReceiver.swift`, neu `Views/SessionRecapSheet.swift`, `Views/DashboardView.swift`, `Views/SessionDetailView.swift`

**Aufgabe:**
1. Engine:

```swift
struct SessionRecap: Equatable {
    let hardestTop: String?          // Anzeige-Grad
    let tops: Int
    let ascents: Int
    let firstTopGrades: [String]     // in dieser Session erstmals überhaupt getoppt, absteigend
    let projectsCompleted: [String]  // Projektnamen, deren erster Top in dieser Session liegt
    let discipline: Discipline?
}

static func sessionRecap(_ session: ClimbSession, allSessions: [ClimbSession]) -> SessionRecap
```

   Erst-Top-Logik über `earliestSendDates` (je Disziplin, Anzeige-System) – Grad zählt, wenn früheste Top-Begehung zu dieser Session gehört. Tests: Erst-Top · wiederholter Grad kein Erst-Top · Projekt-Abschluss · leere Session.
2. Receiver: Nach erfolgreichem **Neu**-Insert (nicht Upsert-Pfad, nicht Training) die Session-ID in `UserDefaults` `pendingRecapSessionID` (String, überschreibt) schreiben.
3. `SessionRecapSheet(session:)`, `.presentationDetents([.medium, .large])`, `Theme.bg`:
   - Kopf: Typ-Symbol + „\(type.label) · \(Datum)" (secondary), darunter größte Aussage in `Theme.Typo.metricHero`, Priorität: Projekt geschafft („\(Name) geschafft") > Erst-Top („Erster Top in \(Grad)") > härtester Top („\(Grad)") > „\(ascents) Begehungen". Gold nur für Projekt/Erst-Top.
   - Zeile: „\(tops) Tops · \(ascents) Begehungen · \(Dauer)".
   - Weitere Erst-Tops (ab dem zweiten) als Chips.
   - „Freigeschaltet" – statische Liste der `AchievementUnlock` mit `sessionID == session.id` (Medaillon klein, statisch, `AchievementMedallion` im unlocked-Zustand, kein Glow-Effekt).
   - „Als Nächstes" – `MilestoneRow`s aus `ProgressEngine.milestones` der Session-Disziplin (max. 2).
   - Sheet-Inhalt steckt in eigenem `NavigationStack`. Buttons unten: „Kurz reflektieren" (`.borderedProminent`) = `NavigationLink { SessionDetailView(session: session) }` innerhalb des Sheets; beim Push `@State detent` auf `.large` setzen (`presentationDetents(_:selection:)`) · „Später" (`.bordered`) = `dismiss()`. Kein Tab-Wechsel, keine globale Navigation.
   - `accessibilityElement(children: .contain)`, VoiceOver liest die Hauptaussage zuerst.
4. `DashboardView`: `@AppStorage("pendingRecapSessionID") var pendingRecapID = ""`. Sheet anzeigen, wenn `!pendingRecapID.isEmpty && currentUnlock == nil && toastUnlock == nil` und Session existiert; beim Schließen `pendingRecapID = ""`. Prüfung bei `.task`, `scenePhase == .active` und `onChange(of: currentUnlock?.id)`.
5. `SessionDetailView`: Menü-Eintrag „Zusammenfassung" (aus EF-5) öffnet dasselbe Sheet (nur Klettersessions mit Begehungen).

**Fertig wenn:** Nach Empfang einer Watch-Session erscheint beim Öffnen der App zuerst ggf. das Erfolgs-Overlay, danach das Recap. Recap zeigt Erst-Top/Projekt korrekt. Tests grün. Kein Timer, keine Partikel, keine Sounds im Recap.

---

### FS-8 · Erfolge-Tab Feinschliff

**Dateien:** `Views/AchievementsView.swift`

**Aufgabe:**
1. Kopf: `unlockedCount` mit `.contentTransition(.numericText())`; Balken-Breite animiert `.animation(.snappy, value: unlockedCount)`.
2. „In Reichweite": Zeilen `MilestoneRow(achievement:)` in `.card()` statt eigener HStack-Zeilen; Tap öffnet Detail-Sheet wie bisher.
3. Kategorie-Chips: `.sensoryFeedback(.selection, trigger: selectedCategory)`, Grid-Wechsel `.animation(.snappy, value: selectedCategory)`.

**Fertig wenn:** „In Reichweite" nutzt `MilestoneRow`. Kategorie-Wechsel animiert.

---

## Block HM · Haptik & Motion

### HM-1 · Haptik auf alle Kerninteraktionen

**Kontext:** Nur 4 Haptik-Stellen am iPhone (Review Kap. 4).

**Dateien:** laut Tabelle

**Aufgabe:** `UIFeedbackGenerator`-Aufrufe in Views durch `.sensoryFeedback` ersetzen und ergänzen. Effekte respektieren die Systemeinstellung automatisch.

| Datei | Trigger | Feedback |
|---|---|---|
| `AddAscentView` | erfolgreicher Save (State-Zähler `savedCount`) | `.success` |
| `EditAscentAssociationsSheet` | Save / Löschen | `.success` / `.impact(weight: .medium)` |
| `SessionDetailView` | RPE-Wert, Limiter-Toggle, Technik-Fokus, Fokus-Rating | `.selection` |
| `SessionDetailView` | `reflectionCompleted` false → true | `.success` |
| `ProjectDetailView` / `ProjectsView` | `isPinned` | `.impact(weight: .light)` |
| `ProjectDetailView` | Status aufgegeben / reaktiviert | `.impact(weight: .medium)` |
| `FortschrittView` | `disciplineRaw`, `period` | `.selection` |
| `ManualSessionView` | Dauer-Chip, Hallen-Chip, Outdoor-Toggle | `.selection` |
| `TodayView` | Monatsrückblick schließen | `.impact(weight: .light)` |
| Chips in `AddAscentView` („Zuletzt", Tags) | Auswahl | `.selection` |

`AchievementToast`/`AchievementUnlockOverlay` unverändert lassen (eigene, abschaltbare Choreografie S34).

**Fertig wenn:** `grep -rn FeedbackGenerator Views/` findet nur noch die Erfolgs-Komponenten.

---

### HM-2 · Übergänge & Symbol-Effekte

**Dateien:** `LevelHeaderView`, `LevelHeroCard`, `ClimbDaysCard`, `PyramidChart`, `GradeTimelineChart`, `ProjectDetailView`, `SessionDetailView`, `TodayView`, `ProjectsView`

**Aufgabe:**
1. Alle Kennzahlen-`Text`s (PB-Grade, Zählungen, Streak, Tops/Tage-Pills) → `.contentTransition(.numericText())` (bei Grad-Strings `.interpolate`).
2. Charts: `.animation(.snappy, value: <Datenquelle>.count)` bzw. auf ein `Equatable`-Array.
3. Pin-Symbol: `.symbolEffect(.bounce, value: project.isPinned)`. Reflexions-Siegel: `.symbolEffect(.bounce, value: session.reflectionCompleted)`.
4. Listen „Letzte Sessions", Begehungen im Session-Detail, Projektsektionen: `.animation(.snappy, value: ids)` mit Zeilen-`.transition(.opacity.combined(with: .move(edge: .top)))`.
5. Alles unter `@Environment(\.accessibilityReduceMotion)`: bei `true` `.animation(nil, …)` für Move-Transitions (numericText/Opacity bleiben erlaubt).

**Fertig wenn:** Disziplinwechsel im Fortschritt zählt Werte sichtbar um; neue Begehung gleitet in die Liste; mit Reduce Motion keine Bewegungen.

---

## Block WT · Watch (minimal)

### WT-1 · Grad-Startwert aus der laufenden Session

**Kontext:** `AttemptLogView` startet ohne Projekt immer bei Index 0 (F8, E5).

**Dateien:** `ClimbReflectWatch Watch App/Views/AttemptLogView.swift`

**Aufgabe:** `onAppear`: zuerst `workoutManager.attempts.last(where: { $0.grade != nil && $0.gradeSystem == gradeSystem })` → dessen Index; sonst bestehender Projekt-Pfad; sonst Index 0. Kommentar zu GR-1 kurz auf „E5: letzte Session-Begehung → Projekt → 0 (S37)" kürzen.

**Fertig wenn:** Zweite Begehung einer Session startet auf dem Grad der ersten. Speicher-Verhalten (S22) unverändert: keine neuen `@Published`, keine neuen Observer.

---

### WT-2 · Ergebnis-Buttons je Disziplin, neutrale Abbruch-Farbe, Summary-Label

**Dateien:** `ClimbReflectWatch Watch App/Views/AttemptLogView.swift`, `ClimbReflectWatch Watch App/Views/SessionSummaryView.swift`

**Aufgabe:**
1. `outcomes` wird berechnet: bei `gradeSystem.isBoulder` (bzw. `sessionType == .boulder`, Watch-Enum prüfen) ohne „Onsight" und ohne „Rotpunkt" → Flash · Top · Versuch · Abbruch (2×2). Seil unverändert 6 Buttons.
2. „Abbruch"-Farbe `WatchTheme.danger` → `WatchTheme.textSecond`.
3. `SessionSummaryView`: Label „Versuche" (Wert `ascents.count`) → „Begehungen".

**Fertig wenn:** Boulder-Session zeigt 4 Ergebnis-Buttons. Summary zeigt „Begehungen" und „Tops".

---

## Block AX · Barrierefreiheit

### AX-1 · Labels, Gruppierung, Trefferflächen

**Kontext:** 0 Accessibility-Labels (Review Kap. 8). Baut auf den neuen Komponenten auf.

**Dateien:** alle iOS-Views mit Icon-only-Buttons und Karten

**Aufgabe:**
1. Jeder Icon-only-`Button`/`NavigationLink`/`Menu`: `.accessibilityLabel` (z. B. „Session hinzufügen", „Einstellungen", „Weitere Aktionen", „Beta-Bibliothek", „Begehung hinzufügen").
2. Karten als eine Einheit: `IntentFollowUpCard`, `MonthRecapCard`, `ThrowbackCard`, `AscentRowView`, Projektzeilen, `ClimbDaysCard` → `.accessibilityElement(children: .combine)`.
3. Charts: `.accessibilityChartDescriptor` nicht nötig; stattdessen `.accessibilityLabel` mit Kernaussage (z. B. Pyramide: „Meiste Tops in \(Grad)").
4. Chips (Tags, Kategorien, Hallen, Dauer): `.frame(minHeight: 44)` über `contentShape(Rectangle())` + vertikales Padding ≥ 10, visuelle Größe darf kleiner bleiben (`.padding(.vertical, 10)` außen um Capsule mit `.contentShape`).
5. Ausgewählte Chips: `.accessibilityAddTraits(.isSelected)`.
6. Dichte Zeilen (`SessionRow`, `MilestoneRow`): bei `dynamicTypeSize >= .accessibility1` Layout von `HStack` auf `VStack(alignment: .leading)` umschalten (`ViewThatFits` oder `AnyLayout`).

**Fertig wenn:** VoiceOver-Durchlauf Heute → Session-Detail → Begehung erfassen ohne unbenannte Elemente. Previews bei `.accessibility3` ohne abgeschnittene Kerninhalte.

---

## Block DOC · Dokumentation

### DOC-1 · CLAUDE.md fortschreiben

**Dateien:** `ClimbReflectWatch Watch App/CLAUDE.md`

**Aufgabe:** Neue Prinzipien anhängen (Stil wie S35–S38, je 4–8 Zeilen):

- **S39 – Glossar ist verbindlich.** Begehung / Top / Versuch / Abgebrochen / Geschafft / Aufgegeben / Klettertag / Reflexion (E8). Kein „Send" in UI-Strings.
- **S40 – Designsystem statt Einzelwerte.** Farben, Radien (`Theme.Radius`, immer `.continuous`), Schrift (`Theme.Typo`, Dynamic Type) nur über Tokens. Kein `.system(size:)` außer Erfolgs-Artwork. Kein dekorativer Hintergrund; `AppBackground` nur auf Tab-Roots. Dark Mode ausschließlich über `UIUserInterfaceStyle`.
- **S41 – Jede Kerninteraktion hat Feedback.** Auswahl → `.selection`, Speichern → `.success`, Zustandswechsel → `.impact`, Kennzahlen mit `numericText`. Nur `sensoryFeedback`, keine `UIFeedbackGenerator` in Views (außer Erfolgs-Choreografie S34).
- **S42 – Kein vorausgewähltes Ergebnis, keine blockierende Bestätigung.** Ergebnis beim Erfassen startet leer (E6); Speichern schließt sofort. Einziger Feier-Kanal bleibt `AchievementUnlockOverlay` (S33); Session-Recap ist Zusammenfassung ohne Effekte (E14).
- **S43 – Meilensteine an einem Ort, in einer Form.** `ProgressEngine.milestones` + `MilestoneRow`; Ring nur bei echter Zählung (E13).
- **S44 – `swipeActions` nur in `List`.** Außerhalb: `contextMenu` + Bestätigung.

Außerdem Abschnitt 7 „Offene Punkte": TODO17 als erledigt eintragen mit Verweis auf dieses Dokument; festhalten, dass TODO17 spec-first ohne Claude-Design-Mockup umgesetzt wurde (Björn-Freigabe), und dass `MountainBackground` bewusst gelöscht ist (Onboarding ON muss eigene Gestaltung bekommen).

**Fertig wenn:** S39–S44 stehen in `CLAUDE.md`, Abschnitt 7 aktualisiert.

---

## Abschluss-Checkliste (nach DOC-1)

- [ ] Beide Schemes bauen, `ClimbReflectTests` grün (neu: `GradeDefaultsTests`, `milestones`, `sessionRecap`)
- [ ] `grep`-Checks: kein `swipeActions` außerhalb `List`, kein `MountainBackground`, kein `preferredColorScheme` außerhalb Previews, kein `.system(size:` außer Erfolgs-Artwork, kein `.attempts`-Aggregat in Views, kein „Send"/„Redpoint" in UI-Strings, kein `CelebrationOverlay`
- [ ] Walkthrough Gerät: Watch-Session → App öffnen → Overlay → Recap → „Kurz reflektieren" → Reflexion speichern
- [ ] Walkthrough: Session nachtragen (Seil) → 5 Begehungen mit „Sichern & nächste" → Begehung löschen → Verwerfen einer leeren Session
- [ ] Walkthrough: Projekt → „Begehung erfassen" → Zeitleiste zeigt neuen Tag
- [ ] VoiceOver kurz auf Heute und Begehung erfassen
- [ ] Merge `feature/premium-ux` → `dev`
