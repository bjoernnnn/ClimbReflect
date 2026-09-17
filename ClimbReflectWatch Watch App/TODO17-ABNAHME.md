# TODO17 – Abnahme der Umsetzung

**Geprüft:** `origin/dev` @ `1c00956` (Merge `feature/premium-ux`, 16.09.2026), 34 Commits VT-1 … DOC-1
**Methode:** Code-Review aller geänderten Dateien, `grep`-Abnahmechecks aus TODO17, Kontrastberechnung der Theme-Farben. Kein Gerätetest – Punkte mit *(Gerät)* bitte am iPhone gegenprüfen.

---

## 1. Gesamturteil

Die Umsetzung ist **sauber und diszipliniert**: ein Commit pro Aufgabe, Aufgaben-IDs in den Kommentaren, `CLAUDE.md` gepflegt (S39–S44). Die großen Brüche aus dem ersten Review sind behoben, das Designsystem existiert und wird überwiegend genutzt.

Was noch fehlt, ist **die letzte Schicht Apple-Qualität**:
- Wie sich eine Berührung anfühlt: Press-States, Haptik zum richtigen Zeitpunkt.
- Konsequente Farbsemantik, besonders bei Gold.
- Lesbarkeit der dritten Textstufe.
- Die Reihenfolge der Inhalte im Session-Detail.

Dazu kommen **zwei Regressionen** und **fehlende Tests**. Beides muss zuerst behoben werden.

---

## 2. Was gut ist

| Bereich | Bewertung |
|---|---|
| **Vertrauen (VT)** | Alle Befunde behoben. Löschen per `contextMenu` mit Bestätigung, `isSaving`-Guard, `GradeDefaults` als reine Funktion, „Verwerfen" für leere Sessions, Add-Flow aus dem Projekt. |
| **Designsystem** | `Theme` ist schlank und verständlich: 4 Flächen, 3 Textstufen, 4 Bedeutungsfarben, 3 Radien, 5 Typo-Rollen. `MountainBackground` ist weg, `.system(size:)` nur noch in Erfolgs-Artwork, Dark Mode zentral im Build-Setting. |
| **Navigation** | Large Titles, native Segmented Controls, `ContentUnavailableView`. Die App fühlt sich strukturell nativ an. |
| **S33** | `CelebrationOverlay` entfernt. Das Recap ist statisch, keine zweite Feier. |
| **Komponenten** | `MilestoneRow`, `ProgressRing`, `OutcomePicker`, `SessionTypeGrid` sind klein, fokussiert und wiederverwendbar. `AnyLayout` für große Schrift ist elegant gelöst. |
| **Quick-Log** | Das Prinzip stimmt: großer Grad, Leiste zum Wischen, Ergebnis ohne Vorauswahl, Details zugeklappt, „Sichern & nächste". |
| **Projekt-Zeitleiste** | Ehrlich (S32) und erzählt den Projektverlauf. Gute Idee, sauber gebaut. |
| **Barrierefreiheit** | Labels für Icon-Buttons, `accessibilityAdjustableAction` auf der Grad-Leiste, 44-pt-Trefferflächen bei Chips. |

---

## 3. Regressionen & Lücken (P0)

### R1 · Watch: Grad-Pflicht wurde überschrieben ❗
Commit `039e0d9` (28.07.) hatte die **Grad-Pflicht** eingeführt: `gradeIndex = nil` bis per Krone gewählt, Fehler-Haptik beim Banken ohne Grad. WT-1 setzt den Fallback wieder auf `gradeIndex = 0`. Die Pflicht greift damit nie – ein versehentlich niedrigster Grad wird still gespeichert.

Der TODO17-Plan basierte auf `2d0b6fc` und kannte diesen Commit nicht. Die Regel „vor Umsetzung gegen aktuellen Code verifizieren" wurde hier nicht angewandt. **Das ist mein Planfehler.** Die Grad-Pflicht ist die bessere Lösung als E5.

### R2 · Keine einzige neue Unit-Test-Datei
VT-4 (`GradeDefaultsTests`), FS-1 (`milestones`) und FS-7 (`sessionRecap`) verlangten Tests. `ClimbReflectTests/` ist seit TODO17 unverändert. Trotzdem vermerkt DOC-1 TODO17 als abgeschlossen.

### R3 · Haptik feuert falsch
- `ManualSessionView`: `.sensoryFeedback(trigger: gymName)` → **ein Haptik-Tick pro getipptem Buchstaben** im Hallen-Feld.
- `ManualSessionView`: `.sensoryFeedback(trigger: durationMinutes)` hängt **in der `ForEach`** → bei jeder Änderung vibriert es 5-fach gleichzeitig.
- `AddAscentView`/`EditAscentAssociationsSheet`: `.success` wird ausgelöst und **im selben Moment `dismiss()`** aufgerufen. Feedback an einer View, die gerade verschwindet, wird oft verschluckt. *(Gerät)*

### R4 · Disabled-Buttons sehen aktiv aus
„Sichern", „Weiter" und „Fertig" in Toolbars tragen `.foregroundStyle(Theme.accent)`. Das überschreibt die System-Darstellung für den deaktivierten Zustand: „Sichern" bleibt grün, obwohl ohne Ergebnis nichts passiert. *(Gerät)*

### R5 · „Details" im Quick-Log ohne Beschriftung
`Picker` außerhalb von `Form`/`List` zeigt keinen Label-Text. In `AddAscentView` und `EditAscentAssociationsSheet` erscheinen deshalb nur Werte wie „Fb (Boulder)", „Top", „—", ohne zu sagen, was sie bedeuten.

### R6 · Grad-Leiste
- Die Markierung (`Capsule` 2 × 18) liegt als `.overlay` **mittig über** dem ausgewählten Grad, als Strich durch den Text.
- `LazyHStack` + `scrollPosition(id:)`: Die Startposition wird auf iOS 17 nicht verlässlich angesteuert, wenn das Ziel-Item noch nicht geladen ist. Das Risiko: Die Leiste steht auf 3, oben steht „6B", und der erste Scroll-Event setzt den Grad zurück. *(Gerät)*
- Grad steht doppelt: groß oben **und** hervorgehoben in der Leiste, dazu das System-Label „Fb (Boulder)". Drei Anzeigen für einen Wert.

### R7 · Recap
- Erscheint auch bei Watch-Sessions **ohne Begehungen** → Hauptaussage „0 Begehungen" in Hero-Größe.
- Detent `.medium`: Header + Statistik + zwei große Buttons füllen die halbe Höhe. Erfolge und „Als Nächstes" liegen unter der Falz, der Nutzer sieht den Kern nicht.
- „Kurz reflektieren" öffnet das Session-Detail **oben**. Die Reflexion liegt ganz unten und ist zugeklappt – drei Scroll-Bildschirme, dann noch ein Tap.
- Ein nackter Grad („6B") als Hauptaussage hat keinen Kontext.
- Im Session-Detail innerhalb des Recaps steht wieder der Menüpunkt „Zusammenfassung" → Recap im Recap.

### R8 · Reflexions-Siegel widerspricht sich
`reflectionCompleted` wird schon durch einen RPE-Tipp im Kurz-Check wahr. Die Reflexionskarte zeigt dann ein **goldenes Siegel** und darunter trotzdem „Reflexion schreiben".

### R9 · S31/S32-Altlast im Session-Detail
Die Insights zeigen weiterhin **„Belastung (sRPE)"** in Gold (S31 verbietet Belastungskennzahlen) und eine **„Erfolgsquote"** ohne Mindeststichprobe und ohne n (S32). Das stammt nicht aus TODO17, wurde aber übersehen.

---

## 4. Premium-Gefühl – Sicht einer Apple-UI/UX-Designerin

### 4.1 Berührung fühlt sich noch „flach" an
Alle tappbaren Karten (Level-Hero, Session-Zeilen, Projekte, Stil-Link) nutzen `.buttonStyle(.plain)` **ohne Druckzustand**. In Apple-Apps gibt jede Karte beim Berühren nach: minimal kleiner und leicht abgedunkelt. Genau das unterscheidet „Website" von „App".

Beim Level-Hero sitzt `.card()` außerhalb des Buttons. Das Padding um den Inhalt ist daher **nicht tappbar**.

### 4.2 Gold ist wieder verwässert
Das System sagt „Gold = ausschließlich Erreichtes". Tatsächlich gold sind aber auch:
- jeder **Versuch** (`AscentResult.attempt.color`)
- angepinnte Projekte
- das Pause-Banner
- Zusatzgewicht im Training
- Fokus-Sterne
- die sRPE-Kachel
- die Versuche-Zeile im Session-Detail

„Abgebrochen" ist auf dem iPhone weiterhin **rot**, obwohl die Watch es bewusst neutral gemacht hat. Wenn fast jede Zeile gold ist, wirkt der echte Bestwert nicht mehr besonders.

### 4.3 Dritte Textstufe ist zu schwach
`textTertiary #5F6772` erreicht **3,1 : 1** auf Karten und **2,8 : 1** auf `surfaceRaised`. Apple empfiehlt für kleinen Text 4,5 : 1. Die Farbe wird 116-mal genutzt, meist für Captions, Daten und Chevrons. Das Ergebnis wirkt „grau in grau" und damit billiger, als es ist.

### 4.4 Session-Detail: Wichtiges steht unten
Reihenfolge heute: Header → Vitalwerte → Zeit-Donut → Metrik-Kacheln → Erfolge → **Begehungen** → Kurz-Check → Reflexion.

Wer eine Session öffnet, will zuerst wissen: *Was habe ich geklettert?* Messwerte sind Kontext, kein Einstieg. Apple Fitness zeigt oben die Zusammenfassung, Details darunter.

Die Datei hat **1.119 Zeilen** – schwer wartbar und schwer gestalterisch zu iterieren.

### 4.5 Uneinheitliche Kleinigkeiten, die das Auge trotzdem sieht
- **Icon-Kacheln:** Kreis (angepinnte Projekte, Projektliste, Monatsrückblick) vs. abgerundetes Quadrat (SessionRow). Apple nutzt pro App eine Form.
- **Abschnittsüberschriften:** `.headline` auf Heute, `Theme.Typo.section` im Fortschritt, `.headline` in Karten.
- **Dauer:** „95 Min" (SessionRow, Recap, Header) vs. „1 Std., 30 Min." (Neue Session).
- **Radien:** 24 `RoundedRectangle(cornerRadius: Theme.Radius…)` **ohne** `.continuous` (verstößt gegen S40).
- **Divider:** 7 × `Divider().background(…)`. Das färbt den Divider nicht ein, richtig ist `.overlay`.
- **Disziplin-Namen:** Hero sagt „Bouldern/Seil", Fortschritt-Picker „Boulder/Seil".
- **Level-Hero** zeigt zusätzlich die zweite Disziplin als graue Zeile – das verdichtet die Karte, ohne ein Ziel zu zeigen.

### 4.6 Daumenreichweite beim Erfassen
Im Quick-Log liegt die **primäre** Aktion „Sichern" oben rechts in der Toolbar. Die **sekundäre** „Sichern & nächste" liegt als großer Button unten. Beim Klettern bedient man einhändig, mit Chalk an den Fingern. Die Hauptaktion gehört nach unten, prominent. Gleiches gilt für „Begehung erfassen" im Projekt-Detail.

### 4.7 Flüssigkeit (Performance)
- `LevelHeroCard` ruft `AchievementViewModel.build(...)` über `milestoneRows` mehrfach pro Render auf.
- `FortschrittView` berechnet PBs, Pyramide, Timeline, Meilensteine und Highlights einzeln aus derselben Session-Liste und animiert dabei das ganze `VStack`.
- `DashboardView` hält ein `@Query` auf **alle** Sessions, nur um die Recap-Session zu finden. Jede Datenänderung rendert damit den gesamten `TabView` neu.

Mit wachsender Historie wird das beim Scrollen und bei Wechseln spürbar. *(Gerät mit echten Daten)*

### 4.8 Charts sind statisch
Der Grad-Verlauf lässt sich nicht antippen. Apple Health, Fitness und Aktien erlauben in jedem Liniendiagramm, den Finger über die Kurve zu ziehen und den Wert zu sehen. Das ist einer der deutlichsten „Apple-Momente", und mit `chartXSelection` (iOS 17) wenig Code.

---

## 5. Konsequenz

Neuer Plan **TODO18-PREMIUM-POLISH.md**:
1. **Block KR** – Korrekturen R1–R9 (zuerst, klein)
2. **Block PG** – Premium-Gefühl 4.1–4.8
3. **Block DOC** – Prinzipien nachschärfen, Arbeitsregel „Plan gegen Git-Log seit Plan-Basis prüfen"

TODO17 bleibt als erledigt stehen. Die Entscheidungen E1–E18 gelten weiter, **außer E5**: Sie wird durch die Grad-Pflicht ersetzt.
