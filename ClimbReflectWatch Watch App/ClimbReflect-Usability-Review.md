# ClimbReflect – Usability- & Premium-Review

**Stand:** `origin/dev` @ `2d0b6fc` (11.07.2026), identisch mit `main` (Tag `v1.0.0`)
**Methode:** Heuristischer Walkthrough über den Code (iPhone + Watch), gegen Apple HIG und die eigenen S-Prinzipien. Kein Test auf echtem Gerät – alles, was mit „verifizieren" markiert ist, bitte kurz am Gerät gegenprüfen.

> ⚠️ Auf dem Remote gibt es keine Commits nach dem 11.07. Falls lokal ungepushte Arbeit liegt (z. B. aus TODO16), können einzelne Punkte schon erledigt sein.

---

## 1. Kurzfazit

Die App ist funktional reif und inhaltlich durchdacht: ehrliche Statistik (S32), Goal-Gradient-Elemente, Erfolge mit Choreografie, ein klarer Watch-first-Ritus. Das Fundament stimmt.

Das **Premium-Gefühl scheitert aktuell nicht an fehlenden Features, sondern an drei Dingen:**

1. **Vertrauensbrüche im Kernflow.** Swipe-to-Delete tut nichts, Begehungen lassen sich am iPhone nicht löschen, ein Doppel-Tipp auf „Speichern" erzeugt Duplikate, Seil-Sessions starten mit einem Boulder-Grad. Jeder dieser Momente fühlt sich „billig" an – egal wie schön der Rest ist.
2. **Ein Designsystem, das nach „Custom-Theme" statt nach Apple aussieht.** Neon-Bergsilhouette auf jedem Screen, 11 verschiedene Eckenradien, 43 hartkodierte Schriftgrößen, fast gleiche Sekundär-/Tertiärfarbe, kaum Haptik, fast keine System-Motion.
3. **Fortschritt ist da, aber verstreut.** „Nächste Stufe", „Wohlfühl-Grad-Kandidat", „Nächster Erfolg", „In Reichweite" und Projekte leben an vier Orten mit vier Visualisierungen. Der emotionalste Moment – das Ende einer Session – ist ein generisches „Gute Session!".

**Die fünf größten Hebel** (Details unten):

| # | Hebel | Aufwand | Wirkung |
|---|---|---|---|
| 1 | P0-Bugs aus Kapitel 2 fixen | klein | Vertrauen |
| 2 | Bergsilhouette raus, ruhige Oberfläche + Materials | klein | sofort hochwertiger |
| 3 | Begehung erfassen als „Quick-Log" neu denken | mittel | Kernflow |
| 4 | Ein „Level & nächster Meilenstein"-Hero auf Heute | mittel | Fortschritt spüren |
| 5 | Session-Recap als Belohnungsmoment | mittel | Emotion |

---

## 2. Funktionsfehler, die das Vertrauen brechen (P0)

Diese Punkte zuerst – sie sind klein, aber sie sind genau das, was sich „unfertig" anfühlt.

### F1 · Swipe-Aktionen sind wirkungslos
`.swipeActions` funktioniert in SwiftUI **nur innerhalb von `List`**. In `ProjectsView` (Z. 65 ff.) und `ProjectDetailView` (Z. 450) stecken die Zeilen in `ScrollView` + `VStack` – die Geste passiert schlicht nicht.

**Folge:** Projekte lassen sich nur über das `…`-Menü im Detail löschen. **Begehungen lassen sich am iPhone nirgends löschen** – weder im Projekt (Swipe tot) noch in der Session (`EditAscentAssociationsSheet` hat keinen Löschen-Button). Ein falsch erfasster Top bleibt für immer in PBs, Pyramide und Erfolgen.

**Fix:** Löschen-Button (destructive, mit Bestätigung) im `EditAscentAssociationsSheet`; zusätzlich `.contextMenu` auf den Zeilen (funktioniert auch außerhalb von `List`). Projekt-Swipe entweder entfernen oder die Liste auf `List` mit `.listRowBackground` umbauen.

### F2 · Doppel-Speichern erzeugt Duplikate
`AddAscentView.save()` zeigt bei einem Top 1,4 s die Feier und dismissed erst danach. Der „Speichern"-Button bleibt in dieser Zeit aktiv. Zweiter Tipp → zweite identische Begehung, zweiter Achievement-Check.

**Fix:** `@State isSaving`, Button `.disabled(isSaving)`, Guard am Anfang von `save()`.

### F3 · „Begehung aus dem Projekt" existiert nicht
`AddAscentView` hat `preselectedProject` (GR-3), aber **niemand übergibt ihn** – der einzige Aufruf ist `AddAscentView(session:)` in `SessionDetailView`. Das Projekt-Detail hat keinen „Begehung hinzufügen"-Einstieg. GR-3 ist damit toter Code.

**⚠️ ABSTIMMEN:** Soll es aus dem Projekt heraus einen Add-Flow geben? Dann braucht er eine Session-Zuordnung (letzte Session von heute oder neue manuelle).

### F4 · Seil-Session startet mit Boulder-Grad
`AddAscentView` initialisiert immer `.fontainebleau` / `"6A"`. Wer eine Vorstieg-Session nachträgt, muss **bei jeder Begehung** System und Grad umstellen. Die Watch macht es richtig (RP-4: `sessionType.defaultGradeSystem`) – das iPhone nicht.

**Fix, in dieser Reihenfolge:** Projekt-Grad → letzter Grad dieser Session → Default des Session-Typs.

### F5 · „Neue Session" legt sofort eine Leiche an
`ManualSessionView` speichert die Session schon bei „Weiter" – bevor irgendetwas erfasst ist. Der Nutzer landet im Detail mit „Fertig", aber ohne „Abbrechen". Wer hier umkehrt, hat eine leere Session in der Historie, die zusätzlich Streak und „Sessions"-Zähler bedient.

Dazu kommt: `scheduleReflectionReminder` wird auch für **nachgetragene** Sessions geplant (Delay min. 30 s). Wer gestern nachträgt und gerade reflektiert, bekommt 30 Sekunden später eine Push „Wie war deine Session am Montag?".

**Fix:** Für manuelle Sessions in der Vergangenheit keinen Reminder planen. Im Detail nach manuellem Anlegen „Verwerfen" anbieten, solange keine Begehung/Reflexion existiert.

### F6 · Angepinnte Projekte auf „Heute" sind nicht tappbar
`pinnedProjectsCard` rendert Zeilen ohne `NavigationLink`. Sieht aus wie ein Link, reagiert nicht.

Zusätzlich zeigt die Karte `project.ascents.reduce { $0 + $1.attempts }` – genau das `attempts`-Feld, das laut **S32 bis zur Route Identity nicht verwendet werden soll**. Gleiches gilt für `Project.totalAttempts` (Projektliste), die Stat-Pill „Versuche" und den Chart „Versuche pro Session" im Projekt-Detail.

### F7 · Drei Bedeutungen von „Versuch"
| Ort | „Versuche" meint |
|---|---|
| Watch-Summary | alle Einträge (`ascents.count`, inkl. Tops) |
| Session-Detail | Einträge mit Ergebnis `.attempt` |
| Projekte / Heute | Summe des `attempts`-Felds |

Der Nutzer sieht auf der Uhr „Versuche 12, Tops 5" und am iPhone „5 Tops, 7 Versuche". Das untergräbt jede Zahl daneben. → Siehe Kapitel 7 (Terminologie).

### F8 · Kleinere Brüche
- **Watch-Grad startet immer bei Index 0** (`AttemptLogView`). Bei einer Boulderhalle heißt das: jede Begehung ~10 Kronen-Rasten hoch. Der Kommentar begründet das mit Ehrlichkeit – aber der **zuletzt erfasste Grad dieser Session** ist ebenso ehrlich und spart den Großteil der Arbeit. (⚠️ Watch-Änderung → abstimmen)
- **Onsight bei Boulder:** Die Watch bietet Flash/Onsight/Rotpunkt/Top für alle Disziplinen an. Onsight ist beim Bouldern kein gebräuchlicher Stil; sechs Buttons statt vier kosten Treffsicherheit am Handgelenk.
- **Edit-Sheet ohne „Abbrechen":** `EditAscentAssociationsSheet` hat nur „Fertig". Runterwischen verwirft still.
- **Header-Icon:** `UIImage(named: "AppIcon")` liefert bei App-Icon-Sets in Asset-Katalogen meist `nil` → es bleibt nur der Schriftzug. *(verifizieren)*
- **Debug-Fallback** in `ClimbReflectApp` (Z. 28) registriert `AchievementUnlock` nicht – nach einem Store-Reset im Debug-Build crasht die erste Erfolgs-Abfrage. Nur Dev, aber verwirrend.

---

## 3. Designsystem – warum es noch nicht „Apple" wirkt

Apple-Apps wirken hochwertig, weil sie **zurückhaltend und extrem konsistent** sind. Farbe trägt Bedeutung, Tiefe entsteht durch Material statt Dekoration, und jedes Detail (Radius, Abstand, Schrift) folgt einem System. Hier die Abweichungen:

### 3.1 Die Bergsilhouette ist das größte „Billig"-Signal
`MountainBackground` liegt hinter **Heute, Fortschritt, Projekte, Erfolge, Session-Detail, Projekt-Detail** – spitze Polygone in Mint→Cyan bei 26 % Deckkraft. Das wirkt wie ein Template-Hintergrund und konkurriert mit Charts und Karten um Aufmerksamkeit.

Apple Fitness, Health, Wetter oder Journal zeigen: Premium entsteht durch **fast schwarze, ruhige Fläche** und Inhalte, die leuchten – nicht durch Hintergrundgrafik.

**Empfehlung:** Silhouette auf allen Daten-Screens entfernen. Wenn Markenidentität gewünscht: ein einziger, sehr weicher radialer Glow oben (Accent, ~6–8 %), der beim Scrollen verschwindet. Oder die Silhouette nur im Onboarding und im Session-Recap als „Bühne".

### 3.2 Farbe
- **Akzent-Inflation:** Mint, Cyan, Mint→Cyan-Gradient, Gold, Gold-Gradient, Rot – oft auf einem Screen. Die Heute-Ansicht nutzt Accent für App-Namen, Toolbar, Stat-Icons, „Alle"-Link, Empty-State, „Reflexion offen". Wenn alles Akzent ist, ist nichts wichtig.
  → **Eine Regel:** Accent = interaktiv / „du". Gold = ausschließlich Erreichtes (PB, Erfolg). Alles andere Grautöne.
- **Hierarchie zu flach:** `textSecondary #8B97A7` und `textTertiary #7A8799` sind auf dunklem Grund praktisch nicht unterscheidbar. Apple arbeitet mit deutlich getrennten Stufen (Label / Secondary ~60 % / Tertiary ~30 %).
  → Semantische Systemfarben (`.primary`, `.secondary`, `.tertiary`) oder eigene Stufen mit echtem Abstand.
- **RPE 8–10 in `danger`-Rot:** Eine harte Session ist kein Fehler. Rot sagt „Problem". Besser: eine Farbintensitäts-Skala in einer Farbe.
- **Hartes Dark Mode** (`.preferredColorScheme(.dark)` 22-mal). Für v1.0 okay, aber zentral an einer Stelle setzen statt pro View.

### 3.3 Formen & Abstände
- **11 verschiedene Eckenradien** (3, 4, 6, 7, 8, 10, 12, 14, 16, 20 …), nur 4 davon `.continuous`. Die „Squircle"-Kurve ist eines der Dinge, die Apple-UI unbewusst hochwertig machen.
  → Drei Tokens: `radius.small 10`, `radius.card 20`, `radius.sheet 28`, **immer** `.continuous`.
- **Karten-Stile uneinheitlich:** `.card()` (surface + Stroke), Hero-Kacheln (surface ohne Stroke), LevelHeader (bgElevated), NextAchievements (bgElevated), Projektzeile (surface, Radius 14), SessionRow (surface 75 %). Das Auge erkennt keine Ordnung.
  → Maximal zwei Ebenen: *Karte* und *Zeile in Karte*. Konturen (`surfaceStroke`) weglassen – Apple trennt über Helligkeit, nicht über Linien.

### 3.4 Typografie
- **43 × `.system(size:)`** – ignoriert Dynamic Type komplett.
- Mischung aus `.rounded .black` (Hero), `.rounded .bold` (LevelHeader), `.title2.bold` (StatTile) für dieselbe Rolle „große Zahl".
- Uppercase-Labels mit `caption2` + Tertiary-Farbe sind auf dem iPhone kaum lesbar.

→ Eine Typo-Skala mit Rollen: `metricHero` (z. B. `.system(.largeTitle, design: .rounded).weight(.semibold)`), `metric`, `title`, `body`, `caption`. Zahlen immer `.monospacedDigit()`. Uppercase-Labels ersetzen durch normale `.footnote` in Secondary.

### 3.5 Navigation & Struktur
- **Heute hat keinen Titel** (`navigationTitle("")`), stattdessen ein zentrierter App-Schriftzug im Scroll-Content. Apple-Muster: Large Title („Heute") + Datum als Untertitel, wie in Fitness („Übersicht") oder Journal.
- **Alle anderen Tabs nutzen `.inline`** – das nimmt der App die typische iOS-Geste „Titel schrumpft beim Scrollen". Large Titles sind *das* iOS-Signal.
- **`toolbarBackground(.hidden)` überall:** Inhalte scrollen ohne Material unter die Statusleiste. Standard-Verhalten (Material erscheint beim Scrollen) fühlt sich nativer an.
- **„+" links, Zahnrad rechts** auf Heute – iOS-Konvention ist umgekehrt (primäre Aktion rechts). Einstellungen gehören eher hinter ein Profil-/Avatar-Symbol rechts oder in einen eigenen Bereich.
- **Informationsarchitektur:** Beta-Bibliothek steckt unten im *Erfolge*-Tab, Schuhe in den *Einstellungen*. Beides sind Kletterinhalte, keine Belohnung bzw. Konfiguration.
  → ⚠️ ABSTIMMEN: Beta-Bibliothek zu *Projekte*; Schuhe als Abschnitt in *Projekte* oder eigene Zeile in einem „Mehr"/Profil-Bereich.
- **Eigene Segment-Picker** (`ProgressDisciplinePicker`, `ProgressPeriodPicker`) mit `caption2` und 4 pt vertikalem Padding → Tap-Fläche ~22 pt statt 44 pt. Apple würde hier `Picker(.segmented)` nehmen – der fühlt sich auch sofort nativ an (inkl. Haptik und Gleit-Animation).

---

## 4. Motion & Haptik – der unsichtbare Qualitätsfaktor

Apple-Apps fühlen sich „teuer" an, weil jede Interaktion eine physische Antwort hat. Aktuell:

- **iPhone-Haptik an genau 4 Stellen** (Speichern in AddAscent ×2, Erfolg-Toast, Erfolg-Overlay).
- **Keine** `contentTransition(.numericText())`, **keine** `symbolEffect`, **kein** `sensoryFeedback`, **kein** `ContentUnavailableView`, **kein** `contextMenu`.
- Zeitraum- oder Disziplinwechsel im Fortschritt: Zahlen und Charts springen hart um.

**Konkrete, kleine Maßnahmen mit großer Wirkung:**

| Interaktion | Maßnahme |
|---|---|
| Grad ändern (Picker/Ruler) | `.sensoryFeedback(.selection, trigger: grade)` |
| Ergebnis wählen | `.sensoryFeedback(.impact(weight: .light))` |
| Begehung gespeichert | `.success`; bei neuem PB zusätzlich stärker |
| Disziplin/Zeitraum wechseln | `.selection` + `withAnimation(.snappy)` + `.contentTransition(.numericText())` auf allen Kennzahlen |
| Anpinnen | `.symbolEffect(.bounce)` auf dem Pin + `.impact` |
| Chip an/aus | `.selection` |
| Neuer PB-Wert erscheint | `.contentTransition(.numericText(countsDown: false))` |
| Leere Zustände | `ContentUnavailableView` statt eigener VStacks |

Wichtig: **leise und kurz**. Die bestehende Erfolgs-Choreografie ist eher zu viel als zu wenig – die Alltags-Interaktionen sind es, die fehlen.

### Die Send-Feier
`CelebrationOverlay` zeigt für **jeden** Top – vom Aufwärm-4A bis zum ersten 7A – dasselbe schwarze Overlay mit „Top!" und blockiert 1,4 s. Beim fünften Aufwärm-Boulder nervt das; beim echten Durchbruch ist es zu wenig.

**Vorschlag – kontextabhängig, nie blockierend:**
- *Normaler Top:* kein Overlay. Haptik + Sheet schließt, die neue Zeile gleitet in die Liste ein.
- *Erster Top in einem Grad / Projekt gesendet:* kompakte Bestätigung oben (Toast-Stil) „Erstmals 6C gesendet".
- *Neuer Höchster Send:* hier darf es groß werden – mit dem Grad als Hauptdarsteller, nicht einem Häkchen.

---

## 5. Erfassen – der Kernflow

### 5.1 „Begehung erfassen" (iPhone)
Aktuell ein `Form` mit **7 Sektionen**: Grad-System + Wheel-Picker, Ergebnis + Stil + Versuche, 3 Tag-Reihen, Projekt + neues Projekt + Set, Schuh, Foto, Notiz. Alles gleichzeitig sichtbar, alles gleich gewichtet.

Das ist die Denkweise „Datenbank-Formular". Apple-Denkweise ist „die eine Frage, die ich gerade beantworten will" – wie beim Erfassen eines Workouts in Fitness oder einer Stimmung in Health.

**Vorschlag „Quick-Log"** *(Mockup-first!)*:

```
┌───────────────────────────────────┐
│ Abbrechen      Begehung    Sichern│
│                                   │
│              6B                   │  ← großer Grad, Scrub-Ruler darunter
│  ‹ 6A · 6A+ · [6B] · 6B+ · 6C ›   │     (Haptik pro Raste)
│  Zuletzt: 6B  6A+  6C             │  ← Grade dieser Session als Chips
│                                   │
│  ┌─────────┐┌─────────┐┌────────┐ │
│  │  Flash  ││   Top   ││Versuch │ │  ← 3 große Ergebnis-Buttons
│  └─────────┘└─────────┘└────────┘ │
│                                   │
│  Projekt: Keins ›                 │  ← eine Zeile, öffnet Menü
│  ▸ Details (Stil-Tags, Schuh,     │  ← DisclosureGroup, zugeklappt
│     Foto, Notiz)                  │
└───────────────────────────────────┘
```

- Grad-System verschwindet aus der Hauptansicht (aus Session-Typ ableiten, F4); bei Bedarf in „Details".
- `presentationDetents([.medium, .large])` – für den Normalfall reicht das halbe Sheet, die Session bleibt im Hintergrund sichtbar.
- **„Sichern & Nächste"** als Sekundäraktion: Bei Nachtragen einer ganzen Session will man nicht 12-mal das Sheet öffnen.
- Schuh ohne „Keiner"-Chip lässt sich nicht abwählen → Chip ergänzen oder als Menü.
- Footer-Text „Projekt einmal wählen – alle Versuche dieser Session übernehmen es automatisch" stimmt auf dem iPhone nicht (gilt pro Begehung) → entfernen.
- Toter Block in `save()` (`if result == .top, let project … { _ = project }`) entfernen.

### 5.2 „Neue Session"
Solide aufgebaut (Art zuerst, gute Frageform „Wann? Wie lange? Wo?"). Verbesserungen:
- Session-Typen mit Checkmark-Zeilen → eine **Segmented-Reihe mit Symbolen** oder ein großes Menü spart eine halbe Bildschirmhöhe.
- Dauer-Stepper in 5er-Schritten bis 480 → 24 Taps für 2 h. Besser: `DatePicker` im `.hourAndMinute`-Stil als Dauer, oder Start- und Endzeit.
- Halle als Freitext → mit `knownGymNames` (existiert bereits in `SessionDetailView`) als Vorschläge. (Vorgriff auf LC-Entity.)
- Persistenz-Problem siehe F5.

### 5.3 Reflexion („Mein Tagebuch")
Eine einzige Karte mit **Session-Typ, Watch-Chips, RPE 1–10, Limiter, Technik-Fokus, Fokus-Rating und drei TextEditoren**. Auf dem iPhone ist das > 2 Bildschirmhöhen Formular am Stück.

- **Zweistufig machen:** *„In 10 Sekunden"* (Anstrengung + 1–2 Limiter-Chips) sichtbar; *„Tagebuch"* (die drei Fragen) als zweiter Schritt oder aufklappbar. Das senkt die Einstiegshürde massiv und macht „Reflexion offen" seltener.
- **Eine Frage pro Screen** wäre noch Apple-näher (vgl. State-of-Mind-Erfassung in Health): kurze, vollflächige Schritte mit „Weiter".
- **Session-Typ ändern** gehört nicht ins Tagebuch → ins `…`-Menü im Header.
- **Kein Speicher-Feedback:** Änderungen werden still über Bindings geschrieben. Ein dezentes „Gespeichert" beim Verlassen oder ein Häkchen am Kartentitel, sobald `reflectionCompleted` true wird, gibt Sicherheit.
- **Doppelte Kurzstatistik:** Tops/Versuche erscheinen oben in der Übersicht *und* unter der Begehungsliste.
- „Tippe auf + um Boulder oder Routen hinzuzufügen" → den leeren Zustand selbst tappbar machen (großer Button), statt auf ein kleines `+` oben rechts zu verweisen.

### 5.4 Watch *(nur Hinweise – laut Absprache kein Eingriff ohne Diskussion)*
- Grad-Startwert = letzter Grad der Session (F8).
- Ergebnis-Buttons nach Disziplin filtern (Boulder: Flash / Top / Versuch / Abbruch).
- „Abbruch" in Rot wirkt wie ein Fehler → neutrale Farbe.

---

## 6. Fortschritt spüren – Status quo und nächster Meilenstein

Dein Ziel: *„Man soll Status quo und die nächsten erreichbaren Meilensteine immer vor Augen haben."* Die Daten dafür existieren alle schon (ProgressEngine: `personalBests`, `nextGrade`, `comfortCandidate`, `firstSends`; Erfolge: `progress.fraction`). Das Problem ist die **Präsentation**.

### 6.1 Heute-Tab: vom Dashboard zur „Seilschaft mit dir selbst"
Aktuelle Reihenfolge: App-Name → Live-Banner → Monatsrückblick → 2 PB-Kacheln → Vorsatz → 3 Stat-Kacheln → Nächster Erfolg → Angepinnte Projekte → Letzte Sessions.

Probleme:
- **PB-Kacheln zeigen nur die Vergangenheit** („Bouldern 6C") – kein Wohin.
- **Stat-Kacheln sind Vanity-Metriken:** „14 Sessions" (gesamt) sagt nichts über Fortschritt. „Streak 3" ohne Einheit (Wochen? Tage?).
- **Nächster Erfolg** wird als „37 %" gezeigt – Prozent ist abstrakt. „Noch 3 Tops" ist greifbar.
- Die wichtigste Zukunftsinfo „Nächste Stufe" gibt es **nur im Fortschritt-Tab**, als Tabellenzeile.

**Vorschlag – ein Level-Hero ganz oben** *(Mockup-first)*:

```
┌─────────────────────────────────────┐
│ Heute                     Mi, 16.9. │
│                                     │
│  BOULDER                            │
│  6C  ─────────────●─────  7A        │  ← Status quo → nächste Stufe
│  Höchster Send     2 Begehungen     │
│                                     │
│  ◔ Wohlfühl-Grad 6B   3 von 5       │  ← Ring mit Zählung (S32-konform:
│  ◔ Rotpunkt 7A        unversucht    │     Stichprobe, keine Quote)
│  ◕ Erfolg „Vielseitig" noch 2 Tops  │
└─────────────────────────────────────┘
```

- **Eine** Komponente „Nächste Meilensteine" mit **einer** Visualisierung (Mini-Ring mit n/Ziel), die überall wiederverwendet wird: Heute, Fortschritt-Header, Erfolge „In Reichweite", Projekt-Detail.
- Maximal **drei** Meilensteine, sortiert nach Nähe. Das ist der Goal-Gradient-Effekt – aber an einem Ort statt an vier.
- Streak mit Einheit („3 Wochen in Folge") und als Unterzeile des Heros statt eigener Kachel; „Sessions gesamt" streichen oder nach Fortschritt verschieben.
- **Ehrlichkeit wahren (S32):** Der Balken zwischen 6C und 7A darf *keine* Quote suggerieren. Er zeigt die Leiter-Position, nicht „wie nah" – die Zählung daneben liefert die Konkretheit.

### 6.2 SessionRow – was zählt, zeigen
Aktuell: Typ, Datum, **Dauer, RPE**, „Reflexion offen".
Für Fortschrittsgefühl zählt: **härtester Top, Anzahl Tops, Ort**.

```
[🧗]  Bouldern · Boulderwelt          6C
      Mo, 14.09. · 7 Tops · 1h 45     ✦ neu
```

„Reflexion offen" in Accent wirkt wie eine Aufgabe/Mahnung. Dezenter: kleiner Punkt am Symbol (wie ungelesene Mail).

### 6.3 Das Session-Ende – der wichtigste emotionale Moment
Aktuell auf der Watch: Siegel + „Gute Session!" + Dauer/Versuche/Tops/HF/kcal. Auf dem iPhone: nichts – die Session erscheint einfach in der Liste.

Das ist der Moment, in dem Nutzer müde, stolz und empfänglich sind. Apple Fitness macht daraus die Zusammenfassung mit Ringen; Strava/Garmin mit „Bestleistungen".

**Vorschlag iPhone-Recap-Sheet**, erscheint beim ersten Öffnen nach Empfang einer Watch-Session:
1. **Highlight zuerst:** „Erstmals 6C gesendet" / „Projekt *Blauer Riss* gesendet" / „Härtester Top: 6B+".
2. **Dann Kontext:** Grad-Verteilung dieser Session als kleine horizontale Pyramide, im Vergleich zu deinem Wohlfühl-Grad.
3. **Dann Meilenstein-Bewegung:** „Wohlfühl-Grad 6B: 3 → 4 von 5".
4. **Freigeschaltete Erfolge** (statt separatem Vollbild-Overlay beim App-Start).
5. **CTA:** „Kurz reflektieren" (→ Schnell-Reflexion aus 5.3) und „Später".

Das bündelt Erfolge-Overlay, Reflexions-Reminder und Fortschritt in einen Moment – statt drei Unterbrechungen zu verschiedenen Zeiten.

⚠️ ABSTIMMEN: Watch-Summary könnte das Highlight (eine Zeile) ebenfalls zeigen – nur nach Diskussion.

### 6.4 Fortschritt-Tab
Inhaltlich stark, visuell zu dicht:
- **Zu viele gleichartige Karten** (LevelHeader, Timeline, Pyramide, Klettertage, Stil-Link, Throwback) ohne visuelle Gewichtung. Der Tab beantwortet drei Fragen (*Wo stehe ich? Werde ich besser? Trägt die Basis?*) – diese Fragen sollten als **Abschnittsüberschriften** sichtbar sein; das gibt Führung.
- **Wohlfühl-Grad-Kandidat „6B · 3/5"** ist ohne Fußnote kryptisch. Klartext: „6B – noch 2 Begehungen bis zur Einschätzung".
- **„Nächste Stufe · 7a · unversucht"** klingt wie ein Defizit. Positiver Rahmen: „7a – bereit für den ersten Versuch".
- Picker nativ machen (3.5), Übergänge animieren (4).
- „Stil & Limiter" als versteckte Zeile am Ende – das ist die „Warum"-Antwort. Mindestens mit einer Vorschau-Zeile („Limiter zuletzt: Fingerkraft") aufwerten.
- Monatsrückblick nur Tag 1–7 sichtbar: wer in dieser Woche die App nicht öffnet, verpasst ihn komplett. → im Fortschritt-Tab dauerhaft abrufbar machen.

### 6.5 Projekte
- **Chart „Versuche pro Session"** basiert auf `attempts` (S32-Verstoß, F6). Ersatz ohne Route Identity: **Tages-Punkte-Zeitleiste** („Tag 1 · 2 · 3 · ✓") – zeigt Hartnäckigkeit ehrlich über `distinctDays`.
- Projektliste: Status-Kreis-Icons (target/pin/check/xmark) sind fein, aber alle gleich groß und gleich gewichtet. Gesendete Projekte dürfen **golden** und stolz wirken („Trophäenwand"), aufgegebene deutlich zurücktreten.
- Sektionstitel „Gesendet ✓" mit Unicode-Häkchen → Symbol oder weglassen.
- Doppelter Projektname wird beim Anlegen **still verworfen** → Hinweis „Projekt existiert bereits" + direkt dorthin navigieren.
- Löschen aus Liste ohne Bestätigung (sobald F1 behoben ist, fällt das auf).
- Das PJ-Block-Ziel (Projekt als Erzählung) passt genau hier; die Tages-Zeitleiste ist der erste Schritt dahin.

### 6.6 Erfolge
- Kopf „Sammlung 12 von 28" + 4-pt-Balken ist nüchtern-gut. Die Kachel-Grid-Darstellung ist visuell der stärkste Screen der App.
- „In Reichweite" zeigt Prozent → wie oben auf „noch N" umstellen.
- Beta-Bibliothek hier ist ein IA-Fremdkörper (3.5).

---

## 7. Mikro-Copy & Terminologie

Uneinheitliche Begriffe kosten mehr Premium-Gefühl als man denkt. Vorschlag für ein verbindliches Glossar (als S-Prinzip in CLAUDE.md):

| Begriff | Bedeutung | Aktuell auch als |
|---|---|---|
| **Begehung** | ein erfasster Eintrag (egal welches Ergebnis) | „Versuch" (Watch), „Einträge" |
| **Top** | Begehung mit Ergebnis top | „Send", „Sends", „Gesendet" |
| **Versuch** | Begehung ohne Top | Summe `attempts`, alle Einträge |
| **Gesendet** | nur für Projekte | „Top" |
| **Klettertag** | Kalendertag mit ≥ 1 Kletter-Session | „Bouldertage", „Seiltage", „Tage" |

Weitere Punkte:
- **Denglisch mischen:** „Höchster Send", „Sends", „Flash", „Rotpunkt"/„Redpoint", „Onsight". Kletterbegriffe dürfen englisch bleiben (Flash, Onsight) – aber **ein** Wort für den Top (Send *oder* Top).
- **„Redpoint"** als Name der Drittanbieter-App steht in Einstellungen, Kommentaren und Card-Namen (`redpointCard`). Für Nutzer mit dem Kletterstil „Rotpunkt" verwirrend. → „Apple Health" reicht als Bezeichnung.
- **„Keins"** (Projekt-Chip) → „Kein Projekt".
- **„Mein Tagebuch"** vs. Tab-/Reminder-Sprache „Reflexion" → ein Begriff.
- **„Noch kein Top"** / „Noch keine Begehung" / „Noch keine Daten" / „Keine Projekte" – vier Tonalitäten für leere Zustände. Einheitlich einladend formulieren und `ContentUnavailableView` nutzen.
- Leerer Heute-Zustand verspricht „Oder importiere deine Einheiten aus Apple Health", der Button öffnet aber die manuelle Erfassung. Entweder zweiter Button, der zu den Einstellungen führt, oder Text streichen. Für den Watch-first-Ritus wäre hier ohnehin der bessere Hinweis: „Starte deine erste Session auf der Apple Watch".

---

## 8. Barrierefreiheit (Qualitätsbasis)

- **0 Accessibility-Labels** in der gesamten iOS-App. VoiceOver liest Symbol-Buttons (`plus`, `gearshape`, `ellipsis.circle`) als Symbolnamen vor, Kacheln als zusammenhanglose Einzeltexte.
- **Kein Dynamic Type** durch hartkodierte Größen (3.4).
- **Tap-Flächen < 44 pt** bei Pickern, Chips (5 pt vertikales Padding) und RPE-Buttons.
- Kontrast Tertiary-Text auf `surface` ist grenzwertig für kleine Schrift.

Apple prüft das im Review nicht streng, aber Nutzer spüren es als „wackelig" – und das AX-Block steht ohnehin im Plan.

---

## 9. Priorisierte Roadmap

### Block A · Vertrauen (P0, sofort, klein – je 1 Commit)
1. Begehung löschen im Edit-Sheet + `contextMenu` (F1)
2. Swipe-Aktionen entfernen oder auf `List` umbauen (F1)
3. Doppel-Speichern verhindern (F2)
4. Grad-Default aus Session-Typ / letzter Begehung (F4)
5. Kein Reminder für nachgetragene Sessions; „Verwerfen" für leere manuelle Session (F5)
6. Angepinnte Projekte tappbar; `attempts`-Anzeigen entfernen (F6)
7. „Abbrechen" im Edit-Sheet, Debug-Container-Fix (F8)

### Block B · Ruhe (klein–mittel)
8. Design-Tokens: Radien (continuous), Typo-Rollen, Farbstufen, eine Karten-Ebene
9. `MountainBackground` von Daten-Screens entfernen
10. Large Titles + Standard-Toolbar-Material; Heute mit Titel statt Schriftzug
11. Native Segmented Picker im Fortschritt-Tab
12. Terminologie-Glossar als S-Prinzip + Copy-Pass (Kap. 7)

### Block C · Gefühl (klein, sehr hohe Wirkung)
13. `sensoryFeedback` an allen Kerninteraktionen (Tabelle Kap. 4)
14. `numericText`- und Chart-Übergänge bei Disziplin-/Zeitraumwechsel
15. Send-Feier kontextabhängig und nicht blockierend

### Block D · Fortschritt *(Mockup-first in Claude Design)*
16. Komponente „Nächste Meilensteine" (Ring + n/Ziel) – einmal bauen, viermal nutzen
17. Level-Hero auf Heute
18. SessionRow mit härtestem Top / Tops / Ort
19. Session-Recap-Sheet auf dem iPhone
20. Projekt-Tages-Zeitleiste statt Versuche-Chart

### Block E · Erfassen *(Mockup-first)*
21. Quick-Log für Begehungen (Grad-Ruler, 3 Ergebnis-Buttons, Details zugeklappt, „Sichern & Nächste")
22. Zweistufige Reflexion

### Zum Abstimmen ⚠️
- Add-Flow aus dem Projekt heraus (F3) – mit welcher Session-Zuordnung?
- Watch: Grad-Startwert, Ergebnis-Buttons pro Disziplin, Highlight-Zeile in der Summary
- IA: Beta-Bibliothek → Projekte, Schuhe raus aus Einstellungen
- Bergsilhouette ganz weg oder nur Onboarding/Recap?

---

**Empfehlung zur Reihenfolge:** A → C → B → D → E. Block A und C sind in wenigen Abenden machbar und verändern das Bediengefühl spürbar, ohne dass ein Layout neu entworfen werden muss. B räumt auf, bevor D und E über Mockups neu gestaltet werden – sonst entwirfst du neue Screens auf altem Designsystem.
