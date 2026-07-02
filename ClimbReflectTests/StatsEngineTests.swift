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

    // MARK: - climbingDays (FB-5)

    private var wideInterval: DateInterval {
        DateInterval(start: Date().addingTimeInterval(-14 * 86400),
                     end: Date().addingTimeInterval(86400))
    }

    func testClimbingDays_boulderAndRouteSameDay_countsOneDay() {
        let boulder = makeSession(daysAgo: 0, type: .boulder)
        let route = makeSession(daysAgo: 0, type: .lead)
        XCTAssertEqual(StatsEngine.climbingDays([boulder, route], in: wideInterval), 1)
    }

    func testClimbingDays_trainingNotCounted() {
        let training = makeSession(daysAgo: 0, type: .training)
        XCTAssertEqual(StatsEngine.climbingDays([training], in: wideInterval), 0)
    }

    func testClimbingDays_twoDistinctDays_countsTwo() {
        let sessions = [makeSession(daysAgo: 0), makeSession(daysAgo: 1)]
        XCTAssertEqual(StatsEngine.climbingDays(sessions, in: wideInterval), 2)
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

    // MARK: - achievements (aktuell: nur "first" und "streak")

    func testAchievements_noSessions_allLocked() {
        let achievements = StatsEngine.achievements(for: [])
        XCTAssertTrue(achievements.allSatisfy { !$0.isUnlocked })
    }

    func testAchievements_firstSession_unlocksErstezug() {
        let achievements = StatsEngine.achievements(for: [makeSession()])
        let first = achievements.first { $0.id == "first" }
        XCTAssertTrue(first?.isUnlocked == true)
    }

    func testAchievements_fourWeekStreak_unlocksStreak() {
        let sessions = [0, 7, 14, 21].map { makeSession(daysAgo: $0) }
        let achievements = StatsEngine.achievements(for: sessions)
        let streak = achievements.first { $0.id == "streak" }
        XCTAssertTrue(streak?.isUnlocked == true)
    }

    func testAchievements_progressIsClampedToOne() {
        let sessions = (0..<30).map { makeSession(daysAgo: $0) }
        let achievements = StatsEngine.achievements(for: sessions)
        XCTAssertTrue(achievements.allSatisfy { $0.progress <= 1.0 })
    }

    // MARK: - Kanonische Grad-Ordnung (skalenübergreifend)

    func testCanonicalOrder_vScaleVsFontainebleau_comparable() {
        // V5 ≈ 6C/6C+ ist schwerer als 6B+ – roher sortOrder (6 vs. 8) sagt das Gegenteil
        let v5   = Ascent(gradeSystem: .vScale, grade: "V5", result: .top)
        let f6bp = Ascent(gradeSystem: .fontainebleau, grade: "6B+", result: .top)
        XCTAssertGreaterThan(v5.canonicalOrder, f6bp.canonicalOrder)
    }

    func testCanonicalOrder_uiaaVsFrench_comparable() {
        // UIAA VII ≈ 6a+/6b ist schwerer als French 5c
        let uiaa7 = Ascent(gradeSystem: .uiaa, grade: "VII", result: .top)
        let f5c   = Ascent(gradeSystem: .french, grade: "5c", result: .top)
        XCTAssertGreaterThan(uiaa7.canonicalOrder, f5c.canonicalOrder)
    }

    func testGradeConverter_v16_convertsTo8Cplus() {
        XCTAssertEqual(GradeConverter.convert(grade: "V16", from: .vScale, to: .fontainebleau), "8C+")
    }

    // MARK: - gradePyramid (Disziplin statt exakter Skala)

    func testGradePyramid_includesConvertedVScaleAscents() {
        let s = makeSession(type: .boulder)
        let a = Ascent(gradeSystem: .vScale, grade: "V6", result: .top)  // ≈ 7A
        a.session = s
        s.ascents.append(a)
        let entries = StatsEngine.gradePyramid([s], system: .fontainebleau)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.grade, "7A")
        XCTAssertEqual(entries.first?.tops, 1)
    }

    func testGradePyramid_excludesRouteAscentsFromBoulderPyramid() {
        let s = makeSession(type: .lead)
        let a = Ascent(gradeSystem: .french, grade: "6a", result: .top)
        a.session = s
        s.ascents.append(a)
        XCTAssertTrue(StatsEngine.gradePyramid([s], system: .fontainebleau).isEmpty)
        XCTAssertEqual(StatsEngine.gradePyramid([s], system: .french).count, 1)
    }

    // MARK: - trainingLoad (kein RPE-Default, ACWR = Woche / 4-Wochen-Ø)

    func testTrainingLoad_sessionWithoutRPE_contributesZero() {
        let sessions = [makeSession(daysAgo: 0, durationMinutes: 60, rpe: nil)]
        let points = StatsEngine.trainingLoad(sessions)
        XCTAssertTrue(points.allSatisfy { $0.load == 0 })
    }

    func testTrainingLoad_currentWeek_isRPETimesMinutes() {
        let sessions = [makeSession(daysAgo: 0, durationMinutes: 60, rpe: 7)]
        let points = StatsEngine.trainingLoad(sessions)
        XCTAssertEqual(points.last?.load, 420)
    }

    // MARK: - insights(for:) – SI-1

    private func makeSessionWithAscents(durationMinutes: Int = 90,
                                        rpe: Int? = nil,
                                        ascents: [(result: AscentResult, durationSec: Double?)] = []) -> ClimbSession {
        let s = makeSession(durationMinutes: durationMinutes, rpe: rpe)
        for a in ascents {
            let ascent = Ascent(gradeSystem: .fontainebleau, grade: "6A", result: a.result)
            ascent.durationSeconds = a.durationSec
            ascent.session = s
            s.ascents.append(ascent)
        }
        return s
    }

    func testInsights_noAscents_hasNoAttemptTimes() {
        let s = makeSessionWithAscents()
        let i = StatsEngine.insights(for: s)
        XCTAssertFalse(i.hasAttemptTimes)
        XCTAssertNil(i.avgAttemptSeconds)
        XCTAssertEqual(i.activeSeconds, 0)
    }

    func testInsights_sumExceedsTotal_isClamped() {
        // total = 60 min = 3600s; two 40-min timed attempts → sum 4800 s > 3600
        let s = makeSessionWithAscents(durationMinutes: 60, ascents: [
            (.top, 2400),
            (.attempt, 2400),
        ])
        let i = StatsEngine.insights(for: s)
        XCTAssertTrue(i.hasAttemptTimes)
        XCTAssertEqual(i.activeSeconds, 3600, accuracy: 1)
    }

    func testInsights_rpe7_60min_load420() {
        let s = makeSessionWithAscents(durationMinutes: 60, rpe: 7)
        let i = StatsEngine.insights(for: s)
        XCTAssertEqual(i.load, 420)
    }

    func testInsights_3tops_90min_sendsPerHour2() {
        let s = makeSessionWithAscents(durationMinutes: 90, ascents: [
            (.top, 600), (.top, 600), (.top, 600),
        ])
        let i = StatsEngine.insights(for: s)
        XCTAssertNotNil(i.sendsPerHour)
        XCTAssertEqual(i.sendsPerHour!, 2.0, accuracy: 0.01)
    }
}
