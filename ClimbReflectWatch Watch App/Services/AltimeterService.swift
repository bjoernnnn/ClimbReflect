import CoreMotion
import Foundation

// Kumuliert relative Höhenmeter via CMAltimeter (W1.2)
// Pro Versuch: Netto-Aufstieg = Maximalhöhe − Basishöhe (robuster als Summe positiver Deltas).

actor AltimeterService {
    private let altimeter = CMAltimeter()
    private(set) var totalGain: Double = 0

    // Pro Versuch
    private var ascentBaseAltitude: Double? = nil
    private var ascentMaxAltitude: Double = 0
    private var lastAltitude: Double = 0

    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
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
    }

    func startAscentTracking() {
        ascentBaseAltitude = lastAltitude
        ascentMaxAltitude = lastAltitude
    }

    func stopAscentTracking() -> Double {
        guard let base = ascentBaseAltitude else { return 0 }
        let gain = max(0, ascentMaxAltitude - base)
        totalGain += gain
        ascentBaseAltitude = nil
        return gain
    }

    private func handleAltitude(_ rel: Double) {
        if ascentBaseAltitude != nil {
            if rel > ascentMaxAltitude { ascentMaxAltitude = rel }
        }
        lastAltitude = rel
    }
}
