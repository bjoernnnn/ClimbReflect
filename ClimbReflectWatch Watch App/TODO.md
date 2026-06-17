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

- ✅ A1 – Timer-Tick entfernt elapsedSeconds; broadcastLiveStatus nutzt currentElapsed() (TODO11)
- ✅ A2 – Live-Werte (HF, Höhe, Energie, MaxHF) in kleine Blatt-Views isoliert (TODO11)
- ✅ A3 – Altitude-Publish gedrosselt (nur wenn gerundeter Meterwert ändert); HK-Tasks gebündelt (TODO11)
- ✅ A4 – Timer-Intervall 1s → 2s (TODO11)
- ✅ A5 – Live-Status-Broadcast alle 10s (5 Ticks × 2s) (TODO11)
- ✅ A6 – DiagnosticLog-Schreibzugriffe gedrosselt (max 1×/10s, flush() bei Session-Ende) (TODO11)
- ✅ A7 – AltimeterService [weak self] im Update-Handler; Sensoren bei unerwartetem Ende stoppen (TODO11)
- ✅ B1 – AttemptDetector / Accelerometer komplett entfernt (TODO11)
- ✅ B3 – Höhen-Tracking nur während aktivem Versuch (AltimeterService) (TODO11)
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
