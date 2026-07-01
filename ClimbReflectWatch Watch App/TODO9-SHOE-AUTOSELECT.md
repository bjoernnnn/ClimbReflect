# TODO9 — Schuh-Sync & automatische Schuh-Vorauswahl auf der Uhr

Branch: `dev` (Stand `ed4b36e`)

## Root Cause (Analyse, kein Code-Change)

Das Feature "Standard-Schuh je Kletterart" (SH-B, `defaultForTypesRaw` auf `Shoe`)
ist **iPhone-seitig vollständig** implementiert (Auswahl-UI in `ShoeFormView`,
Persistenz im Model). Es wird aber an zwei Stellen nicht bis zur Uhr durchgereicht:

1. **`WatchSessionReceiver.pushProjectsToWatch(modelContext:)`** (iOS) baut die
   `shoeList` für den `applicationContext` nur aus `id`, `name`, `condition`.
   `defaultForTypesRaw` wird **nicht mitgesendet** — die Uhr kann also grundsätzlich
   nicht wissen, welcher Schuh Standard für Bouldern/Vorstieg/Toprope/Autobelay ist.
2. **`SyncService.ShoeInfo`** (Watch) hat entsprechend kein `defaultForTypes`-Feld,
   und **`WorkoutManager.startWorkout(type:)`** liest `knownShoes` beim Session-Start
   gar nicht — `selectedShoe` bleibt einfach das, was aus der letzten Session
   persistiert wurde (SH-7), oder `nil`. Es gibt keinerlei automatische Zuordnung
   zum `sessionType`.

Das erklärt beide gemeldeten Symptome:
- Bereits vorhandener Schuh als Standard-Boulderschuh markiert → wird beim
  Bouldertraining nicht vorausgewählt (Daten kommen nie an, Logik fehlt).
- Neuer Schuh mit Standard Autobelay/Toprope/Vorstieg → gleiches Problem.

Die dritte Meldung ("neuer Schuh erscheint gar nicht auf der Uhr") ist mit hoher
Wahrscheinlichkeit dasselbe Symptom in anderer Wahrnehmung (der Schuh taucht in der
Liste ggf. erst verzögert auf, wird aber nie *vorausgewählt* — das fällt als
"nicht angekommen" auf). Die reine Listen-Übertragung (SH-6) ist strukturell
korrekt (`pushProjectsToWatch()` wird bei jedem Anlegen/Bearbeiten/Löschen in
`ShoesView.swift` aufgerufen). Da `updateApplicationContext` aber best-effort/
coalescing ist, wird zusätzlich ein `transferUserInfo`-Fallback ergänzt (SH-13),
analog zum bereits etablierten Muster bei Diagnostics/Session-Transfer.

⚠️ **ABSTIMMEN (kleine Verhaltensentscheidung, sonst keine Architekturänderung):**
Soll `selectedShoe` bei jedem Session-Start **immer** auf den Typ-Standard
zurückgesetzt werden (auch wenn in der vorigen Session manuell ein anderer Schuh
gewählt wurde)? Empfehlung: **Ja** — das ist exakt das beschriebene Wunschverhalten
("bei Start automatisch der Schuh unten angezeigt"). Wenn kein Standard für den Typ
existiert, wird `selectedShoe` auf `nil` gesetzt (kein Fallback auf den letzten
Schuh), damit die Anzeige nicht fälschlich einen falschen Schuh suggeriert.
Falls Björn stattdessen "Standard nur vorschlagen, letzte manuelle Wahl behalten
falls vorhanden" möchte, bitte vor Umsetzung von SH-13 kurz Rückmeldung.

---

## SH-11 — iOS: `defaultForTypesRaw` in Schuh-Liste an Watch übertragen

**Kontext:** `WatchSessionReceiver.pushProjectsToWatch(modelContext:)` sendet die
Schuhliste ohne Standard-Zuordnung.

**Dateien:** `ClimbReflect/ClimbReflect/ClimbReflect/Services/WatchSessionReceiver.swift`

**Aufgabe:**
```swift
// SH-6: Aktive (nicht retired) Schuhe mitsenden inkl. Zustand + Standard-Typen (SH-11)
let shoes = (try? modelContext.fetch(FetchDescriptor<Shoe>())) ?? []
let activeShoes = shoes.filter { !$0.isRetired }
let shoeList: [[String: Any]] = activeShoes.map {
    [
        "id": $0.id.uuidString,
        "name": $0.name,
        "condition": $0.conditionRaw,
        "defaultForTypes": $0.defaultForTypesRaw   // SH-11: [String], z. B. ["boulder"]
    ]
}
```
`shoeList` ist jetzt `[[String: Any]]` statt `[[String: String]]` — der umgebende
`context: [String: Any]`-Dictionary-Typ bleibt unverändert, keine weiteren Anpassungen
nötig. `[String]` ist plist-kompatibel und für `updateApplicationContext` zulässig.

**Fertig-wenn:** `defaultForTypesRaw` ist Teil jedes Schuh-Eintrags im übertragenen
`shoeList`.

---

## SH-12 — Watch: `ShoeInfo` um `defaultForTypes` erweitern

**Kontext:** `SyncService.ShoeInfo` und `applyContext(_:)` kennen nur `id`, `name`,
`condition`.

**Dateien:** `ClimbReflectWatch Watch App/Services/SyncService.swift`

**Aufgabe:**
```swift
// SH-6: Schuh-Info für Watch-Selektor (analog ProjectInfo)
struct ShoeInfo: Identifiable, Hashable {
    let id: String   // UUID-String
    let name: String
    let condition: String?       // ShoeCondition.rawValue, Snapshot zum Zeitpunkt des Empfangs
    let defaultForTypes: [String] = []   // SH-12: SessionType.rawValues, für Auto-Vorauswahl
}
```
Da `ShoeInfo` mit `Hashable`/`Equatable` synthetisiert wird und `defaultForTypes`
für den Vergleich mit reinfließen soll, kein `= []`-Default am Property selbst
verwenden, sondern explizit im Init füllen (siehe unten) — sonst matcht Equatable
ggf. unerwartet. Konkret:

```swift
struct ShoeInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let condition: String?
    let defaultForTypes: [String]
}
```

Und in `applyContext(_:)`:
```swift
// SH-6/SH-12: Schuhe inkl. Standard-Zuordnung
if let list = context[SyncService.shoeListKey] as? [[String: Any]] {
    knownShoes = list.compactMap { dict -> ShoeInfo? in
        guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
        return ShoeInfo(
            id: id,
            name: name,
            condition: dict["condition"] as? String,
            defaultForTypes: dict["defaultForTypes"] as? [String] ?? []
        )
    }
}
```
Beachte: Der Cast von `[[String: String]]` auf `[[String: Any]]` ändert sich —
alle Stellen, die `ShoeInfo(...)` konstruieren (z. B. Restore aus
`PendingSessionStore`/UserDefaults in `WorkoutManager`), müssen um den neuen
Parameter ergänzt werden (Default `[]` dort ist unkritisch, da dort nur der
zuletzt gewählte Schuh rekonstruiert wird, nicht die Standard-Logik).

**Fertig-wenn:** `SyncService.knownShoes` enthält nach Context-Empfang die
Standard-Zuordnung je Schuh; Projekt baut ohne Fehler.

---

## SH-13 — Watch: Automatische Schuh-Vorauswahl bei Session-Start

**Kontext:** `WorkoutManager.startWorkout(type:)` setzt `sessionType`, aber nie
`selectedShoe`.

**Dateien:** `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`

**Aufgabe:** Direkt nach `sessionType = type` in `startWorkout(type:target:)`:
```swift
sessionType = type
trainingTarget = target
attemptState = .idle
lastPublishedAltitudeInt = -1  // force first publish

// SH-13: Automatische Schuh-Vorauswahl anhand des Standard-für-Typ-Flags.
// Training (Krafttraining) hat keine Kletterschuh-Zuordnung → dort keine
// automatische Auswahl/Reset.
if type != .training {
    selectedShoe = SyncService.shared.knownShoes.first {
        $0.defaultForTypes.contains(type.rawValue)
    }
}
```
Das setzt `selectedShoe` bei **jedem** Start neu (überschreibt eine evtl. aus der
Vorsession persistierte manuelle Wahl) — siehe ABSTIMMEN oben. Manuelle Auswahl im
laufenden Training über den bestehenden Picker (`LiveSessionView`, Zeile ~590)
bleibt unverändert möglich und überschreibt den Standard für diese Session.

**Fertig-wenn:** Beim Start eines Bouldertrainings mit als Standard markiertem
Boulderschuh erscheint dieser sofort unten im Live-Screen als ausgewählt — ohne
manuelles Zutun. Gleiches für Vorstieg/Toprope/Autobelay mit dem jeweils
zugeordneten Schuh. Bei Training (Kraft) bleibt `selectedShoe` unverändert/`nil`.

---

## SH-14 — iOS: `transferUserInfo`-Fallback für Projekt-/Schuh-Liste (Robustheit)

**Kontext:** `pushProjectsToWatch()` nutzt ausschließlich `updateApplicationContext`,
was best-effort/coalescing ist und bei inaktiver/nicht erreichbarer Uhr verzögert
zugestellt werden kann. Für Session-Transfer und Diagnostics ist bereits das
robustere `transferUserInfo`-Muster etabliert (siehe `SyncService.send(dto:)`).

**Dateien:** `ClimbReflect/ClimbReflect/ClimbReflect/Services/WatchSessionReceiver.swift`,
`ClimbReflectWatch Watch App/Services/SyncService.swift`

**Aufgabe:** Zusätzlich zu `updateApplicationContext(context)` in
`pushProjectsToWatch(modelContext:)` denselben `context` (bzw. eine separate,
kleinere Payload mit dem Key `"shoeProjectSync"`) per
`WCSession.default.transferUserInfo(...)` senden, wenn `updateApplicationContext`
fehlschlägt (`try?` liefert Fehler) oder die Uhr aktuell nicht erreichbar ist
(`!WCSession.default.isReachable`). Auf Watch-Seite in
`SyncService.session(_:didReceiveUserInfo:)` den entsprechenden Payload-Key
zusätzlich zu `watchCommand`/`diagnosticLog` behandeln und über dieselbe
`applyContext(_:)`-Logik einspielen.

**Fertig-wenn:** Ein neu angelegter Schuh kommt auch dann auf der Uhr an, wenn die
Uhr im Moment des Anlegens nicht reachable war (z. B. Handgelenk gesenkt/Screen aus),
sobald sie das nächste Mal Kontakt hat — ohne dass die App auf der Uhr neu gestartet
werden muss.

---

## Reihenfolge

SH-11 → SH-12 → SH-13 sind der Kern-Fix und beheben beide gemeldeten Symptome
(fehlende Vorauswahl, vermutlich auch "Schuh erscheint nicht"). SH-14 ist eine
zusätzliche Zuverlässigkeits-Härtung, die unabhängig danach gemacht werden kann.
Jeweils ein Commit pro Task.
