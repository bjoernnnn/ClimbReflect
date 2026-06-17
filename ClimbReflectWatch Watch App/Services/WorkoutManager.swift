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
    @Published var totalAltitudeGain: Double = 0
    @Published var sessionEndedUnexpectedly = false
    @Published var lastError: String?
    @Published var selectedProject: ProjectInfo? = nil {  // P5.7 / P2-8
        didSet { persistSelectedProject() }
    }

    var isTraining: Bool { sessionType == .training }

    // MARK: - Private

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private(set) var workoutStartDate: Date?
    private var accumulatedPaused: TimeInterval = 0
    private var pauseStartedAt: Date?
    private var liveStatusTickCount = 0

    let altimeter = AltimeterService()
    private let detector = AttemptDetector()

    // P0-1: Manueller HR-Mittelwert-Akkumulator (Fallback wenn HK-Builder fehlt)
    private var hrSum: Double = 0
    private var hrCount: Int = 0

    // P2-8: selectedProject über App-Neustart erhalten
    private static let selectedProjectIDKey  = "selectedProjectID"
    private static let selectedProjectNameKey = "selectedProjectName"

    // MARK: - P0-2: Crash-sichere Persistierung

    private func savePendingSnapshot() {
        guard let startDate = workoutStartDate else { return }
        let snapshot = PendingSession(
            id: UUID(),
            startDate: startDate,
            sessionTypeRaw: sessionType.rawValue,
            projectID: selectedProject?.id,
            projectName: selectedProject?.name,
            ascents: attempts.map { $0.toDTO() },
            accumulatedPaused: accumulatedPaused
        )
        PendingSessionStore.save(snapshot)
    }

    /// Einheitlicher Einstieg beim App-Start (nach requestAuthorization).
    /// Versucht zuerst eine noch aktive HK-Session wiederherzustellen;
    /// fällt andernfalls auf den Snapshot-Rettungs-Pfad zurück.
    func recoverIfNeeded() async {
        if HKHealthStore.isHealthDataAvailable(),
           let recovered = try? await store.recoverActiveWorkoutSession() {
            await reattach(to: recovered)
            return
        }
        recoverPendingSessionIfNeeded()
    }

    private func reattach(to ws: HKWorkoutSession) async {
        let wb = ws.associatedWorkoutBuilder()
        wb.dataSource = HKLiveWorkoutDataSource(healthStore: store,
                                                workoutConfiguration: ws.workoutConfiguration)
        ws.delegate = self
        wb.delegate = self
        self.session = ws
        self.builder = wb

        // Live-State aus Snapshot wiederherstellen
        if let p = PendingSessionStore.load() {
            self.sessionType       = WatchSessionType(rawValue: p.sessionTypeRaw) ?? .boulder
            self.workoutStartDate  = p.startDate
            self.accumulatedPaused = p.accumulatedPaused
            if let id = p.projectID, let name = p.projectName {
                self.selectedProject = ProjectInfo(id: id, name: name)
            }
            self.attempts = p.ascents.map { WatchAttempt(fromDTO: $0, sessionType: self.sessionType) }
        } else {
            self.workoutStartDate = wb.startDate
        }

        self.isPaused  = (ws.state == .paused)
        self.isRunning = true
        self.elapsedSeconds = Int(currentElapsed())

        await altimeter.start()
        if !isTraining {
            detector.onSuggestion = { [weak self] in
                Task { @MainActor in
                    self?.suggestAttempt = true
                    self?.pendingClassifications += 1
                }
            }
            if !sessionType.usesBarometer { detector.startMotionDetection() }
        }
        if !isPaused { startTimer() }
        DiagnosticLog.shared.log("recoveredActiveSession state=\(ws.state.rawValue) ascents=\(attempts.count)")
    }

    private func recoverPendingSessionIfNeeded() {
        guard let pending = PendingSessionStore.load() else { return }
        PendingSessionStore.clear()
        guard !pending.ascents.isEmpty else {
            DiagnosticLog.shared.log("pendingSession found but empty – discarded")
            return
        }
        DiagnosticLog.shared.log("recoveredPendingSession ascents=\(pending.ascents.count)")
        let dto = WatchSessionDTO(
            id: pending.id,
            workoutUUID: nil,
            date: pending.startDate,
            durationSeconds: -pending.accumulatedPaused + Date().timeIntervalSince(pending.startDate),
            sessionTypeRaw: pending.sessionTypeRaw,
            avgHeartRate: nil,
            maxHeartRate: nil,
            activeEnergyKcal: nil,
            altitudeTotalGain: 0,
            ascents: pending.ascents,
            rpe: nil,
            focusRaw: nil,
            energyRaw: nil
        )
        SyncService.shared.send(dto: dto)
    }

    func currentElapsed() -> TimeInterval {
        guard let start = workoutStartDate else { return 0 }
        if let p = pauseStartedAt {
            return max(0, p.timeIntervalSince(start) - accumulatedPaused)
        }
        return max(0, Date().timeIntervalSince(start) - accumulatedPaused)
    }

    override init() {
        super.init()
        let ud = UserDefaults.standard
        if let id   = ud.string(forKey: Self.selectedProjectIDKey),
           let name = ud.string(forKey: Self.selectedProjectNameKey) {
            _selectedProject = Published(wrappedValue: ProjectInfo(id: id, name: name))
        }
    }

    private func persistSelectedProject() {
        let ud = UserDefaults.standard
        if let p = selectedProject {
            ud.set(p.id,   forKey: Self.selectedProjectIDKey)
            ud.set(p.name, forKey: Self.selectedProjectNameKey)
        } else {
            ud.removeObject(forKey: Self.selectedProjectIDKey)
            ud.removeObject(forKey: Self.selectedProjectNameKey)
        }
    }

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

    // MARK: - P2-7.3: Resync beim Aufwachen (isLuminanceReduced → false)

    func resyncSensors() {
        elapsedSeconds = Int(currentElapsed())
        Task { [weak self] in
            guard let self else { return }
            let alt = await self.altimeter.totalGain
            await MainActor.run { self.totalAltitudeGain = alt }
        }
    }

    // MARK: - Session Start (W1.2)

    func startWorkout(type: WatchSessionType, target: WatchTrainingTarget? = nil) async {
        // P2-7.1: Sicherstellen, dass Authorization abgeschlossen ist.
        await requestAuthorization()

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
        DiagnosticLog.shared.log("start sessionType=\(type.rawValue)")
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

        savePendingSnapshot()
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
                // P1-4: ohne HR-Parameter – detector.currentHR wird im Timer-Tick gesetzt
                detector.startMotionDetection()
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
            sessionType: sessionType,
            projectInfo: selectedProject
        )
        attempts.append(attempt)
        savePendingSnapshot()
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
        pauseStartedAt = Date()
        timer?.invalidate()
        DiagnosticLog.shared.log("pause elapsed=\(elapsedSeconds)s")
        broadcastLiveStatus()
    }

    func resumeWorkout() {
        if let p = pauseStartedAt {
            accumulatedPaused += Date().timeIntervalSince(p)
            pauseStartedAt = nil
        }
        session?.resume()
        isPaused = false
        startTimer()
        DiagnosticLog.shared.log("resume elapsed=\(elapsedSeconds)s")
        broadcastLiveStatus()
    }

    // MARK: - Versuch löschen

    func removeAttempt(id: UUID) {
        attempts.removeAll { $0.id == id }
        savePendingSnapshot()
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
            sessionType: sessionType,
            projectInfo: selectedProject
        )
        attempts.append(attempt)
        savePendingSnapshot()
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
        var avgHR: Double? = nil
        var maxHRfromHK: Double? = nil
        if let ws = session, let wb = builder {
            ws.end()
            try? await wb.endCollection(at: endDate)
            // P0-1: Ø-HF aus HK-Stats lesen (discreteAverage), nicht Momentanwert
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let hrStats = wb.statistics(for: HKQuantityType(.heartRate))
            avgHR = hrStats?.averageQuantity()?.doubleValue(for: bpmUnit)
            maxHRfromHK = hrStats?.maximumQuantity()?.doubleValue(for: bpmUnit)
            let finishedWorkout = try? await wb.finishWorkout()
            resolvedUUID = finishedWorkout?.uuid
        }
        // Fallback: manueller Akkumulator (wenn HK-Builder nie gestartet)
        let finalAvgHR = avgHR ?? (hrCount > 0 ? hrSum / Double(hrCount) : nil)
        let finalMaxHR = maxHRfromHK ?? (maxHeartRate > 0 ? maxHeartRate : nil)

        let duration = workoutStartDate.map { endDate.timeIntervalSince($0) } ?? 0
        let altTotal = await altimeter.totalGain

        let dto = WatchSessionDTO(
            id: UUID(),
            workoutUUID: resolvedUUID,
            date: workoutStartDate ?? endDate,
            durationSeconds: duration,
            sessionTypeRaw: sessionType.rawValue,
            avgHeartRate: finalAvgHR,
            maxHeartRate: finalMaxHR,
            activeEnergyKcal: activeEnergyKcal > 0 ? activeEnergyKcal : nil,
            altitudeTotalGain: altTotal,
            ascents: attempts.map { $0.toDTO() },
            rpe: nil,
            focusRaw: trainingTarget?.rawValue,
            energyRaw: nil
        )

        DiagnosticLog.shared.log("end ascents=\(attempts.count) duration=\(Int(duration))s")
        clearLiveStatus()
        WKInterfaceDevice.current().play(.stop)

        return dto
    }

    /// Session verwerfen – kein HKWorkout wird gespeichert, kein DTO gesendet.
    func discardWorkout() {
        detector.stopMotionDetection()
        timer?.invalidate()
        timer = nil
        session?.end()  // end() ohne finishWorkout() → HKWorkout wird nicht geschrieben
        Task { await altimeter.stop() }
        clearLiveStatus()
        WKInterfaceDevice.current().play(.failure)
        finishSession()
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
        selectedProject = nil
        hrSum = 0
        hrCount = 0
        accumulatedPaused = 0
        pauseStartedAt = nil
        workoutStartDate = nil
        PendingSessionStore.clear()
    }

    // MARK: - E1: Live-Status an iPhone senden

    private func broadcastLiveStatus() {
        guard WCSession.default.activationState == .activated else { return }
        let status = WatchLiveStatus(
            elapsedSeconds: elapsedSeconds,
            sessionTypeRaw: sessionType.rawValue,
            attemptCount: attempts.count,
            isPaused: isPaused,
            startedAt: workoutStartDate ?? Date()
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
                self.elapsedSeconds = Int(self.currentElapsed())
                let alt = await self.altimeter.totalGain
                self.totalAltitudeGain = alt
                if self.sessionType.usesBarometer {
                    self.detector.updateAltitude(alt)
                }
                // P1-4: aktuelle HF an Detector weitergeben (war vorher eingefrorener Wert)
                self.detector.currentHR = self.heartRate
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
                                    date: Date) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            DiagnosticLog.shared.log("didChangeTo \(toState.rawValue)")
            switch toState {
            case .paused:
                if !self.isPaused {
                    self.isPaused = true
                    self.pauseStartedAt = Date()
                    self.timer?.invalidate()
                }
            case .running:
                if self.isPaused {
                    if let p = self.pauseStartedAt {
                        self.accumulatedPaused += Date().timeIntervalSince(p)
                        self.pauseStartedAt = nil
                    }
                    self.isPaused = false
                    self.startTimer()
                }
            case .ended, .stopped:
                if self.isRunning {
                    self.sessionEndedUnexpectedly = true
                }
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            DiagnosticLog.shared.log("didFailWithError \(error.localizedDescription)")
            self?.lastError = error.localizedDescription
            self?.sessionEndedUnexpectedly = true
        }
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
                    if bpm > 0 { self.hrSum += bpm; self.hrCount += 1 }
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!:
                    self.activeEnergyKcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                default: break
                }
            }
        }
    }
}
