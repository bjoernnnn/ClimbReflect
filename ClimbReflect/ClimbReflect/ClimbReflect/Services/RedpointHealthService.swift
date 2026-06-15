import Foundation
import SwiftData
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Redpoint-Integration über Apple Health
//
// Redpoint schreibt seine Klettersessions (Workout-Typ .climbing) inkl.
// Herzfrequenz, Dauer und Energie nach HealthKit. Dieser Service liest neue
// Workouts und legt sie als ClimbSession (source = .healthKit) in der DB an –
// dedupliziert über die HKWorkout-UUID, damit nichts doppelt importiert wird.
//
// Hinweis: HealthKit funktioniert nur auf einem echten Gerät und benötigt die
// HealthKit-Capability + die Usage-Description in der Info.plist. Im Simulator
// und in der Preview bleibt es bei den Mock-Daten.

enum HealthError: LocalizedError {
    case unavailable
    case authorizationDenied
    case noClimbingWorkouts

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "HealthKit ist auf diesem Gerät nicht verfügbar. Der Import funktioniert nur auf einem echten iPhone."
        case .authorizationDenied:
            "Zugriff auf Apple Health wurde verweigert. Bitte unter iPhone-Einstellungen → Datenschutz & Sicherheit → Health → ClimbReflect die Leseberechtigung für Workouts erteilen."
        case .noClimbingWorkouts:
            "Keine Kletter-Workouts in Apple Health gefunden. Stelle sicher, dass Redpoint Workouts nach Apple Health exportiert (Redpoint → Einstellungen → Apple Health aktivieren)."
        }
    }
}

final class RedpointHealthService {
    static let shared = RedpointHealthService()
    private init() {}

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }
        let read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        try await store.requestAuthorization(toShare: [], read: read)
        // Nach requestAuthorization prüfen ob tatsächlich Zugriff erteilt wurde
        let status = store.authorizationStatus(for: HKObjectType.workoutType())
        if status == .sharingDenied {
            throw HealthError.authorizationDenied
        }
    }

    /// Importiert alle Kletter-Workouts, die noch nicht in der DB sind.
    /// Gibt die Anzahl neu importierter Sessions zurück.
    @discardableResult
    @MainActor
    func importNewSessions(into context: ModelContext) async throws -> Int {
        try await requestAuthorization()

        let workouts = try await fetchClimbingWorkouts()
        let existing = (try? context.fetch(FetchDescriptor<ClimbSession>()))?
            .compactMap(\.workoutUUID) ?? []
        let known = Set(existing)

        if workouts.isEmpty { throw HealthError.noClimbingWorkouts }

        var added = 0
        for workout in workouts where !known.contains(workout.uuid) {
            let hr = try? await heartRate(for: workout)
            let session = ClimbSession(
                workoutUUID: workout.uuid,
                date: workout.startDate,
                durationSeconds: workout.duration,
                sessionType: .unknown,
                source: .healthKit,
                avgHeartRate: hr?.avg,
                maxHeartRate: hr?.max,
                activeEnergyKcal: activeEnergyKcal(for: workout)
            )
            context.insert(session)
            NotificationService.shared.scheduleReflectionReminder(for: session)
            added += 1
        }
        if added > 0 { try? context.save() }
        return added
    }

    private func fetchClimbingWorkouts() async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForWorkouts(with: .climbing)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 200
        )
        return try await descriptor.result(for: store)
    }

    private func heartRate(for workout: HKWorkout) async throws -> (avg: Double?, max: Double?) {
        let hr = HKQuantityType(.heartRate)
        let p = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: hr, predicate: p),
            options: [.discreteAverage, .discreteMax]
        )
        let stats = try await descriptor.result(for: store)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return (stats?.averageQuantity()?.doubleValue(for: bpm),
                stats?.maximumQuantity()?.doubleValue(for: bpm))
    }

    private func activeEnergyKcal(for workout: HKWorkout) -> Double? {
        let type = HKQuantityType(.activeEnergyBurned)
        return workout.statistics(for: type)?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    #else
    // Fallback für Plattformen ohne HealthKit (z. B. Tests auf macOS).
    @discardableResult
    @MainActor
    func importNewSessions(into context: ModelContext) async throws -> Int {
        throw HealthError.unavailable
    }
    #endif
}
