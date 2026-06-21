# TODO – Zweite Seite + Ascent-Liste zurück (leak-sicher) + Action-Attempt-Flow

**Branch:** `dev` @ `4c4731a`

## Stand (bestätigt durch letzten Test)

- ✅ **Leak behoben:** 13 min flach bei ~74 MB trotz 2 Ascents. Ursache bestätigt:
  **AttemptLogView als Dauer-Tab** in der Paging-`TabView` (als Sheet flat, als Tab Leak).
- ✅ Version im Log (`v1.0 (1)`) + Recovery-Finalisierung laufen.
- Björn will: **zweite Swipe-Seite** zum Klassifizieren **zurück** und **Ascent-Liste** wieder
  sichtbar. Den Sheet-Button auf der Startseite findet er schlecht → wieder entfernen.
- **Action Button:** `handleActionButton()` ist nicht verdrahtet. Physischer Action-Button ist
  per Drittanbieter nur über **App Intents** ansprechbar (Start/Shortcut-Modell), **nicht** als
  Live-Toggle in der Session. → In-App-Lösung: On-Screen-Button + Doppeltipp-Geste.

> ⚠️ Offene Rücksprache: Bevor TEIL C (Action-Flow) umgesetzt wird, bitte Björns Antwort
> abwarten, ob Doppeltipp-Geste als „Action Button" OK ist.

---

## TEIL A – Ascent-Liste wieder anzeigen (sicher, sofort)

`historyPage` ist nachweislich **nicht** der Leak (L-A: ohne sie trat der Leak trotzdem auf).
In `LiveSessionView.swift` den L-A-Kommentar rückgängig machen:

```swift
        TabView {
            statsPage
                .overlay {
                    if workoutManager.attemptState == .awaitingResult {
                        quickResultOverlay
                    }
                }
            if !workoutManager.attempts.isEmpty {
                historyPage
            }
        }
        .tabViewStyle(.verticalPage)
```

> Nach dem Aktivieren im Test prüfen, dass der Speicher flach bleibt (historyPage sitzt im
> verschachtelten `.verticalPage`-TabView – sollte ok sein, aber im selben Testlauf
> mitbeobachten).

---

## TEIL B – Zweite Swipe-Seite zurück, aber leak-sicher

Ziel: AttemptLogView ist wieder eine Swipe-Seite (Tab 2), **ohne** dauerhaft im Hintergrund zu
leben. Trick: schweren Inhalt nur bauen, wenn die Seite aktiv ist.

**B1** – Sheet-Variante aus TEIL C der letzten Runde zurückbauen:
- `@State private var showAttemptSheet` und das `.sheet(isPresented: $showAttemptSheet) { … }`
  **entfernen**.
- Den „Versuch erfassen"-Button auf `statsPage` **entfernen** (den fand Björn schlecht).

**B2** – AttemptLogView wieder als Tab 2 einhängen, aber **content-gated**:
```swift
        Group {
            if currentTab == 2 {
                AttemptLogView(onBank: { currentTab = 1 })
            } else {
                Color.clear   // Platzhalter: baut den Wheel-Picker NICHT im Hintergrund
            }
        }
        .tag(2)
```
in `climbingTabView`, zwischen `sessionInfoPage.tag(1)` und dem `.tabViewStyle(.page…)`.

> Wirkung: Solange man nicht auf Tab 2 ist, ist die Seite nur `Color.clear` – der Wheel-Picker
> (die vermutete Leak-Quelle, weil als Dauer-Tab retainiert) wird nicht gehalten. Beim
> Hinswipen baut er sich auf. Swipe-UX bleibt erhalten, Wheel-Picker bleibt erhalten.

**B3 – Verifikation (Pflicht, bevor TEIL C):**
Session, **3–4 Ascents über Tab 2 banken**, ~15 min ruhig. Erwartet: Speicher flach (Δ≈0).
- **Flach → super, zweite Seite ist zurück und leak-frei.**
- **Steigt wieder** → dann ist der Wheel-`Picker` selbst die Quelle (auch content-gated nicht
  genug, weil der Pager die Nachbarseite vorrendert). Fallback dann:
  (a) Wheel-`Picker` durch eine nicht-Wheel-Grad-Auswahl ersetzen (Liste/Stepper), **oder**
  (b) Klassifizierung als Sheet, das bei Versuch-Ende **automatisch** erscheint (kein
  Startseiten-Button) – funktional Björns Flow, nur modal statt Swipe.
  → bei diesem Fall Rücksprache + ggf. Instruments-Allocations zur Bestätigung des Picker.

---

## TEIL C – Action-Attempt-Flow (nach Rücksprache zur Geste)

> Erst umsetzen, wenn Björn die Doppeltipp-Geste als „Action Button" bestätigt hat.

Befund: `handleActionButton()` existiert, hat aber **keinen Auslöser**. Zielflow:
**Start → Ascent (Zeit + max. Höhe) → Ende → automatisch zu Tab 2 (klassifizieren).**

**C1 – Auslöser verdrahten:** `handleActionButton()` an
- einen prominenten On-Screen-Button auf `statsPage` (groß, gut tippbar) **und**
- `.handGestureShortcut(.primaryAction)` (Doppeltipp)
hängen.

**C2 – Feedback trennen:**
- Start (`.idle → .active`): `WKInterfaceDevice.current().play(.start)` + sichtbarer
  „läuft"-Zustand (z. B. pulsierender Indikator, Timer der Versuchsdauer).
- Ende (`.active → .awaitingResult`): anderes Haptik-Signal, z. B. `.stop` oder `.success`.

**C3 – Auto-Navigation:** Bei `.active → .awaitingResult` automatisch `currentTab = 2` setzen
(springt zur Klassifizier-Seite). Nach `bankAttempt` zurück auf `currentTab = 1`.

**C4 – Höhe + Zeit pro Versuch:** Der Altimeter-Fix der letzten Runde passt genau:
`startAscentTracking()` bei Start, `stopAscentTracking()` liefert die max. Höhe bei Ende.
Versuchsdauer aus `attemptState = .active(startTime:)`.
- `WatchAttempt` + `WatchSessionDTO.AscentDTO` um optionale Felder `durationSeconds` und
  `maxAltitudeGain` erweitern (abwärtskompatibel).
- In `bankAttempt`/`quickBank` diese Werte setzen und beim Ascent speichern + anzeigen
  (Watch-Detail + iPhone).

**C5 – (optional, später) Physischer Action Button:** Ein App Intent bereitstellen, das eine
**Session startet** (nicht pro-Versuch-Toggle). Dann kann der Nutzer in den Watch-Einstellungen
ClimbReflect dem Action Button zuweisen. Für den Start/Ende-Versuchsflow bleibt es bei
On-Screen-Button + Doppeltipp.

---

## TEIL D – CLAUDE.md dokumentieren

Ergänzen (höchste Nummer aktuell S21):

- **S22 – Memory-Leak war AttemptLogView als Dauer-Tab in der Paging-`TabView`.** Als modales
  Sheet (oder content-gated, nur bei aktiver Seite gebaut) flat; als dauerhaft gehaltener
  Swipe-Tab Leak (~10 MB/min, vermutlich retainierter Wheel-`Picker`). Lehre: schwere/zustands-
  behaftete Views nicht dauerhaft als Pager-Tab halten.
- **S23 – Action Button (Watch Ultra) ist für Dritt-Apps nur via App Intents ansprechbar**
  (Start-/Shortcut-Modell), **kein** Live-Toggle in der laufenden App. In-App-Ersatz:
  On-Screen-Button + `.handGestureShortcut(.primaryAction)` (Doppeltipp).

---

## Reihenfolge
1. **TEIL A** (Ascent-Liste) + **TEIL B** (zweite Seite leak-sicher) + **B3-Test**.
2. **TEIL D** (CLAUDE.md) mitnehmen.
3. **TEIL C** erst nach Björns Bestätigung zur Geste.
