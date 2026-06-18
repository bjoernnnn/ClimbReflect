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

- ✅ TODO12 – INFOPLIST_KEY_WKBackgroundModes-String aus Build-Settings entfernt; Array bleibt in expliziter Info.plist (fix/wkbackgroundmodes)
- ✅ A1–A7, B1, B3 – Energie-/Speicher-Effizienz Watch-App (feature/energy-efficiency)
- ✅ P0-1 – WatchAttempt(fromDTO:) Initializer für Session-Recovery (TODO9)
- ✅ P0-2 – recoverIfNeeded(): HK-Session wiederaufnehmen oder Snapshot senden (TODO9)
- ✅ P1-3 – healthKitActive-Flag + Warnbanner in LiveSessionView (TODO9)
- ✅ P1-4 – endWorkout() robust gegen bereits beendete HK-Session (TODO9)
- ✅ P2-5 – WKBackgroundModes als Array via explizite Info.plist (TODO9)
- ✅ P0-1 – Verstrichene Zeit monoton aus Startdatum; TimelineView für Always-On (TODO8)
- ✅ P0-2 – Session crash-sicher auf Disk; Recovery beim App-Start (TODO8)
- ✅ P1-3 – Accelerometer-Updates auf dedizierter Hintergrund-Queue (TODO8)
- ✅ P1-4 – Session-Statuswechsel + Fehler behandeln; LiveSessionView reagiert (TODO8)
- ✅ P2-5 – Einzelne Info.plist-Quelle für Watch-Target; explizite plist entfernt (TODO8)
- ✅ P2-6 – In-App-Diagnoseprotokoll (Ring-Puffer 200 Einträge, DiagnosticView) (TODO8)
- ✅ P2-7 – Auth-Check vor Start, idempotente Sensoren, Resync beim Aufwachen (TODO8)
- ✅ P5.1–P5.8 – Projekt-Feature (iOS + Watch, Relation, Migration, Picker, Medien, Sync)
- ✅ N1 – Begehung einem Projekt zuordnen
- ✅ N4 – Erfolge zusammenführen
- ✅ N5.1–N5.5, N5.7 – Live Activity / Widget
