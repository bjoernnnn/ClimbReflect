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
    @Published var heartRate: Double = 0
    @Published var maxHeartRate: Double = 0
    @Published var activeEnergyKcal: Double = 0
    @Published var attempts: [WatchAttempt] = []
    @Published var attemptState: AttemptState = .idle  // D1
    @Published var trainingTarget: WatchTrainingTarget? = nil  // C5
    @Published var totalAltitudeGain: Double = 0
    @Published var sessionEndedUnexpectedly = false
    @Published var lastError: String?
    @Published var healthKitActive = false
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
    private var lastPublishedAltitudeInt: Int = -1  // A3: throttle altitude publish
    private var isFinishingIntentionally = false    // P1-2: kein doppeltes Ende

    let altimeter = AltimeterService()

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
        // P1-3: Nur beim echten Kaltstart ausführen
        guard !isRunning, session == nil else { return }
        // P1-2: Alte Fehler aus einer vorherigen Session zurücksetzen
        lastError = nil
        sessionEndedUnexpectedly = false
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

        await altimeter.start()
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
        lastPublishedAltitudeInt = -1  // force first publish

        // Timer und UI-State sofort starten – unabhängig von HealthKit.
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

        if store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingDenied {
            DiagnosticLog.shared.log("HK sharingDenied – Timer-only session, no background")
        }

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
            healthKitActive = true
            DiagnosticLog.shared.log("beginCollection ok")
        } catch {
            healthKitActive = false
            DiagnosticLog.shared.log("HK setup failed: \(error.localizedDescription)")
        }

        savePendingSnapshot()
        await altimeter.start()
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
            attemptState = .active(startTime: .now)
            WKInterfaceDevice.current().play(.start)
            Task { await altimeter.startAscentTracking() }

        case .active:
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
        DiagnosticLog.shared.log("pause elapsed=\(Int(currentElapsed()))s")
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
        DiagnosticLog.shared.log("resume elapsed=\(Int(currentElapsed()))s")
        broadcastLiveStatus()
    }

    // MARK: - Versuch löschen

    func removeAttempt(id: UUID) {
        attempts.removeAll { $0.id == id }
        savePendingSnapshot()
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
        // P1-2: Absichtliches Ende signalisieren – verhindert sessionEndedUnexpectedly im Delegate
        isFinishingIntentionally = true
        await altimeter.stop()
        timer?.invalidate()
        timer = nil
        DiagnosticLog.shared.flush()

        let endDate = Date()

        var resolvedUUID: UUID? = nil
        var avgHR: Double? = nil
        var maxHRfromHK: Double? = nil
        if let ws = session, let wb = builder {
            if ws.state != .ended && ws.state != .stopped { ws.end() }
            try? await wb.endCollection(at: endDate)
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let hrStats = wb.statistics(for: HKQuantityType(.heartRate))
            avgHR = hrStats?.averageQuantity()?.doubleValue(for: bpmUnit)
            maxHRfromHK = hrStats?.maximumQuantity()?.doubleValue(for: bpmUnit)
            let finishedWorkout = try? await wb.finishWorkout()
            resolvedUUID = finishedWorkout?.uuid
        }
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
        isFinishingIntentionally = true  // P1-2
        timer?.invalidate()
        timer = nil
        session?.end()
        Task { await altimeter.stop() }
        DiagnosticLog.shared.flush()
        clearLiveStatus()
        WKInterfaceDevice.current().play(.failure)
        finishSession()
    }

    /// Reset erst NACH Fragebogen + Zusammenfassung aufrufen.
    func finishSession() {
        isRunning = false
        isPaused = false
        session = nil
        builder = nil
        attempts = []
        heartRate = 0
        maxHeartRate = 0
        activeEnergyKcal = 0
        totalAltitudeGain = 0
        lastPublishedAltitudeInt = -1
        attemptState = .idle
        trainingTarget = nil
        selectedProject = nil
        hrSum = 0
        hrCount = 0
        accumulatedPaused = 0
        pauseStartedAt = nil
        workoutStartDate = nil
        healthKitActive = false
        sessionEndedUnexpectedly = false
        lastError = nil
        isFinishingIntentionally = false  // P1-2: für nächste Session zurücksetzen
        PendingSessionStore.clear()
    }

    // MARK: - E1: Live-Status an iPhone senden

    private func broadcastLiveStatus() {
        guard WCSession.default.activationState == .activated else { return }
        let status = WatchLiveStatus(
            elapsedSeconds: Int(currentElapsed()),  // A1: direkt berechnet, kein @Published-Tick
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
        // A4: 2s-Intervall – TimelineView treibt die Uhranzeige, Timer nur für Sensoren + Broadcast.
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // A1: kein elapsedSeconds-Update – TimelineView + currentElapsed() genügen
                let alt = await self.altimeter.totalGain
                // A3: Altitude nur publizieren wenn gerundeter Meterwert sich ändert
                let altInt = Int(alt)
                if altInt != self.lastPublishedAltitudeInt {
                    self.lastPublishedAltitudeInt = altInt
                    self.totalAltitudeGain = alt
                }
                // A4+A5: Broadcast alle 5 Ticks × 2s = 10s
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
                self.healthKitActive = true
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
                    // A7: Sensoren sofort stoppen, nicht erst wenn View reagiert
                    self.timer?.invalidate()
                    self.timer = nil
                    Task { await self.altimeter.stop() }
                    // P1-2: sessionEndedUnexpectedly nur bei unerwartetem Ende setzen
                    if !self.isFinishingIntentionally {
                        self.sessionEndedUnexpectedly = true
                    }
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
            guard let self else { return }
            // P1-2: Fehler beim absichtlichen Beenden nicht als unerwartetes Ende werten
            if !self.isFinishingIntentionally {
                self.lastError = error.localizedDescription
                self.sessionEndedUnexpectedly = true
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    // A3: alle Typen in einem einzigen Task verarbeiten statt je Typ einen Task
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var bpm: Double? = nil
        var kcal: Double? = nil
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let stats = workoutBuilder.statistics(for: quantityType)
            switch quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate)!:
                bpm = stats?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!:
                kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
            default: break
            }
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let bpm {
                self.heartRate = bpm
                if bpm > self.maxHeartRate { self.maxHeartRate = bpm }
                if bpm > 0 { self.hrSum += bpm; self.hrCount += 1 }
            }
            if let kcal { self.activeEnergyKcal = kcal }
        }
    }
}
