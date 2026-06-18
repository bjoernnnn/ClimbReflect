# ClimbReflect – Fehlersuche Schritt 1: Speicher- & scenePhase-Logging

Branch: `dev`. **Reine Diagnose-Instrumentierung**, kein Verhaltensfix. Ziel: ohne JetsamEvent-
Datei feststellen, ob der Speicher während der Session Richtung 300-MB-Limit wächst, und ob die
App kurz vor dem Kill in den Hintergrund geht.

---

## Aufgabe 1 — Speicher-Messhelfer anlegen

- *Datei:* neu `ClimbReflectWatch Watch App/Services/MemoryProbe.swift`
- *Code:*
  ```swift
  import Foundation

  enum MemoryProbe {
      /// Aktueller phys_footprint (die Größe, auf die das Jetsam-Limit wirkt) in MB.
      static func footprintMB() -> Double {
          var info = task_vm_info_data_t()
          var count = mach_msg_type_number_t(
              MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
          let kr = withUnsafeMutablePointer(to: &info) { ptr in
              ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                  task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
              }
          }
          guard kr == KERN_SUCCESS else { return -1 }
          return Double(info.phys_footprint) / 1_048_576.0
      }

      /// Verfügbarer Speicher bis zum Prozess-Limit in MB (kleiner = näher am Kill).
      static func availableMB() -> Double {
          return Double(os_proc_available_memory()) / 1_048_576.0
      }
  }
  ```
- *Hinweis:* `footprintMB()` ist der zuverlässige Hauptwert (reines Mach-API). Falls
  `os_proc_available_memory()` wider Erwarten nicht kompiliert, `availableMB()` weglassen –
  `footprintMB()` allein genügt für die Diagnose.
- *Fertig-wenn:* Datei kompiliert, beide Werte liefern plausible MB-Zahlen.

## Aufgabe 2 — Pro Minute Speicher loggen (am bestehenden 2-s-Timer)

- *Datei:* `ClimbReflectWatch Watch App/Services/WorkoutManager.swift`
- *Aufgabe:*
  1. Property ergänzen: `private var memLogTickCount = 0`.
  2. Im Task des bestehenden 2-s-Timers (in `startTimer()`) ergänzen:
     ```swift
     self.memLogTickCount += 1
     if self.memLogTickCount >= 30 {           // 30 × 2 s = 60 s
         self.memLogTickCount = 0
         let used = MemoryProbe.footprintMB()
         let avail = MemoryProbe.availableMB()
         let mins = Int(self.currentElapsed()) / 60
         DiagnosticLog.shared.log(
             String(format: "mem used=%.0fMB avail=%.0fMB t=%dmin", used, avail, mins))
     }
     ```
  3. Direkt beim Start (in `startWorkout`, nach `DiagnosticLog.shared.log("start …")`) **einmal**
     den Ausgangswert loggen:
     `DiagnosticLog.shared.log(String(format: "mem start used=%.0fMB avail=%.0fMB", MemoryProbe.footprintMB(), MemoryProbe.availableMB()))`.
- *Wichtig:* Der 2-s-Timer feuert auch im Hintergrund (aktive Workout-Session) → das Logging
  läuft auch bei abgesenktem Handgelenk weiter.
- *Fertig-wenn:* Im Diagnose-Log erscheint etwa jede Minute eine Zeile `mem used=… avail=… t=…min`.

## Aufgabe 3 — Letzten Messwert sofort persistieren (nichts vor dem Kill verlieren)

- *Datei:* `ClimbReflectWatch Watch App/Services/DiagnosticLog.swift`
- *Kontext:* A6 hat das Schreiben auf Disk gedrosselt (alle 10 s). Damit der **letzte**
  Speicherwert vor einem Kill nicht verloren geht, soll eine `mem …`-Zeile sofort geschrieben
  werden.
- *Aufgabe:* Entweder `DiagnosticLog.shared.log(_:flushImmediately: Bool = false)` ergänzen und
  bei den `mem …`-Aufrufen `flushImmediately: true` übergeben, **oder** eine `flush()`-Methode
  bereitstellen und nach jedem `mem …`-Log aufrufen. Intern: sofort `persist()` ausführen.
- *Fertig-wenn:* Nach einem Kill steht im persistierten Log noch der letzte `mem …`-Eintrag
  (innerhalb 1 Min vor dem Kill).

## Aufgabe 4 — scenePhase-Wechsel loggen (Hintergrund/Vordergrund)

- *Datei:* `ClimbReflectWatch Watch App/ClimbReflectWatchApp.swift`
- *Aufgabe:*
  1. `@Environment(\.scenePhase) private var scenePhase` ergänzen.
  2. Am Wurzel-View im `WindowGroup`:
     ```swift
     .onChange(of: scenePhase) { _, newPhase in
         DiagnosticLog.shared.log("scenePhase=\(newPhase)")
     }
     ```
     (Falls Deployment < watchOS 10: einparametrige `onChange`-Variante nutzen.)
- *Fertig-wenn:* Beim Wechsel active/inactive/background erscheint eine `scenePhase=…`-Zeile.

---

## Auswertung nach dem Testlauf

Eine Session bis zum Fehler laufen lassen, dann das Diagnose-Log durchsehen:

- **`used` steigt kontinuierlich Richtung ~300 MB** (und `avail` fällt Richtung 0), dann Kill
  → **Speicher ist die Ursache** → weiter mit Fehlersuche **Schritt 3** (HealthKit-Collection
  isolieren).
- **`used` bleibt grob stabil** (z. B. 40–90 MB) und die App stirbt trotzdem → **kein Speicher**
  → weiter mit **Schritt 4** (Watchdog/Hintergrund).
- **`scenePhase` kurz vor dem Kill:** Ging die App nach `background` (Display aus) und wurde dann
  beendet? Oder starb sie im Vordergrund (`active`)? Das unterscheidet Hintergrund-Beendigung von
  einem Vordergrund-Problem.
- Den **Zeitpunkt** des letzten `mem …`-Eintrags mit der bisherigen „mal 25, mal 50 Min"-
  Beobachtung abgleichen (steigt der Speicher in „guten" Läufen langsamer?).

**Bitte nach dem Lauf das Diagnose-Log (oder Fotos davon) schicken** – dann tragen wir das
Ergebnis in `FEHLERSUCHE.md` ein und entscheiden über Schritt 3 vs. Schritt 4.
