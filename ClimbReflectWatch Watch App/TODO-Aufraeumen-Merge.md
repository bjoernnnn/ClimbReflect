# ClimbReflect – Aufräumen, Mergen & Final-Test (A3-Fix produktiv machen)

Ausgangslage: Das Speicherleck ist mit **A3** (Streaming statt `HKLiveWorkoutBuilder`) behoben —
Speicher flach bei 17 MB. `origin/fix/a3-streaming-hr` = `origin/dev` + 2 Commits
(`087aef2` A3-Fix inkl. Variante A / schlankes Workout, `29a1016` Optional-/@Sendable-Fixes).
Live-Anzeige, schlankes Workout und kein Blackscreen sind bestätigt.

Ziel dieser Runde: Diagnose-Instrumentierung entfernen, Projektzuordnung verifizieren/sicherstellen,
A3 nach `dev` und `main` mergen, final testen, Branches aufräumen.

---

## Teil 1 — Diagnose-Instrumentierung entfernen

Auf `fix/a3-streaming-hr` (oder einem Aufräum-Branch davon):

1. **Dateien löschen:**
   - `ClimbReflectWatch Watch App/Services/MemoryProbe.swift`
   - `ClimbReflectWatch Watch App/AppBuildInfo.swift`
   - `ClimbReflectWatch Watch App/Views/DiagnosticView.swift`
2. **`WorkoutManager.swift`:**
   - Die per-Minute-Speicher-Logging-Logik entfernen (`memLogTickCount`-Property + der Block
     „Diagnose: Speicher einmal pro Minute loggen…" ~Z.579).
   - Log-Zeile „mem start used=…" (~Z.228) entfernen.
   - Log-Zeilen „streaming queries started/stopped" (~Z.250/554) entfernen.
3. **`ClimbReflectWatchApp.swift`:** `scenePhase`-Logging entfernen (`.onChange(of: scenePhase)`
   + das `@Environment(\.scenePhase)`, falls nur dafür genutzt).
4. **`SportSelectionView.swift`:** den `NavigationLink(destination: DiagnosticView())` samt
   „Diagnose"-Eintrag (~Z.37–42) entfernen → der Tool-Zugang ist weg.
5. **`DiagnosticLog.swift` (Entscheidung):**
   - **Empfohlen:** Datei + alle `DiagnosticLog.shared.log(...)`-Aufrufe entfernen → komplett
     sauberer Produktionsstand (das ist „das Diagnosetool weg").
   - *Alternative (falls du eine stille Absicherung willst):* `DiagnosticLog` behalten, aber ohne
     sichtbare View — dann nur die obigen temporären Log-Zeilen entfernen. (Nicht nötig, wenn du
     es ganz weg willst.)
6. *Fertig-wenn:* Kein `MemoryProbe`/`AppBuildInfo`/`scenePhase`-Log/Build-Marker mehr; kein
   „Diagnose"-Eintrag in der Sportauswahl; App baut sauber.


## Teil 3 — Mergen

1. Aufräum-Commits auf `fix/a3-streaming-hr`.
2. `fix/a3-streaming-hr` → **`dev`** mergen (A3 ist `dev + 2`, also konfliktfrei).
3. Auf `dev` **final testen** (Teil 4).
4. Nach erfolgreichem Test `dev` → **`main`** mergen.

## Teil 4 — Final-Test (auf `dev`)

- **Langer Lauf (1 h+)** und ein **aktiver Kletter-Lauf**: Speicher muss flach bleiben
  (~20–40 MB), kein Verschwinden.
- Live-HF + Energie korrekt; schlankes Workout erscheint in Apple Health.
- Recovery weiterhin ok (App kommt nach Handgelenk-Heben zurück, kein falscher Banner).
- **Projektzuordnung:** Projekt wählbar, korrekt zugeordnet.
- Beenden: Fragebogen (Zustand/Anstrengung) erscheint zuverlässig, kein Blackscreen.

## Teil 5 — Branches aufräumen

- Löschen: `origin/diagnose/schritt3-a2` (fehlgeschlagenes Experiment),
  `origin/fix/a3-streaming-hr` (nach Merge), ggf. `origin/fix/wkbackgroundmodes` und
  `origin/feature/energy-efficiency` (bereits in `dev` enthalten — vorher prüfen).
- `origin/feature/projects` nur löschen, falls vollständig in `dev` (sonst behalten).

---

## Hinweis
Die Architektur-Erkenntnis ist in `CLAUDE.md` als **S16** festgehalten (kein Live-Builder für lange
Sessions; Streaming-Queries + schlankes Workout). Den Blackscreen-Fix (`TODO-Blackscreen.md`)
brauchst du nur, falls er wieder auftritt — zuletzt war er kein Problem mehr (der
`pendingSummaryDTO`-Ansatz ist in A3 bereits enthalten).
