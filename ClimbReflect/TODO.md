# ClimbReflect – TODO (priorisiert für Claude)

Diese Liste fasst die Ergebnisse des Code-Reviews zusammen und ist als Arbeitsplan
für Claude Code gedacht. Bitte **von oben nach unten** abarbeiten (P0 → P1 → P2),
innerhalb einer Stufe in der angegebenen Reihenfolge. Jeder Punkt hat *Kontext*,
betroffene *Dateien*, die *Aufgabe* und ein *Fertig-wenn*-Kriterium.

## Arbeitsweise (bitte beachten)

- Quellcode liegt (Stand Review) verschachtelt unter
  `ClimbReflect/ClimbReflect/ClimbReflect/` (von Repo-Wurzel). Pfade unten sind
  **relativ zu diesem Quell-Root** (`.../ClimbReflect/`), sofern nicht anders genannt.
- Nach jeder Aufgabe: kompilieren, betroffene `#Preview`s prüfen, Commit mit
  sprechender Message. Eine Aufgabe = ein Commit.
- Bestehenden Stil beibehalten: deutsche UI-Strings, `Theme`-Farben, `.card()`,
  MVVM-nah, `StatsEngine` rein funktional.
- Stufe P0 zuerst vollständig abschließen – erst danach ist die App eigenständig nutzbar.

---

## P0 – Kern-Schleife & Lauffähigkeit (zuerst)

- [x] **1. Manuelle Session-Erfassung**
  - *Kontext:* Aktuell gibt es nur Mock-Daten + Health-Import. Ohne Redpoint kann
    niemand eine echte eigene Session anlegen → die zentrale Schleife der App fehlt.
  - *Dateien:* neu `Views/ManualSessionView.swift`; `Views/DashboardView.swift`
    (Toolbar/Leerzustand), ggf. `Views/AllSessionsView.swift`.
  - *Aufgabe:* Sheet mit Datum, Dauer (Minuten), Sessiontyp; beim Speichern
    `ClimbSession(source: .manual)` einfügen und **direkt in `SessionDetailView`**
    der neuen Session überleiten. „+"-Button in der Dashboard-Toolbar und im
    Leerzustand („Noch keine Sessions." → CTA „Erste Session anlegen").
  - *Fertig wenn:* Ohne HealthKit lässt sich eine Session anlegen, reflektieren und
    erscheint in „Letzte Sessions" und „Alle Sessions".

- [x] **2. Sessions löschen (und Basisdaten editieren)**
  - *Kontext:* Keine Lösch-/Editiermöglichkeit; Mock-/Fehleinträge bleiben für immer.
  - *Dateien:* `Views/AllSessionsView.swift` (Swipe-to-Delete via `.onDelete` /
    SwiftData `context.delete`), optional `Views/SessionDetailView.swift`
    (Datum/Dauer editierbar + Löschen).
  - *Fertig wenn:* Eine Session kann aus der Liste gelöscht werden; Statistiken/Charts
    aktualisieren sich.

- [x] **3. HealthKit-Capability & Entitlement korrekt konfigurieren**
  - *Kontext:* Der Redpoint-Import (Headline-Feature) scheitert zur Laufzeit, weil
    nur der Usage-String gesetzt ist, aber **nicht** die HealthKit-Capability /
    `com.apple.developer.healthkit`-Entitlement. Es existiert keine `.entitlements`-Datei.
  - *Dateien:* `project.yml` (Entitlement + `entitlements`-Block ergänzen), neu
    `ClimbReflect.entitlements`; ggf. committetes `ClimbReflect.xcodeproj`.
  - *Aufgabe:* HealthKit-Entitlement ins Target aufnehmen. Import-Button nur anzeigen,
    wenn `HKHealthStore.isHealthDataAvailable()`. Klare Fehlermeldung, wenn Capability
    fehlt/abgelehnt.
  - *Fertig wenn:* Auf echtem Gerät fragt der Import die Health-Freigabe an, ohne
    Entitlement-Crash; ohne HealthKit ist der Button ausgeblendet statt fehlerwerfend.

- [x] **4. Mock-Daten kennzeichnen / entschärfen**
  - *Kontext:* 14 Fake-Sessions sind nicht von echten unterscheidbar (Freitext
    wörtlich „Mock-Eintrag") und schalten beim Erststart ~6/8 Erfolge frei → Motivation
    und „deine Reise"-Framing entwertet.
  - *Dateien:* `Models/MockData.swift`, `App`-Einstieg `ClimbReflectApp.swift`.
  - *Aufgabe:* Seeding nur im `#if DEBUG`-Build **oder** Beispieldaten klar markieren
    (z. B. Flag `isSample`) + „Beispieldaten löschen"-Aktion (siehe Settings, P1).
    Release-Build startet leer mit Onboarding-Leerzustand.
  - *Fertig wenn:* Frische Installation (Release) zeigt keine Fake-Sessions; Erfolge
    starten gesperrt.

---

## P1 – Verständlichkeit, Vertrauen, Qualität

- [x] **5. Settings-Screen**
  - *Dateien:* neu `Views/SettingsView.swift`; Einstieg über Dashboard-Toolbar.
  - *Aufgabe:* HealthKit-Status anzeigen, „Jetzt synchronisieren", „Beispieldaten
    löschen", Datenschutz-Hinweis („Alle Daten bleiben on-device"), Daten-Export (P2).
  - *Fertig wenn:* Nutzer sieht Sync-Status und kann ihn manuell auslösen.

- [x] **6. Onboarding & Auffindbarkeit des Imports**
  - *Kontext:* Import-Button ist nur ein Icon (`heart.text.square`) ohne Label/Erklärung;
    Erstnutzer versteht ihn nicht, Tippen ohne Setup erzeugt nur einen Fehler-Alert.
  - *Dateien:* `Views/DashboardView.swift`; optional kurzer Onboarding-Sheet.
  - *Aufgabe:* `.accessibilityLabel("Aus Apple Health importieren")` + sichtbarer
    Hinweis/Tooltip; kurzer Erststart-Screen, der App-Zweck und Import erklärt.
  - *Fertig wenn:* Zweck des Buttons ist ohne Vorwissen klar; VoiceOver liest ihn vor.

- [x] **7. Repo-/Build-Hygiene aufräumen**
  - *Kontext:* Zwei konkurrierende Projektquellen (committetes Xcode-16-`.xcodeproj`
    auf Repo-Ebene **und** `project.yml` drei Ebenen tiefer), dreifache Verschachtelung
    `ClimbReflect/ClimbReflect/ClimbReflect/`, README-Befehl `cd ClimbReflect &&
    xcodegen generate` passt nicht zum Ort der `project.yml`. Kein committetes Info.plist.
  - *Aufgabe:* **Eine** Projektquelle festlegen (Empfehlung: committetes `.xcodeproj`
    behalten und `project.yml` als Quelle dokumentieren oder entfernen). Verschachtelung
    auf eine Ebene reduzieren. README-Befehle an reale Pfade angleichen. Info.plist-Quelle
    eindeutig machen.
  - *Fertig wenn:* Ein frisch geklontes Repo baut nach den README-Schritten ohne
    Pfad-Workarounds; nur eine `.xcodeproj`-Definition im Repo.

- [x] **8. Kontrast, Dynamic Type, Textfeld-Platzhalter**
  - *Kontext:* `Theme.textTertiary` (0x5C6675) auf fast-schwarzem Grund liegt für kleinen
    Text vermutlich unter WCAG-AA. `TextEditor` hat keine Platzhalter → leere Kästen.
    Feste Schriftgrößen/Kartengrößen (z. B. 132×132) könnten bei großem Dynamic Type
    abschneiden.
  - *Dateien:* `Theme/Theme.swift`, `Views/SessionDetailView.swift`,
    `Views/Components/AchievementCard.swift`, Chart-Komponenten.
  - *Aufgabe:* Tertiär-Kontrast anheben (mind. AA für Beschriftungen); Platzhalter-Overlay
    in den drei Reflexions-Feldern; mit größten Dynamic-Type-Stufen testen, Karten
    flexibel statt fix.
  - *Fertig wenn:* Achsen/Untertitel gut lesbar; Textfelder zeigen Hint; Layout hält bei
    XXL-Schrift.

- [x] **9. Redpoint-Annahme verifizieren & Fehlertexte schärfen**
  - *Kontext:* Es ist unbestätigt, dass Redpoint `.climbing`-Workouts inkl. HF/Energie
    nach Apple Health schreibt. Falls nicht, liefert der Import nichts.
  - *Dateien:* `Services/RedpointHealthService.swift`.
  - *Aufgabe:* Auf echtem Gerät prüfen; falls Redpoint anders exportiert, Workout-Typ/
    Quelle anpassen. „Keine Workouts gefunden"-Fall vom „keine Berechtigung"-Fall klar
    unterscheiden.
  - *Fertig wenn:* Import-Verhalten und Meldungen entsprechen dem realen Redpoint-Export.

---

## P2 – Differenzierung & Wachstum

- [x] **10. Aussagekräftigere Fortschritts-Metriken**
  - *Kontext:* „Fortschritt = Minuten/Woche" misst nur Volumen, nicht Können.
  - *Dateien:* `Models/Achievement.swift` (`StatsEngine`),
    `Views/Components/ProgressChartView.swift`, ggf. neue Charts.
  - *Aufgabe:* RPE-Trend über Zeit, Auswertung pro Sessiontyp, optional Grad/Schwierigkeit
    (falls erfasst). Limiter-Entwicklung über Zeit ergänzen.
  - *Fertig wenn:* Mindestens eine Metrik zeigt Entwicklung der Leistung, nicht nur Menge.

- [x] **11. Reflexions-Erinnerungen (Local Notifications)**
  - *Kontext:* Wert entsteht erst nach vielen Einträgen → Retention sichern.
  - *Aufgabe:* Nach Import/neuer Session optionale Erinnerung „Session reflektieren?".
    Opt-in in Settings.
  - *Fertig wenn:* Nutzer kann Erinnerungen aktivieren; offene Reflexionen werden angestoßen.

- [ ] **12. CloudKit-Sync (Backup + geräteübergreifend)**
  - *Kontext:* Aktuell rein on-device → Gerät weg = Daten weg.
  - *Dateien:* `ClimbReflectApp.swift` (`ModelConfiguration(... cloudKitDatabase:)`),
    Entitlements.
  - *Fertig wenn:* Daten überleben Neuinstallation / erscheinen auf zweitem Gerät.
  - *Hinweis:* Erfordert CloudKit-Container im Apple Developer Portal → zurückgestellt.

- [x] **13. Unit-Tests für `StatsEngine`**
  - *Kontext:* Reine Funktionen, ideal testbar; Streak-/Wochenlogik aktuell ungesichert.
  - *Aufgabe:* Tests für `weeklyMinutes`, `weekStreak` (inkl. Lücken), Erfolgsschwellen,
    `sessionsThisWeek`.
  - *Fertig wenn:* Test-Target vorhanden, grün, deckt Grenzfälle ab.
  - *Umsetzung:* `ClimbReflectTests/StatsEngineTests.swift` erstellt; Test-Target in
    `project.yml` eingetragen. Nach `xcodegen generate` lauffähig.

- [x] **14. Datenexport / Backup**
  - *Aufgabe:* Export der Sessions (z. B. JSON/CSV) aus Settings.
  - *Fertig wenn:* Nutzer kann seine Daten sichern/teilen.

- [ ] **15. Später: iPad-Layout, Home-Screen-Widget (Streak), Lokalisierung (EN)**

---

## P3 – Vom Logbuch zum Performance-Tool (Kletter-Erfolge im Kern)

Diese Stufe verschiebt den Fokus von „Session geloggt" zu „Boulder/Route gesendet".
Aktuell kennt die App nur *Sessions* (Zeitblöcke), nicht *Begehungen* (einzelne Boulder/
Routen mit Grad und Ergebnis) – deshalb sind die „Erfolge" bisher App-Nutzungs-Erfolge,
keine echten Kletter-Erfolge/-Misserfolge. **P3.1 ist das Fundament; alles weitere baut
darauf auf** – daher zwingend zuerst.

> Leitprinzip: **Nachhaltigen Fortschritt belohnen, nicht rohes Volumen oder Streaks um
> jeden Preis.** Klettern hat echtes Verletzungsrisiko (Ringbänder/Finger). Erholung,
> Comebacks und bewusstes Techniküben dürfen ebenso „Erfolge" sein wie harte Sends.

- [x] **P3.1 Begehung als neue Einheit (Grad + Ergebnis)** — *Fundament*
  - *Kontext:* Ohne Grad und Top/Versuch gibt es keine messbaren Kletter-Erfolge.
  - *Dateien:* neu `Models/Ascent.swift` (`@Model`, `@Relationship` zu `ClimbSession`);
    `Models/Enums.swift` (`GradeSystem` [Fb/V-Scale Boulder, French/UIAA Route], `Grade`,
    `AscentResult` = top/versuch/aufgegeben, `AscentStyle` = flash/onsight/redpoint/projekt);
    `Models/ClimbSession.swift` (`@Relationship var ascents: [Ascent]`);
    `Views/SessionDetailView.swift` (Begehungen erfassen/auflisten/löschen).
    SwiftData-Schema-Migration beachten (additiv, daher i. d. R. unkritisch).
  - *Aufgabe:* In einer Session mehrere Begehungen anlegen: Grad (Skala wählbar),
    Ergebnis, Stil, Versuchszahl, optionale Notiz.
  - *Fertig wenn:* Ich kann pro Session mehrere Boulder/Routen mit Grad und Ergebnis
    erfassen; sie persistieren und erscheinen in der Detailansicht.

- [x] **P3.2 Send-Moment feiern**
  - *Kontext:* Das Top ist der Dopamin-Moment – aktuell nur eine Zeile.
  - *Dateien:* neu Celebration-Component (Animation + Haptik via
    `UINotificationFeedbackGenerator`); `Views/SessionDetailView.swift`.
  - *Aufgabe:* Bei Ergebnis „Top" kurze Feier; „Neuer Höchstgrad!"-Badge, wenn der Grad
    ein persönliches Maximum ist.
  - *Fertig wenn:* Ein Top auslösen gibt sicht-/spürbares Feedback; neuer PB wird erkannt.

- [x] **P3.3 Grad-Pyramide**
  - *Kontext:* Standard-Überblickswerkzeug der Kletterer (breite leichte Basis vs. harte Spitze).
  - *Dateien:* neu `Views/Components/GradePyramidView.swift`; `Models/Achievement.swift`
    (StatsEngine: Sends pro Grad aggregieren).
  - *Aufgabe:* Gestapelte Pyramide der Sends pro Grad (getrennt Boulder/Route), Zeitraum filterbar.
  - *Fertig wenn:* Dashboard zeigt die Send-Verteilung über die Grade; Höchstgrad erkennbar.

- [x] **P3.4 Send-Rate & Flash-Quote über Zeit**
  - *Dateien:* `Models/Achievement.swift` (StatsEngine: sends/attempts, flashRate); neu Chart-Component.
  - *Aufgabe:* Verhältnis Tops/Versuche und Flash-Quote als Trend.
  - *Fertig wenn:* Ich sehe, wie sich meine Erfolgsquote entwickelt – Misserfolge als Signal, nicht Makel.

- [x] **P3.5 Projekte-Board (Mehr-Session-Sends)**
  - *Kontext:* Das mehrwöchige Arbeiten an einem Boulder bis zum Send ist Kernmotivation.
  - *Dateien:* neu `Views/ProjectsView.swift`; Verknüpfung gleicher Boulder über Sessions
    (z. B. `projectName`/`projectID` am `Ascent`).
  - *Aufgabe:* Liste „in Arbeit": Versuche über Sessions zählen, Beta-Notizen, „gesendet" mit Datum.
  - *Fertig wenn:* Ich kann ein Projekt anlegen, Versuche sammeln und den Send markieren.

- [x] **P3.6 Technik-Fokus pro Session + Auswertung** — *Kernziel „Technik verbessern"*
  - *Kontext:* Besser werden braucht bewusstes Üben (deliberate practice), nicht nur Sends.
  - *Dateien:* `Models/ClimbSession.swift` (`techniqueFocus`, `focusRating`);
    `Views/ManualSessionView.swift` + `Views/SessionDetailView.swift`; neu Trend-Chart.
  - *Aufgabe:* Fokus wählen (stille Füße, Hüfte an die Wand, Dynamos committen, Heel-/Toe-Hooks …),
    nach der Session 1–5 selbst bewerten; Chart „Fokus über Zeit"; optional „Skill der Woche".
  - *Fertig wenn:* Ich kann je Session einen Technikfokus setzen/bewerten und die Entwicklung sehen.

- [x] **P3.7 Stil-Tags an der Begehung + Antistyle-Radar**
  - *Kontext:* Misserfolge in eine Trainingskarte verwandeln – wo falle ich ab?
  - *Dateien:* `Models/Enums.swift` (`WallAngle` Platte/senkrecht/Überhang/Dach, `HoldType`
    Leisten/Sloper/Pinch/Pockets, `ClimbStyle` technisch/kraftvoll/dynamisch); `Models/Ascent.swift`;
    StatsEngine (Send-Rate × Stil); neu `Views/Components/AntistyleRadarView.swift`.
  - *Aufgabe:* Begehung taggen; Heatmap/Radar der Send-Rate pro Stil; optional Fokus-Vorschlag aus der Schwäche.
  - *Fertig wenn:* Ich sehe, in welchem Stil ich abfalle, und bekomme daraus eine Trainingsrichtung.

- [x] **P3.8 Beta-Bibliothek**
  - *Dateien:* durchsuchbare `Ascent`-Notizen; neu Such-/Listenansicht.
  - *Aufgabe:* Schlüsselzüge/Beta an Begehungen, durchsuchbar.
  - *Fertig wenn:* Ich finde frühere Beta wieder.

- [x] **P3.9 Adaptive, kletter-bezogene Erfolge (statt fixer Schwellen)**
  - *Kontext:* Behebt den Schwachpunkt „alle Erfolge gleichzeitig entsperrt"; Bezug zur eigenen Baseline.
  - *Dateien:* `Models/Achievement.swift` (StatsEngine), ggf. persistente Baseline.
  - *Aufgabe:* Erfolge wie „2 Grade über 30-Tage-Schnitt", „3 Flashes in einer Session",
    „Projekt nach 8+ Versuchen gesendet", „neuer Höchstgrad" – plus wellbeing-positive Erfolge
    („Ruhetag genommen", „Comeback nach Pause").
  - *Fertig wenn:* Mind. 4 adaptive, kletter-bezogene Erfolge, die nicht alle gleichzeitig auslösen.

- [ ] **P3.10 Wochen-Recap-Karte (teilbar)**
  - *Aufgabe:* „Diese Woche: X Tops · neuer Höchstgrad · Antistyle · Ø RPE" als teilbares Bild.
  - *Fertig wenn:* Am Wochenende erscheint eine teilbare Zusammenfassung.

- [ ] **P3.11 „Dein Kletterjahr" / Highlight-Reel + Crux-Clips**
  - *Dateien:* Foto/Video an `Ascent` (Files/PhotosPicker); Jahresansicht.
  - *Aufgabe:* Kurzclip/Foto je Begehung; Jahresrückblick der härtesten Sends.
  - *Fertig wenn:* Medien hängen an Begehungen; ein Jahresrückblick lässt sich erzeugen.

- [x] **P3.12 Form-/Plateau-Signal (behutsam)**
  - *Dateien:* StatsEngine (RPE × Send-Rate); dezente Hinweis-Component.
  - *Aufgabe:* Flash-Quote sinkt + RPE steigt → „Deload erwägen"; Grad flach + RPE hoch über
    N Wochen → „Technikwoche". Bewusst zurückhaltend, kein Push zu Übertraining.
  - *Fertig wenn:* Bei klaren Mustern erscheint ein dezenter, gesundheitsbewusster Hinweis.

- [ ] **P3.13 Gym-/Set-Kontext (optional)**
  - *Aufgabe:* Begehung an Halle/Sektion/Set hängen, indoor/outdoor trennen; fairer Pyramiden-Zeitraum
    (Hallen schrauben regelmäßig um).
  - *Fertig wenn:* Sends lassen sich nach Ort/Set filtern.

---

## Kleinere Fixes / Tech-Debt (nebenbei erledigbar)

- [x] **„Reflexion offen"-Logik vereinheitlichen:** `SessionRow` wertet nun
  `reflectionCompleted` aus (nicht nur `perceivedEffort`), gleiche Quelle wie
  `SessionDetailView`. (`Views/Components/SessionRow.swift`, `Views/SessionDetailView.swift`)
- [x] **Force-Unwrap entfernen:** `MockData.daysAgo` nutzt jetzt `guard` statt `!`
  bei der Datumsberechnung. (`Models/MockData.swift`)
- [ ] **Hintergrund-Grafik:** Optional Kletterwand-Charakter statt generischer Bergsilhouette
  und Hintergrund entsättigen, damit der Akzentverlauf der UI nicht konkurriert und der
  Textkontrast steigt. (`Background/MountainBackground.swift`)
- [ ] **Assets:** App-Icon und `AccentColor` sind leere Platzhalter – echtes Icon/Farbe
  hinterlegen. (`Assets.xcassets`)
- [ ] **Lokalisierung vorbereiten:** Hartkodierte deutsche Strings in einen
  `String(localized:)`-Katalog überführen (Grundlage für EN, P2).

---

## Fortschritt

Erledigte Punkte abhaken (`[x]`). P0–P1 sind erledigt, P2 weitgehend (offen: CloudKit,
iPad/Widget/Lokalisierung). **Nächster großer Bogen: P3** – er macht aus dem Logbuch ein
echtes Performance-Tool. Innerhalb P3 zwingend mit **P3.1 (Begehung mit Grad + Ergebnis)**
beginnen, da alle weiteren P3-Punkte darauf aufbauen.
