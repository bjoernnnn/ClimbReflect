import CoreMotion
import Foundation

// Kumuliert relative Höhenmeter via CMAltimeter (W1.2)
// totalGain: laufend (positive Deltas immer, unabhängig von Versuchs-Klammer)
// stopAscentTracking: gibt Netto-Höhe pro Versuch zurück (max − base)

actor AltimeterService {
    private let altimeter = CMAltimeter()
    private(set) var totalGain: Double = 0
    private var running = false

    // Pro Versuch (Netto-Messung)
    private var ascentBaseAltitude: Double? = nil
    private var ascentMaxAltitude: Double = 0
    private var lastAltitude: Double = 0

    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable(), !running else { return }
        running = true
        let queue = OperationQueue()
        queue.qualityOfService = .utility
        altimeter.startRelativeAltitudeUpdates(to: queue) { [self] data, _ in
            guard let data else { return }
            let rel = data.relativeAltitude.doubleValue
            Task { [self] in self.handleAltitude(rel) }
        }
    }

    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
        running = false
    }

    func startAscentTracking() {
        ascentBaseAltitude = lastAltitude
        ascentMaxAltitude = lastAltitude
    }

    /// Gibt Netto-Höhe des Versuchs zurück (max − base).
    /// totalGain wird hier NICHT verändert (läuft bereits live via handleAltitude).
    func stopAscentTracking() -> Double {
        guard let base = ascentBaseAltitude else { return 0 }
        let gain = max(0, ascentMaxAltitude - base)
        ascentBaseAltitude = nil
        return gain
    }

    // Signifikantes Höhendelta; darunter = Sensorrauschen / Druckdrift
    private let noiseFloor = 0.3

    private func handleAltitude(_ rel: Double) {
        let delta = rel - lastAltitude
        if delta > noiseFloor { totalGain += delta }
        if ascentBaseAltitude != nil, rel > ascentMaxAltitude {
            ascentMaxAltitude = rel
        }
        lastAltitude = rel
    }
}
