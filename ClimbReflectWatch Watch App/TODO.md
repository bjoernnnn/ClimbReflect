# ClimbReflect – Offener Backlog

Pfade: **iOS** `ClimbReflect/ClimbReflect/ClimbReflect/`, **Watch** `ClimbReflectWatch Watch App/`

---

## Offen – nächste Runden

### N5.6 · Live-Activity-Steuerung (optional)
- Pause/Beenden direkt aus der Live Activity via App Intents (iOS 17+).
- Leitet Befehle an Watch weiter (`WCSession transferUserInfo`).

### N2 · Sync-DTO echte Entdoppelung
- `WatchSessionDTO` liegt in iOS + Watch doppelt vor. Strukturell jetzt identisch (Sendable, nonisolated).
- Echte Zusammenführung (geteilte Target-Membership) via Xcode GUI: Datei aus Shared-Ordner in beide Targets aufnehmen.

---

## Backlog (später)

### N3 · Statistik-Unterscreen
- Dashboard-Charts in einen eigenen „Statistik"-Tab auslagern, Startseite verschlanken.

### N6 · CoreML-Bewegungsklassifikator (Watch)
- On-Device-ML als Upgrade der heuristischen Versuchserkennung.
- Erst sinnvoll wenn genug gelabelte Sessions als Trainingsdaten vorliegen.

---

## Abgeschlossen (zuletzt)

- ✅ P5.1 – Echte Project ↔ Ascent-Relation; ProjectMedia-Modell; isPinned, targetGradeRaw
- ✅ P5.2 – Einmalige Migration projectName → Project-Entität
- ✅ P5.3 – Session-Projektmodus iOS: aktives Projekt-Banner + Picker in SessionDetailView; AddAscentView mit Chip-Picker
- ✅ P5.4 – Anpinnen: eigene Sektion in ProjectsView; Pin-Toggle in DetailSheet; Karte im Dashboard
- ✅ P5.5 – ProjectDetailView: Header, Verlaufs-Chart, Beta-Notizen, Versuchs-Timeline
- ✅ P5.6 – Medienbereich: PhotosPicker + ProjectMedia-Galerie in ProjectDetailView
- ✅ P5.7 – Watch Projekt-Wahl: AscentDTO bekommt projectName/projectID; ProjectInfo über WC; Watch-Selektor in LiveSessionView; WatchSessionReceiver mappt auf Project-Entität
- ✅ P5.8 – DTO-Strukturen angeglichen (beide Sendable, nonisolated, gleiche Felder)
- ✅ N1 – Begehung einem Projekt zuordnen (iOS + Watch, als Teil von P5.3/P5.7)
- ✅ N4 – Erfolge zusammenführen (eine Sektion, adaptive + App-Erfolge)
- ✅ N5.1 – Widget Extension Target „ClimbReflectActivity" per xcodeproj-Gem angelegt
- ✅ N5.2 – `NSSupportsLiveActivities = YES` in iOS Info.plist
- ✅ N5.3 – `ClimbActivityAttributes.swift` (iOS App + Extension)
- ✅ N5.4 – `LiveActivityController` (Start/Update/Ende an `liveStatus`-Wechsel)
- ✅ N5.5 – Widget-UI: Sperrbildschirm + Dynamic Island (compact/expanded/minimal)
- ✅ N5.7 – Verwaiste Live Activities beim App-Start beenden
