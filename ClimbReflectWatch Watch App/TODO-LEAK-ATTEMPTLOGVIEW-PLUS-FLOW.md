# TODO – Leak korrekt eingrenzen + Doku + Version + Action-Button-Flow

**Branch:** `dev` @ `4c4731a`

## Was die 3 Tests gezeigt haben

✅ **Recovery-Härtung funktioniert** (Test 4.2 + Zusatztest): Session hart beendet → App
wieder geöffnet → läuft synchron mit dem Handy weiter. Log zeigt `recover: hk session state=2`
→ `recoveredActiveSession`. Teil 2+3 der letzten Runde sind damit bestätigt. 🎉

❌ **Der Altimeter ist NICHT der Leak** – meine Hypothese war falsch. Beweis aus dem Zusatztest:
- 9 Minuten **flach bei 49 MB** mit laufendem `TimelineView` (statsPage), **bevor** ein Versuch
  gebankt wurde.
- Der Leak startet erst **nach dem ersten Öffnen der AttemptLogView (Tab 2)**.
- Die Altimeter-Subscription war dabei **nie aktiv** (im Log nur `ascentTracking stop`, **nie**
  `start`, weil über die AttemptLogView gebankt wird, nicht über den Action-Button).
- Nach der Recovery (kein Tab-2-Besuch) bleibt der Speicher **flach trotz vorhandener ascents**.

➡️ **Leak-Trigger = Besuch von Tab 2 (AttemptLogView) in der Paging-`TabView`.** Eine
`.page`-`TabView` hält besuchte Seiten am Leben; zusammen mit dem verschachtelten
`.verticalPage`-`TabView` (in `sessionInfoPage`) + dem 1-Hz-`TimelineView` leakt das pro Render.
(Auch die `historyPage` ist als Ursache ausgeschlossen – L-A ist weiterhin aktiv.)

❗ **Action-Button-Flow ist nicht verdrahtet:** `handleActionButton()` hat **keinen Aufrufer**
im UI – kein Button, keine Geste. Deshalb kein optisches/haptisches Feedback und nie ein
Höhen-Tracking. Der gewünschte Versuch-Start/Stop-Flow existiert im Code nur als Zustandsmaschine
(`.idle/.active/.awaitingResult`), wird aber von nichts ausgelöst.

---

## TEIL A – Erkenntnisse in CLAUDE.md dokumentieren (Björn-Wunsch)

> **Bitte generell:** wichtige Erkenntnisse fortlaufend direkt in `CLAUDE.md` als `S…`-Prinzip
> festhalten – auch bei künftigen Runden. Das ist Teil des Auftrags, nicht optional.

In `ClimbReflectWatch Watch App/CLAUDE.md` ergänzen (höchste Nummer aktuell S18):

- **S19 – Memory-Leak liegt in der verschachtelten Paging-`TabView`, nicht im Altimeter.**
  Reproduziert: Speicher flach, bis Tab 2 (`AttemptLogView`) das erste Mal besucht wird; danach
  linearer Anstieg ~10 MB/min bis Jetsam. Nach Recovery ohne Tab-2-Besuch flach trotz ascents.
  Lehre: `.page`-TabView mit verschachteltem `.verticalPage`-TabView + 1-Hz-`TimelineView`
  vermeiden; modale Sheets statt Swipe-Tabs für selten genutzte Views.

- **S20 – Korrelation ≠ Ursache (Altimeter-Fehlspur).** Das Auto-Re-Arm
  (`startAscentTracking()` nach jedem Bank) ließ den Altimeter wie den Leak-Trigger aussehen,
  weil Banken und Tracking gekoppelt waren. Erst Entkopplung (Subscription nur während echtem
  Versuch) + Test über die AttemptLogView zeigte: Leak besteht ohne aktiven Altimeter.

- **S21 – Recovery nach Jetsam.** `recoverActiveWorkoutSession()` liefert bei laufender Session
  `state=2` → `reattach()`. Liefert sie eine beendete Session oder `nil`, **muss**
  `finalizeUnrecoverableSession()` laufen (DTO syncen + `clearLiveStatus()`), sonst läuft das
  Handy weiter, während die Watch in der Auswahl steht. Recover-Logging gibt den Zweig preis.

---

## TEIL B – Versionsnummer im Diagnose-Log (Björn-Wunsch)

Damit jedes Log eindeutig einem Build zuzuordnen ist.

**B1** – kleiner Helfer (z. B. in `MemoryFootprint.swift` oder neue `AppVersion.swift`):
```swift
enum AppVersion {
    static var short: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) (\(b))"
    }
}
```

**B2** – in `WorkoutManager.init()` die Launch-Zeile ergänzen:
```swift
DiagnosticLog.shared.log("app launch #\(launchCount) \(AppVersion.short) mem=\(MemoryFootprint.residentMB())MB")
```

**B3** – in `DiagnosticView.swift` die Version oben anzeigen (z. B. unter dem „Diagnose"-Titel):
```swift
Text(AppVersion.short)
    .font(.system(size: 11, design: .monospaced))
    .foregroundStyle(WatchTheme.textSecondary)   // falls Token anders heißt: .secondary
```

> So steht die Version sowohl im exportierten Log (jede `app launch`-Zeile) als auch sichtbar
> auf dem Diagnose-Screen.

---

## TEIL C – Leak-Fix: AttemptLogView als Sheet statt Swipe-Tab

Das entfernt Tab 2 aus der Paging-`TabView` (Leak-Quelle) **und** ist die Grundlage für den
gewünschten Action-Button-Flow (Teil D). Niedriges Risiko, reversibel.

**C1** – in `LiveSessionView.swift` ein State-Flag ergänzen (bei `currentTab`):
```swift
@State private var showAttemptSheet = false
```

**C2** – in `climbingTabView` die AttemptLogView-Seite **entfernen**:
```swift
        AttemptLogView(onBank: { currentTab = 1 }).tag(2)   // <- löschen
```
und stattdessen als Sheet anhängen (neben den bestehenden `.sheet`/`.confirmationDialog`):
```swift
        .sheet(isPresented: $showAttemptSheet) {
            AttemptLogView(onBank: { showAttemptSheet = false })
        }
```

**C3** – einen gut erreichbaren Button auf `statsPage` (Tab 1) ergänzen, der das Sheet öffnet,
z. B. „Versuch erfassen":
```swift
Button { showAttemptSheet = true } label: {
    Label("Versuch", systemImage: "plus.circle.fill")
        .font(.system(size: 13, weight: .semibold))
}
.buttonStyle(.plain)
.foregroundStyle(WatchTheme.accent)
```
(Platzierung sinnvoll wählen – Hauptsache ohne Swipe auf Tab 1 erreichbar.)

**C4 – Verifikation:** Build, Session, **2–3 Versuche** über den neuen Button banken, ~15 min
ruhig. Erwartet: Speicher flach (Δ≈0), kein Jetsam.
- **Flach → Leak behoben.** Danach L-A rückgängig machen (`historyPage` wieder als Sheet/Tab
  einbinden, siehe Teil D-Hinweis) und erneut testen.
- **Steigt weiter → Instruments-Allocations-Lauf** (Xcode ⌘I → Allocations, 1 Versuch banken,
  5 min, „Mark Generation" alle 60 s). Wachsenden Allocation-Typ an mich.

---

## TEIL D – Action-Button-Attempt-Flow (dein eigentliches Ziel – „für später" ok)

### Befund
`handleActionButton()` ist nicht verdrahtet. Es gibt keinen On-Screen-Auslöser und keine
Geste. Der physische Action-Button der Watch Ultra macht aktuell seine **System-Aktion** – ihn
direkt in der App abzufangen ist nicht ohne Weiteres möglich (API-Lage unklar, bitte
recherchieren / Rücksprache). Pragmatisch verfügbar ist `.handGestureShortcut(.primaryAction)`
(Doppel-Tipp-Geste), die im Code an anderer Stelle schon genutzt wird.

### Zielbild (so wie du es beschrieben hast)
1. **Start** (On-Screen-Button + `.primaryAction`-Geste): Versuch beginnt → Haptik A
   (`.start`) + sichtbarer „läuft"-Zustand. Ab hier **Zeit messen** und **max. Höhe** des
   Versuchs tracken.
2. **Ende** (gleicher Auslöser): Haptik B (anders, z. B. `.stop`) → Versuch endet.
3. **Klassifizieren**: das AttemptLogView-Sheet (aus Teil C) öffnet sich **automatisch**
   (`showAttemptSheet = true` bei Übergang nach `.awaitingResult`) → Flash/Onsight/Versuch/…
   wählen → bankt mit **Dauer + max. Höhe** des Versuchs.
4. Diese Werte (Dauer, max. Höhe) pro Begehung **speichern und anzeigen** (Watch-Detail +
   iPhone).

### Umsetzungsskizze (wenn wir es angehen – vorher Rücksprache)
- `WatchAttempt`/`AscentDTO` um `durationSeconds` und `maxAltitudeGain` erweitern (DTO
  abwärtskompatibel, optionale Felder).
- `handleActionButton()` an einen prominenten Button **und** `.handGestureShortcut(.primaryAction)`
  hängen; Start-Zeit in `attemptState = .active(startTime:)` ist schon vorhanden.
- Der Altimeter-Fix aus der letzten Runde passt **genau** hierzu: `startAscentTracking()` bei
  Start, `stopAscentTracking()` liefert die max. Höhe bei Ende. (Deshalb war „Höhe = 0 bei
  AttemptLogView-Banking" korrekt – Höhe gibt es nur im echten Versuch-Flow.)
- Bei `.active → .awaitingResult` automatisch das Klassifizier-Sheet öffnen.
- Feedback klar trennen: `WKInterfaceDevice.current().play(.start)` für Start,
  `.stop`/`.success` für Ende.

> Empfehlung: Teil C zuerst (behebt den Leak, schafft die Sheet-Basis), Teil D danach als
> eigenes Feature mit Rücksprache und ggf. eigenem TODO.

---

## Reihenfolge
1. **Teil C** (Leak-Fix) + **C4-Verifikation** – höchste Priorität.
2. **Teil B** (Version im Log) + **Teil A** (CLAUDE.md) – klein, sofort mitnehmen.
3. **Teil D** – Feature, nach Rücksprache.

## Offen / Hinweis
- `historyPage` ist noch per L-A deaktiviert – nach bestätigtem Leak-Fix wieder einbinden
  (idealerweise ebenfalls nicht als verschachtelte Pager-Seite, sondern als eigener Tab/Sheet –
  siehe S19).
