import Foundation
import Combine
import HealthKit
import WatchKit

// W1.1: HKWorkoutSession + HKLiveWorkoutBuilder für .climbing auf Apple Watch

@MainActor
final class WorkoutManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var sessionType: WatchSessionType = .boulder
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var elapsedSeconds: Int = 0
    @Published var heartRate: Double = 0
    @Published var maxHeartRate: Double = 0
    @Published var activeEnergyKcal: Double = 0
    @Published var attempts: [WatchAttempt] = []
    @Published var suggestAttempt = false          // W4: Detektions-Vorschlag
    @Published var pendingClassifications: Int = 0 // Wie viele auto-erkannte Versuche noch offen

    // MARK: - Private

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var workoutStartDate: Date?

    let altimeter = AltimeterService()
    private let detector = AttemptDetector()

    // MARK: - HealthKit Auth (W1.3)

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        try? await store.requestAuthorization(toShare: share, read: read)
    }

    // MARK: - Session Start (W1.2)

    func startWorkout(type: WatchSessionType) async {
        sessionType = type

        let config = HKWorkoutConfiguration()
        config.activityType = .climbing
        config.locationType = .indoor

        do {
            let ws = try HKWorkoutSession(healthStore: store, configuration: config)
            let wb = ws.associatedWorkoutBuilder()
            wb.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

            ws.delegate = self
            wb.delegate = self

            self.session = ws
            self.builder = wb

            let startDate = Date()
            workoutStartDate = startDate
            ws.startActivity(with: startDate)
            try await wb.beginCollection(at: startDate)
            // UUID kommt erst nach finishWorkout() — wird in endWorkout() gesetzt

            isRunning = true
            isPaused = false
            startTimer()

            await altimeter.start()
            detector.onSuggestion = { [weak self] in
                Task { @MainActor in
                    self?.suggestAttempt = true
                    self?.pendingClassifications += 1
                }
            }
            if type.usesBarometer {
                // Seil: AltimeterService-Feedback an AttemptDetector
                // (Polling via timer, da AltimeterService ein Actor ist)
            } else {
                detector.startMotionDetection(currentHR: heartRate)
            }
        } catch {
            print("[WorkoutManager] startWorkout error: \(error)")
        }
    }

    // MARK: - Pause / Resume (W6.1)

    func pauseWorkout() {
        session?.pause()
        isPaused = true
        timer?.invalidate()
    }

    func resumeWorkout() {
        session?.resume()
        isPaused = false
        startTimer()
    }

    // MARK: - Versuch löschen

    func removeAttempt(id: UUID) {
        attempts.removeAll { $0.id == id }
    }

    // MARK: - Fehlhafte Erkennung verwerfen

    func dismissSuggestion() {
        if pendingClassifications > 0 { pendingClassifications -= 1 }
        suggestAttempt = pendingClassifications > 0
    }

    // MARK: - Versuch banken (W3.2)

    func bankAttempt(gradeSystem: WatchGradeSystem,
                     grade: String?,
                     result: WatchAscentResult?,
                     style: WatchAscentStyle?) async {
        let gain = await altimeter.stopAscentTracking()
        let attempt = WatchAttempt(
            gradeSystem: gradeSystem,
            grade: grade,
            result: result,
            style: style,
            altitudeGain: gain,
            heartRateAtBanking: heartRate > 0 ? heartRate : nil,
            sessionType: sessionType
        )
        attempts.append(attempt)
        await altimeter.startAscentTracking()
        if pendingClassifications > 0 { pendingClassifications -= 1 }
        suggestAttempt = pendingClassifications > 0
        // W8.2: Unterscheidbare Haptik pro Ergebnis
        switch result {
        case .top:     WKInterfaceDevice.current().play(.success)   // langer Puls = Top
        case .attempt: WKInterfaceDevice.current().play(.click)     // kurzer Klick = Versuch
        case .quit:    WKInterfaceDevice.current().play(.failure)   // Puls = Aufgegeben
        case nil:      WKInterfaceDevice.current().play(.click)
        }
    }

    // MARK: - Session beenden (W7)

    func endWorkout() async -> WatchSessionDTO? {
        guard let ws = session, let wb = builder else { return nil }
        detector.stopMotionDetection()
        await altimeter.stop()
        timer?.invalidate()

        let endDate = Date()
        ws.end()
        try? await wb.endCollection(at: endDate)
        // UUID aus dem fertigen HKWorkout auslesen (einziger zuverlässiger Weg auf watchOS)
        let finishedWorkout = try? await wb.finishWorkout()
        let resolvedUUID = finishedWorkout?.uuid

        let duration = workoutStartDate.map { endDate.timeIntervalSince($0) } ?? 0
        let altTotal = await altimeter.totalGain

        let dto = WatchSessionDTO(
            id: UUID(),
            workoutUUID: resolvedUUID,
            date: workoutStartDate ?? endDate,
            durationSeconds: duration,
            sessionTypeRaw: sessionType.rawValue,
            avgHeartRate: heartRate > 0 ? heartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            activeEnergyKcal: activeEnergyKcal > 0 ? activeEnergyKcal : nil,
            altitudeTotalGain: altTotal,
            ascents: attempts.map { $0.toDTO() },
            rpe: nil, focusRaw: nil, energyRaw: nil
        )

        // Reset
        isRunning = false
        isPaused = false
        session = nil
        builder = nil
        attempts = []
        elapsedSeconds = 0
        heartRate = 0
        maxHeartRate = 0
        activeEnergyKcal = 0

        // W8.2: Training-beendet-Haptik
        WKInterfaceDevice.current().play(.stop)

        return dto
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds += 1
                // Barometer-Poll für Seil-Detektion
                if self.sessionType.usesBarometer {
                    let alt = await self.altimeter.totalGain
                    self.detector.updateAltitude(alt)
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        print("[WorkoutManager] session error: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let stats = workoutBuilder.statistics(for: quantityType)

            Task { @MainActor [weak self] in
                guard let self else { return }
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate)!:
                    let bpm = stats?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                    self.heartRate = bpm
                    if bpm > self.maxHeartRate { self.maxHeartRate = bpm }
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!:
                    self.activeEnergyKcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                default: break
                }
            }
        }
    }
}
