import Foundation
import Combine
import HealthKit
import WatchKit
import WatchConnectivity

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
    @Published var healthKitDenied = false
    @Published var pendingSummaryDTO: WatchSessionDTO? = nil
    @Published var selectedProject: ProjectInfo? = nil {  // P5.7 / P2-8
        didSet { persistSelectedProject() }
    }

    var isTraining: Bool { sessionType == .training }

    // MARK: - Private

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var hrQuery: HKAnchoredObjectQuery?
    private var energyQuery: HKAnchoredObjectQuery?
    private var timer: Timer?
    private(set) var workoutStartDate: Date?
    private var accumulatedPaused: TimeInterval = 0
    private var pauseStartedAt: Date?
    private var liveStatusTickCount = 0
    private var memTickCount = 0
    private var lastMemMB = 0
    private var lastPublishedAltitudeInt: Int = -1  // A3: throttle altitude publish
    private var isFinishingIntentionally = false    // P1-2: kein doppeltes Ende

    let altimeter = AltimeterService()

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
            accumulatedPaused: accumulatedPaused,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            hrSum: hrSum > 0 ? hrSum : nil,
            hrCount: hrCount > 0 ? hrCount : nil,
            activeEnergyKcal: activeEnergyKcal > 0 ? activeEnergyKcal : nil,
            lastHeartRate: heartRate > 0 ? heartRate : nil
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
            DiagnosticLog.shared.log("recover: hk session state=\(recovered.state.rawValue)")
            await reattach(to: recovered)
            return
        }
        DiagnosticLog.shared.log("recover: keine HK-Session – finalize")
        await finalizeUnrecoverableSession()
    }

    private func reattach(to ws: HKWorkoutSession) async {
        // P1: beendete Session nicht als laufend reattachen
        guard ws.state == .running || ws.state == .paused else {
            DiagnosticLog.shared.log("reattach abgebrochen: state=\(ws.state.rawValue)")
            await finalizeUnrecoverableSession()
            return
        }
        ws.delegate = self
        self.session = ws
        // Builder referenzieren – Collection läuft bereits (S16)
        self.builder = ws.associatedWorkoutBuilder()

        // Live-State aus Snapshot wiederherstellen
        if let p = PendingSessionStore.load() {
            self.sessionType       = WatchSessionType(rawValue: p.sessionTypeRaw) ?? .boulder
            self.workoutStartDate  = p.startDate
            self.accumulatedPaused = p.accumulatedPaused
            if let id = p.projectID, let name = p.projectName {
                self.selectedProject = ProjectInfo(id: id, name: name)
            }
            self.attempts = p.ascents.map { WatchAttempt(fromDTO: $0, sessionType: self.sessionType) }
            // B3: hrSum/hrCount/activeEnergyKcal werden in startStreamingHR/Energy aus der
            // kompletten HealthKit-Historie neu aufgebaut – hier nicht restoren (Doppelzählung).
            // maxHeartRate und lastHeartRate als Anzeige-Seed, damit die UI nicht kurz auf 0 springt.
            if let max  = p.maxHeartRate   { self.maxHeartRate     = max  }
            if let hr   = p.lastHeartRate  { self.heartRate        = hr   }
        } else {
            // Kein Snapshot – startDate aus dem assoziierten Builder lesen (read-only, kein Collect)
            self.workoutStartDate = ws.associatedWorkoutBuilder().startDate
        }

        self.isPaused  = (ws.state == .paused)
        self.isRunning = true
        // S14: didChangeTo(.running) feuert bei Recovery nicht → Flag explizit setzen
        self.healthKitActive = (ws.state == .running || ws.state == .paused)

        await altimeter.start()
        if !isPaused { startTimer() }
        startStreamingHeartRate()
        startStreamingEnergy()
        DiagnosticLog.shared.log("streaming queries started")
        DiagnosticLog.shared.log("recoveredActiveSession state=\(ws.state.rawValue) ascents=\(attempts.count)")
    }

    /// Session kann nicht wieder aufgenommen werden → sauber finalisieren:
    /// Begehungen ans Handy syncen (falls vorhanden) und Handy-Live-Anzeige in jedem Fall beenden.
    private func finalizeUnrecoverableSession() async {
        if let pending = PendingSessionStore.load(), !pending.ascents.isEmpty {
            let avg: Double? = {
                guard let sum = pending.hrSum, let cnt = pending.hrCount, cnt > 0 else { return nil }
                return sum / Double(cnt)
            }()
            let dto = WatchSessionDTO(
                id: pending.id,
                workoutUUID: nil,
                date: pending.startDate,
                durationSeconds: -pending.accumulatedPaused + Date().timeIntervalSince(pending.startDate),
                sessionTypeRaw: pending.sessionTypeRaw,
                avgHeartRate: avg,
                maxHeartRate: pending.maxHeartRate,
                activeEnergyKcal: pending.activeEnergyKcal,
                altitudeTotalGain: 0,
                ascents: pending.ascents,
                rpe: nil, focusRaw: nil, energyRaw: nil
            )
            SyncService.shared.send(dto: dto)
            DiagnosticLog.shared.log("finalize: DTO gesendet ascents=\(pending.ascents.count)")
        } else {
            DiagnosticLog.shared.log("finalize: keine ascents – nur Live-Status löschen")
        }
        PendingSessionStore.clear()
        clearLiveStatus()      // leeres Data → Handy setzt liveStatus = nil (Live-Anzeige aus)
        isRunning = false
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
        let launchCount = ud.integer(forKey: "launchCount") + 1
        ud.set(launchCount, forKey: "launchCount")
        DiagnosticLog.shared.log("app launch #\(launchCount) mem=\(MemoryFootprint.residentMB())MB")
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
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
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
            healthKitDenied = true
            healthKitActive = false
        } else {
            do {
                let ws = try HKWorkoutSession(healthStore: store, configuration: config)
                ws.delegate = self
                self.session = ws
                ws.startActivity(with: startDate)
                // S16: Builder NUR für Session-Preservation – KEINE DataSource, keine Samples
                let wb = ws.associatedWorkoutBuilder()
                try await wb.beginCollection(at: startDate)
                self.builder = wb
                startStreamingHeartRate()
                startStreamingEnergy()
                healthKitActive = true
                DiagnosticLog.shared.log("beginCollection ok")
                DiagnosticLog.shared.log("streaming queries started")
            } catch {
                healthKitActive = false
                DiagnosticLog.shared.log("HK setup failed: \(error.localizedDescription)")
            }
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
            DiagnosticLog.shared.log("ascentTracking start mem=\(MemoryFootprint.residentMB())MB")
            Task { await altimeter.startAscentTracking() }

        case .active:
            attemptState = .awaitingResult
            WKInterfaceDevice.current().play(.click)

        case .awaitingResult:
            break
        }
        DiagnosticLog.shared.log("actionButton -> \(String(describing: attemptState)) mem=\(MemoryFootprint.residentMB())MB")
    }

    /// Schnelles Banken aus dem Action-Button-Flow (ohne Grad-Auswahl)
    func quickBank(result: WatchAscentResult) async {
        DiagnosticLog.shared.log("ascentTracking stop mem=\(MemoryFootprint.residentMB())MB")
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
        DiagnosticLog.shared.log("ascentTracking stop mem=\(MemoryFootprint.residentMB())MB")
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
        // S4: Guard gegen Doppelaufruf (z. B. UI + Delegate parallel)
        guard !isFinishingIntentionally else { return nil }
        isFinishingIntentionally = true
        await altimeter.stop()
        timer?.invalidate()
        timer = nil
        stopStreamingQueries()
        DiagnosticLog.shared.flush()

        let endDate = Date()

        var resolvedUUID: UUID? = nil
        if let ws = session, let wb = builder, let startDate = workoutStartDate {
            if ws.state != .ended && ws.state != .stopped { ws.end() }
            // Energie-Sample hinzufügen, dann Builder abschließen (S16: kein neuer Builder nötig)
            if activeEnergyKcal > 0 {
                let qty = HKQuantity(unit: .kilocalorie(), doubleValue: activeEnergyKcal)
                let s = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                         quantity: qty, start: startDate, end: endDate)
                try? await wb.addSamples([s])
            }
            try? await wb.endCollection(at: endDate)
            resolvedUUID = try? await wb.finishWorkout()?.uuid
        }
        let finalAvgHR = hrCount > 0 ? hrSum / Double(hrCount) : nil
        let finalMaxHR = maxHeartRate > 0 ? maxHeartRate : nil

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

        // End-Flow in ContentView treiben; finishSession() setzt isRunning=false
        // (pendingSummaryDTO bleibt bis der Nutzer in SessionEndFlowView „Fertig" tippt)
        pendingSummaryDTO = dto
        finishSession()
        return dto
    }

    /// Session verwerfen – kein HKWorkout wird gespeichert, kein DTO gesendet.
    func discardWorkout() {
        isFinishingIntentionally = true  // P1-2
        timer?.invalidate()
        timer = nil
        stopStreamingQueries()
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
        hrQuery = nil
        energyQuery = nil
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
        healthKitDenied = false
        sessionEndedUnexpectedly = false
        lastError = nil
        isFinishingIntentionally = false
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
            startedAt: workoutStartDate ?? Date(),
            heartRate: heartRate > 0 ? heartRate : nil,
            activeEnergyKcal: activeEnergyKcal > 0 ? activeEnergyKcal : nil
        )
        guard let data = try? JSONEncoder().encode(status) else { return }
        try? WCSession.default.updateApplicationContext([WatchLiveStatus.key: data])
    }

    private func clearLiveStatus() {
        guard WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([WatchLiveStatus.key: Data()])
    }

    // MARK: - Streaming Queries (A3)

    private func startStreamingHeartRate() {
        // C: laufende Query stoppen bevor neue gestartet wird (kein paralleler Doppel-Stream)
        if let q = hrQuery { store.stop(q); hrQuery = nil }
        let hrType = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let startDate = workoutStartDate ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil,
                                                     options: .strictStartDate)
        // B1: Ø-Akkumulatoren vor Start zurücksetzen – anchor:nil liefert die komplette Historie,
        // also wird Ø vollständig aus dem Stream neu aufgebaut (keine Doppelzählung nach Relaunch).
        hrSum = 0
        hrCount = 0
        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            [weak self] _, samples, _, _, _ in
            guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty
            else { return }
            let bpms = quantitySamples.map { $0.quantity.doubleValue(for: unit) }
            let lastBpm = bpms.last ?? 0
            let batchMax = bpms.max() ?? 0
            let batchSum = bpms.reduce(0, +)
            let batchCount = bpms.count
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.heartRate = lastBpm
                if batchMax > self.maxHeartRate { self.maxHeartRate = batchMax }
                self.hrSum += batchSum
                self.hrCount += batchCount
            }
        }
        let q = HKAnchoredObjectQuery(type: hrType, predicate: predicate, anchor: nil,
                                       limit: HKObjectQueryNoLimit, resultsHandler: handler)
        q.updateHandler = handler
        store.execute(q)
        hrQuery = q
    }

    private func startStreamingEnergy() {
        // C: laufende Query stoppen bevor neue gestartet wird (kein paralleler Doppel-Stream)
        if let q = energyQuery { store.stop(q); energyQuery = nil }
        let energyType = HKQuantityType(.activeEnergyBurned)
        let startDate = workoutStartDate ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil,
                                                     options: .strictStartDate)
        // B2: Akkumulator zurücksetzen – anchor:nil liefert die komplette Historie, die Summe
        // wird vollständig neu aufgebaut (keine Doppelzählung nach Relaunch).
        activeEnergyKcal = 0
        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            [weak self] _, samples, _, _, _ in
            let delta = (samples as? [HKQuantitySample])?.reduce(0.0) {
                $0 + $1.quantity.doubleValue(for: .kilocalorie())
            } ?? 0
            guard delta > 0 else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeEnergyKcal += delta
            }
        }
        let q = HKAnchoredObjectQuery(type: energyType, predicate: predicate, anchor: nil,
                                       limit: HKObjectQueryNoLimit, resultsHandler: handler)
        q.updateHandler = handler
        store.execute(q)
        energyQuery = q
    }

    private func stopStreamingQueries() {
        if let q = hrQuery { store.stop(q); hrQuery = nil }
        if let q = energyQuery { store.stop(q); energyQuery = nil }
        DiagnosticLog.shared.log("streaming queries stopped")
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        memTickCount = 0
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
                // Memory-Log + Snapshot alle 30 Ticks × 2s = 60s
                self.memTickCount += 1
                if self.memTickCount >= 30 {
                    self.memTickCount = 0
                    let m = MemoryFootprint.residentMB()
                    let d = m - self.lastMemMB
                    self.lastMemMB = m
                    let sign = d >= 0 ? "+" : ""
                    DiagnosticLog.shared.log("tick mem=\(m)MB \u{0394}=\(sign)\(d) hr=\(Int(self.heartRate)) max=\(Int(self.maxHeartRate))")
                    self.savePendingSnapshot()
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
            guard let self else { return }
            DiagnosticLog.shared.log("didFailWithError \(error.localizedDescription)")
            // P1-2: Fehler beim absichtlichen Beenden nicht als unerwartetes Ende werten
            if !self.isFinishingIntentionally {
                self.lastError = error.localizedDescription
                self.sessionEndedUnexpectedly = true
            }
        }
    }
}

