# TODO18 – Premium-Polish (nach Abnahme TODO17)

> **Ablage im Repo:** `ClimbReflectWatch Watch App/TODO18-PREMIUM-POLISH.md`
> **Referenz:** `TODO17-ABNAHME.md` (Befunde R1–R9, Kap. 4.1–4.8), `TODO17-PREMIUM-UX.md` (Entscheidungen E1–E18)
> **Basis:** `origin/dev` @ `1c00956`

---

## 0. Regeln für die ausführende KI

1. **Plan-Basis prüfen (neu, Pflicht):** Vor dem Start `git log --oneline 1c00956..origin/dev`. Für **jede** Aufgabe zusätzlich `git log --oneline 1c00956..HEAD -- <Dateien der Aufgabe>`. Widerspricht ein neuerer Commit der Aufgabe, gewinnt der Commit. Die Aufgabe wird angepasst und die Abweichung im Commit-Text genannt. (Anlass: WT-1 hat die Grad-Pflicht aus `039e0d9` überschrieben.)
2. **Branch:** `feature/premium-polish` von `dev`.
3. **Eine Aufgabe = ein Commit.** Format: `fix(scope): KR-1 – …`, `feat(…)`, `refactor(…)`.
4. **Nach jedem Commit:** Schemes `ClimbReflect` und `ClimbReflectWatch Watch App` bauen, `ClimbReflectTests` grün.
5. **Eine Aufgabe ist erst fertig, wenn alle „Fertig wenn"-Punkte erfüllt sind – inklusive Tests.** Nicht erfüllte Punkte im Commit-Text als „OFFEN:" nennen, nie stillschweigend weglassen.
6. Reihenfolge: **KR-1 … KR-9 → PG-1 … PG-10 → DOC-2.**
7. Alle Regeln aus TODO17 §0 gelten weiter: iOS 17 APIs, keine neuen Abhängigkeiten, keine Schemaänderung, S-Prinzipien, deutsche Strings, Previews.
8. **Code-Stil (Björn):** minimal, menschlich lesbar, keine Über-Abstraktion. Animationen nur dezent (≤ 0,25 s, `.snappy`), nie dekorativ. Keine Kommentare, die nur den Code nacherzählen.

---

## 1. Entscheidungen

| ID | Entscheidung |
|---|---|
| **E5′** (ersetzt E5) | Watch-Grad: letzte Begehung der Session (gleiches System) → Projekt-Grad → **`nil` = Grad-Pflicht** (`039e0d9`). Kein Index-0-Fallback. |
| E19 | **Gold nur für Erreichtes:** PB-Grad (Hero, Grad-Verlauf-Top-Linie, NEU-Badge), geschaffte Projekte, Erst-Top/Projekt-Aussage im Recap, Flash/Onsight (Auswahl + Stil-Badge), Erfolge, gefülltes Reflexions-Siegel. Alles andere ist Accent oder neutral. |
| E20 | `textTertiary` = `#848D9A` (≥ 4,8 : 1 auf allen Flächen). |
| E21 | Jede tappbare Karte oder Zeile nutzt `CardButtonStyle` (Druckzustand). |
| E22 | Eine Icon-Kachel-Form in der App: abgerundetes Quadrat (`IconTile`). Kreise nur für `ProgressRing`/`MilestoneRow`. |
| E23 | Erfolgs-Haptik (`.success`/`.impact`) sitzt an der View, **deren Liste sich ändert**, nicht an Sheets, die sich gleich schließen. |
| E24 | Primäre Aktion in Erfassungs-Flows unten in Daumenreichweite (`safeAreaInset`), Toolbar nur „Abbrechen". |
| E25 | Session-Detail-Reihenfolge: Zusammenfassung → Erfolge → Begehungen → Kurz-Check → Reflexion → Messwerte. |
| E26 | Recap nur bei ≥ 1 Begehung, Detent `.large`, Hauptaussage immer mit Eyebrow-Label. |
| E27 | Disziplin-Namen einheitlich **„Boulder" / „Seil"** über `ProgressEngine.Discipline.label`. |

---

## Block KR · Korrekturen

### KR-1 · Watch-Grad-Pflicht wiederherstellen

**Kontext:** WT-1 setzt `gradeIndex = 0` als Fallback und hebelt die Grad-Pflicht aus `039e0d9` aus (Abnahme R1, E5′).

**Dateien:** `ClimbReflectWatch Watch App/Views/AttemptLogView.swift`, `ClimbReflectWatch Watch App/CLAUDE.md`

**Aufgabe:**
1. Den letzten `else`-Zweig in `onAppear` löschen, sodass `gradeIndex` ohne Session-Begehung und ohne Projekt-Grad `nil` bleibt. Die Session-Begehung behält Vorrang.
2. Kommentar: `// E5′: letzte Session-Begehung → Projekt → nil (Grad-Pflicht, 039e0d9)`.
3. `CLAUDE.md` S37 um einen Satz ergänzen: „Auf der Watch gilt statt eines Fallbacks die Grad-Pflicht (`gradeIndex = nil` bis zur aktiven Wahl)."

**Fertig wenn:** Erste Begehung einer Session ohne Projekt zeigt „–". Banken ohne Grad löst die bestehende Fehler-Haptik aus. Die zweite Begehung startet auf dem Grad der ersten.

---

### KR-2 · Fehlende Tests nachliefern

**Kontext:** VT-4, FS-1 und FS-7 ohne Tests (Abnahme R2). Stil wie `ProgressEngineTests.swift` (XCTest).

**Dateien:** neu `ClimbReflectTests/GradeDefaultsTests.swift`, `ClimbReflectTests/ProgressEngineTests.swift`

**Aufgabe:**
- `GradeDefaultsTests`:
  - Projekt-Grad gewinnt.
  - Session-Begehung gewinnt vor Historie.
  - Historie greift bei leerer Session.
  - Seil-Session ohne Daten → French, erster Grad.
  - Boulder-Projekt in Seil-Session wird ignoriert.
  - `boulderScale = vScale` wird respektiert; UserDefaults-Key im `tearDown` zurücksetzen.
- `milestones`:
  - Kein Top → leer.
  - Nächster Grad unversucht → Detail „noch nicht versucht".
  - Nächster Grad mit 2 Fehlversuchen → „2 Begehungen".
  - Kandidat 3/5 → `current 3, target 5, detail "noch 2"`.
  - Vorhandener Wohlfühl-Grad → kein Kandidat.
  - Leiter-Ende → kein `nextGrade`.
- `sessionRecap`:
  - Erster Top eines Grads.
  - Wiederholter Grad ist kein Erst-Top.
  - Projekt mit erstem Top in der Session → `projectsCompleted`.
  - Training → `discipline == nil`.
  - Härtester Top in Anzeige-Skala.

**Fertig wenn:** Mindestens 16 neue Testfälle, alle grün.

---

### KR-3 · Haptik korrekt auslösen

**Kontext:** Haptik pro Tastendruck, 5-fach in `ForEach`, verschluckt beim Schließen (Abnahme R3, E23).

**Dateien:** `Views/ManualSessionView.swift`, `Views/AddAscentView.swift`, `Views/EditAscentAssociationsSheet.swift`, `Views/SessionDetailView.swift`, `Views/ProjectDetailView.swift`

**Aufgabe:**
1. `ManualSessionView`:
   - `.sensoryFeedback(trigger: gymName)` entfernen. Stattdessen `@State gymChipTap = 0`, im Chip-Button `gymChipTap += 1`, Feedback auf `gymChipTap`.
   - `.sensoryFeedback(trigger: durationMinutes)` aus der `ForEach` an die umschließende `ScrollView` verschieben (einmal).
2. `AddAscentView`: `.sensoryFeedback(.success, trigger: savedCount)` und `savedCount` entfernen.
3. `EditAscentAssociationsSheet`: `savedTrigger`, `deletedTrigger` und beide `.sensoryFeedback` entfernen.
4. `SessionDetailView` (am `ScrollView`) und `ProjectDetailView`:

```swift
.sensoryFeedback(trigger: session.ascents.count) { old, new in
    new > old ? .success : (new < old ? .impact(weight: .medium) : nil)
}
```

   Im Projekt-Detail mit `project.ascents.count`.

**Fertig wenn:** Tippen im Hallen-Feld vibriert nicht. Dauer-Chip vibriert genau einmal. Sichern (auch „Sichern & nächste") und Löschen einer Begehung vibrieren spürbar genau einmal. *(Gerät)*

---

### KR-4 · Toolbar-Buttons mit System-Zuständen

**Kontext:** `.foregroundStyle(Theme.accent)` auf Toolbar-Buttons überschreibt die deaktivierte Darstellung (Abnahme R4).

**Dateien:** alle Views mit `ToolbarItem`-Buttons (`grep -rn -A2 "ToolbarItem" Views`)

**Aufgabe:** Auf **allen** Toolbar-Buttons `.foregroundStyle(...)` entfernen. Farbe kommt aus `.tint(Theme.accent)` am `NavigationStack`/`TabView`. „Abbrechen" ebenfalls ohne eigene Farbe. Primäre Aktionen behalten `.fontWeight(.semibold)`. Menü-Labels (`ellipsis.circle`) ohne `foregroundStyle`.

**Fertig wenn:** `grep -rn -B4 "foregroundStyle" Views | grep ToolbarItem` findet nichts mehr. Deaktivierte Buttons erscheinen grau. *(Gerät)*

---

### KR-5 · Beschriftete Detail-Felder

**Kontext:** `Picker` außerhalb von `Form` zeigt kein Label (Abnahme R5).

**Dateien:** `Views/AddAscentView.swift`, `Views/EditAscentAssociationsSheet.swift`

**Aufgabe:** Jeden `Picker` in `detailsContent` in eine Zeile packen:

```swift
LabeledContent("Grad-System") {
    Picker("Grad-System", selection: $gradeSystem) { … }
        .pickerStyle(.menu)
        .labelsHidden()
}
.foregroundStyle(Theme.textPrimary)
```

Gilt für Grad-System, Ergebnis, Stil, Schuh. Stepper bleibt. Zwischen den Zeilen `Divider().overlay(Theme.separator)`. Tag-Reihen, Set, Foto und Notiz behalten ihre Titel.

**Fertig wenn:** Jedes Feld unter „Details" hat links ein Label und rechts den Wert.

---

### KR-6 · Grad-Leiste robust und eindeutig

**Kontext:** Markierung schneidet den Text, Startposition nicht verlässlich, Grad dreifach angezeigt (Abnahme R6).

**Dateien:** `Views/Components/GradeRuler.swift`, `Views/AddAscentView.swift`, `Views/EditAscentAssociationsSheet.swift`

**Aufgabe:**
1. `GradeRuler`:
   - `LazyHStack` → `HStack` (maximal ~30 Grade).
   - Äußere `ScrollViewReader`. In `.onAppear` und `.onChange(of: grades)`: `proxy.scrollTo(selection, anchor: .center)` ohne Animation.
   - `@State private var isReady = false`. Der `set` der `scrollBinding` ignoriert Werte, solange `!isReady`. Nach dem ersten `scrollTo`: `Task { await Task.yield(); isReady = true }`.
   - `.scrollPosition(id:anchor: .center)`.
   - Markierung aus `.overlay` entfernen. Stattdessen:

```swift
VStack(spacing: 6) {
    ScrollView … .frame(height: 44)
    Capsule().fill(Theme.accent).frame(width: 16, height: 3)
}
```

   - Items: nicht ausgewählt `Theme.textSecondary`, ausgewählt `Theme.accent`. `scrollTransition` bleibt.
2. `AddAscentView.gradeBlock`: `Text(gradeSystem.label)` entfernen. „Zuletzt"-Chips zentrieren (`HStack` in `frame(maxWidth: .infinity)`), Label „Zuletzt:" entfernen. Chips erhalten `.frame(minHeight: 44).contentShape(Rectangle())`.
3. `EditAscentAssociationsSheet`: gleiche Anpassungen am Grad-Block.

**Fertig wenn:** Beim Öffnen mit vorbelegtem Grad 6B steht die Leiste mittig auf 6B, ohne Sprung. Die Markierung liegt unter der Leiste. Kein Strich durch den Text. *(Gerät, auch bei French-Leiste und Grad am Leiter-Ende)*

---

### KR-7 · Recap schärfen

**Kontext:** Recap bei 0 Begehungen, halbe Höhe, Reflexion schwer erreichbar, Hauptaussage ohne Kontext, Rekursion (Abnahme R7, E26).

**Dateien:** `Services/WatchSessionReceiver.swift`, `Views/DashboardView.swift`, `Views/SessionRecapSheet.swift`, `Views/SessionDetailView.swift`

**Aufgabe:**
1. **Receiver:** `pendingRecapSessionID` nur setzen, wenn `sessionType != .training && !dto.ascents.isEmpty`.
2. **`SessionRecapSheet`:**
   - `.presentationDetents([.large])`. Die `detent`-States entfallen.
   - `headline` liefert `(eyebrow: String, text: String, gold: Bool)`:

| Fall | Eyebrow | Text | Gold |
|---|---|---|---|
| Projekt geschafft | „Projekt geschafft" | Projektname | ja |
| Erster Top | „Erster Top" | Grad | ja |
| Härtester Top | „Härtester Top" | Grad | nein |
| sonst | „Session" | „N Begehungen" | nein |

   - Eyebrow in `Theme.Typo.label`/`textSecondary` über dem Hero-Text, zwischen Kopfzeile und Hero 20 pt Abstand.
   - Hero-Text `.lineLimit(2).minimumScaleFactor(0.7)`.
   - Buttons: „Kurz reflektieren" `.borderedProminent` volle Breite, darunter `Button("Später") { dismiss() }.buttonStyle(.plain).foregroundStyle(Theme.textSecondary)`. Die Bottom-Bar erhält `padding(.bottom, 8)`.
   - `navigationDestination` → `SessionDetailView(session:, focusReflection: true, showsRecapAction: false)`.
3. **`SessionDetailView`:**
   - Neue Parameter `var focusReflection = false`, `var showsRecapAction = true`.
   - `ScrollView` in `ScrollViewReader`, Reflexionskarte `.id("reflection")`.
   - `.task`: wenn `focusReflection` → `reflectionExpanded = true`, `try? await Task.sleep(for: .milliseconds(350))`, `withAnimation(.snappy) { proxy.scrollTo("reflection", anchor: .top) }`.
   - Menüpunkt „Zusammenfassung" nur bei `showsRecapAction`.
4. **`DashboardView`:** Recap nur bei `!(recapSession?.ascents.isEmpty ?? true)`.

**Fertig wenn:** Watch-Session ohne Begehung zeigt kein Recap. „Kurz reflektieren" landet direkt auf der aufgeklappten Reflexion. Hauptaussage hat immer ein Eyebrow.

---

### KR-8 · Reflexions-Siegel eindeutig

**Kontext:** Das Siegel ist gold, obwohl die Reflexion leer ist (Abnahme R8).

**Dateien:** `Views/SessionDetailView.swift`

**Aufgabe:** Siegel und `symbolEffect` an `hasReflectionContent` binden statt an `reflectionCompleted`. `reflectionCompleted` (Modell, Reminder-Logik) bleibt unverändert. Den `.success`-Trigger `reflectionJustCompleted` entfernen; die Haptik kommt über KR-3 bzw. entfällt.

**Fertig wenn:** Nach nur einem RPE-Tipp bleibt das Siegel leer und grau. Nach Text in einem Reflexionsfeld wird es gold.

---

### KR-9 · S31/S32 in den Session-Insights

**Kontext:** „Belastung (sRPE)" verstößt gegen S31, „Erfolgsquote" ohne Stichprobe gegen S32 (Abnahme R9).

**Dateien:** `Views/SessionDetailView.swift`

**Aufgabe:**
1. Eintrag `insights.load` aus `insightsMetrics` entfernen. `StatsEngine.SessionInsights.load` bleibt, weil `StatsEngineTests` es nutzt.
2. `successRate` nur zeigen, wenn `insights.ascentCount >= ProgressEngine.minSampleSize`. Label „Erfolgsquote", Wert `"\(Int(rate * 100)) % · n=\(insights.ascentCount)"`.
3. „Top-Grad"-Kachel: Farbe `Theme.accent` statt Gold (E19).

**Fertig wenn:** Keine sRPE-Kachel. Erfolgsquote nur ab 5 Begehungen und mit n.

---

## Block PG · Premium-Gefühl

### PG-1 · Farbsemantik und Lesbarkeit

**Kontext:** Gold verwässert, „Abgebrochen" rot, dritte Textstufe unter 4,5 : 1 (Abnahme 4.2, 4.3, E19, E20).

**Dateien:** `Theme/Theme.swift`, `Models/Enums.swift`, `Views/SessionDetailView.swift`, `Views/TodayView.swift`, `Views/ProjectsView.swift`, `Views/Components/LiveSessionBanner.swift`, `Views/Components/MonthRecapCard.swift`, `Views/ShoesView.swift`, `Views/ManualSessionView.swift`

**Aufgabe:**
1. `Theme.textTertiary = Color(hex: 0x848D9A)`.
2. `AscentResult.color`: `.attempt → Theme.textSecondary`, `.quit → Theme.textTertiary`.
3. Gold → Accent/neutral:

| Datei | Element | Neu |
|---|---|---|
| `SessionDetailView` | „Versuche"-Label unter Begehungen | `textSecondary` |
| `SessionDetailView` | Energie-Kachel (`flame.fill`) | `accent` |
| `SessionDetailView` | Trainings-Zusatzgewicht | `textPrimary` |
| `SessionDetailView` | Fokus-Bewertung aktive Sterne | `accent` |
| `TodayView` | Icon angepinnter Projekte | via `IconTile` in PG-2, `accent` |
| `ProjectsView` | Pin-Icon | `accent` |
| `LiveSessionBanner` | Pause-Zustand (Stroke, Fill, Icon, Text) | `textSecondary` |
| `MonthRecapCard` | Icon-Kreis | `accent` |
| `ShoesView` | Status „eingetragen" | `accent` |

4. Alle `Section`-Header-Texte in Forms (`Text("…").foregroundStyle(Theme.textTertiary)` im `header:`) → `Theme.textSecondary`.

**Fertig wenn:** `grep -rn "Theme.gold" Views | grep -v Achievement` zeigt nur noch Stellen aus der E19-Whitelist. `AscentRowView` zeigt Versuche grau, Abgebrochen gedämpft grau.

---

### PG-2 · Druckzustand und Icon-Kachel

**Kontext:** Karten ohne Feedback beim Berühren, zwei Icon-Formen (Abnahme 4.1, 4.5, E21, E22).

**Dateien:** neu `Theme/CardButtonStyle.swift`, neu `Views/Components/IconTile.swift`; Anwendung in `LevelHeroCard`, `SessionRow`-Aufrufern (`TodayView`, `AllSessionsView`), `TodayView.pinnedProjectsCard`, `ProjectsView.projectRow`, `FortschrittView.styleLink`, `AchievementsView` (In Reichweite), `ThrowbackCard`, `IntentFollowUpCard`, `MonthRecapCard`, `SessionDetailView.sessionHeader`, `ProjectDetailView.headerCard`

**Aufgabe:**
1. Neue Datei `Theme/CardButtonStyle.swift`:

```swift
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressedLabel(configuration: configuration)
    }

    private struct PressedLabel: View {
        let configuration: Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .contentShape(.rect(cornerRadius: Theme.Radius.card, style: .continuous))
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(.snappy(duration: 0.18), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { .init() }
}
```

   Falls `.rect(cornerRadius:style:)` auf iOS 17 nicht kompiliert: `RoundedRectangle(cornerRadius:style:)`.
2. Neue Datei `Views/Components/IconTile.swift`:

```swift
struct IconTile: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle.theme(Theme.Radius.small).fill(tint.opacity(0.14)))
            .accessibilityHidden(true)
    }
}
```

3. Alle genannten tappbaren Karten und Zeilen: `.buttonStyle(.plain)` → `.buttonStyle(.card)`.
   **`LevelHeroCard`:** `.card()` **in** das Button-Label verschieben, damit die ganze Karte tappbar ist und gemeinsam einsinkt.
4. Icon-Kreise und die 44-pt-Quadrate durch `IconTile` ersetzen:

| Ort | Größe | Tint |
|---|---|---|
| SessionRow | 40 | accent |
| angepinnte Projekte | 40 | accent |
| Projektliste | 40 | gold bei geschafft, `textTertiary` bei aufgegeben, sonst accent |
| MonthRecapCard | 40 | accent |
| Session-Header | 52 | accent |
| Projekt-Header | 52 | Status-Farbe |

   Den Reflexions-Punkt der SessionRow als `.overlay(alignment: .topTrailing)` auf der `IconTile` mit `offset(x: 3, y: -3)` belassen.

**Fertig wenn:** Jede tappbare Karte sinkt beim Berühren sichtbar leicht ein, bei Reduce Motion nur Abdunklung. Keine `Circle().fill(...)` hinter SF-Symbolen mehr außer in `MilestoneRow`.

---

### PG-3 · Konsistenz-Sweep

**Kontext:** Abschnittsüberschriften, Divider, Radien, Dauer-Format und Disziplin-Namen uneinheitlich (Abnahme 4.5, E27).

**Dateien:** neu `Views/Components/SectionHeader.swift`, `Models/ClimbSession.swift`, `Models/ProgressEngine.swift`, betroffene Views

**Aufgabe:**
1. `SectionHeader`:

```swift
struct SectionHeader<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Theme.Typo.section).foregroundStyle(Theme.textPrimary)
            Spacer()
            accessory
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(_ title: String) { self.init(title: title) { EmptyView() } }
}
```

   Nutzen für Seiten-Abschnitte **außerhalb** von Karten:
   - Heute: „Angepinnt" (Titel aus der Karte heraus, darüber) und „Letzte Sessions" mit „Alle"-Link.
   - Fortschritt: die drei Leitfragen, lokales `sectionHeader` entfernen.
   - Recap: „Freigeschaltet", „Als Nächstes".
   - Projekte: Sektionen „Angepinnt", „In Arbeit", …; die Anzahl-Capsule als Accessory.

   Titel **innerhalb** von Karten bleiben `Theme.Typo.cardTitle`.
2. Alle `Divider().background(` → `Divider().overlay(`.
3. Alle `RoundedRectangle(cornerRadius: Theme.Radius.x)` ohne `style:` → `RoundedRectangle.theme(Theme.Radius.x)`.
4. `ClimbSession`:

```swift
var durationText: String {
    Duration.seconds(durationSeconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
}
```

   Überall statt `"\(session.durationMinutes) Min"` nutzen (SessionRow, Session-Header, Recap). `formatMinutes` in `SessionDetailView` analog über `Duration`.
5. `ProgressEngine.Discipline`: `var label: String { isBoulder ? "Boulder" : "Seil" }`. Alle Literale „Bouldern"/„Seil"/„Boulder" für die **Disziplin** ersetzen (LevelHeroCard, Picker, Empty-State, ClimbDaysCard-Titel bleibt „Bouldertage"/„Seiltage"). `SessionType.label` („Bouldern") bleibt für Session-Typen.

**Fertig wenn:** `grep -rn "Divider().background"` leer. `grep -rn "cornerRadius: Theme.Radius" Views | grep -v continuous` leer. `grep -rn "durationMinutes) Min" Views` leer.

---

### PG-4 · Quick-Log: Hauptaktion in Daumenreichweite

**Kontext:** Primäre Aktion oben rechts, sekundäre groß unten (Abnahme 4.6, E24).

**Dateien:** `Views/AddAscentView.swift`

**Aufgabe:**
1. Toolbar-„Sichern" entfernen. Toolbar trailing bleibt leer, leading „Abbrechen".
2. `bottomBar`:

```swift
VStack(spacing: 8) {
    feedbackLine                                  // bestehende Bestätigung, unverändert
    HStack(spacing: 10) {
        Button { save(keepOpen: true) } label: {
            Text("Nächste").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Button { save(keepOpen: false) } label: {
            Text("Sichern").fontWeight(.semibold).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
    .controlSize(.large)
    .disabled(outcome == nil || isSaving)
}
```

3. Feedback-Timer robust: statt `Task { sleep; lastSavedFeedback = nil }` ein `@State feedbackID = 0` hochzählen und `.task(id: feedbackID) { try? await Task.sleep(for: .seconds(2)); lastSavedFeedback = nil }` – bricht bei schnellem Folgespeichern sauber ab.
4. `Text("\(session.ascents.count) in dieser Session")` → `"\(n) Begehung\(n == 1 ? "" : "en") in dieser Session"`.

**Fertig wenn:** Beide Aktionen liegen unten nebeneinander, „Sichern" ist prominent. Zwei schnelle „Nächste" hintereinander zeigen die zweite Bestätigung volle 2 s.

---

### PG-5 · Session-Detail aufteilen (reiner Refactor)

**Kontext:** 1.119 Zeilen, Voraussetzung für PG-6 (Abnahme 4.4).

**Dateien:** `Views/SessionDetailView.swift` → neuer Ordner `Views/SessionDetail/`

**Aufgabe:** Ohne Verhaltens- oder Layoutänderung aufteilen in:

| Datei | Inhalt |
|---|---|
| `SessionDetailView.swift` | Komposition, Toolbar, Sheets, Dialoge, Auto-Open, `isPristine` |
| `SessionAscentsCard.swift` | Begehungen inkl. contextMenu, Edit-Sheet, Lösch-Dialog |
| `SessionQuickCheckCard.swift` | Kurz-Check inkl. RPE, Limiter, Watch-Chips |
| `SessionReflectionCard.swift` | Reflexion inkl. Technik-Fokus, Fokus-Rating, Textfelder, `updateReflectionCompleted` |
| `SessionInsightsSection.swift` | Donut, Metrik-Kacheln, Health-Karte |
| `SessionTrainingCard.swift` | Trainings-Sets |
| `SessionLocationEditor.swift` | Standort-Sheet |

Subviews als `struct` mit `@Bindable var session: ClimbSession` und nötigen Bindings/Closures. Keine neuen ViewModels. Jede Datei < 300 Zeilen.

**Fertig wenn:** Build grün, Previews unverändert. `SessionDetailView.swift` hat < 250 Zeilen. Keine sichtbare Änderung. *(Gerät: kurzer Vergleich)*

---

### PG-6 · Session-Detail: Wichtiges zuerst

**Kontext:** E25. Begehungen stehen heute unter Messwerten (Abnahme 4.4).

**Dateien:** `Views/SessionDetail/SessionDetailView.swift`, neu `Views/SessionDetail/SessionSummaryHeader.swift`, `Views/SessionDetail/SessionInsightsSection.swift`

**Aufgabe:**
1. Neuer `SessionSummaryHeader` (ersetzt `sessionHeader`):
   - Zeile 1: `IconTile(symbol: type.symbol, size: 52)` + `VStack`: Datum „Mittwoch, 16. September · 18:30" (`label`/secondary), darunter Ort (`gymName`/„Outdoor") + Quelle-Badge (Apple Watch / Apple Health) in `caption`/secondary.
   - Zeile 2 (nur Klettersession mit Begehungen): `HStack(alignment: .firstTextBaseline, spacing: 20)` mit drei Kennzahlen, je `VStack(alignment: .leading)`:

| Kennzahl | Wert | Label |
|---|---|---|
| härtester Top | `Theme.Typo.metricHero`, `textPrimary` | „Härtester Top" |
| Anzahl Tops | `Theme.Typo.metric` | „Tops" |
| Dauer | `Theme.Typo.metric`, `durationText` | „Dauer" |

   - Ohne Top: erste Kennzahl entfällt.
   - Zahlen `.monospacedDigit()` + `.contentTransition(.numericText())`.
   - Kein Kartenhintergrund, steht direkt auf `Theme.bg` (Apple-Fitness-Stil).
2. Navigation: `ToolbarItem(.principal)` entfernen, stattdessen `.navigationTitle(session.sessionType.label)` inline.
3. Reihenfolge im ScrollView:
   1. `SessionSummaryHeader`
   2. Erfolge dieser Session (falls vorhanden)
   3. Training (falls Training)
   4. Begehungen
   5. Kurz-Check
   6. Reflexion
   7. `SectionHeader("Messwerte")` + `SessionInsightsSection` (Vitalwerte, Donut, Kacheln) – ganzer Block nur, wenn mindestens eine Messgröße existiert
4. In der Begehungskarte die Zusammenfassungszeile („N Tops · N Versuche") entfernen – steht jetzt im Header.

**Fertig wenn:** Session-Detail beginnt mit Datum, Ort und „6B · 7 Tops · 1 Std., 35 Min.". Begehungen sind ohne Scrollen sichtbar anzutippen (iPhone 15, Standardschrift). Messwerte stehen am Ende.

---

### PG-7 · Level-Hero entschlacken

**Kontext:** Karte zu dicht, zweite Disziplin ohne Ziel, Bezeichnungen uneinheitlich, Rechenaufwand pro Render (Abnahme 4.5, 4.7).

**Dateien:** `Views/Components/LevelHeroCard.swift`, `Views/TodayView.swift`

**Aufgabe:**
1. Alle abgeleiteten Werte **einmal** berechnen: `private struct Model` mit `init(sessions:projects:unlocks:)`, darin `discipline`, `pb`, `nextGrade`, `comfort`, `achievement`. Im `body`: `let m = Model(...)`. Computed Properties, die Engine-Funktionen aufrufen, entfernen.
2. Zeile „zweite Disziplin" entfernen.
3. Streak-Zeile aus der Karte entfernen. In `TodayView.dateLine` anhängen: `"Mittwoch, 16. September · 3 Wochen in Folge"`, nur ab Streak ≥ 2; Rekord nicht auf Heute.
4. Kopfzeile: `Text(m.discipline.label)` (PG-3).
5. Unter dem Hero-Grad: „Höchster Top · März 2026" bleibt. Abstand zwischen Hero-Block und Meilensteinen 16 pt, zwischen Meilenstein-Zeilen 12 pt.
6. Ohne Meilensteine: Karte endet nach der Caption, kein leerer Divider.

**Fertig wenn:** Hero zeigt maximal: Disziplin · PB → nächste Stufe · Caption · ≤ 2 Meilensteine. `AchievementViewModel.build` wird pro Render genau einmal aufgerufen.

---

### PG-8 · Projekt-Detail als Bühne

**Kontext:** Name klein in der Leiste, Ziel-Grad als Chip, Hauptaktion mitten im Scroll (Abnahme 4.6, E24).

**Dateien:** `Views/ProjectDetailView.swift`

**Aufgabe:**
1. `.navigationBarTitleDisplayMode(.large)` (Name als Large Title).
2. `headerCard` neu, ohne Kartenhintergrund:
   - Links großer Ziel-Grad in `Theme.Typo.metricHero`: gold wenn geschafft, sonst `textPrimary`. Tap öffnet Grad-Editor. Ohne Ziel-Grad: `Button("Ziel-Grad festlegen")` `.bordered`, `.controlSize(.small)`.
   - Rechts oben Status-Capsule (bestehend).
   - Darunter eine Zeile `caption`/secondary: „4 Klettertage · 11 Begehungen · 1 Top". Die drei Stat-Pills entfallen.
   - „Wieder aktivieren" / „Aufgeben" bleiben unter der Zeile als `.bordered .small`.
3. Inline-Button „Begehung erfassen" entfernen. Stattdessen am `ScrollView`, nur wenn nicht aufgegeben:

```swift
.safeAreaInset(edge: .bottom) {
    Button { showSessionChoice = true } label: {
        Label("Begehung erfassen", systemImage: "plus").frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(.bar)
}
```

4. Reihenfolge: Header → `ProjectDayTimeline` → Beta-Notizen → Medien → Verlauf.

**Fertig wenn:** Projektname steht groß oben, Ziel-Grad ist das dominante Element, „Begehung erfassen" ist unten immer erreichbar.

---

### PG-9 · Grad-Verlauf zum Antippen

**Kontext:** Statisches Chart, Apple-typisches Scrubbing fehlt (Abnahme 4.8).

**Dateien:** `Views/Components/GradeTimelineChart.swift`

**Aufgabe:**
1. `@State private var selectedMonth: Date?`, am `Chart`: `.chartXSelection(value: $selectedMonth)`.
2. Nächsten Punkt bestimmen: `points.min { abs($0.month.timeIntervalSince(sel)) < abs($1.month.timeIntervalSince(sel)) }`.
3. Bei Auswahl:
   - `RuleMark(x: .value("Monat", p.month, unit: .month))` in `Theme.separator`, `lineWidth: 1`.
   - `.annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled))` mit kleiner Blase (`.inset()`-Stil, `caption`): Monat (`month(.wide)`), „Top \(grade)", optional „Flash \(grade)".
4. Kopfzeile der Karte bei Auswahl ausblenden (`opacity(selectedMonth == nil ? 1 : 0)`), damit die Blase Platz hat.
5. `.sensoryFeedback(.selection, trigger: nearestPoint?.month)`.
6. Loslassen setzt `selectedMonth = nil` (Standardverhalten von `chartXSelection`).

**Fertig wenn:** Finger über den Verlauf ziehen zeigt Monat und Grad, mit leichter Haptik pro Monat. Loslassen blendet aus.

---

### PG-10 · Flüssigkeit: einmal rechnen, gezielt beobachten

**Kontext:** Mehrfachberechnung pro Render, `@Query` aller Sessions im Dashboard (Abnahme 4.7).

**Dateien:** `Views/FortschrittView.swift`, `Views/DashboardView.swift`

**Aufgabe:**
1. `FortschrittView`: `private struct Snapshot` mit `init(sessions:discipline:period:)`, berechnet einmal `bests`, `comfortGrade`, `milestones`, `highlights`, `timeline`, `pyramid`, `monthlyDays`, `totals`, `mostCommonLimiter`, `hasData`, `celebratesSend`. Im `body`: `let s = Snapshot(...)`. Alle bisherigen Engine-Computed-Properties löschen.
2. `FortschrittView`: `.animation(.snappy, value: disciplineRaw/period)` vom umschließenden `VStack` entfernen. Nur auf die Karten-Inhalte, die sich ändern, ist Animation erlaubt. Charts animieren bereits intern über `value: points`.
3. `DashboardView`:
   - `@Query allSessions` entfernen.
   - `@State private var recapSession: ClimbSession?`
   - `func loadRecapSession()`: bei gültiger UUID `context.fetch(FetchDescriptor<ClimbSession>(predicate: #Predicate { $0.id == uuid })).first`, sonst `nil`.
   - Aufruf in `.task(id: pendingRecapID)` und bei `scenePhase == .active`.

**Fertig wenn:** Keine Engine-Funktion wird im Fortschritt-Tab pro Render mehrfach aufgerufen (per Breakpoint/Log einmalig prüfen, Log danach entfernen). `DashboardView` hat kein `@Query` auf `ClimbSession`. Scrollen im Fortschritt mit Mock-Szenario „Voll" ohne Ruckler. *(Gerät)*

---

## Block DOC

### DOC-2 · Prinzipien nachschärfen

**Dateien:** `ClimbReflectWatch Watch App/CLAUDE.md`

**Aufgabe:**
- **S37** ergänzt um die Watch-Grad-Pflicht (KR-1).
- **S40** ergänzt: Gold-Whitelist (E19), `textTertiary` ≥ 4,5 : 1, eine Icon-Kachel-Form (E22), Abschnitte über `SectionHeader`.
- **S41** ergänzt: Erfolgs-Haptik an der View, deren Liste sich ändert (E23). Nie `sensoryFeedback` innerhalb von `ForEach`, nie auf Texteingabe-Werten.
- **S45 – Tappbare Flächen geben nach.** Jede tappbare Karte/Zeile nutzt `CardButtonStyle`; `.plain` nur für Inline-Elemente ohne Flächenwirkung.
- **S46 – Hauptaktion in Daumenreichweite.** Erfassungs-Flows haben die primäre Aktion unten (`safeAreaInset`), Toolbar-Buttons tragen keine eigene Farbe.
- **S47 – Pläne altern.** Vor Umsetzung eines TODO: `git log <Plan-Basis>..HEAD -- <Dateien>`. Neuere Commits gewinnen gegen den Plan. Anlass: WT-1 vs. `039e0d9`.
- **S48 – Fertig heißt getestet.** Eine Aufgabe mit Test-Anforderung gilt ohne grüne Tests als offen und wird so im Commit markiert.
- Abschnitt 7: TODO18 eintragen.

**Fertig wenn:** S37/S40/S41 ergänzt, S45–S48 vorhanden.

---

## Abschluss-Checkliste

**Build & Tests**
- [ ] Beide Schemes bauen, alle Tests grün (inkl. ≥ 16 neue aus KR-2)

**grep-Checks**
- [ ] kein `Divider().background`
- [ ] kein Radius ohne `.continuous`
- [ ] kein `foregroundStyle` an Toolbar-Buttons
- [ ] `Theme.gold` nur laut E19
- [ ] kein `sensoryFeedback` in `ForEach`

**Gerät: Watch**
- [ ] Session starten → erste Begehung zeigt „–" (Grad-Pflicht) → zweite startet auf dem Grad der ersten
- [ ] Session mit Begehungen beenden → iPhone öffnen → Overlay → Recap (groß, Eyebrow) → „Kurz reflektieren" landet in der offenen Reflexion

**Gerät: iPhone**
- [ ] Seil-Session nachtragen → Grad-Leiste startet mittig ohne Sprung → 3 × „Nächste" → „Sichern" → genau eine Haptik pro Speichern
- [ ] Session-Detail beginnt mit Zusammenfassung, Begehungen ohne Scrollen sichtbar
- [ ] Karten sinken beim Tippen ein; mit Reduce Motion nur Abdunklung
- [ ] Grad-Verlauf mit dem Finger abfahren
- [ ] Dynamic Type `.accessibility2` auf Heute, Session-Detail, Quick-Log

**Merge**
- [ ] `feature/premium-polish` → `dev`
