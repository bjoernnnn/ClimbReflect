import Foundation
import Combine
import HealthKit
import WatchKit
import WatchConnectivity

// W1.1: HKWorkoutSession + HKLiveWorkoutBuilder für .climbing auf Apple Watch

// D1: State-Machine für den Action Button
enum AttemptState: Equatable {
    case idle
    case active(startTime: Date)
    case awaitingResult
}

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
    @Published var suggestAttempt = false
    @Published var pendingClassifications: Int = 0
    @Published var attemptState: AttemptState = .idle  // D1
    @Published var trainingTarget: WatchTrainingTarget? = nil  // C5

    var isTraining: Bool { sessionType == .training }

    // MARK: - Private

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var workoutStartDate: Date?
    private var liveStatusTickCount = 0

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

    func startWorkout(type: WatchSessionType, target: WatchTrainingTarget? = nil) async {
        sessionType = type
        trainingTarget = target
        attemptState = .idle

        // Timer und UI-State sofort starten – unabhängig von HealthKit.
        // HealthKit kann beim ersten Start Permission-Dialog zeigen oder fehlschlagen;
        // der Timer läuft dadurch auch ohne HK-Session korrekt.
        let startDate = Date()
        workoutStartDate = startDate
        isRunning = true
        isPaused = false
        startTimer()

        // HealthKit-Session aufsetzen (best-effort)
        let config = HKWorkoutConfiguration()
        config.activityType = type == .training ? .functionalStrengthTraining : .climbing
        config.locationType = .indoor

        do {
            let ws = try HKWorkoutSession(healthStore: store, configuration: config)
            let wb = ws.associatedWorkoutBuilder()
            wb.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            ws.delegate = self
            wb.delegate = self
            self.session = ws
            self.builder = wb
            ws.startActivity(with: startDate)
            try await wb.beginCollection(at: startDate)
        } catch {
            // HK-Fehler: Timer läuft weiter, DTO wird aus lokalen Daten erstellt
            print("[WorkoutManager] HealthKit-Setup fehlgeschlagen: \(error)")
        }

        await altimeter.start()

        // C5: Im Trainingsmodus kein Auto-Detektor
        if !isTraining {
            detector.onSuggestion = { [weak self] in
                Task { @MainActor in
                    self?.suggestAttempt = true
                    self?.pendingClassifications += 1
                }
            }
            if type.usesBarometer {
                // Seil: AltimeterService-Feedback an AttemptDetector via Barometer-Poll
            } else {
                detector.startMotionDetection(currentHR: heartRate)
            }
        }
    }

    // MARK: - D1: Action Button State Machine

    func handleActionButton() {
        if isTraining {
            // Im Training: Pause/Resume
            if isPaused { resumeWorkout() } else { pauseWorkout() }
            return
        }
        switch attemptState {
        case .idle:
            // Versuch starten
            attemptState = .active(startTime: .now)
            WKInterfaceDevice.current().play(.start)
            Task { await altimeter.startAscentTracking() }

        case .active:
            // Versuch beenden → Ergebnis abfragen
            attemptState = .awaitingResult
            WKInterfaceDevice.current().play(.click)

        case .awaitingResult:
            break
        }
    }

    /// Schnelles Banken aus dem Action-Button-Flow (ohne Grad-Auswahl)
    func quickBank(result: WatchAscentResult) async {
        let gain = await altimeter.stopAscentTracking()
        let attempt = WatchAttempt(
            gradeSystem: WatchGradeSystem(rawValue: UserDefaults.standard.string(forKey: "watchGradeSystem") ?? "fontainebleau") ?? sessionType.defaultGradeSystem,
            grade: nil,
            result: result,
            style: result == .top ? nil : nil,
            altitudeGain: gain,
            heartRateAtBanking: heartRate > 0 ? heartRate : nil,
            sessionType: sessionType
        )
        attempts.append(attempt)
        attemptState = .idle
        await altimeter.startAscentTracking()
        switch result {
        case .top:     WKInterfaceDevice.current().play(.success)
        case .attempt: WKInterfaceDevice.current().play(.click)
        case .quit:    WKInterfaceDevice.current().play(.failure)
        }
    }

    // MARK: - Pause / Resume (W6.1)

    func pauseWorkout() {
        session?.pause()
        isPaused = true
        timer?.invalidate()
        broadcastLiveStatus()
    }

    func resumeWorkout() {
        session?.resume()
        isPaused = false
        startTimer()
        broadcastLiveStatus()
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
        // Falls aus Action-Button-Flow → State zurücksetzen
        if attemptState == .awaitingResult { attemptState = .idle }
        switch result {
        case .top:     WKInterfaceDevice.current().play(.success)
        case .attempt: WKInterfaceDevice.current().play(.click)
        case .quit:    WKInterfaceDevice.current().play(.failure)
        case nil:      WKInterfaceDevice.current().play(.click)
        }
    }

    // MARK: - Session beenden (W7)

    func endWorkout() async -> WatchSessionDTO? {
        detector.stopMotionDetection()
        await altimeter.stop()
        timer?.invalidate()
        timer = nil

        let endDate = Date()

        // HK-Session beenden (best-effort – kann nil sein wenn HK-Setup fehlschlug)
        var resolvedUUID: UUID? = nil
        if let ws = session, let wb = builder {
            ws.end()
            try? await wb.endCollection(at: endDate)
            let finishedWorkout = try? await wb.finishWorkout()
            resolvedUUID = finishedWorkout?.uuid
        }

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
            rpe: nil,
            focusRaw: trainingTarget?.rawValue,
            energyRaw: nil
        )

        clearLiveStatus()
        WKInterfaceDevice.current().play(.stop)

        return dto
    }

    /// Reset erst NACH Fragebogen + Zusammenfassung aufrufen,
    /// damit LiveSessionView nicht vorzeitig abgebaut wird.
    func finishSession() {
        isRunning = false
        isPaused = false
        session = nil
        builder = nil
        attempts = []
        elapsedSeconds = 0
        heartRate = 0
        maxHeartRate = 0
        activeEnergyKcal = 0
        attemptState = .idle
        trainingTarget = nil
    }

    // MARK: - E1: Live-Status an iPhone senden

    private func broadcastLiveStatus() {
        guard WCSession.default.activationState == .activated else { return }
        let status = WatchLiveStatus(
            elapsedSeconds: elapsedSeconds,
            sessionTypeRaw: sessionType.rawValue,
            attemptCount: attempts.count,
            isPaused: isPaused
        )
        guard let data = try? JSONEncoder().encode(status) else { return }
        try? WCSession.default.updateApplicationContext([WatchLiveStatus.key: data])
    }

    private func clearLiveStatus() {
        guard WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([WatchLiveStatus.key: Data()])
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        // RunLoop.main + .common: Timer feuert auch während UI-Scrolling/Interaktion.
        // Timer.scheduledTimer würde im async-Kontext ggf. auf falschem RunLoop landen.
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.sessionType.usesBarometer {
                    let alt = await self.altimeter.totalGain
                    self.detector.updateAltitude(alt)
                }
                // E1: Live-Status alle 5 Sekunden senden
                self.liveStatusTickCount += 1
                if self.liveStatusTickCount >= 5 {
                    self.liveStatusTickCount = 0
                    self.broadcastLiveStatus()
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
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
