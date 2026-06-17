# ClimbReflect – Runde 5: Projekte als echtes Mehr-Session-Konstrukt

Arbeitsplan für Claude Code. Pfade relativ zu:
- **iOS:** `ClimbReflect/ClimbReflect/ClimbReflect/`
- **Watch:** `ClimbReflectWatch Watch App/`

> **Ziel (aus Kletterer-Sicht):** Ein Projekt ist eine *Route/ein Boulder, an dem ich über
> mehrere Sessions arbeite*. Es hat eine **eigene Historie** (jeder Versuch über Wochen/Monate),
> wird **über die Zeit besser** sichtbar (Verlauf), lässt sich **anpinnen/highlighten** und ich
> kann während einer Session sagen **„ich arbeite jetzt an Projekt X"** – jeder Versuch zählt
> dann **in die Gesamtstatistik UND** wird dem Projekt zugeordnet (kein Doppelzählen).

---

## Leitentscheidung (zuerst lesen): String-Tag → echte Relation

**Heute:** Ein Versuch wird per **Freitext** an ein Projekt gehängt (`Ascent.projectName: String?`).
Die `ProjectsView` baut „Projekte" zur Laufzeit, indem sie alle Ascents nach diesem String
gruppiert und per Namensgleichheit (`project.name == ascent.projectName`) auf eine `Project`-
Entität matcht. `Project` und `Ascent` sind **nicht** wirklich verbunden.

**Das ist genau der „Datensalat", den du befürchtest:**
- Tippfehler / Groß-Kleinschreibung erzeugen Phantom-Projekte („Action Direct" ≠ „action direct").
- **Projekt umbenennen verwaist alle Versuche** (deren String bleibt der alte).
- `DerivedProject.sessionsWithAscents` ist aktuell ein Stub (`return []`) – es gibt keine echte
  Verknüpfung, auf die man bauen kann.
- Es gibt keine stabile Identität → keine zuverlässige Historie, kein verlässlicher Medienbereich.

**Empfehlung (Tech Lead):** Jetzt – solange der Datenbestand klein ist – auf eine **echte
SwiftData-Relation** umstellen: `Project` ↔ `[Ascent]`. `projectName` bleibt nur noch als
Migrations-Brücke/Cache. Nachträgliches Retrofitten ist deutlich teurer. Die Änderung ist
**additiv** (neue optionale Felder + neue Entität) → leichtgewichtige Migration.

---

## P5.1 – Datenmodell: echte `Project` ↔ `Ascent`-Relation (Fundament)

- *Kontext:* Ersetzt das String-Matching durch eine stabile Relation. Basis für ALLES Weitere.
- *Dateien:* `Models/Project.swift`, `Models/Ascent.swift`, `ClimbReflectApp.swift` (Schema),
  neu `Models/ProjectMedia.swift`.
- *Aufgabe:*
  - `Ascent`: neues Feld `var project: Project?` (echte Relation). `projectName` **bleibt**
    (deprecated, nur Migration/Anzeige-Cache).
  - `Project`: echte Inverse + Anpinnen + optionaler Zielgrad:
    ```swift
    @Model
    final class Project {
        @Attribute(.unique) var id: UUID
        var name: String
        var betaNotes: String = ""
        var statusRaw: String?              // nil = auto-abgeleitet, "abandoned" = manuell
        var isPinned: Bool = false          // NEU – highlighten / anpinnen
        var gradeSystemRaw: String?         // NEU – Zielgrad-Skala (optional)
        var targetGradeRaw: String?         // NEU – Zielgrad (optional)
        var createdAt: Date

        @Relationship(deleteRule: .nullify, inverse: \Ascent.project)
        var ascents: [Ascent] = []          // Projekt löschen lässt Ascents/Statistik unberührt

        @Relationship(deleteRule: .cascade, inverse: \ProjectMedia.project)
        var media: [ProjectMedia] = []      // projekteigene Medien (siehe P5.6)
    }
    ```
  - Neue Entität `ProjectMedia` (siehe P5.6).
  - In `ClimbReflectApp` Schema um `ProjectMedia.self` erweitern.
- *Wichtig:* `deleteRule: .nullify` auf den Ascents → ein gelöschtes Projekt entfernt **nie**
  Versuche aus der Session/Gesamtstatistik (es löst nur die Zuordnung). Das ist die technische
  Garantie hinter Bedenken #1.
- *Fertig wenn:* Ascents tragen eine echte `project`-Referenz; Umbenennen eines Projekts hält
  alle Versuche; Schema migriert ohne Store-Reset.

## P5.2 – Einmalige Migration `projectName` → `Project`

- *Kontext:* Bestandsdaten (Versuche mit `projectName`-String) in die neue Relation überführen.
- *Dateien:* neu `Services/ProjectMigration.swift`; Aufruf in `ClimbReflectApp.init` (idempotent).
- *Aufgabe:* Einmal-Lauf: für jeden distinct `Ascent.projectName` ein `Project` find-or-create
  (per Name, getrimmt/case-insensitive) und `ascent.project` setzen. Flag in `UserDefaults`
  („projectMigrationV1 done"), damit es nur einmal läuft.
- *Fertig wenn:* Alle Alt-Versuche mit Projektnamen hängen an einer echten `Project`-Entität;
  die `ProjectsView` zeigt identische Projekte wie vorher, jetzt aber stabil verknüpft.

## P5.3 – Session-Projektmodus: „Ich arbeite jetzt an Projekt X" (iOS) — *Bedenken #1*

- *Kontext:* Kern-UX gegen unzugeordnete Versuche. Statt pro Versuch den Projektnamen zu tippen,
  setzt man **einmal pro Session** ein aktives Projekt; alle folgenden Versuche tag-en automatisch.
- *Dateien:* `Views/SessionDetailView.swift` (aktives Projekt-Banner + Auswahl), `Views/AddAscentView.swift`
  (Projekt-Picker statt Freitext), evtl. kleiner `@Observable SessionContext`.
- *Aufgabe:*
  - In der laufenden/offenen Session ein **Banner „Aktuelles Projekt: …"** mit Auswahl
    (Picker/Chips aus bestehenden Projekten + „Neu" + „Keins").
  - `AddAscentView`: Freitextfeld ersetzen durch **Picker über bestehende Projekte**
    (Autocomplete/Chips), vorbelegt mit dem aktiven Projekt der Session. Freie Neuanlage bleibt
    möglich, aber gegen die Projektliste – keine Tippfehler-Duplikate mehr.
  - Jeder so erfasste Versuch ist ein **ganz normaler `Ascent` der Session** (zählt voll in
    Gesamtstatistik) **plus** `ascent.project = X`. Kein zweiter Datensatz, kein Doppelzählen.
  - „Keins" wählbar → bewusst unzugeordnet (z. B. random Auf-/Abwärmen).
- *Fertig wenn:* Ich aktiviere ein Projekt einmal, logge fünf Versuche, und alle fünf sind dem
  Projekt zugeordnet **und** in der Session/Gesamtstatistik – ohne pro Versuch zu tippen.

## P5.4 – Anpinnen / Highlight — *expliziter Wunsch*

- *Kontext:* Ein Projekt soll dauerhaft sichtbar/oben angepinnt sein.
- *Dateien:* `Views/ProjectsView.swift`, `Views/DashboardView.swift`.
- *Aufgabe:*
  - `Project.isPinned` (aus P5.1). Swipe-Action / Toggle im `ProjectDetailSheet` zum Anpinnen.
  - `ProjectsView`: angepinnte Projekte als eigene oberste Sektion **„📌 Angepinnt"**, sonst
    sortiert wie bisher.
  - `DashboardView`: **eine** schlanke Karte „Aktuelles Projekt" für das (zuletzt) angepinnte
    aktive Projekt – Name, Grad, „X Versuche · Y Tage", Tap → Detail. Nur angepinnte zeigen,
    damit das Dashboard ruhig bleibt (siehe Bedenken #3).
- *Fertig wenn:* Ein angepinntes Projekt steht oben in der Liste und als kompakte Karte im
  Dashboard; Anpinnen/Lösen mit einem Tap.

## P5.5 – Projekt-Detail: eigene Historie & Verlauf — *Bedenken #3*

- *Kontext:* Das heutige `ProjectDetailSheet` zeigt nur Stats + Beta-Notiz + Aufgegeben-Toggle.
  Es fehlt die **Versuchs-Historie über Sessions** und der **Fortschritt über die Zeit**.
- *Dateien:* neu `Views/ProjectDetailView.swift` (ersetzt/erweitert das Sheet).
- *Aufgabe:* Eine fokussierte, eigenständige Detailseite (NICHT mit Dashboard-Infos überladen):
  - **Kopf:** Name, Status (In Arbeit / Gesendet ✓ / Aufgegeben), bester Top-Grad, Zielgrad,
    Pin-Button.
  - **Verlauf:** Versuche gruppiert nach Tag/Session, chronologisch (Timeline). Pro Eintrag:
    Datum, Ergebnis (Top/Versuch/Abbruch), Stil (Flash/Onsight/Rotpunkt), Notiz, Foto-Thumb.
  - **Fortschrittsanzeige:** kompaktes Chart „Highpoint/Ergebnis je Session" → zeigt das
    „über die Zeit besser werden". (Swift Charts, gleiche Optik wie `ProgressChartView`.)
  - **Beta-Notizen** (bestehend) + **Medien-Galerie** (P5.6).
  - Reine Lese-/Pflege-Ansicht – keine globalen Stats, kein Hero, kein Rauschen.
- *Fertig wenn:* Ich öffne ein Projekt und sehe NUR seine Geschichte: alle Versuche über alle
  Sessions, den Verlauf und die Beta – nichts anderes.

## P5.6 – Projekt-Medienbereich (getrennt von Ascent-Fotos) — *Bedenken #2*

- *Kontext:* Heute hängen Fotos nur am einzelnen `Ascent` (`photoData`). Es gibt keinen Ort für
  projektweite Bilder/Topos/Beta-Skizzen.
- *Dateien:* `Models/ProjectMedia.swift` (P5.1), `Views/ProjectDetailView.swift`.
  ```swift
  @Model
  final class ProjectMedia {
      @Attribute(.unique) var id: UUID
      @Attribute(.externalStorage) var imageData: Data?   // hält Haupt-DB klein
      var caption: String?
      var createdAt: Date
      var project: Project?
  }
  ```
- *Aufgabe:* In der Projekt-Detailseite eine **Galerie** mit `PhotosPicker` zum Hinzufügen,
  Caption optional, Löschen pro Bild. Klar getrennt von den Crux-Fotos einzelner Versuche.
- *Fertig wenn:* Ich kann mehrere Bilder samt Notiz an EIN Projekt hängen, ohne dass sie sich mit
  Session-/Ascent-Fotos vermischen.

## P5.7 – Watch: aktives Projekt wählen (vormals N1 + W5.2) — *Bedenken #4*

- *Kontext:* Heute kennt die Watch keine Projekte; `WatchSessionDTO.AscentDTO` hat kein Projektfeld.
- *Dateien:* iOS `Services/WatchSessionReceiver.swift` (oder neuer `ProjectSyncService`),
  Watch `Services/SyncService.swift`, `Views/LiveSessionView.swift`, `Views/AttemptLogView.swift`,
  `Services/WorkoutManager.swift`, beidseitig `WatchSessionDTO.swift`.
- *Aufgabe:*
  1. **iPhone → Watch:** aktive (+ angepinnte) Projekte als leichte Liste (id, name, grade) via
     `WCSession` `updateApplicationContext`/`transferUserInfo` an die Watch pushen.
  2. **Watch-Auswahl:** in `LiveSessionView` ein **„Aktuelles Projekt"-Selektor** (einmal pro
     Session setzen, gleiche Logik wie iOS-Session-Modus). Optional Tap im `AttemptLogView`.
  3. `WorkoutManager.bankAttempt(...)` trägt das aktive `projectID`/`projectName` in den Versuch.
  4. **DTO:** `AscentDTO` bekommt `projectName: String?` **und** `projectID: UUID?`.
  5. **Empfang iOS:** `WatchSessionReceiver` mappt den Versuch auf die echte `Project`-Entität
     (per id, Fallback name) → `ascent.project = …`. Versuch zählt normal in die Session.
  6. **Send-Automatik:** Ein `.top` auf ein Projekt setzt dessen Status automatisch auf „gesendet".
- *UI/UX-Leitplanke (Watch):* eine Hauptaktion pro Screen, Auswahl per Krone/Liste, nie ein
  Pflichtschritt vor dem Versuch. Projekt-Auswahl ist optional und „klebrig" für die Session.
- *Fertig wenn:* Ich wähle am Handgelenk zu Session-Beginn ein Projekt, logge Versuche, und auf
  dem iPhone sind diese Versuche dem Projekt zugeordnet **und** in der Session erfasst – ohne
  Duplikate.

## P5.8 – Sync-DTO entdoppeln (vormals N2)

- *Kontext:* `WatchSessionDTO` liegt in iOS + Watch doppelt vor. Vor dem Projektfeld (P5.7) sauber
  zusammenführen, sonst driften die Strukturen.
- *Dateien:* `WatchSessionDTO.swift` → geteilte Target-Membership (iOS + Watch).
- *Fertig wenn:* Eine einzige DTO-Definition, beide Targets nutzen sie; Projektfeld nur an einer
  Stelle gepflegt.

---

## Reihenfolge & Abhängigkeiten

```
P5.1 (Modell)  ──►  P5.2 (Migration)  ──►  P5.3 (Session-Modus iOS)
   │                                          │
   ├──►  P5.4 (Anpinnen)                       │
   ├──►  P5.5 (Detail/Historie)  ◄────────────┘
   ├──►  P5.6 (Medienbereich)   (braucht P5.1)
   └──►  P5.8 (DTO entdoppeln)  ──►  P5.7 (Watch-Projektwahl)
```

- **P5.1 + P5.2 zuerst** – ohne stabile Relation bleibt alles Datensalat.
- **P5.3** ist die wichtigste UX gegen unzugeordnete Versuche – direkt danach.
- **P5.4/P5.5/P5.6** sind UI auf dem Fundament, parallelisierbar.
- **P5.8 vor P5.7** (DTO erst sauber, dann erweitern).

---

## Mapping zu den 4 Bedenken

| Bedenken | Heute | Lösung |
|---|---|---|
| **1 – Projekt in Ruhe bearbeiten, keine unzugeordneten Ascents** | Projekt = Freitext pro Versuch; vergisst man es, ist der Versuch unzugeordnet | **P5.3 Session-Projektmodus**: einmal setzen, alle Versuche taggen automatisch; zählen voll in Gesamtstatistik (`deleteRule .nullify` schützt Statistik) |
| **2 – Infos/Bilder im „Projektbereich" ohne Salat** | Fotos nur am Ascent; Projekt-Match per String → fragil | **P5.1 echte Relation** (kein Salat) + **P5.6 ProjectMedia** (eigener Medienbereich) |
| **3 – Übersichtliche Anzeige ohne Überflutung** | Detail-Sheet nur Stats + Beta; keine Historie | **P5.5 Projekt-Detail**: nur die eigene Geschichte (Verlauf, Versuche, Beta, Galerie), kein Dashboard-Rauschen |
| **4 – Projekt direkt von der Uhr wählen** | Watch kennt keine Projekte; DTO ohne Projektfeld | **P5.7**: iPhone→Watch-Push, „Aktuelles Projekt" am Handgelenk, DTO-Feld, Mapping beim Empfang; Versuche bleiben in der Session |

---

## Offene Entscheidung für dich (Tech-Lead-Empfehlung markiert)

1. **String-Tag vs. echte Relation** → *Empfehlung: echte Relation jetzt (P5.1/P5.2).* Der einzige
   „Preis" ist eine einmalige Migration; dafür verschwindet der Datensalat dauerhaft.
2. **Status „gesendet"**: weiter automatisch aus „mind. 1 Top" ableiten (heutiges Verhalten) –
   ich würde es so lassen und nur „aufgegeben" manuell halten.
3. **Dashboard-Sichtbarkeit**: nur **angepinnte** Projekte als Karte zeigen (ruhiges Dashboard),
   Rest in der Projekte-Liste.
