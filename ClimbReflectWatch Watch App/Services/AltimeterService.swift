import CoreMotion
import Foundation

// Höhenmessung via CMAltimeter.
// LEAK-FIX: Die Relative-Altitude-Subscription läuft NUR während eines aktiven Versuchs
// (startAscentTracking … stopAscentTracking) – nicht über die ganze Session. Damit kann
// CoreMotion keine Daten über Minuten/Stunden akkumulieren.
// totalGain: Netto-Höhe des aktuellen Versuchs (0 außerhalb eines Versuchs).

actor AltimeterService {
    private let altimeter = CMAltimeter()
    private(set) var totalGain: Double = 0
    private var tracking = false
    private var ascentMaxAltitude: Double = 0

    /// No-op: Subscription wird erst in startAscentTracking() gestartet.
    /// (Aufrufe in startWorkout()/reattach() bleiben unschädlich.)
    func start() {}

    /// Hartstopp bei Session-Ende: sicherstellen, dass keine Updates mehr laufen.
    func stop() {
        if tracking { altimeter.stopRelativeAltitudeUpdates() }
        tracking = false
        totalGain = 0
        ascentMaxAltitude = 0
    }

    /// Beginnt einen Versuch: startet Höhen-Updates und misst die Netto-Höhe.
    func startAscentTracking() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        ascentMaxAltitude = 0
        totalGain = 0
        guard !tracking else { return }      // doppelten Start vermeiden
        tracking = true
        let queue = OperationQueue()
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let rel = data.relativeAltitude.doubleValue
            Task { [weak self] in await self?.handleAltitude(rel) }
        }
    }

    /// Beendet den Versuch, stoppt Höhen-Updates, gibt Netto-Höhe (max − 0) zurück.
    func stopAscentTracking() -> Double {
        let gain = max(0, ascentMaxAltitude)   // base = 0, da relativeAltitude bei Start = 0
        if tracking { altimeter.stopRelativeAltitudeUpdates() }
        tracking = false
        totalGain = 0
        ascentMaxAltitude = 0
        return gain
    }

    private func handleAltitude(_ rel: Double) {
        guard tracking else { return }
        if rel > ascentMaxAltitude { ascentMaxAltitude = rel }
        totalGain = ascentMaxAltitude
    }
}
