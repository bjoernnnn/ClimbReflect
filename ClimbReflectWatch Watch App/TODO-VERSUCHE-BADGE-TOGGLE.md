# TODO – Versuche-Badge als Start/Stopp-Schalter + Aufräumen (Phase 2)

**Branch:** `dev` @ `62bcdda`
**Stand:** Leak behoben (74 min flach), Action-Flow funktioniert, Dauer + max. Höhe pro Versuch
werden gespeichert und angezeigt. Diese Runde: UX-Feinschliff + Aufräumen.

---

## TEIL 1 – „Versuche"-Badge wird der Start/Stopp-Schalter

**Ziel:** Der separate Button unten (verschiebt das Layout) verschwindet. Stattdessen wird die
**„Versuche"-Badge** (neben „Tops") selbst zum Schalter:
- **Idle:** zeigt wie bisher die Anzahl der Versuche.
- **Tippen → Versuch startet:** Badge wird **orange** und zeigt einen **Timer** statt der Zahl.
- **Nochmal tippen → Versuch endet:** Badge nimmt wieder ihr normales Aussehen an (zählt
  Versuche), und es geht automatisch zu Tab 2 zum Klassifizieren (bestehende Auto-Nav bleibt).

Haptik/Sound-Feedback bleibt wie es ist (gut).

### 1.1 Neue Toggle-Badge in `LiveSessionView.swift`

Die bestehende „Versuche"-`statBadge` (in der `HStack` bei Zeile ~163) durch eine neue
`attemptToggleBadge` ersetzen:

```swift
            HStack(spacing: 8) {
                attemptToggleBadge
                statBadge(value: "\(topCount)",
                          label: "Tops", icon: "checkmark.circle.fill",
                          color: WatchTheme.accent)
            }
```

Neue View ergänzen (z. B. direkt vor `attemptActionButton`):

```swift
@ViewBuilder
private var attemptToggleBadge: some View {
    Button { workoutManager.handleActionButton() } label: {
        if case .active(let startTime) = workoutManager.attemptState {
            // Versuch läuft: orange + Timer statt Anzahl
            HStack(spacing: 5) {
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 11))
                VStack(alignment: .leading, spacing: 0) {
                    TimelineView(.periodic(from: startTime, by: 1)) { _ in
                        Text(formatDuration(Date().timeIntervalSince(startTime)))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    Text("läuft")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.orange.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            // Idle / awaitingResult: normale Versuche-Badge
            statBadge(value: "\(workoutManager.attempts.count)",
                      label: "Versuche", icon: "figure.climbing",
                      color: WatchTheme.textSecond)
        }
    }
    .buttonStyle(.plain)
    .handGestureShortcut(.primaryAction)
}
```

> Orange: `.orange` (System) ist sicher; falls ein Theme-Token gewünscht ist, ist
> `WatchTheme.gold` der vorhandene orange/goldene Akzent – nach Geschmack.

### 1.2 Separaten Button unten entfernen (Layout „wie vorher")

- In `statsPage` die Zeile `attemptActionButton.padding(.bottom, 4)` (≈ Zeile 196) **entfernen**.
- Den vor 554c995 dort vorhandenen `actionStateIndicator` wiederherstellen **oder**, da die
  orange Badge den aktiven Zustand jetzt selbst anzeigt, den unteren Bereich ganz entfernen –
  Hauptsache **kein Button verschiebt mehr das Layout**. (Stand vor dem Button:
  `git show 554c995^:"ClimbReflectWatch Watch App/Views/LiveSessionView.swift"`.)
- Den `attemptActionButton`-`@ViewBuilder` (≈ Zeilen 216–255) entfernen, da nicht mehr genutzt.
  `formatDuration(...)` **behalten** (wird von der Badge gebraucht).
- Die `.onChange(of: attemptState) { … currentTab = 2 }`-Auto-Navigation **behalten**.

### 1.3 Achten auf
- Nur **eine** sichtbare `.handGestureShortcut(.primaryAction)` pro Kontext. Die Badge (Tab 1)
  und die Ergebnis-Buttons (Tab 2) sind nie gleichzeitig sichtbar – sollte passen, beim Testen
  kurz prüfen, dass der Doppeltipp den Versuch startet/stoppt.
- Kein Leak-Risiko: der `TimelineView` läuft nur im aktiven Zustand und auf der sichtbaren Seite
  (wie der bisherige Button) – unkritisch.

### 1.4 Test
Session, Badge tippen → orange + Timer, klettern, Badge tippen → zurück zur Zahl + Auto-Nav zu
Tab 2, klassifizieren. Layout darf sich beim Start/Stopp **nicht** verschieben.

---

## TEIL 2 – Diagnose-Logging für den Normalbetrieb zähmen (Phase 2)

Das Logging ist super zum Debuggen, aber zu gesprächig fürs Release (Memory-Ticks alle 60 s,
scenePhase-Wechsel). Lösung: **Verbose-Logging hinter einen Schalter**, Schlüssel-Ereignisse
bleiben.

### 2.1 Schalter in `DiagnosticLog`
```swift
var isVerbose: Bool {
    get { UserDefaults.standard.bool(forKey: "diagVerbose") }
    set { UserDefaults.standard.set(newValue, forKey: "diagVerbose") }
}

/// Nur loggen, wenn Verbose aktiv (für hochfrequente Einträge).
func logVerbose(_ event: String) {
    guard isVerbose else { return }
    log(event)
}
```

### 2.2 Hochfrequente Logs auf `logVerbose` umstellen
- Memory-Tick (alle 60 s im Timer) → `logVerbose`
- `scenePhase=…` → `logVerbose`

**Behalten** (über normales `log`, niedrige Frequenz, wertvoll): `app launch`, `start`,
`beginCollection`, `end`, `recover…`, `finalize…`, `recoveredActiveSession`,
`ascentTracking start/stop`, `streaming queries …`.

### 2.3 Toggle im UI
In der iOS- (und/oder Watch-)Diagnose-/Settings-Ansicht einen `Toggle("Ausführliches
Diagnose-Logging", isOn: …)` ergänzen, der `DiagnosticLog.shared.isVerbose` schaltet.
**Default: aus.** So bleibt der Normalbetrieb schlank; für einen gezielten Testlauf schaltest du
es an.

> Export-Funktion und Diagnose-Screen bleiben unverändert nutzbar.

---

## TEIL 3 – Physischer Action Button (für SPÄTER notiert)

Nur Vormerkung, nicht jetzt umsetzen.

- Der physische Action Button der Watch Ultra ist für Dritt-Apps **nur über App Intents**
  ansprechbar (Start-/Shortcut-Modell), **kein** Live-Toggle pro Versuch in der laufenden App.
- **Idee für später:** Ein App Intent „ClimbReflect-Session starten" bereitstellen. Dann kann
  der Nutzer in den Watch-Einstellungen den Action Button auf ClimbReflect legen → ein Druck
  **startet eine Session**. Das Start/Stopp pro Versuch bleibt bei Badge-Tipp + Doppeltipp-Geste.
- Verweise: `developer.apple.com/documentation/appintents/actionbuttonarticle`.
- (Bereits in CLAUDE.md als **S23** dokumentiert.)

---

## TEIL 4 – CLAUDE.md
Kurzer Nachtrag bei den UI-Prinzipien:
- **S24 – Versuch-Start/Stopp läuft über die „Versuche"-Badge** (Tipp → orange + Timer; erneut
  → zurück zur Anzahl + Auto-Nav zu Tab 2). Kein separater Button → kein Layout-Shift.
  Auslöser zusätzlich per `.handGestureShortcut(.primaryAction)` (Doppeltipp).

---

## Reihenfolge
1. **TEIL 1** (Badge-Toggle) – das willst du sehen.
2. **TEIL 2** (Diagnose-Schalter) – kleiner Aufräumschritt.
3. **TEIL 4** (CLAUDE.md) mitnehmen.
4. **TEIL 3** bleibt Vormerkung.

> Danach ist die Live-Session/Versuchs-Seite rund – der nächste große Brocken wären die
> **Projekte** (`TODO5-PROJEKTE.md`) + der Watch-Projekt-Picker-Bug.
