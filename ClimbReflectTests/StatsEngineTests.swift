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

    // MARK: - bestClimbWeekStreak (MO-5)

    func testBestClimbWeekStreak_gapPattern_takesLongestRun() {
        // 4 zusammenhängende Wochen, Lücke, dann 2 → Rekord = 4
        let days = [0, 7, 14, 21, 42, 49]
        let sessions = days.map { makeSession(daysAgo: $0) }
        XCTAssertEqual(StatsEngine.bestClimbWeekStreak(sessions), 4)
    }

    func testBestClimbWeekStreak_singleWeek_isOne() {
        XCTAssertEqual(StatsEngine.bestClimbWeekStreak([makeSession(daysAgo: 3)]), 1)
    }

    func testBestClimbWeekStreak_empty_isZero() {
        XCTAssertEqual(StatsEngine.bestClimbWeekStreak([]), 0)
    }

    func testBestClimbWeekStreak_trainingExcluded() {
        let climb = makeSession(daysAgo: 0, type: .boulder)
        let training = makeSession(daysAgo: 7, type: .training)
        // nur die Kletter-Session zählt → Rekord 1 (kein Lauf über das Training)
        XCTAssertEqual(StatsEngine.bestClimbWeekStreak([climb, training]), 1)
    }

    func testBestClimbWeekStreak_yearBoundaryStaysOneRun() {
        let cal = Calendar(identifier: .gregorian)
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: day))!
        }
        // Vier Mittwoche in Folge über den Jahreswechsel (KW 51→52→1→2)
        let sessions = [d(2023, 12, 20), d(2023, 12, 27), d(2024, 1, 3), d(2024, 1, 10)]
            .map { ClimbSession(date: $0, durationSeconds: 3600, sessionType: .boulder) }
        XCTAssertEqual(StatsEngine.bestClimbWeekStreak(sessions), 4)
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
