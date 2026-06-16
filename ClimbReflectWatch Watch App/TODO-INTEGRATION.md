# ClimbReflect – TODO: Integration, Fixes & Training-Trennung

Arbeitsplan für Claude Code, abgeleitet aus dem gemeinsamen Review von iPhone- **und**
Watch-App. Reihenfolge: **A → B → C → D → E → F** (A sind risikoarme Quick-Wins, danach
die größeren Bausteine). Format wie gewohnt: Kontext · Dateien · Aufgabe · Fertig wenn.

## Leitprinzipien

- **Kletterer-Sicht:** Jede Funktion muss helfen, **Leistung zu steigern** – Erfolge,
  Schwächen und Fortschritt sichtbar machen. Im Zweifel: Was bringt es dem Kletterer am Fels?
- **Nichts verwahrlosen:** Keine Funktion bleibt halb integriert. Ergibt eine Funktion keinen
  Sinn, wird sie **nicht eigenmächtig entfernt** – erst Rücksprache (siehe F1).
- **Getroffene Entscheidungen** (verbindlich für diese Runde):
  1. Training-Erfassung: **leicht** – Ziel/Schwäche + Dauer + RPE (keine Übungs-/Satzlisten,
     kein Last-/Kapazitätsverlauf).
  2. Action Button: **kontextabhängig** – Versuch starten → beenden → Ergebnis.
  3. Session-Screen: **sanftes Einrasten** zu den Begehungen (kein Hard-Paging jeder Sektion).

## Kanonische Projektquelle (wichtig)

Das committete **`ClimbReflect.xcodeproj`** (Repo-Wurzel) ist die echte Build-Quelle (enthält
iOS- + Watch-Target + Watch-Embed). Die alte **`ClimbReflect/ClimbReflect/project.yml`** ist
veraltet/abweichend – Änderungen gehen ins `.xcodeproj`, nicht in die `project.yml` (siehe A4).
iOS-Quellpfad: `ClimbReflect/ClimbReflect/ClimbReflect/`. Watch-Quellpfad:
`ClimbReflectWatch Watch App/`.

---

## A – Quick-Fixes & Vereinheitlichung

- [x] **A1 Naming vereinheitlichen → beide heißen „ClimbReflect"**
  - *Kontext:* Watch zeigt aktuell „ClimbReflectWatch"; im iOS-Target steckt der Alt-Name
    „KletterTagebuch".
  - *Dateien:* `ClimbReflect.xcodeproj/project.pbxproj`
    (`INFOPLIST_KEY_CFBundleDisplayName = ClimbReflect` für das Watch-Target; `productName`
    „KletterTagebuch" → „ClimbReflect").
  - *Fertig wenn:* iPhone und Watch zeigen beide „ClimbReflect" als App-Namen.

- [x] **A2 Erfolgs-Boxen einheitlich groß (Bug)**
  - *Kontext (Ursache):* `AchievementCard` nutzt variable Breite (`minWidth 120/maxWidth 160`)
    und nur `minHeight` → bei zweizeiligem Titel oder sichtbarem Fortschrittsbalken werden
    Karten größer als andere.
  - *Dateien:* `Views/Components/AchievementCard.swift` (ggf. `Views/DashboardView.swift`).
  - *Aufgabe:* Feste, einheitliche Kachelgröße (feste Breite **und** Höhe); Titel auf feste
    2-Zeilen-Höhe (`lineLimit(2)` + reservierte Höhe); Platz für den Fortschrittsbalken
    **immer** reservieren (auch wenn freigeschaltet), damit Höhe konstant bleibt.
  - *Fertig wenn:* Alle Erfolgs-Boxen sind exakt gleich groß – unabhängig von Textlänge oder
    Lock-Status.

- [x] **A3 Session-Screen: sanftes Einrasten zu den Begehungen (Bug/UX)**
  - *Kontext:* `SessionDetailView` zeigt Übersicht und Begehungen in **einer** ScrollView
    untereinander, getrennt durch einen Divider. Gewünscht: Übersicht steht zuerst für sich,
    beim kontrollierten Scrollen rastet die Ansicht **sanft** auf den Begehungs-Abschnitt ein.
  - *Dateien:* `Views/SessionDetailView.swift`.
  - *Aufgabe:* Trennlinie zwischen Übersicht und Begehungen entfernen; der Übersichtsblock
    bekommt genug Präsenz, um allein zu stehen. Begehungs-Abschnitt als Scroll-Ziel markieren
    (`.scrollTargetLayout()` + `.scrollTargetBehavior(.viewAligned)` bzw. Anchor/`scrollPosition`),
    sodass er beim Scrollen sanft oben einrastet. **Kein** Hard-Paging der übrigen Sektionen.
  - *Fertig wenn:* Übersicht wirkt als eigener „Screen"; ein kontrolliertes Scrollen zieht
    weich zu den Begehungen, ohne harten Seitenumbruch.

- [x] **A4 Repo-Hygiene: nur eine Projektquelle**
  - *Kontext:* Veraltete `project.yml` + nested README driften vom echten `.xcodeproj` ab.
  - *Dateien:* `ClimbReflect/ClimbReflect/project.yml`, `ClimbReflect/ClimbReflect/README.md`.
  - *Aufgabe:* Stale Konfiguration entfernen (oder klar als „nicht genutzt" markieren);
    README an die reale Struktur angleichen.
  - *Fertig wenn:* Es gibt genau eine maßgebliche Projektquelle; ein frischer Clone baut ohne
    Pfad-Workarounds.

---

## B – Sync vervollständigen & Datenintegrität

- [x] **B1 Kletterhöhe pro Begehung iOS-seitig speichern & anzeigen**
  - *Kontext:* Die Watch misst und zeigt `altitudeGain` pro Versuch, das **iOS-`Ascent`-Modell
    hat aber kein Höhenfeld** → beim Empfang geht die Kletterhöhe verloren.
  - *Dateien:* `Models/Ascent.swift` (`var altitudeGain: Double = 0` ergänzen, additive
    SwiftData-Migration), `Services/WatchSessionReceiver.swift` (`AscentDTO.altitudeGain`
    mappen), `Views/Components/AscentRowView.swift` + `Views/SessionDetailView.swift`
    (Höhe anzeigen, sinnvoll v. a. bei Seil-Begehungen), `Views/AddAscentView.swift`
    (optional manuell editierbar).
  - *Aufgabe:* Höhe end-to-end durchreichen und darstellen. Watch-seitig sicherstellen, dass
    `AltimeterService.start/stopAscentTracking()` jeden Versuch klammert – bei **allen** Pfaden
    (Auto-Erkennung, Action Button, manueller „+Versuch").
  - *Fertig wenn:* Eine auf der Watch geseilte Begehung zeigt ihre Höhe (m) auch auf dem iPhone.

- [ ] **B2 Sync-DTO entdoppeln (Drift verhindern)**
  - *Kontext:* `WatchSessionDTO` liegt doppelt vor (iOS + Watch) und muss von Hand synchron
    gehalten werden.
  - *Dateien:* neu geteiltes Modul/Target-Membership für `WatchSessionDTO.swift` (eine Datei,
    beiden Targets zugeordnet) oder kleines `ClimbShared`-Package; bestehende Kopien
    zusammenführen.
  - *Fertig wenn:* Es gibt genau **eine** DTO-Definition, die iPhone und Watch teilen.

---

## C – Training als eigene Aktivitätsart (Entscheidung 1: leicht)

- [x] **C1 Trennung climbing ↔ training im Modell**
  - *Kontext:* Aktuell ist `training` nur ein `SessionType` und wird in Kletterstatistiken
    gemischt. Training (z. B. Fingerkraft) soll **getrennt** behandelt werden.
  - *Dateien:* `Models/ClimbSession.swift` + `Models/Enums.swift` (Aktivitätsart unterscheiden,
    z. B. `var isTraining: Bool` bzw. abgeleitet aus `SessionType.training`), neu leichtes
    Trainingsfeld-Set.
  - *Aufgabe:* **Leichtes** Trainingsmodell: **Zielkapazität** (gemappt auf `Limiter`:
    Fingerkraft/Ausdauer/Technik/Beweglichkeit/Mental/…), **Dauer**, **RPE**, optionale Notiz.
    **Keine** Begehungen/Grade für Trainingssessions.
  - *Fertig wenn:* Ein Training lässt sich anlegen (iOS + Watch) mit Ziel + Dauer + RPE, ohne
    Grad/Begehung.

- [x] **C2 Kletterstatistiken schließen Training aus**
  - *Kontext:* Training hat keine Grade/Sends und darf Kletterauswertungen nicht verfälschen.
  - *Dateien:* `Models/Achievement.swift` (StatsEngine), `Views/Components/GradePyramidView.swift`,
    `RPETrendView`/Send-/Flash-Quote, `AntistyleRadarView`, Sessiontyp-Kletterchart,
    „Kletter-Erfolge".
  - *Aufgabe:* Alle kletterspezifischen Aggregationen filtern Trainingssessions heraus
    (Pyramide, Send-/Flash-Quote, Höchstgrad, Antistyle, Kletter-Erfolge).
  - *Fertig wenn:* Ein Trainingseintrag verändert keine Kletterstatistik.

- [x] **C3 Schwächen-Loop: „Training & Schwächen-Arbeit"**
  - *Kontext:* Der eigentliche Nutzen – sichtbar an Schwächen arbeiten.
  - *Dateien:* neu `Views/TrainingView.swift` (oder Abschnitt im Dashboard), `StatsEngine`
    (häufigste Limiter aus Klettersessions; Trainings je Zielkapazität zählen).
  - *Aufgabe:* Anzeige wie „Häufigste Schwäche: Fingerkraft — diesen Monat 5× gezielt
    trainiert ✅"; Verknüpfung der aus Klettersessions erkannten Limiter mit den dagegen
    geloggten Trainings.
  - *Fertig wenn:* Der Kletterer sieht auf einen Blick, ob und wie viel er an seiner
    häufigsten Schwäche arbeitet.

- [x] **C4 Aktivität/Streak sauber trennen**
  - *Kontext:* Klettern-Fortschritt nicht durch Training verwässern, Training aber als
    Aktivität würdigen.
  - *Aufgabe (Default, Rücksprache-fähig):* Kletter-Streak bleibt rein klettern; Training
    zählt zu „aktive Tage" und fließt in Apple Health/Fitness (Ringe/Kalorien). Optional ein
    dezenter separater Trainings-Indikator. **Bei Unklarheit Rücksprache.**
  - *Fertig wenn:* Streak/Volumen-Anzeigen sind eindeutig „klettern" vs. „aktiv inkl. Training".

- [x] **C5 Watch-Training-Flow (ohne Begehungs-Logging)**
  - *Kontext:* Bei „Training" ergeben Begehungen/Grade keinen Sinn.
  - *Dateien:* `Views/SportSelectionView.swift`, `Views/LiveSessionView.swift`,
    `Services/WorkoutManager.swift`, Fragebogen.
  - *Aufgabe:* Wählt man „Training", startet ein **anderer** Flow: Zielkapazität wählen,
    aufzeichnen (HR/Energie/Dauer + RPE über den Fragebogen), **kein** Versuchs-Logging.
    Sync als Trainingssession. Action-Button-Ergebnislogik im Trainingsmodus deaktiviert
    (siehe D1).
  - *Fertig wenn:* Ein Watch-Training erzeugt eine getrennte Trainingssession ohne Begehungen.

---

## D – Action Button: kontextabhängig (Entscheidung 2)

- [x] **D1 Kontext-State-Machine (Versuch starten → beenden → Ergebnis)**
  - *Dateien:* `ClimbReflectWatch Watch App` (Workout/Live-Session, Action-Button-Handling),
    `Services/AttemptDetector.swift`, `Views/LiveSessionView.swift`, `Views/AttemptLogView.swift`.
  - *Aufgabe:* Im Klettermodus: Druck im Ruhezustand = **Versuch starten** (Ruhe-Timer stoppen,
    Auto-Detector-Klammer öffnen, Höhen-Tracking starten); Druck während/nach dem Versuch =
    **beenden** und direkt in die 2-Tap-Ergebnisabfrage (Top/Versuch). Klar unterscheidbare
    Haptik je Übergang. Im **Trainingsmodus**: Button = Workout pausieren/fortsetzen.
  - *Fertig wenn:* Eine komplette Versuchsschleife ist hands-free über den Action Button
    bedienbar; im Training löst er kein Versuch-Logging aus.

- [x] **D2 Fallbacks & Geräte ohne Action Button**
  - *Aufgabe:* Double Tap (Series 9/Ultra 2) als Bestätigung; manueller „+ Versuch" bleibt
    immer 1 Tap entfernt; Geräte ohne Action Button bekommen ein gleichwertiges On-Screen-
    Element.
  - *Fertig wenn:* Auch ohne Action Button ist der volle Flow erreichbar.

---

## E – Aktives Training im iOS-Dashboard (Default: In-App-Banner v1)

- [x] **E1 Live-Status Watch → iPhone**
  - *Dateien:* `Services/SyncService.swift` (Watch), `Services/WatchSessionReceiver.swift` (iOS).
  - *Aufgabe:* Bei Erreichbarkeit laufende Werte senden (`sendMessage`/`updateApplicationContext`):
    laufende Zeit, Sportart, Versuchszähler, Status (aktiv/pausiert).
  - *Fertig wenn:* Das iPhone kennt während eines Watch-Trainings den Live-Status.

- [x] **E2 Dashboard-Banner mit Steuerung**
  - *Dateien:* `Views/DashboardView.swift` (Banner-Komponente).
  - *Aufgabe:* Oben am Dashboard ein Banner „Training läuft · 00:34" mit **Pause/Beenden**
    (Befehl zurück an die Watch). Bei Nicht-Erreichbarkeit: Anzeige bleibt, Steuer-Buttons
    deaktiviert + Hinweis.
  - *Fertig wenn:* Läuft ein Watch-Training, erscheint das Banner; Pause/Beenden wirken bei
    Erreichbarkeit.

- [ ] **E3 (Später) Live Activity / Dynamic Island**
  - *Aufgabe:* Sperrbildschirm/Dynamic-Island-Anzeige als Ausbau – eigener Meilenstein, kein
    v1-Blocker.

---

## F – Funktions-Audit & Governance

- [ ] **F1 Vollständiges Funktions-Audit (iOS + Watch)**
  - *Aufgabe:* Jede Funktion durchgehen und einordnen: **(a)** sinnvoll eingebunden,
    **(b)** ausbaufähig, **(c)** Kandidat zum Zusammenführen/Entfernen → **nur nach
    Rücksprache**. Ergebnis als kurze Liste festhalten.
  - *Fertig wenn:* Es gibt eine bewertete Funktionsliste; nichts hängt „verwaist" herum.

- [ ] **F2 Erfolge zusammenführen (konkreter Audit-Punkt)**
  - *Kontext:* „App-Erfolge" (feste Schwellen) und „Kletter-Erfolge" (adaptiv) existieren
    parallel und überschneiden sich.
  - *Dateien:* `Models/Achievement.swift`, `Views/DashboardView.swift`.
  - *Aufgabe:* Vorschlag erarbeiten (zusammenführen oder feste reduzieren), **dann Rücksprache**,
    erst danach umsetzen.
  - *Fertig wenn:* Es gibt einen abgestimmten, redundanzfreien Erfolge-Bereich.

- [x] **F3 Redpoint-Import als optional/sekundär kennzeichnen**
  - *Kontext:* Import bleibt vorerst, Ziel ist die eigenständige App.
  - *Dateien:* `Services/RedpointHealthService.swift`, `Views/SettingsView.swift`.
  - *Aufgabe:* Import klar als „andere Climbing-Workouts importieren (optional)" labeln; die
    Watch-Aufzeichnung ist die primäre Quelle.
  - *Fertig wenn:* Nutzer versteht, dass die App ohne Redpoint vollständig funktioniert.

---

## Reihenfolge & Rücksprache

- **Quick-Wins zuerst:** A1–A4 (Naming, beide Bugs, Hygiene) sind risikoarm und sofort sichtbar.
- **Dann Integrität:** B1/B2 (Höhe end-to-end, DTO entdoppeln).
- **Dann Features:** C (Training-Trennung) → D (Action Button) → E (Banner).
- **Begleitend:** F (Audit/Governance).
- **Regel:** Bei jeder Unklarheit oder wenn eine Funktion keinen Sinn ergibt → **erst
  Rücksprache**, gemeinsam entscheiden, dann umsetzen. Erledigtes mit `[x]` abhaken.
