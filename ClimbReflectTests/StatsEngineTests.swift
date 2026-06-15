import XCTest
@testable import ClimbReflect

final class StatsEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeSession(daysAgo: Int = 0,
                              durationMinutes: Int = 60,
                              type: SessionType = .boulder,
                              rpe: Int? = nil) -> ClimbSession {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return ClimbSession(
            date: date,
            durationSeconds: Double(durationMinutes * 60),
            sessionType: type,
            perceivedEffort: rpe
        )
    }

    // MARK: - weeklyMinutes

    func testWeeklyMinutes_emptySessions_returnsZeroMinutesPerWeek() {
        let points = StatsEngine.weeklyMinutes([], weeks: 4)
        XCTAssertEqual(points.count, 4)
        XCTAssertTrue(points.allSatisfy { $0.minutes == 0 })
        XCTAssertTrue(points.allSatisfy { $0.sessions == 0 })
    }

    func testWeeklyMinutes_sessionThisWeek_appearsInLastBucket() {
        let session = makeSession(daysAgo: 0, durationMinutes: 90)
        let points = StatsEngine.weeklyMinutes([session], weeks: 4)
        let lastBucket = points.last!
        XCTAssertEqual(lastBucket.sessions, 1)
        XCTAssertEqual(lastBucket.minutes, 90)
    }

    func testWeeklyMinutes_sessionFiveWeeksAgo_outsideWindowIsNotCounted() {
        let session = makeSession(daysAgo: 35)
        let points = StatsEngine.weeklyMinutes([session], weeks: 4)
        let totalSessions = points.map(\.sessions).reduce(0, +)
        XCTAssertEqual(totalSessions, 0)
    }

    func testWeeklyMinutes_multipleSessions_accumulateCorrectly() {
        let sessions = [
            makeSession(daysAgo: 0, durationMinutes: 60),
            makeSession(daysAgo: 1, durationMinutes: 45),
        ]
        let points = StatsEngine.weeklyMinutes(sessions, weeks: 4)
        let lastBucket = points.last!
        XCTAssertEqual(lastBucket.sessions, 2)
        XCTAssertEqual(lastBucket.minutes, 105)
    }

    func testWeeklyMinutes_alwaysReturnsRequestedWeekCount() {
        let sessions = [makeSession(daysAgo: 3)]
        XCTAssertEqual(StatsEngine.weeklyMinutes(sessions, weeks: 8).count, 8)
        XCTAssertEqual(StatsEngine.weeklyMinutes(sessions, weeks: 1).count, 1)
    }

    // MARK: - weekStreak

    func testWeekStreak_noSessions_isZero() {
        XCTAssertEqual(StatsEngine.weekStreak([]), 0)
    }

    func testWeekStreak_sessionThisWeek_isOne() {
        let session = makeSession(daysAgo: 0)
        XCTAssertEqual(StatsEngine.weekStreak([session]), 1)
    }

    func testWeekStreak_sessionThisAndLastWeek_isTwo() {
        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 8),
        ]
        XCTAssertEqual(StatsEngine.weekStreak(sessions), 2)
    }

    func testWeekStreak_gapInMiddle_resetsStreak() {
        // This week + 3 weeks ago (missing 1 and 2 weeks ago → streak = 1)
        let sessions = [
            makeSession(daysAgo: 0),
            makeSession(daysAgo: 22),
        ]
        XCTAssertEqual(StatsEngine.weekStreak(sessions), 1)
    }

    func testWeekStreak_onlyOldSession_isZero() {
        let session = makeSession(daysAgo: 14)
        XCTAssertEqual(StatsEngine.weekStreak([session]), 0)
    }

    // MARK: - sessionsThisWeek

    func testSessionsThisWeek_noSessions_isZero() {
        XCTAssertEqual(StatsEngine.sessionsThisWeek([]), 0)
    }

    func testSessionsThisWeek_sessionToday_isOne() {
        let session = makeSession(daysAgo: 0)
        XCTAssertEqual(StatsEngine.sessionsThisWeek([session]), 1)
    }

    func testSessionsThisWeek_sessionLastWeek_isZero() {
        let session = makeSession(daysAgo: 10)
        XCTAssertEqual(StatsEngine.sessionsThisWeek([session]), 0)
    }

    // MARK: - rpeHistory

    func testRPEHistory_noRPE_returnsEmpty() {
        let sessions = [makeSession(rpe: nil), makeSession(rpe: nil)]
        XCTAssertTrue(StatsEngine.rpeHistory(sessions).isEmpty)
    }

    func testRPEHistory_withRPE_returnsPoints() {
        let sessions = [makeSession(daysAgo: 5, rpe: 6), makeSession(daysAgo: 1, rpe: 8)]
        let points = StatsEngine.rpeHistory(sessions)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points.first?.rpe, 6)
        XCTAssertEqual(points.last?.rpe, 8)
    }

    func testRPEHistory_respectsLimit() {
        let sessions = (1...25).map { makeSession(daysAgo: $0, rpe: 5) }
        let points = StatsEngine.rpeHistory(sessions, limit: 10)
        XCTAssertEqual(points.count, 10)
    }

    // MARK: - sessionTypeDistribution

    func testSessionTypeDistribution_empty_returnsEmpty() {
        XCTAssertTrue(StatsEngine.sessionTypeDistribution([]).isEmpty)
    }

    func testSessionTypeDistribution_allSameType_shareIsOne() {
        let sessions = [makeSession(type: .boulder), makeSession(type: .boulder)]
        let dist = StatsEngine.sessionTypeDistribution(sessions)
        XCTAssertEqual(dist.count, 1)
        XCTAssertEqual(dist.first?.share, 1.0)
    }

    func testSessionTypeDistribution_twoTypes_sharesAddUpToOne() {
        let sessions = [makeSession(type: .boulder), makeSession(type: .lead)]
        let dist = StatsEngine.sessionTypeDistribution(sessions)
        XCTAssertEqual(dist.count, 2)
        let totalShare = dist.map(\.share).reduce(0, +)
        XCTAssertEqual(totalShare, 1.0, accuracy: 0.001)
    }

    func testSessionTypeDistribution_sortedByCountDescending() {
        let sessions = [
            makeSession(type: .boulder),
            makeSession(type: .boulder),
            makeSession(type: .lead),
        ]
        let dist = StatsEngine.sessionTypeDistribution(sessions)
        XCTAssertEqual(dist.first?.sessionType, .boulder)
        XCTAssertEqual(dist.first?.count, 2)
    }

    // MARK: - achievements

    func testAchievements_noSessions_allLocked() {
        let achievements = StatsEngine.achievements(for: [])
        XCTAssertTrue(achievements.allSatisfy { !$0.isUnlocked })
    }

    func testAchievements_firstSession_unlocksErstezug() {
        let achievements = StatsEngine.achievements(for: [makeSession()])
        let first = achievements.first { $0.id == "first" }
        XCTAssertTrue(first?.isUnlocked == true)
    }

    func testAchievements_fiveSessions_unlocksWarmgeklettert() {
        let sessions = (0..<5).map { makeSession(daysAgo: $0) }
        let achievements = StatsEngine.achievements(for: sessions)
        let five = achievements.first { $0.id == "five" }
        XCTAssertTrue(five?.isUnlocked == true)
    }

    func testAchievements_fourSessions_doesNotUnlockWarmgeklettert() {
        let sessions = (0..<4).map { makeSession(daysAgo: $0) }
        let achievements = StatsEngine.achievements(for: sessions)
        let five = achievements.first { $0.id == "five" }
        XCTAssertFalse(five?.isUnlocked == true)
    }

    func testAchievements_120MinSession_unlocksMarathon() {
        let session = makeSession(durationMinutes: 120)
        let achievements = StatsEngine.achievements(for: [session])
        let marathon = achievements.first { $0.id == "marathon" }
        XCTAssertTrue(marathon?.isUnlocked == true)
    }

    func testAchievements_threeDistinctTypes_unlocksVielseitig() {
        let sessions = [
            makeSession(type: .boulder),
            makeSession(type: .lead),
            makeSession(type: .topRope),
        ]
        let achievements = StatsEngine.achievements(for: sessions)
        let versatile = achievements.first { $0.id == "versatile" }
        XCTAssertTrue(versatile?.isUnlocked == true)
    }

    func testAchievements_progressIsClampedToOne() {
        let sessions = (0..<30).map { makeSession(daysAgo: $0) }
        let achievements = StatsEngine.achievements(for: sessions)
        XCTAssertTrue(achievements.allSatisfy { $0.progress <= 1.0 })
    }
}
