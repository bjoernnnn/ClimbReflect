# TODO – Übersicht offene Punkte + Fokus: Action Button & iPhone-Lock-Screen-Timer

**Branch:** `dev` @ `eeeadbb`

## Stand
Kernarbeit erledigt: Leak behoben, Recovery robust, maxHF, Action-Flow (Badge-Toggle +
Doppeltipp), Dauer/Höhe pro Versuch (Watch + iPhone), Design-Feinschliff, Verbose-Logging-Schalter.

---

## A) Restliche offene TODOs (Übersicht)

1. **Physischer Action Button** (watchOS App Intent für Session-Start) – *Fokus, siehe B.*
2. **iPhone Live Activity / Lock-Screen-Timer** – ist gebaut, erscheint aber nicht – *Fokus, siehe C.*
3. **Projekte-Feature** (`TODO5-PROJEKTE.md`): echte `Project ↔ [Ascent]`-SwiftData-Relation,
   Migration, Projekt-Modus, Pinning, Projekt-Detail mit Versuchs-Historie + Fortschrittschart,
   `ProjectMedia`, Watch-Projektauswahl. **Der nächste große Brocken.**
4. **Watch-Projekt-Picker-Bug**: `knownProjects` kommt auf der Watch nicht an.
5. **Design-Restfeinschliff**: Klassifizier-Buttons/Größen am Gerät final justieren (läuft schon).
6. **Blackscreen am Ende langer Sessions**: zuletzt nicht reproduziert – beobachten, kein Handlungsbedarf.

---

## B) FOKUS 1 – Physischer Action Button (watchOS App Intent)

**Ziel:** ClimbReflect taucht in den Action-Button-Einstellungen der Watch auf; ein Druck
**startet eine Session**. (Start/Ende pro Versuch bleibt bei Badge + Doppeltipp – der physische
Button kann das technisch nicht, siehe S23.)

### B1 – App Intent im **Watch-Target** anlegen
Neue Datei `ClimbReflectWatch Watch App/Intents/StartSessionIntent.swift`:
```swift
import AppIntents

struct StartSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Klettersession starten"
    static var description = IntentDescription("Startet eine ClimbReflect-Session.")
    static var openAppWhenRun: Bool = true     // App in den Vordergrund holen

    // Optional: Sportart wählbar machen (erscheint bei Action-Button-Zuweisung)
    @Parameter(title: "Sportart")
    var sport: SportIntentEnum?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Start-Wunsch hinterlegen; die App startet beim Erscheinen.
        PendingStart.set(sport?.sessionTypeRaw)
        return .result()
    }
}

enum SportIntentEnum: String, AppEnum {
    case boulder, lead, topRope, autoBelay, training
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Sportart"
    static var caseDisplayRepresentations: [SportIntentEnum: DisplayRepresentation] = [
        .boulder: "Bouldern", .lead: "Vorstieg", .topRope: "Toprope",
        .autoBelay: "Autobelay", .training: "Training"
    ]
    var sessionTypeRaw: String { rawValue }
}
```

### B2 – Start-Wunsch an die App übergeben
Da `WorkoutManager` an die App-Instanz gebunden ist (kein Singleton), den Intent **nicht** direkt
starten lassen, sondern einen Merker setzen, den die App beim Start/Erscheinen liest:
```swift
enum PendingStart {
    static func set(_ raw: String?) {
        UserDefaults.standard.set(raw ?? "lead", forKey: "pendingStartSport")
        UserDefaults.standard.set(true, forKey: "pendingStartFlag")
    }
}
```
In `ClimbReflectWatchApp` / `ContentView` beim Erscheinen prüfen:
```swift
.task {
    if UserDefaults.standard.bool(forKey: "pendingStartFlag"), !workoutManager.isRunning {
        UserDefaults.standard.set(false, forKey: "pendingStartFlag")
        let raw = UserDefaults.standard.string(forKey: "pendingStartSport") ?? "lead"
        workoutManager.startWorkout(sessionType: SessionType(rawValue: raw) ?? .lead)
    }
}
```

### B3 – Intent sichtbar machen
`AppShortcutsProvider` ergänzen, damit der Intent in Shortcuts/Action-Button-Liste erscheint:
```swift
struct ClimbShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartSessionIntent(),
                    phrases: ["Starte \(.applicationName)"],
                    shortTitle: "Session starten", systemImageName: "figure.climbing")
    }
}
```

### B4 – Test
Watch-Einstellungen → Action Button → ClimbReflect zuweisen → drücken → App startet Session.
> Hinweis: Exakte Action-Button-Zuweisung von Drittanbieter-Intents am Gerät prüfen; ggf. ist
> die Zuweisung nur über die „Kurzbefehl"-Option des Action Buttons möglich. Verhalten
> dokumentieren.

---

## C) FOKUS 2 – iPhone Live Activity (Lock-Screen-Timer)

**Befund: Das Widget ist bereits vollständig gebaut** – `LiveActivityController`
(Start/Update/Ende über `WatchSessionReceiver`), Lock-Screen-View + Dynamic Island mit Live-Timer
(`Text(timerInterval:…)`), `NSSupportsLiveActivities` gesetzt. Es erscheint trotzdem nicht.

**Wahrscheinliche Ursache:** Eine Live Activity lässt sich mit `Activity.request()` **nur
starten, wenn die iPhone-App im Vordergrund ist.** Wird die Session auf der **Watch** gestartet,
wacht die iPhone-App nur kurz **im Hintergrund** auf (`didReceiveApplicationContext`) → der
`Activity.request()` wirft → der `catch` (Zeile 42) **verschluckt den Fehler stillschweigend** →
keine Live Activity. Ohne Push-Server (Push-to-Start, iOS 17.2+) lässt sich das nicht aus dem
Hintergrund starten.

### C1 – Fehler sichtbar machen (Diagnose)
In `LiveActivityController.startActivity` den leeren `catch` ersetzen:
```swift
        } catch {
            print("LiveActivity start failed: \(error)")   // oder in ein iOS-Diag-Log
        }
```
Außerdem loggen, wenn `areActivitiesEnabled == false` (Nutzer hat Live Activities deaktiviert).

### C2 – Vordergrund-Start nachrüsten (praktikable Lösung ohne Server)
Den letzten Live-Status merken und die Activity beim **Vordergrund-Werden** der App starten,
falls noch keine läuft:
- In `LiveActivityController` den letzten `WatchLiveStatus` puffern (`lastStatus`).
- In der iPhone-App auf `scenePhase == .active` reagieren: wenn `lastStatus != nil` und keine
  Activity läuft → `update(with: lastStatus)` erneut aufrufen (jetzt im Vordergrund → startet).

**Ergebnis:** Du startest auf der Watch, das iPhone ist in der Tasche → noch keine Activity.
Sobald du das iPhone das nächste Mal **aktiv ansiehst/entsperrst** (App kurz im Vordergrund),
startet die Activity und **bleibt** danach auf dem Sperrbildschirm + aktualisiert sich. Das ist
ohne Push-Backend die zuverlässigste Variante.

### C3 – Einschränkung dokumentieren / Entscheidung
- **Ohne Server:** Auto-Start bei reiner Watch-Session mit gesperrtem, nie geöffnetem iPhone ist
  **nicht möglich** (iOS-Limit). C2 ist der beste Kompromiss.
- **Mit Server (später, optional):** Push-to-Start via APNs würde echten Hintergrund-Start
  erlauben – nur sinnvoll, falls ohnehin ein Backend kommt.

### C4 – Embedding prüfen
Sicherstellen, dass das `ClimbReflectActivity`-Widget-Extension-Target in der iPhone-App
**eingebettet** ist (Build Phase „Embed App Extensions") und dasselbe `ClimbActivityAttributes`
in beiden Targets liegt (es gibt zwei Dateien – prüfen, dass sie identisch sind / geteiltes
Target-Membership).

### C5 – CLAUDE.md
- **S26 – iPhone Live Activity lässt sich nur im Vordergrund starten** (`Activity.request`).
  Watch-gestartete Session + Hintergrund-iPhone → Start beim nächsten Vordergrund nachholen
  (gepufferter `lastStatus`). Echter Hintergrund-Start nur via Push-to-Start (APNs/Server).

---

## Reihenfolge
1. **C1 + C2** zuerst (Live Activity zum Laufen bringen – kleiner, sichtbarer Gewinn) + C4-Check.
2. **B1–B4** Action Button.
3. CLAUDE.md (S26) mitnehmen.
4. Danach großer Block: **Projekte** (`TODO5-PROJEKTE.md`) + Watch-Projekt-Picker.
