import CoreMotion
import Foundation

// W4: Heuristische Versuchserkennung (Vorschlag, nie stiller Auto-Log)
// - Seil (W4.1): Netto-Höhengewinn ≥ barometer threshold → Versuch vorschlagen
// - Boulder (W4.2): Bewegungsburst + erhöhte HF → Versuch vorschlagen

final class AttemptDetector {
    var onSuggestion: (() -> Void)?

    private let motion = CMMotionManager()
    private var ropeThreshold: Double = 1.5  // Meter Netto-Aufstieg
    private var lastRelativeAltitude: Double = 0
    private var ascentStartAlt: Double? = nil
    private var burstWindow: [Double] = []

    // MARK: - Seil (W4.1) — wird von AltimeterService-Daten getriggert

    func updateAltitude(_ relative: Double) {
        let delta = relative - lastRelativeAltitude
        lastRelativeAltitude = relative

        if delta > 0.1 {
            if ascentStartAlt == nil { ascentStartAlt = relative - delta }
            let gain = relative - (ascentStartAlt ?? relative)
            if gain >= ropeThreshold {
                ascentStartAlt = nil
                onSuggestion?()
            }
        } else if delta < -0.5 {
            // Abstieg reset
            ascentStartAlt = nil
        }
    }

    // MARK: - Boulder (W4.2) — Bewegungsburst

    // P1-4: currentHR als Property statt eingefangener Parameter → wird vom Timer-Tick
    // laufend aktualisiert und spiegelt immer die echte aktuelle HF wider.
    var currentHR: Double = 0

    func startMotionDetection() {
        guard motion.isAccelerometerAvailable else { return }
        // W8.4: 0.2 s statt 0.1 s → 50% weniger Samples, ausreichend für Burst-Erkennung
        motion.accelerometerUpdateInterval = 0.2
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let mag = sqrt(pow(data.acceleration.x, 2) +
                           pow(data.acceleration.y, 2) +
                           pow(data.acceleration.z, 2))
            self.burstWindow.append(mag)
            if self.burstWindow.count > 30 { self.burstWindow.removeFirst() }

            let avg = self.burstWindow.reduce(0, +) / Double(self.burstWindow.count)
            // Burst: hohe Bewegung + erhöhte HF (laufend aktualisiert via currentHR)
            if avg > 2.5 && self.currentHR > 100 && self.burstWindow.count >= 20 {
                self.burstWindow.removeAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.onSuggestion?()
                }
            }
        }
    }

    func stopMotionDetection() {
        motion.stopAccelerometerUpdates()
        burstWindow.removeAll()
    }
}
