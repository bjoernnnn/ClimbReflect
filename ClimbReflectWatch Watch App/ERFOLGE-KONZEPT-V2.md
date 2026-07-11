# ERFOLGE-KONZEPT V2 — Gipfelmarken

**Stand der Analyse:** `main` @ `0306575` (v1.0.0). Ersetzt `ERFOLGE-KONZEPT.md` und `TODO11-ERFOLGE.md`
(beide nie implementiert — auf `main` existieren weder `AchievementEngine` noch `AchievementUnlock`).
Umsetzung: `TODO13-ERFOLGE-PREMIUM.md`.

---

## 1. Ist-Zustand (Befund aus dem Code)

Das aktuelle System besteht aus **7 live abgeleiteten Erfolgen** ohne jede Persistenz:

- `StatsEngine.climbAchievements(for:)` (Models/Achievement.swift, Z. 100–190): `new_pb`,
  `triple_flash`, `project_done`, `comeback`, `flash_rate` — bei jedem View-Render neu berechnet.
- `StatsEngine.achievements(for:)` (Z. 268–289): `first`, `streak` — zweiter, paralleler Struct-Typ.
- `AchievementsView.swift`: horizontaler Streifen aus 52-pt-Kacheln, Merge der beiden Typen ad hoc
  in der View, Detail-Sheet mit statischem Text.
- `Views/Components/AchievementCard.swift`: **toter Code** — nirgends referenziert.
- Kein Unlock-Ereignis, keine Haptik, keine Animation, keine Einstellung. Nichts feiert.

## 2. Schwächen des aktuellen Systems

**W1 — Kein Ereignis, nur Zustand.** Ohne Persistenz gibt es kein „Freigeschaltet am …", keine
Historie, keinen Moment. Ein Erfolg ist ein Boolean, der beim Rendern zufällig wahr wird. Löscht man
eine Session, verschwindet der Erfolg rückwirkend — das Gegenteil von „verdient".

**W2 — Der Unlock-Moment existiert nicht.** Der psychologisch wertvollste Augenblick (Kompetenz-
Feedback unmittelbar nach der Leistung, SDT) verpufft: Die App zeigt den neuen Zustand kommentarlos
beim nächsten Tab-Besuch. Genau hier entsteht bei Premium-Apps das Qualitätsgefühl.

**W3 — Triviale und kaputte Definitionen.**
- `new_pb` („Neuer Höchstgrad") schaltet nach der **allerersten bewerteten Begehung** frei und kann
  danach nie wieder verdient werden — ein wiederholbares Ereignis, als Einmal-Boolean modelliert.
- `flash_rate` (≥ 30 % Flash-Quote) verletzt S32: Quote über einen Nenner, in dem Tops ohne
  gesetzten Stil mitzählen; mit n = 5 statistisch wertlos.
- `comeback` feuert schon nach 14 Tagen Pause — bei normaler Urlaubslänge quasi garantiert.

**W4 — Kein Bogen, keine Progression.** 6 von 7 Erfolgen sind in den ersten zwei Wochen erledigt.
Danach gibt es exakt nichts mehr, worauf man hinarbeiten könnte. Kein Tier-System, keine
Meilensteine, kein Fernziel. Der Goal-Gradient-Effekt hat keine Fläche.

**W5 — Kein Fortschritt sichtbar.** Gesperrte Kacheln unterscheiden sich nur durch Deckkraft.
Fortschritt existiert als Text („2/3 Flashes") in einem Fall; kein Ring, keine Nähe-Signale, kein
„In Reichweite". Der stärkste bekannte Motivations-Hebel (sichtbare Zielannäherung) fehlt komplett.

**W6 — Keine Verbindung zum Kern-Loop.** Session auf der Watch beenden → Sync → … nichts. Weder
Today-Tab noch Session-Detail wissen von Erfolgen. Der Tab ist eine Sackgasse mit Beta-Bibliothek-Link.

**W7 — Optik unter App-Niveau.** Einheitsgold auf Mint, keine Hierarchie, keine Wertigkeitsstufen,
Icon-Kreise ohne Material. Die restliche App (LevelHeader, Charts, Karten-Stil) wirkt deutlich
hochwertiger als ihr Belohnungssystem.

**W8 — Architektur-Schuld.** Zwei parallele Struct-Typen, Merge in der View, toter `AchievementCard`,
Erfolgs-Logik vermischt mit Session-Insights in `StatsEngine`.

Das ältere `ERFOLGE-KONZEPT.md` (23 Definitionen) hat W1–W6 richtig erkannt, aber selbst Lücken:
wöchentlich wiederholbare Erfolge (`four_in_week`, `active_month`) erzeugen Achievement-Spam und
nudgen Richtung Übertraining (Geist von S31); `ascents_count` belohnt das Loggen von Fehlversuchen;
es gibt kein visuelles Konzept, keine Wertigkeitsstufen, keine Animations-/Performance-Spezifikation
und keine Einstellung. V2 übernimmt das tragfähige Fundament (Katalog + pure Engine + persistente
Unlocks + Backfill) und baut Katalog, Psychologie-Schicht und Erscheinungsbild neu.

---

## 3. Leitplanken aus Psychologie & Game Design

Jeder Mechanismus unten ist an genau eine Erkenntnis gebunden — nichts ist Dekoration.

**L1 — Goal-Gradient-Effekt** (Hull; Kivetz/Urminsky/Zheng 2006: Anstrengung steigt mit Zielnähe).
→ Fortschrittsring direkt am Medaillon jeder gesperrten Karte; Sektion **„In Reichweite"** (bis zu
3 Erfolge ≥ 50 %) ganz oben im Tab; **„Nächster Erfolg"**-Karte im Today-Tab. Tier-Leitern zeigen
immer nur die *nächste* Stufe als Ziel (kleine gefühlte Distanz), nie die ganze Leiter als Berg.

**L2 — Endowed Progress** (Nunes/Drèze 2006: geschenkter Startfortschritt erhöht Abschlussrate).
→ Backfill über die Bestandsdaten: Beim ersten Start nach dem Update sind historische Erfolge bereits
freigeschaltet (mit korrektem damaligem Datum), Tier-Leitern stehen nicht auf 0. Kein leerer Tab am Tag 1.

**L3 — Kompetenz statt Aktivität** (Self-Determination Theory: informierendes Feedback stärkt
intrinsische Motivation, kontrollierendes untergräbt sie).
→ Erfolge messen **Kletterleistung** (Grade über `canonicalOrder`, Stil, Projekte, Konsistenz), nicht
App-Nutzung. Freischalt-Texte benennen die gezeigte Fähigkeit („Du liest Routen und setzt sie im
ersten Versuch um"), nie „Weiter so, komm morgen wieder!". Keine XP, keine Coins, keine Level-Währung —
extrinsische Punktesysteme verdrängen genau die Motivation, die die App aufbauen will.

**L4 — Autonomie respektieren** (SDT).
→ Kein Streak-Shaming: Der Wochen-Streak vergibt die laufende leere Woche (bestehende
`weekStreak`-Logik), ein gerissener Streak wird nirgends rot markiert. `comeback` (Rückkehr nach
≥ 30 Tagen) feiert Wiederanfangen statt Pausen zu bestrafen. Effekte, Sound und Benachrichtigungen
sind abschaltbar.

**L5 — Mastery-Kurve** (Flow: Anforderungen wachsen mit Können).
→ Tier-Schwellen wachsen degressiv-gestuft (10 → 25 → 50 → 100 → 250), Grad-Meilensteine folgen den
echten „magischen Graden" der Community (6A · 6C · 7A · 7C · 8A). Die PB-Erfolge (`pb_boulder`/
`pb_route`) sind endlos wiederholbar — das System wächst mit, statt auszulaufen. Fernziele mit
Jahres-Horizont (52-Wochen-Streak, 1000 Tops, 8 848 Höhenmeter) geben dem „darauf habe ich
hingearbeitet"-Gefühl echte Substanz.

**L6 — Variable Belohnung nur, wo sie sinnvoll ist** (Operante Konditionierung: variable Verstärkung
wirkt stark — und genau deshalb sparsam einsetzen, nicht als Slot-Machine).
→ Genau **3 verborgene Erfolge** („Besondere Momente", angezeigt als ???). Sie sind an echte, seltene
Kletter-Momente gebunden (Session vor 7 Uhr, PB-Sprung um ≥ 2 Grade, Neujahrs-Session) und nicht
planbar farmbar. Alles andere ist transparent — Berechenbarkeit ist beim Hinarbeiten der Motivator,
Überraschung nur als Gewürz.

**L7 — Anti-Spam-Politik.**
→ Wöchentlich/monatlich wiederholbare Erfolge sind gestrichen. Wiederholbare Session-Erfolge
(`flash_day`, `big_day`) feiern **leise** (Toast + leichte Haptik, kein Vollbild). Pro Sync maximal
**ein** Vollbild-Overlay; mehrere Unlocks paginieren darin („1 von 3"). Backfill setzt `seenByUser =
true` — niemals eine Celebration-Flut über Altdaten.

**L8 — Ehrlichkeit (S6/S27/S32 gelten auch hier).**
→ Jede Definition ist aus echten Daten berechenbar. Keine Quoten-Erfolge (Stichproben-Problem),
keine `attempts`-basierten Metriken außer der Projekt-Versuchszählung über die Relation, nur
`isGraded`-Begehungen in Grad-Erfolgen, Höhenmeter nur gemessen (Watch). Einmal freigeschaltet
bleibt freigeschaltet — der Unlock ist ein historisches Ereignis (Widerrufs-Politik aus V1 übernommen).

---

## 4. Systementscheidungen

1. **Persistenz:** `AchievementUnlock` (@Model, Schema V10): `definitionID`, `tier?`, `unlockedAt`,
   `contextValue?`, `sessionID?`, `seenByUser`. Idempotenz-Schlüssel wie in V1
   (once → id, tiered → id+tier, repeatable → id+sessionID bzw. id+contextValue).
2. **Katalog + pure Engine:** statischer `AchievementDefinition`-Katalog; `AchievementEngine`
   rein funktional (Sessions/Projekte/Unlocks rein, PendingUnlocks + Progress raus), unit-getestet —
   exakt das ProgressEngine-Muster.
3. **Ein Trigger-Punkt:** `AchievementService.checkNow(context:)` nach Watch-Insert, manuellem
   Session-Save, Ascent-Anlage/-Edit und Projekt-Statuswechsel.
4. **Celebration-Politik pro Definition:** `.full` (Vollbild-Overlay) oder `.quiet` (Toast).
5. **Wertigkeitsstufen:** Bronze · Silber · Gold · Diamant — als *Material* des Medaillon-Rings,
   nicht als Loot-Rarity. Diamant ist strikt limitiert (6 Vorkommen im Katalog, alle mit
   Mehrjahres-Horizont). Wiederholbare PB-Erfolge sind immer Gold.
6. **Verborgen:** `isHidden`-Flag; gesperrt als „???"-Karte ohne Fortschritt oder Kriterium.
7. **Abgrenzung — bewusst nicht in V2:**
   - **Multipitch:** Das Datenmodell kennt keine Seillängen (kein `pitches`-Feld an `Ascent`).
     Ein Erfolg ohne Datenbasis wäre erfunden (S6). → Kandidat für später, wenn das Feld existiert.
   - **Community:** Kein Backend, keine Accounts. → „Zukünftig geplant" bleibt Zukunft.
   - **XP/Level/Coins:** siehe L3. Der Fortschritt-Tab beantwortet „Werde ich besser?" bereits ehrlich.

---

## 5. Der Katalog (28 Definitionen, 7 Kategorien)

Legende: Kind `1×` = once, `T[…]` = tiered, `↻` = repeatable · Feier `●` = full, `○` = quiet ·
Material B/S/G/D. Grad-Schwellen laufen über `GradeConverter.canonicalIndex` (Referenz Fb bzw.
French), Anzeige in der eingestellten Skala.

### 1 · Anfänge — die ersten Male (schnelles Kompetenz-Feedback, Endowment)

| id | Titel | Kind | Kriterium | Mat. | Feier |
|---|---|---|---|---|---|
| `first_session` | Seil frei | 1× | Erste Session aufgezeichnet | B | ● |
| `first_top` | Erster Top | 1× | Erste Begehung mit Ergebnis Top | B | ● |
| `first_reflection` | Innehalten | 1× | Erste Reflexion abgeschlossen (`reflectionCompleted`) | B | ● |
| `first_outdoor` | Ans echte Gestein | 1× | Erste Outdoor-Session | S | ● |
| `discipline_trio` | Dreiklang | 1× | ≥ 1 Session in 3 verschiedenen Kletter-Disziplinen (Boulder/Vorstieg/Toprope/Autobelay) | S | ● |

`first_reflection` ist bewusst dabei: Reflexion ist der Namenskern der App — einmal würdigen, nicht
dauerhaft gamifizieren (L3).

### 2 · Konsistenz — dranbleiben, ohne Druck

| id | Titel | Kind | Kriterium | Mat. | Feier |
|---|---|---|---|---|---|
| `week_streak` | Am Ball | T[4, 8, 13, 26, 52] | Wochen in Folge mit ≥ 1 Session (laufende leere Woche verzeiht) | B·B·S·G·**D** | ● |
| `sessions_total` | Stammgast | T[10, 25, 50, 100, 250] | Sessions gesamt | B·B·S·G·**D** | ● |
| `climb_days_year` | Jahr der Wand | ↻ (je Jahr) | ≥ 50 Klettertage in einem Kalenderjahr (contextValue = Jahr) | G | ● |
| `comeback` | Wieder da | 1× | Klettersession nach ≥ 30 Tagen Pause | S | ● |

Ersatzlos gestrichen gegenüber V1: `four_in_week` und `active_month` (Wochen-/Monats-Spam,
Übertrainings-Nudge, L7/S31).

### 3 · Schwierigkeit — die Krone des Systems

| id | Titel | Kind | Kriterium | Mat. | Feier |
|---|---|---|---|---|---|
| `pb_boulder` | Neue Bestmarke | ↻ | Neuer Boulder-Höchstgrad (canonicalOrder, nur `isGraded`; contextValue = Grad) | G | ● |
| `pb_route` | Neue Bestmarke | ↻ | Neuer Seil-Höchstgrad (analog) | G | ● |
| `grade_boulder` | Boulder-Meilensteine | T[6A, 6C, 7A, 7C, 8A] | Erster Boulder-Top ab kanonischem Grad | B·S·G·G·**D** | ● |
| `grade_route` | Routen-Meilensteine | T[6a, 6c, 7a, 7c+, 8a] | Erster Seil-Top ab kanonischem Grad | B·S·G·G·**D** | ● |

`new_pb` (W3) wird damit korrekt: jede echte Bestleistung ist ein eigenes, datiertes Ereignis mit
Grad im Untertitel — die unendliche Mastery-Leiter (L5).

### 4 · Stil — Können, nicht Quote

| id | Titel | Kind | Kriterium | Mat. | Feier |
|---|---|---|---|---|---|
| `flash_total` | Blitzsammler | T[5, 25, 100] | Flash-Tops gesamt | B·S·G | ● |
| `onsight_total` | Auf Sicht | T[1, 10, 25] | Onsight-Tops gesamt | S·G·G | ● |
| `flash_day` | Lauf | ↻ (je Session) | ≥ 3 Flashes in einer Session | S | ○ |
| `angle_allrounder` | Allrounder | 1× | Tops in allen 4 Wandwinkeln (Platte/Senkrecht/Überhang/Dach) | G | ● |

`flash_rate` (Quote) ist gestrichen — absolute Zähler statt Stichproben-Prozente (L8/S32).
`angle_allrounder` zählt nur getaggte Begehungen; das ist ehrlich und macht die Stil-Tags wertvoll.

### 5 · Ausdauer — Volumen mit Fernzielen

| id | Titel | Kind | Kriterium | Mat. | Feier |
|---|---|---|---|---|---|
| `tops_total` | Gipfelsammler | T[10, 50, 100, 250, 500, 1000] | Getoppte Begehungen gesamt | B·B·S·G·G·**D** | ● |
| `hours_total` | Stunden an der Wand | T[10, 25, 50, 100, 250] | Aktive Kletterstunden (`activeSeconds`, nur Klettersessions) | B·S·S·G·**D** | ● |
| `altitude_total` | Höhenmeter | T[100, 500, 1000, 8848] | Kumulierte gemessene Kletterhöhenmeter (Watch-Barometer, `Ascent.altitudeGain`) | B·S·G·**D** | ● |
| `big_day` | Marathon-Tag | ↻ (je Session) | ≥ 20 Tops in einer Session | S | ○ |

Tier 4 von `altitude_total` = **8 848 m — „Everest"**: das langfristigste Ziel der App, nur aus echt
gemessenen Watch-Daten. `ascents_count` aus V1 (zählte Fehlversuche) ist gestrichen — es belohnte
Logging-Volumen statt Klettern. `training_count` ebenfalls gestrichen: Training bleibt un-gamifiziert
(Geist von S31).

### 6 · Projekte — der Prozess

| id | Titel | Kind | Kriterium | Mat. | Feier |
|---|---|---|---|---|---|
| `project_first_send` | Der Prozess | 1× | Erstes Projekt gesendet (über Relation, `isSent`) | S | ● |
| `projects_total` | Projektjäger | T[3, 10, 25] | Gesendete Projekte gesamt | S·G·G | ● |
| `project_persistent` | Hartnäckig | ↻ (je Projekt) | Projekt mit ≥ 10 gebuchten Versuchen gesendet (contextValue = Projektname) | G | ● |
| `project_longgame` | Langes Spiel | 1× | Projekt über ≥ 3 verschiedene Klettertage gesendet (`distinctDays`) | G | ● |

### 7 · Besondere Momente — verborgen (L6)

| id | Titel | Kind | Kriterium | Mat. | Feier |
|---|---|---|---|---|---|
| `dawn_patrol` | Frühschicht | 1× | Session vor 7:00 Uhr gestartet | S | ● |
| `grade_leap` | Quantensprung | 1× | Neue Bestmarke, die den alten Höchstgrad um ≥ 2 kanonische Stufen überspringt | G | ● |
| `new_year_climb` | Guter Vorsatz | 1× | Session am 1. Januar | S | ● |

Gesperrt erscheinen sie als „???"-Karte ohne Kriterium und ohne Fortschritt.

**Bilanz:** 28 Definitionen ≈ 60+ Unlock-Momente über Jahre. Gestrichen aus dem Live-System:
`flash_rate`, altes `new_pb`; gestrichen aus V1: `four_in_week`, `active_month`, `ascents_count`,
`training_count`, `year_50` (aufgegangen in `climb_days_year`). Jede Streichung ist oben begründet.

---

## 6. Visuelles System — „Gipfelmarken"

Das Erscheinungsbild erweitert die bestehende Design-Sprache (Theme.swift: `bg 0x0B0E13`,
`surface 0x171C25`, Karten mit `cornerRadius 20 continuous` + 1-pt-Stroke, SF Rounded für große
Zahlen wie im `LevelHeaderView`) — nichts wirkt wie ein Fremdkörper.

### 6.1 Signatur: das Medaillon

Jeder Erfolg ist eine runde **Gipfelmarke**: dunkle Plakette (`bgElevated`) mit eingraviertem
diagonalem Grat — eine feine Polyline (8 % Weiß), die den diagonalen `MountainBackground` der App
zitiert. Außen ein 2,5-pt-**Materialring** (Bronze/Silber/Gold/Diamant als dezenter
Angular-Gradient), innen das SF Symbol. Gesperrt: Plakette bleibt, Symbol in `textTertiary`,
statt Materialring ein **Fortschrittsring** (`Theme.accent`, 3 pt, `trim`). Der Grat ist das eine
wiedererkennbare Element; alles andere bleibt ruhig.

### 6.2 Design-Tokens (Erweiterung von `Theme`)

```swift
extension Theme {                       // Theme+Achievements.swift
    static let bronze     = Color(hex: 0xC9905E)
    static let bronzeDeep = Color(hex: 0x8A5A34)
    static let silver     = Color(hex: 0xC9D4E0)
    static let silverDeep = Color(hex: 0x7E8C9E)
    // Gold nutzt bestehendes goldGradient (0xFFD976 → 0xF5C451)
    static let diamond     = Color(hex: 0xA8ECFF)
    static let diamondDeep = Color(hex: 0x4FC3F7)   // Familie von accent2
}
```

Materialringe als `AngularGradient([deep, hell, deep])` — metallisch, nie neonhaft. Diamant ist
kühles Eisblau (alpin, verwandt mit `accent2`), kein Regenbogen.

### 6.3 Typografie

Bestehende Rollen weiterführen: Titel `.subheadline.weight(.semibold)`, Status `.caption2`,
Eyebrows (Kategorie-Header) `.caption2.weight(.semibold)` + `uppercased` + Tracking wie im
LevelHeader. Große Momente (Overlay-Titel, Grad im Detail) in `.system(.., design: .rounded)`
`.bold` — dieselbe Stimme wie die PB-Kacheln im Fortschritt-Tab.

### 6.4 Karten & Layout des Erfolge-Tabs

1. **Header:** „Sammlung" + `12 von 28` (Rounded-Zahl) + dünner Gesamtfortschrittsbalken.
2. **In Reichweite** (nur wenn vorhanden): bis zu 3 horizontale Karten — Medaillon mit Ring,
   Titel, Rest-Text („Noch 2 Sessions"). Goal-Gradient-Bühne (L1).
3. **Kategorie-Chips** (horizontal scrollbar): Alle · Anfänge · Konsistenz · … · Momente. Filter.
4. **Grid** (2 Spalten, `LazyVGrid`): `AchievementTile` = Karte im bestehenden `card()`-Stil,
   zentriertes 56-pt-Medaillon, Titel (2 Zeilen), Statuszeile (freigeschaltet: Datum bzw. „×3" /
   Stufe „III von V" als Punkte-Reihe · gesperrt: Rest-Text), unten bei Tiered eine Punktreihe
   (gefüllt = Material, offen = `surfaceStroke`). Gesperrte Karten bleiben **klar** (kein
   Grau-Schleier über der ganzen Karte wie bisher) — nur das Medaillon ist monochrom.
5. **Detail-Sheet:** 96-pt-Medaillon mit statischer Material-Aura (RadialGradient), Titel,
   Material-Chip, Kriteriumstext, Fortschrittsbalken + Rest-Text, Unlock-Datum; bei `↻` eine
   Ereignis-Timeline (Datum + contextValue, z. B. die PB-Historie „6B+ → 6C → 7A"). Verborgen &
   gesperrt: nur „Geheimer Erfolg — wird beim Freischalten enthüllt."

### 6.5 Ikonografie

SF Symbols, pro Definition kuratiert (z. B. `flag.fill`, `mountain.2.fill`, `bolt.fill`,
`eye.fill`, `target`, `flame.fill`, `sparkles`, `sunrise.fill`, `books.vertical.fill` →
konkrete Zuordnung im Katalog-Code, TODO EP-1). Keine Emoji, keine Custom-Assets nötig.

---

## 7. Der Unlock-Moment

**Choreografie (Vollbild-Overlay, gesamt ≈ 1,5 s bis interaktiv):**

| t (ms) | Ebene | Animation (nur transform/opacity) |
|---|---|---|
| 0 | Backdrop | schwarz, opacity 0 → 0.55, easeOut 200 ms |
| 0 | Glow | vorgebaute RadialGradient-Scheibe im Material: opacity 0 → 0.8, scale 0.8 → 1.15, 450 ms |
| 60 | Medaillon | scale 0.6 → 1.0 + opacity, `spring(response 0.45, dampingFraction 0.7)` |
| 60 | **Haptik** | `UINotificationFeedbackGenerator(.success)` (mit `prepare()` davor) |
| 150 | Materialring | `trim 0 → 1`, easeOut 550 ms (Ring „zeichnet sich") |
| 250 | Partikel | 24 Funken (Material-Farbe), radiale Bahnen, je translate + scale 1 → 0.3 + opacity → 0, 900–1200 ms |
| 300 | Grat-Glanz | schmaler Highlight-Streifen läuft einmal diagonal über die Plakette (rotierte Gradient-Maske, nur offset/opacity) |
| 350 | Text | Titel + Untertitel (contextValue/Stufe): opacity + 8-pt-Offset nach oben, 300 ms |
| 500 | Glow | zurück auf opacity 0.35 (Ruhezustand) |
| ~1500 | UI | „Weiter"-Button einblenden; bei N Unlocks Pager „1 von N" |

**Sound (optional, Standard aus):** ein einzelner, kurzer Glas-/Chime-Tick (< 0,5 s) beim
Medaillon-Apex — eigener Toggle.

**Leise Feier (`.quiet`):** kein Overlay. Kompakter Toast oben (Kapsel mit Mini-Medaillon + Titel,
slide-in per offset/opacity, 2,5 s), `UIImpactFeedbackGenerator(.light)`. Zusätzlich pulst die
betreffende Karte beim nächsten Tab-Besuch einmal dezent (scale 1 → 1.03 → 1).

**Reduzierte Variante** (Toggle aus **oder** System „Bewegung reduzieren"): Overlay als reiner
Crossfade (Backdrop + Medaillon opacity, keine Skalierung, keine Partikel, kein Glanzlauf),
Haptik bleibt. Der Moment bleibt erhalten, die Bewegung nicht.

---

## 8. Performance-Regeln (verbindlich)

1. **Nur `transform` (scale/offset/rotation) und `opacity` animieren.** Kein animierter Blur, kein
   animiertes Layout, keine Frame-/Padding-Animationen. Glow = vorgebauter Gradient, der nur in
   Opacity/Scale animiert.
2. **Kein Layout-Shift:** Overlay und Toast leben als `.overlay`/oberste `ZStack`-Ebene über dem
   Tab-Container; sie verdrängen nie Inhalt. Kachel-Höhen sind fix (wie bisher im Karten-Stil).
3. **Partikel-Budget:** max. 24 Partikel, Bahnen beim Start einmalig vorberechnet (Winkel, Tempo,
   Spin), gerendert in **einem** `Canvas` innerhalb `TimelineView(.animation)`; nach 1,4 s wird die
   TimelineView pausiert/entfernt — kein Dauer-Ticker (Lehre aus S3/S19).
4. **60 fps-Nachweis:** die gesamte Komposition (Canvas + Medaillon) bei Bedarf in `drawingGroup()`;
   Test auf ältestem Zielgerät, Instruments „Animation Hitches" = 0 während der Choreografie.
5. **Vollständig deaktivierbar:** `@AppStorage("achievementEffectsEnabled") = true` und
   `@AppStorage("achievementSoundEnabled") = false`; zusätzlich wird
   `@Environment(\.accessibilityReduceMotion)` immer respektiert (ODER-Logik → reduzierte Variante).

---

## 9. Einstellungen

Neue Section in `SettingsView` (zwischen „Grad-Skala" und „Daten"):

> **Animationen**
> Achievement-Effekte ⟶ Toggle (an)
> Sound bei Erfolgen ⟶ Toggle (aus)
> Footer: „Steuert Glow, Partikel und Haptik beim Freischalten von Erfolgen. Die Systemeinstellung
> ‚Bewegung reduzieren' wird zusätzlich immer respektiert."

---

## 10. Integration in den Nutzerfluss

- **Today:** kompakte „Nächster Erfolg"-Karte (Mini-Ring + Rest-Text, höchster Fortschritt < 100 %),
  Tap → Erfolge-Tab. Der Goal-Gradient beginnt auf dem Homescreen.
- **Session-Detail:** Zeile „In dieser Session freigeschaltet" mit Mini-Medaillons
  (Unlocks mit passender `sessionID`) — die Session erzählt ihre eigene Geschichte.
- **Hintergrund-Sync:** kommt eine Watch-Session an, während die App im Hintergrund ist, sichert
  eine lokale Notification den Moment („Erfolg freigeschaltet — Neue Bestmarke: 7A"); im Vordergrund
  nur das Overlay, nie beides. Respektiert das bestehende `NotificationService.isEnabled`.
- **Watch:** bewusst **nicht** in V2 (Rückkanal = ABSTIMMEN, siehe TODO Phase 3) — der End-Flow der
  Watch ist heilig (S4/S21), da wird nichts riskiert.

---

## 11. Offene Fragen (⚠️ ABSTIMMEN, vor Umsetzung)

1. **Schwellen-Kalibrierung** gegen Björns reale Daten: `big_day` (20 Tops), `climb_days_year` (50),
   Stunden-Leiter — passt das zum tatsächlichen Volumen? (Backfill-Preview in EP-4 hilft.)
2. **`grade_leap`** (±2 kanonische Stufen): ausreichend selten, oder auf 3 Stufen schärfen?
3. **Sound-Asset:** eigenes kurzes `.caf` erstellen oder Feature vorerst hinter dem (aus-)Toggle
   ohne Asset lassen?
4. **`discipline_trio`:** 3 von 4 Disziplinen ok — oder alle 4 inkl. Autobelay (nicht jede Halle
   hat welche)?
