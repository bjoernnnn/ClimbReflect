import XCTest
@testable import ClimbReflect

final class AchievementEngineTests: XCTestCase {

    // MARK: - Helpers (Muster: ProgressEngineTests)

    private func date(_ offsetDays: Int) -> Date {
        let base = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 (Dienstag)
        return Calendar.current.date(byAdding: .day, value: offsetDays, to: base)!
    }

    private func ascent(_ system: GradeSystem, _ grade: String,
                        result: AscentResult = .top, style: AscentStyle? = nil,
                        angle: WallAngle? = nil, altitude: Double = 0, day: Int = 0) -> Ascent {
        let a = Ascent(gradeSystem: system, grade: grade, result: result, style: style,
                      wallAngle: angle, date: date(day))
        a.altitudeGain = altitude
        return a
    }

    private func session(_ ascents: [Ascent], type: SessionType = .boulder,
                         durationMinutes: Int = 60, reflection: Bool = false,
                         outdoor: Bool = false, day: Int = 0) -> ClimbSession {
        let s = ClimbSession(date: date(day), durationSeconds: Double(durationMinutes * 60),
                             sessionType: type, reflectionCompleted: reflection, outdoor: outdoor)
        for a in ascents { a.session = s; s.ascents.append(a) }
        return s
    }

    private func project(_ name: String, ascents: [Ascent]) -> Project {
        let p = Project(name: name)
        for a in ascents { a.project = p; p.ascents.append(a) }
        return p
    }

    private func existingKey(_ u: AchievementEngine.PendingUnlock) -> AchievementEngine.ExistingUnlockKey {
        .init(definitionID: u.definitionID, tier: u.tier,
             contextValue: u.tier == nil ? u.contextValue : nil,
             sessionID: u.tier == nil ? u.sessionID : nil)
    }

    private func events(_ sessions: [ClimbSession], projects: [Project] = [], id: String) -> [AchievementEngine.PendingUnlock] {
        AchievementEngine.evaluate(sessions: sessions, projects: projects, existing: []).filter { $0.definitionID == id }
    }

    // MARK: - Katalog

    func testCatalog_has28DefinitionsWithSymbolAndValidTiers() {
        XCTAssertEqual(AchievementDefinition.all.count, 28)
        for def in AchievementDefinition.all {
            XCTAssertFalse(def.symbol.isEmpty, def.id)
            if case .tiered(let tiers) = def.kind {
                XCTAssertFalse(tiers.isEmpty, def.id)
            }
        }
    }

    // MARK: - Anfänge

    func testFirstSession_earliestSessionWins() {
        let s1 = session([], day: 5)
        let s2 = session([], day: 0)
        let e = events([s1, s2], id: "first_session")
        XCTAssertEqual(e.first?.sessionID, s2.id)
    }

    func testFirstTop_ignoresAttempts() {
        let s = session([ascent(.fontainebleau, "6A", result: .attempt, day: 0),
                         ascent(.fontainebleau, "6A", result: .top, day: 1)])
        let e = events([s], id: "first_top")
        XCTAssertEqual(e.first?.date, date(1))
    }

    func testFirstReflection_onlyCompletedSessions() {
        let s1 = session([], reflection: false, day: 0)
        let s2 = session([], reflection: true, day: 1)
        let e = events([s1, s2], id: "first_reflection")
        XCTAssertEqual(e.first?.sessionID, s2.id)
    }

    func testDisciplineTrio_locked_belowThreeDisciplines() {
        let s1 = session([], type: .boulder, day: 0)
        let s2 = session([], type: .lead, day: 1)
        XCTAssertTrue(events([s1, s2], id: "discipline_trio").isEmpty)
    }

    func testDisciplineTrio_unlocks_atThirdDistinctDiscipline() {
        let s1 = session([], type: .boulder, day: 0)
        let s2 = session([], type: .lead, day: 1)
        let s3 = session([], type: .topRope, day: 2)
        let e = events([s1, s2, s3], id: "discipline_trio")
        XCTAssertEqual(e.first?.sessionID, s3.id)
    }

    func testDisciplineTrio_trainingDoesNotCount() {
        let s1 = session([], type: .boulder, day: 0)
        let s2 = session([], type: .lead, day: 1)
        let s3 = session([], type: .training, day: 2)
        XCTAssertTrue(events([s1, s2, s3], id: "discipline_trio").isEmpty)
    }

    // MARK: - Konsistenz

    func testWeekStreak_belowFirstTier_noUnlock() {
        let sessions = [0, 7, 14].map { session([], day: $0) }
        XCTAssertTrue(events(sessions, id: "week_streak").isEmpty)
    }

    func testWeekStreak_fourConsecutiveWeeks_unlocksTierZero() {
        let sessions = [0, 7, 14, 21].map { session([], day: $0) }
        let e = events(sessions, id: "week_streak")
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e.first?.tier, 0)
    }

    func testWeekStreak_eightWeeks_crossesTwoTiersWithDistinctDates() {
        let sessions = [0, 7, 14, 21, 28, 35, 42, 49].map { session([], day: $0) }
        let e = events(sessions, id: "week_streak").sorted { $0.tier! < $1.tier! }
        XCTAssertEqual(e.map(\.tier), [0, 1])
        XCTAssertLessThan(e[0].date, e[1].date)
    }

    func testSessionsTotal_tierCrossing_atTenthSession() {
        let sessions = (0..<10).map { session([], day: $0) }
        let e = events(sessions, id: "sessions_total")
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e.first?.sessionID, sessions[9].id)
    }

    func testClimbDaysYear_twoYearsBothQualifyIndependently() {
        let cal = Calendar(identifier: .gregorian)
        func day(_ year: Int, _ dayOfYear: Int) -> Date {
            cal.date(byAdding: .day, value: dayOfYear - 1,
                     to: cal.date(from: DateComponents(year: year, month: 1, day: 1))!)!
        }
        var sessions: [ClimbSession] = []
        for d in 1...50 {
            sessions.append(ClimbSession(date: day(2023, d), durationSeconds: 3600, sessionType: .boulder))
            sessions.append(ClimbSession(date: day(2024, d), durationSeconds: 3600, sessionType: .boulder))
        }
        let e = events(sessions, id: "climb_days_year")
        XCTAssertEqual(e.count, 2)
        XCTAssertEqual(Set(e.compactMap(\.contextValue)), ["2023", "2024"])
    }

    func testComeback_gapOf30DaysTriggersOnLaterSession() {
        let s1 = session([], day: 0)
        let s2 = session([], day: 31)
        let e = events([s1, s2], id: "comeback")
        XCTAssertEqual(e.first?.sessionID, s2.id)
    }

    func testComeback_gapBelowThreshold_noUnlock() {
        let s1 = session([], day: 0)
        let s2 = session([], day: 20)
        XCTAssertTrue(events([s1, s2], id: "comeback").isEmpty)
    }

    // MARK: - Schwierigkeit (PB über Skalen-Mix)

    func testPbBoulder_fontVScaleMix_canonicalProgressionOnly() {
        // Fb 6A (canonical 5) → V-Scale V4 (~6B+, canonical höher) → Fb 6A erneut (kein neuer PB)
        let s = session([
            ascent(.fontainebleau, "6A", day: 0),
            ascent(.vScale, "V4", day: 1),
            ascent(.fontainebleau, "6A", day: 2),
        ])
        let e = events([s], id: "pb_boulder")
        XCTAssertEqual(e.count, 2)
        XCTAssertEqual(e[0].contextValue, "6A")
        XCTAssertEqual(e[1].date, date(1))
    }

    func testPbBoulder_tie_noNewEvent() {
        let s = session([ascent(.fontainebleau, "6A", day: 0), ascent(.fontainebleau, "6A", day: 1)])
        XCTAssertEqual(events([s], id: "pb_boulder").count, 1)
    }

    func testGradeBoulder_lowFirstAscent_noTierYet() {
        let s = session([ascent(.fontainebleau, "5", day: 0)])
        XCTAssertTrue(events([s], id: "grade_boulder").isEmpty)
    }

    func testGradeBoulder_highFirstAscent_crossesMultipleTiersAtOnce() {
        // Erster gewerteter Top gleich 7A → 6A- und 6C-Stufe fallen mit
        let s = session([ascent(.fontainebleau, "7A", day: 0)])
        let e = events([s], id: "grade_boulder").sorted { $0.tier! < $1.tier! }
        XCTAssertEqual(e.map(\.tier), [0, 1, 2])
        XCTAssertTrue(e.allSatisfy { $0.date == date(0) })
    }

    // MARK: - Stil

    func testFlashTotal_tierCrossing() {
        let ascents = (0..<5).map { ascent(.fontainebleau, "6A", style: .flash, day: $0) }
        let s = session(ascents)
        let e = events([s], id: "flash_total")
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e.first?.tier, 0)
    }

    func testFlashDay_threeFlashesInOneSession() {
        let s = session((0..<3).map { ascent(.fontainebleau, "6A", style: .flash, day: $0) })
        let e = events([s], id: "flash_day")
        XCTAssertEqual(e.first?.contextValue, "3")
    }

    func testFlashDay_belowThreshold_noUnlock() {
        let s = session((0..<2).map { ascent(.fontainebleau, "6A", style: .flash, day: $0) })
        XCTAssertTrue(events([s], id: "flash_day").isEmpty)
    }

    func testAngleAllrounder_locked_threeOfFourAngles() {
        let s = session([
            ascent(.fontainebleau, "6A", angle: .slab, day: 0),
            ascent(.fontainebleau, "6A", angle: .vertical, day: 1),
            ascent(.fontainebleau, "6A", angle: .overhang, day: 2),
        ])
        XCTAssertTrue(events([s], id: "angle_allrounder").isEmpty)
    }

    func testAngleAllrounder_unlocks_atFourthDistinctAngle() {
        let s = session([
            ascent(.fontainebleau, "6A", angle: .slab, day: 0),
            ascent(.fontainebleau, "6A", angle: .vertical, day: 1),
            ascent(.fontainebleau, "6A", angle: .overhang, day: 2),
            ascent(.fontainebleau, "6A", angle: .roof, day: 3),
        ])
        XCTAssertEqual(events([s], id: "angle_allrounder").first?.date, date(3))
    }

    // MARK: - Ausdauer

    func testTopsTotal_tierCrossing() {
        let ascents = (0..<10).map { ascent(.fontainebleau, "6A", day: $0) }
        let s = session(ascents)
        XCTAssertEqual(events([s], id: "tops_total").count, 1)
    }

    func testHoursTotal_cumulativeAcrossSessions() {
        // 6 Sessions à 100 Min Aktivzeit (kein pausedSeconds) = 10 h → Tier 0
        let sessions = (0..<6).map { session([], durationMinutes: 100, day: $0) }
        let e = events(sessions, id: "hours_total")
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(e.first?.sessionID, sessions[5].id)
    }

    func testAltitudeTotal_cumulativeAcrossAscents() {
        let ascents = (0..<10).map { ascent(.fontainebleau, "6A", altitude: 10, day: $0) }
        let s = session(ascents)   // 10 × 10 m = 100 m → Tier 0
        XCTAssertEqual(events([s], id: "altitude_total").count, 1)
    }

    func testBigDay_twentyTopsInSession() {
        let ascents = (0..<20).map { ascent(.fontainebleau, "6A", day: $0) }
        let s = session(ascents)
        XCTAssertEqual(events([s], id: "big_day").first?.contextValue, "20")
    }

    func testBigDay_belowThreshold_noUnlock() {
        let ascents = (0..<19).map { ascent(.fontainebleau, "6A", day: $0) }
        let s = session(ascents)
        XCTAssertTrue(events([s], id: "big_day").isEmpty)
    }

    // MARK: - Projekte (Wiederholbarkeit über zwei Projekte)

    func testProjectFirstSend_earliestSentProjectWins() {
        let p1 = project("Später", ascents: [ascent(.fontainebleau, "7A", day: 10)])
        let p2 = project("Zuerst", ascents: [ascent(.fontainebleau, "7A", day: 5)])
        let e = events([], projects: [p1, p2], id: "project_first_send")
        XCTAssertEqual(e.first?.date, date(5))
    }

    func testProjectPersistent_twoProjectsBothQualifyIndependently() {
        func tenAscentProject(_ name: String, sendDay: Int) -> Project {
            var ascents = (0..<9).map { i in ascent(.fontainebleau, "7A", result: .attempt, day: sendDay - 9 + i) }
            ascents.append(ascent(.fontainebleau, "7A", result: .top, day: sendDay))
            return project(name, ascents: ascents)
        }
        let p1 = tenAscentProject("Projekt A", sendDay: 10)
        let p2 = tenAscentProject("Projekt B", sendDay: 20)
        let e = events([], projects: [p1, p2], id: "project_persistent")
        XCTAssertEqual(e.count, 2)
        XCTAssertEqual(Set(e.compactMap(\.contextValue)), ["Projekt A", "Projekt B"])
    }

    func testProjectPersistent_belowTenAscents_noUnlock() {
        let ascents = (0..<9).map { ascent(.fontainebleau, "7A", result: $0 == 8 ? .top : .attempt, day: $0) }
        let p = project("Kurz", ascents: ascents)
        XCTAssertTrue(events([], projects: [p], id: "project_persistent").isEmpty)
    }

    func testProjectLonggame_requiresThreeDistinctDays() {
        let ascents = [
            ascent(.fontainebleau, "7A", result: .attempt, day: 0),
            ascent(.fontainebleau, "7A", result: .attempt, day: 1),
            ascent(.fontainebleau, "7A", result: .top, day: 2),
        ]
        let p = project("Mehrtägig", ascents: ascents)
        XCTAssertEqual(events([], projects: [p], id: "project_longgame").count, 1)
    }

    func testProjectLonggame_singleDay_noUnlock() {
        let ascents = [
            ascent(.fontainebleau, "7A", result: .attempt, day: 0),
            ascent(.fontainebleau, "7A", result: .top, day: 0),
        ]
        let p = project("Eintägig", ascents: ascents)
        XCTAssertTrue(events([], projects: [p], id: "project_longgame").isEmpty)
    }

    // MARK: - Besondere Momente (hidden)

    func testDawnPatrol_beforeSevenAM() {
        let early = Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: date(0))!
        let s = ClimbSession(date: early, durationSeconds: 3600, sessionType: .boulder)
        XCTAssertEqual(events([s], id: "dawn_patrol").count, 1)
    }

    func testDawnPatrol_afterSevenAM_noUnlock() {
        let late = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date(0))!
        let s = ClimbSession(date: late, durationSeconds: 3600, sessionType: .boulder)
        XCTAssertTrue(events([s], id: "dawn_patrol").isEmpty)
    }

    func testGradeLeap_twoCanonicalStepsTriggers() {
        // 6A (order 5) → 6C+ (order 10): Sprung von 5 ≥ 2 → löst aus
        let s = session([ascent(.fontainebleau, "6A", day: 0), ascent(.fontainebleau, "6C+", day: 1)])
        XCTAssertEqual(events([s], id: "grade_leap").first?.contextValue, "6C+")
    }

    func testGradeLeap_oneStep_noUnlock() {
        let s = session([ascent(.fontainebleau, "6A", day: 0), ascent(.fontainebleau, "6A+", day: 1)])
        XCTAssertTrue(events([s], id: "grade_leap").isEmpty)
    }

    func testNewYearClimb_onJanuaryFirst() {
        let jan1 = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 10))!
        let s = ClimbSession(date: jan1, durationSeconds: 3600, sessionType: .boulder)
        XCTAssertEqual(events([s], id: "new_year_climb").count, 1)
    }

    // MARK: - Idempotenz (Doppel-Evaluate)

    func testEvaluate_secondCallWithExistingKeysProducesNoDuplicates() {
        let s = session([ascent(.fontainebleau, "7A", day: 0)])
        let first = AchievementEngine.evaluate(sessions: [s], projects: [], existing: [])
        XCTAssertFalse(first.isEmpty)
        let keys = Set(first.map(existingKey))
        let second = AchievementEngine.evaluate(sessions: [s], projects: [], existing: keys)
        XCTAssertTrue(second.isEmpty)
    }

    func testEvaluate_partialExistingKeys_onlyNewEventsReturned() {
        let sessions = [0, 7, 14, 21].map { session([], day: $0) }
        let first = events(sessions, id: "week_streak")
        XCTAssertEqual(first.count, 1)
        let keys = Set(first.map(existingKey))
        let moreSessions = sessions + [28, 35, 42, 49].map { session([], day: $0) }
        let second = AchievementEngine.evaluate(sessions: moreSessions, projects: [], existing: keys)
            .filter { $0.definitionID == "week_streak" }
        XCTAssertEqual(second.count, 1)   // nur die neue Stufe, nicht die bereits bekannte
        XCTAssertEqual(second.first?.tier, 1)
    }

    // MARK: - progress(for:)

    func testProgress_tiered_belowFirstTier() {
        let sessions = (0..<5).map { session([], day: $0) }
        let p = AchievementEngine.progress(for: "sessions_total", sessions: sessions, projects: [])
        XCTAssertEqual(p?.current, 5)
        XCTAssertEqual(p?.target, 10)
    }

    func testProgress_tiered_allTiersReached_returnsNil() {
        let sessions = (0..<250).map { session([], day: $0) }
        XCTAssertNil(AchievementEngine.progress(for: "sessions_total", sessions: sessions, projects: []))
    }

    func testProgress_hiddenDefinition_isNilForFirstMomentAchievements() {
        XCTAssertNil(AchievementEngine.progress(for: "dawn_patrol", sessions: [], projects: []))
    }

    func testProgress_onceWithScale_disciplineTrio() {
        let sessions = [session([], type: .boulder, day: 0), session([], type: .lead, day: 1)]
        let p = AchievementEngine.progress(for: "discipline_trio", sessions: sessions, projects: [])
        XCTAssertEqual(p?.current, 2)
        XCTAssertEqual(p?.target, 3)
    }

    func testProgress_repeatable_climbDaysYearCurrentYear() {
        // Fixer Bezug mitten im Jahr (date(0) = 2023-11-14) statt Date(): eine
        // reale "jetzt"-Referenz nahe Jahreswechsel würde die 10-Tage-Rückschau
        // sonst über zwei Kalenderjahre spreizen und den Test flaky machen.
        let now = date(0)
        let sessions = (0..<10).map { d in session([], day: -d) }
        let p = AchievementEngine.progress(for: "climb_days_year", sessions: sessions, projects: [], now: now)
        XCTAssertEqual(p?.current, 10)
        XCTAssertEqual(p?.target, 50)
    }

    func testProgress_repeatablePB_returnsNil() {
        let s = session([ascent(.fontainebleau, "6A", day: 0)])
        XCTAssertNil(AchievementEngine.progress(for: "pb_boulder", sessions: [s], projects: []))
    }
}
