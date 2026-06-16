# ClimbReflect – Go-Live für den Gym-Test heute Abend

Ziel: Heute Abend im Klettergym eine echte Session auf der Watch aufzeichnen, Versuche
loggen, beenden, auf dem iPhone wiederfinden. Reihenfolge strikt einhalten: **🔴 Blocker
zuerst → �amber Geräteschritte → ✅ Smoke-Test**. Alles unter „Nach dem Test" ist Polish und
**nicht** testkritisch.

---

## 🔴 BLOCKER – vor dem Build zwingend fixen

### B1 – Hintergrund & Always-On für die Watch aktivieren
**Problem:** Ohne diese Keys stoppt die Workout-Aufzeichnung, sobald das Handgelenk sinkt /
der Bildschirm schläft. Aktuell fehlen sie komplett.

**Fix (Watch-App-Target „ClimbReflectWatch Watch App", für Debug *und* Release):**
- Weg A (Xcode, foolproof): Target → *Signing & Capabilities* → **+ Capability →
  Background Modes** → Haken bei **„Workout processing"**.
- Weg B (Build-Setting, da `GENERATE_INFOPLIST_FILE = YES`): im `project.pbxproj` ergänzen:
  - `INFOPLIST_KEY_WKBackgroundModes = "workout-processing"`
  - `INFOPLIST_KEY_WKSupportsAlwaysOnDisplay = YES`

**Fertig wenn:** Während eines laufenden Workouts bleibt der Screen im (gedimmten)
Always-On, und die Zeit/HF läuft weiter, wenn der Arm unten ist.

### B2 – Falsches HealthKit-Entitlement entfernen
**Problem:** Beide `.entitlements` enthalten `com.apple.developer.healthkit.access`
(`health-records` = Clinical Health Records, braucht Apple-Sondergenehmigung) → Signieren/
Installieren auf echtem Gerät kann fehlschlagen.

**Fix:** In **beiden** Dateien
(`ClimbReflectWatch Watch App/ClimbReflectWatch Watch App.entitlements` und
`ClimbReflect/ClimbReflect/ClimbReflect/ClimbReflect.entitlements`) den Inhalt reduzieren auf:
```xml
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
</dict>
</plist>
```
(`...healthkit.access`/`health-records` und `...background-delivery` raus – beides wird nicht
gebraucht.)

**Fertig wenn:** App lässt sich ohne Provisioning-Fehler auf Watch + iPhone installieren.

---

## 🟠 Manuelle Schritte in Xcode / auf den Geräten

> Diese Schritte kann nur der Mensch am Mac/Gerät machen.

- [ ] **Signing:** Beide Targets (iOS + Watch) auf dein Apple-Developer-Team setzen,
      *Automatically manage signing* an. Eindeutige Bundle-IDs prüfen
      (`de.dreselbjoern.ClimbReflect` + Watch-Suffix).
- [ ] **App-Icon einsetzen:** Die mitgelieferte `ClimbReflect-AppIcon-1024.png` in den
      AppIcon-Slot **beider** Targets ziehen (Xcode generiert die übrigen Größen). Details
      siehe „Icon" unten.
- [ ] **Auf die Watch bauen:** Watch per Bluetooth gekoppelt, Watch-Target wählen, auf die
      echte Apple Watch installieren (Simulator hat kein echtes HealthKit/Barometer).
- [ ] **Aufs iPhone bauen:** iOS-Target aufs iPhone installieren.
- [ ] **Berechtigungen erteilen:** Beim ersten Start auf der Watch HealthKit (HF/Energie +
      Workouts schreiben) **und** Bewegung & Fitness erlauben; auf dem iPhone HealthKit-
      Lesen erlauben.
- [ ] **Akku:** Watch geladen (Workout + Barometer + Motion zieht spürbar).

---

## ✅ Smoke-Test (5 Min, vor dem Gym zu Hause)

- [ ] Watch-App öffnen → **Bouldern** wählen → Training startet, Zeit + HF laufen.
- [ ] Arm senken / Handgelenk drehen → Screen geht in Always-On, **Zeit läuft weiter**
      (validiert B1).
- [ ] **Action Button** drücken → „Versuch gestartet" (Haptik) → nochmal drücken →
      Ergebnis-Abfrage → **Top** mit Grad wählen → Versuch erscheint, Zähler steigt.
- [ ] Einen Versuch über **„+ Versuch"** manuell anlegen (Fallback-Pfad).
- [ ] **iPhone** öffnen → Dashboard zeigt das **„Training läuft"-Banner** (validiert E1/E2).
- [ ] Auf der Watch **Beenden** → kurz warten → Session erscheint auf dem **iPhone** mit den
      Versuchen/Grade (validiert Sync).
- [ ] In der **Health-App** nachsehen: ein Workout ist eingetragen, Ringe haben sich bewegt.

Wenn alle Häkchen sitzen → gym-ready.

---

## 🧗 Im Gym worauf achten (kurzes Testprotokoll)

- Läuft die Aufzeichnung über die ganze Session, auch in Pausen? (Hintergrund)
- Action-Button-Flow flüssig mit chalkigen Händen ohne Hinschauen?
- Auto-Erkennung beim Seil (Höhenmeter) plausibel? Boulder grob? Falsch-Positive verwerfbar?
- Nach dem Beenden: Versuche/Grade vollständig auf dem iPhone?
- Notiere, was nervt – daraus wird die nächste TODO-Runde.

---

## 🟡 NACH dem Test – Polish (nicht testkritisch)

- [ ] **AntiStyle „100%" Überlauf fixen.** `Views/Components/AntistyleRadarView.swift`:
      Prozent-Label von `.annotation(position: .trailing)` auf `.annotation(position: .overlay,
      alignment: .trailing)` mit `.padding(.trailing, 4)` + kontrastreicher Farbe; alternativ
      `.chartXScale(domain: 0...1.15)`.
- [ ] **Ascents als eigene Seite (Wetter-App-Gefühl).** `Views/SessionDetailView.swift`:
      `.scrollTargetBehavior(.viewAligned)` → **`.paging`**; Übersicht **und** Begehungen je
      auf volle Viewport-Höhe (Safe-Area/Navbar abziehen, sonst lugen Begehungen unten
      hervor); dezenter Chevron-Hinweis „nach unten" am Ende der Übersicht.
- [ ] **Zeiträume für Grafiken.** Auswählbarer Zeitraum (z. B. *4 Wochen / 3 Monate /
      Gesamt*) für Antistyle, Limiter, RPE-Trend, Pyramide – als kleiner Segment-Picker pro
      Chart; Default „4 Wochen".
- [ ] **Erfolge stärker hervorheben.** Höchstgrad als **Hero-Trophäe** oben am Dashboard
      (groß, immer sichtbar, motivierend). `Views/DashboardView.swift` + `Models/Achievement.swift`.
- [ ] **App-Erfolge archivieren.** Freigeschaltete App-Erfolge nach dem Ansehen in ein
      „Archiv" verschieben; am Dashboard nur die **in Arbeit** zeigen (mehr Fokus/Motivation).
- [ ] **Training-Activity-Type.** Trainingssessions als `.functionalStrengthTraining` statt
      `.climbing` in HealthKit speichern (Ringe schließen weiterhin, aber korrekt einsortiert).
      `Services/WorkoutManager.swift` → `config.activityType` abhängig von `sessionType`.
- [ ] **(Optional) Freund-Skala.** Globale *Anzeige*-Skala, die nur fürs Rendern umrechnet
      (Speicherung bleibt im Original) + Fb↔V↔French-Umrechnungstabelle für eine
      zusammengeführte Pyramide.

---

## Icon

`ClimbReflect-AppIcon-1024.png` ist ein **vorläufiges** Icon, aus deinem Entwurf
freigestellt (1024×1024, opak, quadratisch – iOS/watchOS maskieren Ecken/Kreis automatisch).
Für beide Targets verwendbar. Für die finale Qualität später ein **flaches, quadratisches
1024er-Master ohne abgerundete Ecken** exportieren (aus dem ChatGPT-Entwurf) und ersetzen –
dann gibt es keine doppelte Rundung.
