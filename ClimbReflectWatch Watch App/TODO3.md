# ClimbReflect – Umsetzung Runde 3 (nach 2. Test)

Arbeitsplan für Claude Code. Pfade relativ zu:
- **iOS:** `ClimbReflect/ClimbReflect/ClimbReflect/`
- **Watch:** `ClimbReflectWatch Watch App/`

---

## P0 · Berg-Hintergrund wiederherstellen ✅

- Diagonale Bergsilhouette aus Commit `6423ea9~1` wiederhergestellt.
- Watch-seitige `MountainBackground.swift` (verwendete `Theme` statt `WatchTheme`) gelöscht,
  da sie von keiner Watch-View genutzt wurde.

---

## P1 · Funktionale Bugs ✅

### F1 – Manuelle Session: Art der Session wählbar machen ✅
- `Views/ManualSessionView.swift`: Typ-Picker an den Anfang des Formulars,
  `.contentShape(Rectangle())` auf alle Button-Labels.

### F2 – watchOS: Herzfrequenz UND Höhe zeigen echte Werte ✅
- `AltimeterService`: positive Höhendeltas immer auf `totalGain` addieren (unabhängig
  von der Versuchs-Klammer).
- `LiveSessionView`: `vitalsRow` auch im Always-On zeigen (`.opacity(0.6)` statt hidden).

### F3 – iOS: Pause/Beenden-Buttons des Live-Trainings ✅
- `LiveSessionBanner`: Buttons 44×44, `transferUserInfo`-Fallback wenn nicht reachable.
- `SyncService` (Watch): `didReceiveUserInfo` implementiert für `"watchCommand"`.

---

## P2 · UI / UX ✅

### U1 – Technik-Fokus: Mehrfachauswahl + Sterne entfernen ✅
- `ClimbSession`: `techniqueFocusesRaw: [String] = []`, Migration aus altem Einzelfeld.
- `SessionDetailView`: Multi-Select (toggeln wie Limiter), Sterne-Block entfernt.

### U2 – Zeitraum-Auswahl in Charts schöner ✅
- `ChartPeriodPicker`: Pill-Segment im App-Stil, kompakt oben rechts im Karten-Header.
- Einheitlich in RPETrendView, AntistyleRadarView, GradePyramidView, LimiterFrequencyView.

### U3 – AllSessions: Pfeil (Chevron) rechts entfernen ✅
- `AllSessionsView`: `ZStack { SessionRow + NavigationLink(EmptyView).opacity(0) }`.

### U4 – watchOS: Timer-Größe zurücksetzen ✅
- `LiveSessionView`: `elapsedFormatted` wieder `.font(.system(.title, …))`.

### U5 – „Bester Rotpunkt" → „Bester Ascent" ✅
- `DashboardView`: Text in `heroTrophyCard` ersetzt.

---

## Noch offen – nächste Runde

### N1 – Sync-DTO entdoppeln
- *Kontext:* `WatchSessionDTO` liegt doppelt vor (iOS + Watch) und muss von Hand synchron
  gehalten werden.
- *Aufgabe:* Geteiltes Target-Membership oder `ClimbShared`-Package; eine Datei, beide Targets.
- *Fertig wenn:* Genau eine DTO-Definition, die iPhone und Watch teilen.

### N2 – Vollständiges Funktions-Audit (iOS + Watch)
- *Aufgabe:* Jede Funktion einordnen: sinnvoll eingebunden / ausbaufähig / Kandidat zum
  Entfernen → erst Rücksprache, dann umsetzen.
- *Fertig wenn:* Bewertete Funktionsliste, nichts hängt verwaist herum.

### N3 – Erfolge zusammenführen
- *Kontext:* „App-Erfolge" (feste Schwellen) und „Kletter-Erfolge" (adaptiv) überschneiden sich.
- *Aufgabe:* Vorschlag erarbeiten (zusammenführen oder reduzieren) → Rücksprache → umsetzen.
- *Fertig wenn:* Redundanzfreier Erfolge-Bereich.

### N4 – Live Activity / Dynamic Island
- *Aufgabe:* Sperrbildschirm/Dynamic-Island-Anzeige für laufende Watch-Session.
- *Hinweis:* Eigener Meilenstein, kein v1-Blocker.

### N5 – CoreML-Bewegungsklassifikator (Watch)
- *Aufgabe:* On-Device-ML als Upgrade der heuristischen Versuchserkennung (wie Redpoint).
- *Hinweis:* Eigener Meilenstein, kein v1-Blocker.
