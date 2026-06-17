# ClimbReflect – Offener Backlog

Pfade: **iOS** `ClimbReflect/ClimbReflect/ClimbReflect/`, **Watch** `ClimbReflectWatch Watch App/`

---

## Offen – nächste Runden

### N1 · Begehung einem Projekt zuordnen (iOS + Watch)
- iOS `AddAscentView`: Dropdown/Chips mit aktiven Projekten.
- Watch `AttemptLogView`: optionaler Projekt-Picker nach Ergebnis.
- Send auf Projekt → automatisch auf „gesendet" setzen.

### N2 · Sync-DTO entdoppeln
- `WatchSessionDTO` liegt in iOS + Watch doppelt vor → geteiltes Target-Membership.

### N5.6 · Live-Activity-Steuerung (optional)
- Pause/Beenden direkt aus der Live Activity via App Intents (iOS 17+).
- Leitet Befehle an Watch weiter (`WCSession transferUserInfo`).

---

## Backlog (später)

### N3 · Statistik-Unterscreen
- Dashboard-Charts in einen eigenen „Statistik"-Tab auslagern, Startseite verschlanken.

### N6 · CoreML-Bewegungsklassifikator (Watch)
- On-Device-ML als Upgrade der heuristischen Versuchserkennung.
- Erst sinnvoll wenn genug gelabelte Sessions als Trainingsdaten vorliegen.

---

## Abgeschlossen (zuletzt)

- ✅ N4 – Erfolge zusammenführen (eine Sektion, adaptive + App-Erfolge)
- ✅ N5.1 – Widget Extension Target „ClimbReflectActivity" per xcodeproj-Gem angelegt
- ✅ N5.2 – `NSSupportsLiveActivities = YES` in iOS Info.plist
- ✅ N5.3 – `ClimbActivityAttributes.swift` (iOS App + Extension)
- ✅ N5.4 – `LiveActivityController` (Start/Update/Ende an `liveStatus`-Wechsel)
- ✅ N5.5 – Widget-UI: Sperrbildschirm + Dynamic Island (compact/expanded/minimal)
- ✅ N5.7 – Verwaiste Live Activities beim App-Start beenden
