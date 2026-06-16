import CoreMotion
import Foundation

// Kumuliert relative Höhenmeter via CMAltimeter (W1.2)
// Netto-Aufstieg pro Versuch ist über start/stopCurrentAscent() messbar.

actor AltimeterService {
    private let altimeter = CMAltimeter()
    private(set) var totalGain: Double = 0

    // Pro Versuch
    private var ascentBaseAltitude: Double? = nil
    private var lastAltitude: Double = 0
    private(set) var currentAscentGain: Double = 0

    // W8.4: Barometer-Updates auf Queue mit niedrigerer Priorität → weniger CPU/Akku
    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        let queue = OperationQueue()
        queue.qualityOfService = .utility   // nicht Main-Thread, spart Energie
        altimeter.startRelativeAltitudeUpdates(to: queue) { [self] data, _ in
            guard let data else { return }
            let rel = data.relativeAltitude.doubleValue
            // Actor-Methode von außen: Task mit explizitem self-Hop
            Task { [self] in self.handleAltitude(rel) }
        }
    }

    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
    }

    func startAscentTracking() {
        ascentBaseAltitude = lastAltitude
        currentAscentGain = 0
    }

    func stopAscentTracking() -> Double {
        let gain = max(0, currentAscentGain)
        totalGain += gain
        ascentBaseAltitude = nil
        return gain
    }

    private func handleAltitude(_ rel: Double) {
        let delta = rel - lastAltitude
        if delta > 0 {
            if ascentBaseAltitude != nil {
                currentAscentGain += delta
            }
        }
        lastAltitude = rel
    }
}
