# ClimbReflect – Umsetzung Runde 4 + offene Punkte

Arbeitsplan für Claude Code. Pfade relativ zu:
- **iOS:** `ClimbReflect/ClimbReflect/ClimbReflect/`
- **Watch:** `ClimbReflectWatch Watch App/`

---

## A · iOS ✅

### A1 – Hero oben: Bouldern UND Klettern nebeneinander ✅
- `DashboardView`: `heroTrophyRow` mit zwei kompakten `heroCard`s (HStack).
- `heroBoulder` / `heroRoute` aus Sessions nach Typ gefiltert.
- Anzeige via `GradeConverter.display` in der jeweils eingestellten Skala.

### A2 – Header: „ClimbReflect" mittig, Kletter-Symbol entfernt ✅
- `DashboardView.header`: `alignment: .center`, kein `figure.climbing`-Fallback.

### A3 – Höhenmeter in der Session-Übersicht (Seilklettern) ✅
- `ClimbSession.altitudeTotalGain: Double = 0` (additive Migration).
- `WatchSessionReceiver.insert`: mappt `dto.altitudeTotalGain`.
- `SessionDetailView.redpointCard`: 4. Kennzahl für Seil-Sessions; bei 4 Metriken 2×2-Grid.

---

## B · Projekte ✅

### B1 – Project SwiftData-Modell ✅
- `Models/Project.swift`: `@Model` mit `name`, `betaNotes`, `statusRaw`, `createdAt`.
- In `ClimbReflectApp` als Schema-Typ registriert (additiv, kein Breaking Change).

### B2 – Projekt-Ansicht: aktiv vs. gesendet ✅
- `ProjectsView` neu: drei Sektionen „In Arbeit" / „Gesendet ✓" / „Aufgegeben".
- Pro Projekt: Name, Grad, „X Versuche · Y Tage", Sendedatum, Beta-Hinweis.
- Tap → `ProjectDetailSheet` mit Beta-Notizen-Editor und Aufgegeben-Toggle.
- Toolbar-+ → Projekt manuell anlegen.

### B3 – Begehung einem Projekt zuordnen – **noch offen**
- iOS `AddAscentView` und Watch `AttemptLogView` erhalten Projekt-Picker.
- Wird in nächster Runde umgesetzt.

---

## C · watchOS ✅

### C1 – Session verwerfen mit Bestätigung ✅
- `WorkoutManager.discardWorkout()`: stoppt Detector/Altimeter/Timer,
  ruft `session?.end()` **ohne** `finishWorkout()` → kein HKWorkout, kein DTO.
- `controlsPage`: neuer „Verwerfen"-Button (grau), eigener `confirmationDialog`.

### C2 – Training-Auswahl als Vollbild-Liste ✅
- `SportSelectionView`: Tipp auf „Training" schaltet inline auf Ziel-Liste um,
  Ziel-Tipp startet direkt ohne weiteren Button. `TrainingSetupView`-Sheet entfällt.

### C3 – Doppelte kcal im Training entfernt ✅
- `trainingInfoPage`: separate kcal-`statBadge` entfernt (vitalsRow zeigt kcal bereits).

---

## Noch offen – nächste Runde

### N1 – B3: Begehung einem Projekt zuordnen (iOS + Watch)
- iOS `AddAscentView`: Dropdown/Chips mit aktiven Projekten.
- Watch `AttemptLogView`: optionaler Projekt-Picker nach Ergebnis.
- Send auf Projekt → automatisch auf „gesendet" setzen.

### N2 – Sync-DTO entdoppeln
- `WatchSessionDTO` liegt in iOS + Watch doppelt vor → geteiltes Target-Membership.

### N3 – Vollständiges Funktions-Audit (iOS + Watch)
- Bewertete Funktionsliste; nichts hängt verwaist herum.

### N4 – Erfolge zusammenführen
- „App-Erfolge" und „Kletter-Erfolge" überschneiden sich → Vorschlag + Rücksprache.

### N5 – Live Activity / Dynamic Island
- Sperrbildschirm-Anzeige für laufende Watch-Session (eigener Meilenstein).

### N6 – CoreML-Bewegungsklassifikator (Watch)
- On-Device-ML als Upgrade der heuristischen Versuchserkennung (späterer Meilenstein).
