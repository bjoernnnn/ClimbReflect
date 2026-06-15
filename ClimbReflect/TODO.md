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

- [ ] **1. Manuelle Session-Erfassung**
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

- [ ] **2. Sessions löschen (und Basisdaten editieren)**
  - *Kontext:* Keine Lösch-/Editiermöglichkeit; Mock-/Fehleinträge bleiben für immer.
  - *Dateien:* `Views/AllSessionsView.swift` (Swipe-to-Delete via `.onDelete` /
    SwiftData `context.delete`), optional `Views/SessionDetailView.swift`
    (Datum/Dauer editierbar + Löschen).
  - *Fertig wenn:* Eine Session kann aus der Liste gelöscht werden; Statistiken/Charts
    aktualisieren sich.

- [ ] **3. HealthKit-Capability & Entitlement korrekt konfigurieren**
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

- [ ] **4. Mock-Daten kennzeichnen / entschärfen**
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

- [ ] **5. Settings-Screen**
  - *Dateien:* neu `Views/SettingsView.swift`; Einstieg über Dashboard-Toolbar.
  - *Aufgabe:* HealthKit-Status anzeigen, „Jetzt synchronisieren", „Beispieldaten
    löschen", Datenschutz-Hinweis („Alle Daten bleiben on-device"), Daten-Export (P2).
  - *Fertig wenn:* Nutzer sieht Sync-Status und kann ihn manuell auslösen.

- [ ] **6. Onboarding & Auffindbarkeit des Imports**
  - *Kontext:* Import-Button ist nur ein Icon (`heart.text.square`) ohne Label/Erklärung;
    Erstnutzer versteht ihn nicht, Tippen ohne Setup erzeugt nur einen Fehler-Alert.
  - *Dateien:* `Views/DashboardView.swift`; optional kurzer Onboarding-Sheet.
  - *Aufgabe:* `.accessibilityLabel("Aus Apple Health importieren")` + sichtbarer
    Hinweis/Tooltip; kurzer Erststart-Screen, der App-Zweck und Import erklärt.
  - *Fertig wenn:* Zweck des Buttons ist ohne Vorwissen klar; VoiceOver liest ihn vor.

- [ ] **7. Repo-/Build-Hygiene aufräumen**
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

- [ ] **8. Kontrast, Dynamic Type, Textfeld-Platzhalter**
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

- [ ] **9. Redpoint-Annahme verifizieren & Fehlertexte schärfen**
  - *Kontext:* Es ist unbestätigt, dass Redpoint `.climbing`-Workouts inkl. HF/Energie
    nach Apple Health schreibt. Falls nicht, liefert der Import nichts.
  - *Dateien:* `Services/RedpointHealthService.swift`.
  - *Aufgabe:* Auf echtem Gerät prüfen; falls Redpoint anders exportiert, Workout-Typ/
    Quelle anpassen. „Keine Workouts gefunden"-Fall vom „keine Berechtigung"-Fall klar
    unterscheiden.
  - *Fertig wenn:* Import-Verhalten und Meldungen entsprechen dem realen Redpoint-Export.

---

## P2 – Differenzierung & Wachstum

- [ ] **10. Aussagekräftigere Fortschritts-Metriken**
  - *Kontext:* „Fortschritt = Minuten/Woche" misst nur Volumen, nicht Können.
  - *Dateien:* `Models/Achievement.swift` (`StatsEngine`),
    `Views/Components/ProgressChartView.swift`, ggf. neue Charts.
  - *Aufgabe:* RPE-Trend über Zeit, Auswertung pro Sessiontyp, optional Grad/Schwierigkeit
    (falls erfasst). Limiter-Entwicklung über Zeit ergänzen.
  - *Fertig wenn:* Mindestens eine Metrik zeigt Entwicklung der Leistung, nicht nur Menge.

- [ ] **11. Reflexions-Erinnerungen (Local Notifications)**
  - *Kontext:* Wert entsteht erst nach vielen Einträgen → Retention sichern.
  - *Aufgabe:* Nach Import/neuer Session optionale Erinnerung „Session reflektieren?".
    Opt-in in Settings.
  - *Fertig wenn:* Nutzer kann Erinnerungen aktivieren; offene Reflexionen werden angestoßen.

- [ ] **12. CloudKit-Sync (Backup + geräteübergreifend)**
  - *Kontext:* Aktuell rein on-device → Gerät weg = Daten weg.
  - *Dateien:* `ClimbReflectApp.swift` (`ModelConfiguration(... cloudKitDatabase:)`),
    Entitlements.
  - *Fertig wenn:* Daten überleben Neuinstallation / erscheinen auf zweitem Gerät.

- [ ] **13. Unit-Tests für `StatsEngine`**
  - *Kontext:* Reine Funktionen, ideal testbar; Streak-/Wochenlogik aktuell ungesichert.
  - *Aufgabe:* Tests für `weeklyMinutes`, `weekStreak` (inkl. Lücken), Erfolgsschwellen,
    `sessionsThisWeek`.
  - *Fertig wenn:* Test-Target vorhanden, grün, deckt Grenzfälle ab.

- [ ] **14. Datenexport / Backup**
  - *Aufgabe:* Export der Sessions (z. B. JSON/CSV) aus Settings.
  - *Fertig wenn:* Nutzer kann seine Daten sichern/teilen.

- [ ] **15. Später: iPad-Layout, Home-Screen-Widget (Streak), Lokalisierung (EN)**

---

## Kleinere Fixes / Tech-Debt (nebenbei erledigbar)

- [ ] **„Reflexion offen"-Logik vereinheitlichen:** `SessionRow` wertet nur
  `perceivedEffort == nil` aus, `reflectionCompleted` ist breiter definiert. Gleiche
  Quelle nutzen. (`Views/Components/SessionRow.swift`, `Views/SessionDetailView.swift`)
- [ ] **Force-Unwrap entfernen:** `MockData.daysAgo` nutzt `!` bei der Datumsberechnung
  → defensiv umbauen. (`Models/MockData.swift`)
- [ ] **Hintergrund-Grafik:** Optional Kletterwand-Charakter statt generischer Bergsilhouette
  und Hintergrund entsättigen, damit der Akzentverlauf der UI nicht konkurriert und der
  Textkontrast steigt. (`Background/MountainBackground.swift`)
- [ ] **Assets:** App-Icon und `AccentColor` sind leere Platzhalter – echtes Icon/Farbe
  hinterlegen. (`Assets.xcassets`)
- [ ] **Lokalisierung vorbereiten:** Hartkodierte deutsche Strings in einen
  `String(localized:)`-Katalog überführen (Grundlage für EN, P2).

---

## Fortschritt

Erledigte Punkte abhaken (`[x]`). Empfehlung: P0 vollständig, dann Review/Test auf
echtem Gerät, danach P1. P2 nach Bedarf.
