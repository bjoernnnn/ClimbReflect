import CoreMotion
import Foundation

// Höhenmessung via CMAltimeter.
// totalGain: Netto-Höhe des aktuellen Versuchs (0 außerhalb eines Versuchs).
// Akkumuliert nur wenn startAscentTracking() aktiv ist (B3).

actor AltimeterService {
    private let altimeter = CMAltimeter()
    private(set) var totalGain: Double = 0
    private var running = false

    // Pro Versuch (Netto-Messung: max − base)
    private var ascentBaseAltitude: Double? = nil
    private var ascentMaxAltitude: Double = 0
    private var lastAltitude: Double = 0

    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable(), !running else { return }
        running = true
        let queue = OperationQueue()
        queue.qualityOfService = .utility
        // A7: [weak self] vermeidet Retain-Cycle AltimeterService → CMAltimeter → closure → AltimeterService
        altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let rel = data.relativeAltitude.doubleValue
            Task { [weak self] in await self?.handleAltitude(rel) }
        }
    }

    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
        running = false
        ascentBaseAltitude = nil
        totalGain = 0
    }

    func startAscentTracking() {
        ascentBaseAltitude = lastAltitude
        ascentMaxAltitude = lastAltitude
        totalGain = 0
    }

    /// Gibt Netto-Höhe des Versuchs zurück (max − base), setzt Tracking zurück.
    func stopAscentTracking() -> Double {
        let gain = max(0, ascentMaxAltitude - (ascentBaseAltitude ?? 0))
        ascentBaseAltitude = nil
        totalGain = 0
        return gain
    }

    // B3: Höhe nur während aktivem Versuch akkumulieren.
    // Kein noiseFloor-Filter mehr nötig – Netto (max−base) ist inhärent rauscharm.
    private func handleAltitude(_ rel: Double) {
        defer { lastAltitude = rel }
        guard let base = ascentBaseAltitude else { return }
        if rel > ascentMaxAltitude { ascentMaxAltitude = rel }
        totalGain = max(0, ascentMaxAltitude - base)
    }
}
