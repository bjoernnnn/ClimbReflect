# ClimbReflect

Minimalistische iOS-App (SwiftUI + **SwiftData**, MVVM-nah, iOS 17+) mit dunklem Design,
diagonalem, gefadetem Berg-Hintergrund, Erfolgen, Fortschritts-Chart und echter
On-Device-Datenbank. Beim ersten Start mit Mock-Daten befüllt. Optionaler Import von
Redpoint-Klettersessions über Apple Health (HealthKit).

## Schnellstart (empfohlen, ein Befehl)

Voraussetzung: macOS mit Xcode und [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen          # falls noch nicht installiert
cd ClimbReflect
xcodegen generate              # erzeugt ClimbReflect.xcodeproj
open ClimbReflect.xcodeproj    # in Xcode öffnen → ▶ im iPhone-Simulator starten
```

## Alternativ: manuell in Xcode

1. Xcode → **File ▸ New ▸ Project ▸ App** (Interface: SwiftUI, Storage: None).
   Produktname `ClimbReflect`.
2. Die von Xcode erzeugte `ContentView.swift` und `ClimbReflectApp.swift` **löschen**.
3. Den gesamten Ordner `ClimbReflect/` aus diesem Paket per Drag & Drop in das
   Projekt ziehen („Copy items if needed" + „Create groups").
4. ▶ starten.

## Optional: echter Redpoint-Import (HealthKit)

Standardmäßig läuft die App mit Mock-Daten (Button oben rechts wirft sonst nur einen
Hinweis). Für echten Import von Redpoint-Sessions:

1. Target ▸ **Signing & Capabilities** ▸ „+ Capability" ▸ **HealthKit** hinzufügen.
2. Sicherstellen, dass `NSHealthShareUsageDescription` in der Info.plist steht
   (beim XcodeGen-Weg bereits enthalten).
3. Auf einem **echten iPhone** starten (Simulator hat kein vollständiges HealthKit
   für Workouts), Zugriff erlauben, dann oben rechts auf das Health-Symbol tippen.

Redpoint schreibt Kletter-Workouts (`.climbing`) inkl. Herzfrequenz, Dauer und Energie
nach Apple Health; die App liest diese und legt sie dedupliziert (über die Workout-UUID)
als `ClimbSession` an.

## Projektstruktur

```
ClimbReflect/
├─ ClimbReflectApp.swift          App-Einstieg, SwiftData-Container, Mock-Seeding
├─ Theme/Theme.swift              Dunkles Farb-Theme + Karten-Stil
├─ Background/MountainBackground.swift   Diagonaler, gefadeter Berg (~26 %)
├─ Models/
│  ├─ Enums.swift                 SessionType, Limiter, Source
│  ├─ ClimbSession.swift          @Model – persistente DB-Entität
│  ├─ Achievement.swift           Erfolge + Statistik-/Wochen-Engine
│  └─ MockData.swift              Startbefüllung der DB
├─ Views/
│  ├─ DashboardView.swift         Hauptscreen
│  └─ Components/                 AchievementCard, ProgressChartView, StatTile, SessionRow
└─ Services/RedpointHealthService.swift   HealthKit/Redpoint-Import
```

## Daten zurücksetzen

App vom Simulator/Gerät löschen und neu starten – dann wird wieder frisch geseedet.
