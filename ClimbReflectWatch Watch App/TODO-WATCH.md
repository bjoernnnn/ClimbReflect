# ClimbReflect Watch – TODO (watchOS-Companion, priorisiert)

**Ziel:** Eine eigenständige watchOS-App, mit der man ein Klettertraining am Handgelenk
startet, alle Vital- und Höhenwerte aufzeichnet, **Versuche automatisch + manuell** erfasst
und **pro Versuch** Grad / Ergebnis (Top? Flash/Onsight/Redpoint) zuordnet. Die Versuche
hängen am Training. Alles synchronisiert mit dem iPhone (SwiftData) **und** Apple Health/
Fitness. Damit erzeugt ClimbReflect **seinen eigenen Climbing-Workout** und wird
**unabhängig von Redpoint** (standalone) – der bisherige Redpoint-Import bleibt nur optional.

> **Abhängigkeit:** Setzt **P3.1 (Begehung/`Ascent` mit Grad + Ergebnis)** aus der
> erweiterten `TODO.md` voraus. Einzelne Versuche ergeben nur Sinn, wenn sie an einem
> Training hängen – also zuerst P3.1, dann diese Watch-Roadmap. Ergänzt `TODO.md`,
> ersetzt sie nicht.

---

## UI/UX-Leitlinien – HÖCHSTE PRIORITÄT (gelten für alle W-Punkte)

Die Watch muss **instinktiv ohne Überforderung** bedienbar sein – mit verschwitzten,
chalkigen Fingern, oft ohne genau hinzuschauen.

- **Eine Hauptaktion pro Screen.** Glanceable, kein Daten-Overload. Im Zweifel weniger zeigen.
- **Große Tap-Ziele, dunkles High-Contrast-Theme** (identisch zur iPhone-App).
- **Krone + Buttons statt Mini-Touch:** Digital Crown für Grad-Auswahl, **Double Tap**
  (Series 9 / Ultra 2) zum Bestätigen, **Action Button** (Ultra) für Start/Versuch/Tick –
  damit man den chalkigen Screen nicht berühren muss (wie Redpoint).
- **Haptik bei jeder Bestätigung** – man schaut beim Klettern nicht aufs Display.
- **Defaults nutzen:** letzte Sportart und letzter Grad vorausgewählt → 1-Tap-Wiederholung
  (Gym-Circuits haben oft denselben Grad in Serie).
- **Auto-Erkennung ist assistierend, nicht autoritativ:** sie *schlägt* einen Versuch vor,
  du bestätigst/labelst. Nie still falsch loggen. **„+ Versuch" ist immer 1 Tap entfernt.**
- **Minimale Interaktion:** erkannter Versuch → 1 Tap *Top/Versuch* → (bei Top) Krone auf
  *Grad* + 1 Tap *Stil* → fertig. **Ziel: ein Send in ≤ 3 Interaktionen.**
- **„Später"-Prinzip überall:** Versuch ohne Label „banken" und Details später am iPhone
  vervollständigen (Watch-Session → iPhone → zuordnen, wie Redpoint).
- **Always-On-tauglich:** Zeit + Versuchszähler ohne Aufwecken sichtbar.

## Orientierung an Redpoint (bewährte UX als Referenz)

- Workout starten → Sportart/Gear-Style wählen; Workout liegt als **Climbing in HealthKit**
  → Fitness-Ringe, sichtbar in Health/Workouts.
- **Barometer** misst Höhenmeter und erkennt Routen-Peaks; zusätzlich **On-Device-ML** zur
  Bewegungsklassifikation. → Wir starten **heuristisch** (Barometer für Seil,
  Bewegungsburst + HF für Boulder), ML als späteres Upgrade.
- **Grad & Tick-Type direkt am Handgelenk**; auf Ultra per Action Button ohne Touch.
- **Fehlversuche zählen nicht** zu Tops/Höhenmetern.
- Nach der Session **Transfer aufs iPhone**, dort jeden Ascent zuordnen.
- **Bekannte Redpoint-Schwäche vermeiden:** bei gemischten Sessions (Boulder + Toprope +
  Lead) behält Redpoint fälschlich die Skala der ersten Wahl. Bei uns ist **Typ/Skala pro
  Versuch** wählbar bzw. der Wechsel sauber.

---

## W0 – Watch-Target & Fundament

- [x] **W0.1 watchOS-App-Target anlegen**
  - *Aufgabe:* SwiftUI-watchOS-Target hinzufügen, Bundle-ID-Suffix, **App-Group** für
    geteilte Settings/Daten. `Theme` und gemeinsame Modelle/DTOs in ein geteiltes Modul
    (`ClimbCore` Swift Package) oder per Datei-Sharing auslagern, damit iPhone & Watch
    denselben Code/Look nutzen.
  - *Dateien:* `project.yml` (Watch-Target + Shared-Framework), neu `Watch/`-Ordner.
  - *Fertig wenn:* Die Watch-App startet auf Simulator/Gerät und zeigt einen Startbildschirm
    im ClimbReflect-Dark-Theme.

## W1 – Workout-Session & Live-Metriken (HealthKit)

- [x] **W1.1 Climbing-Workout mit Live-Werten**
  - *Aufgabe:* `HKWorkoutSession` + `HKLiveWorkoutBuilder` für
    `HKWorkoutActivityType.climbing`; live **Herzfrequenz, aktive Energie, Dauer**;
    Hintergrundausführung während des Workouts; Pause/Resume; am Ende **HKWorkout in
    HealthKit speichern**.
  - *Dateien:* neu `Watch/Services/WorkoutManager.swift`.
  - *Fertig wenn:* Ein Climbing-Workout läuft mit Live-HF/Energie/Zeit, speichert ein
    HKWorkout (sichtbar in Health/Fitness, schließt die Ringe).

- [x] **W1.2 Höhenmeter via Barometer**
  - *Aufgabe:* `CMAltimeter` (relative Höhe) erfassen und kumulieren; max. Höhe / Aufstieg
    pro Versuch ableitbar machen.
  - *Berechtigungen:* HealthKit (read+share: Workouts/HF/Energie), Motion & Altimeter
    Usage-Strings + Entitlement.
  - *Fertig wenn:* Während des Trainings werden Höhenmeter zuverlässig erfasst und angezeigt.

## W2 – Session-Flow & Sportartwahl (UX, hohe Priorität)

- [x] **W2.1 Startflow: Sportart wählen**
  - *Aufgabe:* Große, ikonische Liste (Bouldern/Toprope/Vorstieg/Autobelay/Training);
    **letzte Wahl vorausgewählt**; die Grad-Skala folgt der Sportart (Fb/V fürs Bouldern,
    French/UIAA fürs Seil).
  - *Dateien:* neu `Watch/Views/SportSelectionView.swift`.
  - *Fertig wenn:* Training startet in ≤ 2 Taps.

- [x] **W2.2 Live-Screen**
  - *Aufgabe:* Groß: **Dauer, HF, Versuchszähler, Höhenmeter**; prominente
    **„+ Versuch"-Aktion**; Krone/Swipe zu Detailwerten; **„Beenden"** mit Bestätigung.
  - *Dateien:* neu `Watch/Views/LiveSessionView.swift`.
  - *Fertig wenn:* Live-Werte sind glanceable; Beenden führt zur Zusammenfassung (W7).

## W3 – Versuch erfassen & zuordnen (KERN-UX, höchste Priorität)

- [x] **W3.1 Manueller „+ Versuch" (primärer, zuverlässiger Pfad)**
  - *Aufgabe:* Immer mit 1 Tap erreichbar; legt sofort einen Versuch an der laufenden
    Session an.
  - *Fertig wenn:* Ein Versuch ist jederzeit mit einem Tap erfassbar.

- [x] **W3.2 Schnell-Zuordnung nach dem Versuch**
  - *Aufgabe:* **Schritt 1 – Ergebnis:** groß zweigeteilt *Top* / *Versuch*.
    **Schritt 2 (nur bei Top):** *Stil* (Flash/Onsight/Redpoint/Top after work) + **Grad
    über Digital Crown** (große Zahlen, **letzter Grad als Default**).
  - *Dateien:* neu `Watch/Views/AttemptLogView.swift`.
  - *Fertig wenn:* Ein Send ist in **≤ 3 Interaktionen** vollständig geloggt.

- [x] **W3.3 „Banken & später"**
  - *Aufgabe:* Versuch ohne Label speichern; Detail später am iPhone (oder am Handgelenk)
    ergänzen.
  - *Fertig wenn:* Ein unbeschrifteter Versuch lässt sich banken und erscheint später zum
    Vervollständigen.

- [x] **W3.4 Versuche an die Session hängen + Live-Aggregat**
  - *Aufgabe:* Versuche in-memory an die laufende Session binden; **Zähler / Tops /
    Höchstgrad** live aktualisieren; Fehlversuche **nicht** in Höhenmeter/Tops zählen.
  - *Fertig wenn:* Alle Versuche der Session erscheinen in der Zusammenfassung mit korrektem
    Aggregat.

- [x] **W3.5 Typ/Skala pro Versuch (Mixed-Session)**
  - *Aufgabe:* Versuchstyp/Skala pro Versuch wählbar bzw. sauberer Wechsel → vermeidet die
    Redpoint-Schwäche bei gemischten Sessions.
  - *Fertig wenn:* In einer Session lassen sich Boulder- und Seil-Versuche mit jeweils
    korrekter Skala mischen.

## W4 – Automatische Versuchserkennung (heuristisch v1, ehrlich begrenzt)

- [x] **W4.1 Seil (Toprope/Vorstieg) per Barometer**
  - *Aufgabe:* Anhaltender Netto-Höhengewinn über Schwelle (z. B. 2–3 m) startet einen
    Versuch; Rückkehr Richtung Baseline (Ablassen/Abklettern) beendet ihn → Höhenmeter pro
    Versuch.
  - *Fertig wenn:* Eine geseilte Route wird zuverlässig als Versuch vorgeschlagen.

- [x] **W4.2 Boulder per Bewegungsburst + HF**
  - *Aufgabe:* `CMMotionManager` (Beschleunigung/Gyro): Effort-Burst zwischen Ruhephasen +
    erhöhte HF erkennt einen Versuch (Barometer ist beim Bouldern unzuverlässig, da nur
    wenige Meter). Optional Ruhe-Timer zwischen Versuchen.
  - *Fertig wenn:* Ein Boulderversuch wird grob erkannt – immer mit manueller Korrektur.

- [x] **W4.3 Erkennung als Vorschlag (nie still loggen)**
  - *Aufgabe:* Karte **„Versuch erkannt – zuordnen?"** mit Haptik; falsch-positive mit 1 Tap
    verwerfbar; ohne Reaktion verfällt der Vorschlag oder wird unbeschriftet gebankt
    (konfigurierbar).
  - *Fertig wenn:* Auto-Erkennung unterbricht nie den Flow und führt nie zu stillen
    Fehl-Logs.

- [ ] **W4.4 (Später, eigener Meilenstein) CoreML-Bewegungsklassifikator**
  - *Aufgabe:* On-Device-ML-Modell als Upgrade der Heuristik (wie Redpoint). **Kein
    v1-Blocker.**
  - *Fertig wenn:* ML-Erkennung schlägt die Heuristik messbar und läuft on-device.

## W5 – Sync Watch ↔ iPhone

- [x] **W5.1 Session-Transfer Watch → iPhone**
  - *Aufgabe:* `WCSession` (WatchConnectivity): fertige Session inkl. aller Ascents als
    **Codable-DTO** via `transferUserInfo`/`transferFile` (zuverlässig auch im Hintergrund)
    an iPhone; iPhone fügt in **SwiftData** ein; **Dedupe über `workoutUUID`**.
  - *Dateien:* neu `Shared/SessionTransferDTO.swift`, `Watch/Services/SyncService.swift`,
    iPhone-seitiger Empfänger.
  - *Fertig wenn:* Eine auf der Watch beendete Session erscheint **vollständig** (Versuche,
    Grad, Ergebnis, Höhenmeter) auf dem iPhone – ohne Duplikate.

- [x] **W5.2 iPhone → Watch (Settings/Projekte)**
  - *Aufgabe:* Grad-Skalen, Einstellungen und aktuelle **Projekte** an die Watch übertragen,
    damit ein Projekt direkt am Handgelenk taggbar ist. (Niedrigere Priorität.)
  - *Fertig wenn:* Eigene Skalen/Projekte stehen auf der Watch zur Auswahl.

- [x] **W5.3 Robustheit**
  - *Aufgabe:* Transfer überlebt App-Beendigung; Retry bei Fehlern; **Watch-Session ist
    Quelle der Wahrheit** für das, was am Handgelenk passiert ist.
  - *Fertig wenn:* Kein Datenverlust bei Verbindungsabbruch/Beenden.

## W6 – Apple Health / Fitness & Redpoint-Unabhängigkeit

- [x] **W6.1 Eigener Workout ersetzt den Import**
  - *Aufgabe:* Der in W1 erzeugte Climbing-Workout wird zur **primären Quelle** → App ist
    standalone. Bestehender Redpoint-Import bleibt optional („andere Climbing-Workouts
    importieren").
  - *Fertig wenn:* Ohne Redpoint entsteht ein vollständiger Eintrag.

- [x] **W6.2 Verknüpfung Health-Workout ↔ App-Session**
  - *Aufgabe:* Das HKWorkout des Watch-Trainings auf dem iPhone über `workoutUUID` mit der
    gesyncten Session verbinden – objektive Werte (HF/Energie/Höhe) aus Health, Versuche aus
    dem App-Sync.
  - *Fertig wenn:* Eine Session zeigt sowohl Health-Metriken als auch die Versuche; Fitness-
    Ringe werden geschlossen.

## W7 – Zusammenfassung am Handgelenk

- [x] **W7.1 Session-Summary**
  - *Aufgabe:* Nach „Beenden" eine Karte mit **Dauer, HF (Ø/max), Höhenmeter, #Versuche,
    #Tops, Höchstgrad, Flash-Quote, Activity-Ringe**; Hinweis „Details am iPhone".
  - *Fertig wenn:* Direkt nach der Session erscheint eine sinnvolle Zusammenfassung.

## W8 – UX-Feinschliff, Accessibility, Akku – HÖCHSTE PRIORITÄT

- [x] **W8.1 Hardware-Bedienung ohne Touch**
  - *Aufgabe:* **Action Button** (Ultra) → Workout starten / Versuch loggen / Tick-Type
    (wie Redpoint); **Double Tap** (S9/Ultra 2) zum Bestätigen; **Krone** für Grad.
  - *Fertig wenn:* Eine ganze Session inkl. Logging ist ohne präzisen Screen-Touch bedienbar.

- [x] **W8.2 Haptik-Schema**
  - *Aufgabe:* Klar unterscheidbare Haptik für *Versuch erkannt*, *Top bestätigt*, *Training
    beendet*.
  - *Fertig wenn:* Aktionen sind ohne Hinschauen fühlbar bestätigt.

- [x] **W8.3 Always-On, Tap-Ziele, Accessibility**
  - *Aufgabe:* Always-On-Layout (Zeit + Versuchszähler ohne Wecken); große Tap-Ziele;
    Kontrast/Dynamic Type; VoiceOver-Labels.
  - *Fertig wenn:* Glanceable, gut lesbar, mit VoiceOver bedienbar.

- [x] **W8.4 Akku & Sampling**
  - *Aufgabe:* Workout + Barometer + Motion sind stromhungrig → auf **2–3 h** auslegen,
    Low-Battery-Hinweis, Sampling-Raten optimieren.
  - *Fertig wenn:* Eine typische Session läuft ohne Akku-Engpass durch.

---

## Reihenfolge & Fortschritt

- **Nutzbarer Kern:** W0 → W1 → W2 → W3 → **W5** (Training aufzeichnen + manuelle Versuche +
  Sync aufs iPhone). Damit ist die App schon eigenständig brauchbar.
- **Rund:** W4 (Auto-Erkennung), W6 (Health/Standalone), W7 (Summary).
- **Erlebnis & Reife:** W8 (UX/Accessibility/Akku) – begleitend, **durchgehend höchste
  Priorität** zusammen mit W2/W3.
- Abgeschlossenes mit `[x]` abhaken. Erst **P3.1** (Ascent) in `TODO.md`, dann hier starten.
