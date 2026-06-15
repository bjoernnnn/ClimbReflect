# ClimbReflect

iOS-Tagebuch für Klettertraining (SwiftUI + SwiftData, MVVM, iOS 17+). Ergänzt
die [Redpoint-App](https://www.redpoint.app): Daten kommen per HealthKit-Import,
du fügst Reflexionen, Stärken/Schwächen und Lernnotizen hinzu.

## Schnellstart

Voraussetzung: macOS + Xcode 16+

```bash
git clone https://github.com/bjoernnnn/ClimbReflect.git
open ClimbReflect/ClimbReflect.xcodeproj   # ▶ → iPhone-Simulator
```

Das committete `.xcodeproj` ist die maßgebliche Projektdefinition. Das `project.yml`
(XcodeGen-Quelle, drei Ebenen tiefer) dient als Referenz; nach Änderungen daran
ggf. `xcodegen generate` im Verzeichnis `ClimbReflect/ClimbReflect/` ausführen.

## Redpoint-Import (HealthKit)

Erfordert ein **echtes iPhone** (Simulator hat kein Workout-HealthKit):

1. In Xcode: **Signing & Capabilities → HealthKit** aktivieren (Entitlement-Datei
   ist bereits im Repo unter `ClimbReflect/ClimbReflect/ClimbReflect/ClimbReflect.entitlements`).
2. App starten → **Einstellungen → Jetzt synchronisieren**.
3. Health-Freigabe bestätigen → Sessions erscheinen automatisch.

Redpoint schreibt Kletter-Workouts (`.climbing`) inkl. Herzfrequenz und Energie nach
Apple Health; die App dedupliziert über die HKWorkout-UUID.

## Features

| Feature | Beschreibung |
|---------|-------------|
| Dashboard | Stats, Wochenstreak, Erfolge, Fortschritts-Chart |
| Tagebuch | RPE, Limiter, Freitext (gelernt / schwierig / verbessern) |
| Analysen | Limiter-Häufigkeit, RPE-Verlauf, Sessiontypen |
| Import | Redpoint-Workouts aus Apple Health (echtes Gerät) |
| Export | JSON-Export aller Sessions (Einstellungen) |
| Notifications | Opt-in Erinnerung, Session zu reflektieren |

## Projektstruktur

```
ClimbReflect/                        ← Repo-Wurzel
├─ ClimbReflect.xcodeproj            ← maßgebliches Xcode-Projekt
└─ ClimbReflect/                     ← Quellgruppe
   ├─ ClimbReflect/                  ← Xcode-Sync-Gruppe
   │  ├─ ClimbReflect/               ← Swift-Quellen
   │  │  ├─ ClimbReflectApp.swift
   │  │  ├─ ClimbReflect.entitlements
   │  │  ├─ Theme/
   │  │  ├─ Background/
   │  │  ├─ Models/                  ← ClimbSession, StatsEngine, Enums, MockData
   │  │  ├─ Services/                ← RedpointHealthService, NotificationService
   │  │  └─ Views/
   │  │     ├─ DashboardView.swift
   │  │     ├─ SessionDetailView.swift
   │  │     ├─ AllSessionsView.swift
   │  │     ├─ ManualSessionView.swift
   │  │     ├─ SettingsView.swift
   │  │     └─ Components/
   │  ├─ project.yml                 ← XcodeGen-Referenz
   │  └─ README.md                   ← diese Datei
   └─ ClimbReflectTests/             ← Unit-Tests (StatsEngine)
```

## Daten zurücksetzen

App im Simulator/Gerät löschen und neu installieren.  
Oder: **Einstellungen → Beispieldaten löschen** (DEBUG-Build).
