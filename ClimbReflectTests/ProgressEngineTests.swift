import XCTest
@testable import ClimbReflect

final class ProgressEngineTests: XCTestCase {

    // MARK: - Helpers

    private func date(_ offsetDays: Int) -> Date {
        // fester Bezug, damit Monatsgrenzen deterministisch sind
        let base = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
        return Calendar.current.date(byAdding: .day, value: offsetDays, to: base)!
    }

    private func ascent(_ system: GradeSystem, _ grade: String,
                        result: AscentResult = .top, style: AscentStyle? = nil,
                        angle: WallAngle? = nil, day: Int = 0) -> Ascent {
        Ascent(gradeSystem: system, grade: grade, result: result, style: style,
               wallAngle: angle, date: date(day))
    }

    private func session(_ ascents: [Ascent], type: SessionType = .boulder,
                         limiters: [Limiter] = [], day: Int = 0) -> ClimbSession {
        let s = ClimbSession(date: date(day), durationSeconds: 3600, sessionType: type, limiters: limiters)
        for a in ascents { a.session = s; s.ascents.append(a) }
        return s
    }

    // MARK: - personalBests

    func testPersonalBests_mixedScales_highestCanonicalWins() {
        let s = session([
            ascent(.fontainebleau, "7A", day: 0),   // canonical 11
            ascent(.vScale, "V4", day: 1)           // canonical 7
        ])
        let best = ProgressEngine.personalBests([s], discipline: .boulder)
        XCTAssertEqual(best.send?.grade, "7A")
    }

    func testPersonalBests_tie_earliestDateWins() {
        let s = session([
            ascent(.fontainebleau, "7A", day: 10),
            ascent(.fontainebleau, "7A", day: 2)
        ])
        let best = ProgressEngine.personalBests([s], discipline: .boulder)
        XCTAssertEqual(best.send?.date, date(2))
    }

    func testPersonalBests_ungradedExcluded() {
        let s = session([ ascent(.fontainebleau, Ascent.ungraded) ])
        let best = ProgressEngine.personalBests([s], discipline: .boulder)
        XCTAssertNil(best.send)
    }

    func testPersonalBests_emptyHistory_nil() {
        let best = ProgressEngine.personalBests([], discipline: .boulder)
        XCTAssertNil(best.send)
        XCTAssertNil(best.flash)
    }

    func testPersonalBests_ropeFlashOrOnsight() {
        let s = session([
            ascent(.french, "6a", style: .onsight, day: 0),
            ascent(.french, "6b", style: .redpoint, day: 1)   // kein Flash/Onsight
        ], type: .lead)
        let best = ProgressEngine.personalBests([s], discipline: .rope)
        // Flash-PB = härtester Flash/Onsight → 6a (onsight), nicht 6b (redpoint)
        XCTAssertEqual(best.flash?.grade, "6a")
        XCTAssertEqual(best.send?.grade, "6b")
    }

    func testPersonalBests_disciplineSeparation() {
        let s = session([
            ascent(.fontainebleau, "7A", day: 0),
            ascent(.french, "6a", day: 0)
        ])
        XCTAssertEqual(ProgressEngine.personalBests([s], discipline: .boulder).send?.grade, "7A")
        XCTAssertEqual(ProgressEngine.personalBests([s], discipline: .rope).send?.grade, "6a")
    }

    // MARK: - periodHighlights (MO-2)

    func testPeriodHighlights_firstSendWithinPeriod() {
        let s = session([ascent(.fontainebleau, "6A", day: -10)], day: -10)
        let h = ProgressEngine.periodHighlights([s], discipline: .boulder,
                                                monthsBack: 3, now: date(0))
        XCTAssertEqual(h.firstSends.map(\.grade), ["6A"])
    }

    func testPeriodHighlights_firstSendOutsidePeriodExcluded() {
        let s = session([ascent(.fontainebleau, "6A", day: -200)], day: -200)
        let h = ProgressEngine.periodHighlights([s], discipline: .boulder,
                                                monthsBack: 3, now: date(0))
        XCTAssertTrue(h.firstSends.isEmpty)
    }

    func testPeriodHighlights_scaleMixIsNotFirstSend() {
        // 6C wurde alt (vor dem Zeitraum) gesendet; ein V5 (== Fb 6C) im Zeitraum
        // ist derselbe kanonische Grad → KEIN Erst-Send.
        let old = session([ascent(.fontainebleau, "6C", day: -200)], day: -200)
        let recent = session([ascent(.vScale, "V5", day: -5)], day: -5)
        let h = ProgressEngine.periodHighlights([old, recent], discipline: .boulder,
                                                monthsBack: 3, now: date(0))
        XCTAssertTrue(h.firstSends.isEmpty)
    }

    func testPeriodHighlights_allTimeYieldsNoFirstSends() {
        let s = session([ascent(.fontainebleau, "6A", day: -5)], day: -5)
        let h = ProgressEngine.periodHighlights([s], discipline: .boulder,
                                                monthsBack: nil, now: date(0))
        XCTAssertTrue(h.firstSends.isEmpty)   // Konsens-Punkt 2
        XCTAssertNotNil(h.hardestSend)        // Bestwert bleibt
    }

    func testPeriodHighlights_isAllTimeBestTrue() {
        let s = session([ascent(.fontainebleau, "7A", day: -5)], day: -5)
        let h = ProgressEngine.periodHighlights([s], discipline: .boulder,
                                                monthsBack: 3, now: date(0))
        XCTAssertTrue(h.isAllTimeBest)
        XCTAssertEqual(h.hardestSend?.grade, "7A")
    }

    func testPeriodHighlights_isAllTimeBestFalseWhenOlderHarder() {
        let old = session([ascent(.fontainebleau, "7B", day: -200)], day: -200)
        let recent = session([ascent(.fontainebleau, "6C", day: -5)], day: -5)
        let h = ProgressEngine.periodHighlights([old, recent], discipline: .boulder,
                                                monthsBack: 3, now: date(0))
        XCTAssertFalse(h.isAllTimeBest)
        XCTAssertEqual(h.hardestSend?.grade, "6C")   // härtester IM Zeitraum
    }

    func testPeriodHighlights_emptyHistory() {
        let h = ProgressEngine.periodHighlights([], discipline: .boulder,
                                                monthsBack: 3, now: date(0))
        XCTAssertTrue(h.firstSends.isEmpty)
        XCTAssertNil(h.hardestSend)
        XCTAssertFalse(h.isAllTimeBest)
    }

    // MARK: - nextGrade (MO-3)

    func testNextGrade_middleRungReturnsSuccessor() {
        // order 11 = Fb "7A"; Nachfolger order 12 = "7A+"
        XCTAssertEqual(ProgressEngine.nextGrade(afterOrder: 11, discipline: .boulder), "7A+")
    }

    func testNextGrade_ropeMiddleRung() {
        // routeFrench order 12 = "7a"; Nachfolger order 13 = "7a+"
        XCTAssertEqual(ProgressEngine.nextGrade(afterOrder: 12, discipline: .rope), "7a+")
    }

    func testNextGrade_vScaleDisplay() {
        UserDefaults.standard.set(GradeSystem.vScale.rawValue, forKey: "boulderScale")
        defer { UserDefaults.standard.removeObject(forKey: "boulderScale") }
        // Font-Referenz order 10 = "6C+"; Nachfolger 11 = Fb "7A" → V-Scale "V6"
        XCTAssertEqual(ProgressEngine.nextGrade(afterOrder: 10, discipline: .boulder), "V6")
    }

    func testNextGrade_topOfLadderIsNil() {
        // boulderFb endet bei order 23 = "9A" → Nachfolger außerhalb der Leiter → nil
        XCTAssertNil(ProgressEngine.nextGrade(afterOrder: 23, discipline: .boulder))
    }

    func testPersonalBest_carriesCanonicalOrder() {
        let s = session([ascent(.fontainebleau, "7A", day: 0)])
        let best = ProgressEngine.personalBests([s], discipline: .boulder)
        XCTAssertEqual(best.send?.order, 11)   // Fb "7A" == canonical 11
    }

    // MARK: - gradeTimeline

    func testGradeTimeline_gapMonthOmitted() {
        // Sends in Monat 0 und ~2 Monate später, dazwischen Lücke
        let s0 = session([ascent(.fontainebleau, "6A", day: 0)], day: 0)
        let s2 = session([ascent(.fontainebleau, "6B", day: 62)], day: 62)
        let points = ProgressEngine.gradeTimeline([s0, s2], discipline: .boulder, monthsBack: nil)
        // Nur Monate mit Sends erscheinen (kein interpolierter Lücken-Monat)
        XCTAssertEqual(points.count, 2)
        XCTAssertTrue(points.allSatisfy { $0.sendOrder != nil })
    }

    func testGradeTimeline_flashSubsetOfSend() {
        let s = session([
            ascent(.fontainebleau, "7A", day: 0),                    // Send, kein Flash
            ascent(.fontainebleau, "6B", style: .flash, day: 1)      // Flash
        ], day: 0)
        let p = ProgressEngine.gradeTimeline([s], discipline: .boulder, monthsBack: nil).first!
        XCTAssertNotNil(p.sendOrder)
        // Flash-Order ≤ Send-Order (Flash ist Teilmenge)
        XCTAssertLessThanOrEqual(p.flashOrder ?? Int.min, p.sendOrder ?? 0)
    }

    func testGradeLabel_boulderOrderToDisplay() {
        // canonical 11 = Fb "7A" (Standard-Anzeige = Fb)
        XCTAssertEqual(ProgressEngine.gradeLabel(forOrder: 11, discipline: .boulder), "7A")
    }

    // MARK: - pyramid

    func testPyramid_vScaleAscentLandsInFbBucket() {
        // V4 (~6B+) in Standard-Anzeige Fb → landet als Fb-Grad, nicht als eigener V-Balken
        let s = session([ascent(.vScale, "V4", day: 0)])
        let rows = ProgressEngine.pyramid([s], discipline: .boulder, monthsBack: nil)
        XCTAssertEqual(rows.count, 1)
        XCTAssertFalse(rows[0].grade.hasPrefix("V"))   // ins Fb-System konvertiert
        XCTAssertEqual(rows[0].sends, 1)
    }

    func testPyramid_sendVsFailedSplit() {
        let s = session([
            ascent(.fontainebleau, "6A", result: .top, day: 0),
            ascent(.fontainebleau, "6A", result: .attempt, day: 0)
        ])
        let row = ProgressEngine.pyramid([s], discipline: .boulder, monthsBack: nil).first!
        XCTAssertEqual(row.sends, 1)
        XCTAssertEqual(row.failedTries, 1)
    }

    func testPyramid_ungradedExcluded() {
        let s = session([ascent(.fontainebleau, Ascent.ungraded, result: .top)])
        XCTAssertTrue(ProgressEngine.pyramid([s], discipline: .boulder, monthsBack: nil).isEmpty)
    }

    // MARK: - comfortGrade

    private func repeated(_ system: GradeSystem, _ grade: String,
                          sends: Int, fails: Int) -> [Ascent] {
        (0..<sends).map { _ in ascent(system, grade, result: .top) }
        + (0..<fails).map { _ in ascent(system, grade, result: .attempt) }
    }

    func testComfortGrade_exactly60PercentQualifies() {
        // 3 Sends / 5 Begehungen = 60 %
        let s = session(repeated(.fontainebleau, "6A", sends: 3, fails: 2))
        XCTAssertEqual(ProgressEngine.comfortGrade([s], discipline: .boulder, monthsBack: nil), "6A")
    }

    func testComfortGrade_belowSampleSizeIgnored() {
        // 4 Begehungen auf hohem Grad (unter n=5) → ignoriert
        let s = session(repeated(.fontainebleau, "7A", sends: 4, fails: 0))
        XCTAssertNil(ProgressEngine.comfortGrade([s], discipline: .boulder, monthsBack: nil))
    }

    func testComfortGrade_highestQualifyingWins() {
        let s = session(
            repeated(.fontainebleau, "6A", sends: 5, fails: 0)   // 100 %
            + repeated(.fontainebleau, "6B", sends: 4, fails: 1) // 80 %, höher
        )
        XCTAssertEqual(ProgressEngine.comfortGrade([s], discipline: .boulder, monthsBack: nil), "6B")
    }

    // MARK: - climbDaysPerMonth / periodTotals

    func testClimbDaysPerMonth_sameDayCountedOnce() {
        // zwei Sessions am selben Tag → 1 Klettertag
        let s1 = session([ascent(.fontainebleau, "6A")], day: 0)
        let s2 = session([ascent(.fontainebleau, "6B")], day: 0)
        let months = ProgressEngine.climbDaysPerMonth([s1, s2], discipline: .boulder,
                                                       monthsBack: 1, now: date(0))
        XCTAssertEqual(months.last?.days, 1)
    }

    func testClimbDaysPerMonth_disciplineSeparated() {
        // Boulder + Seil am selben Tag → je Disziplin 1 Tag
        let b = session([ascent(.fontainebleau, "6A")], type: .boulder, day: 0)
        let r = session([ascent(.french, "6a")], type: .lead, day: 0)
        let boulder = ProgressEngine.climbDaysPerMonth([b, r], discipline: .boulder,
                                                        monthsBack: 1, now: date(0))
        let rope = ProgressEngine.climbDaysPerMonth([b, r], discipline: .rope,
                                                     monthsBack: 1, now: date(0))
        XCTAssertEqual(boulder.last?.days, 1)
        XCTAssertEqual(rope.last?.days, 1)
    }

    func testClimbDaysPerMonth_emptyMonthIsZero() {
        // keine Sessions → alle Monate 0 (Nullen sind hier echt)
        let months = ProgressEngine.climbDaysPerMonth([], discipline: .boulder,
                                                       monthsBack: 3, now: date(0))
        XCTAssertEqual(months.count, 3)
        XCTAssertTrue(months.allSatisfy { $0.days == 0 })
    }

    // MARK: - styleRates / limiterCounts

    func testStyleRates_belowSampleSizeOmitted_atSampleSizeAppears() {
        // Overhang: 4 Begehungen (unter n=5) → fehlt; Slab: 5 → erscheint
        let over = (0..<4).map { _ in ascent(.fontainebleau, "6A", angle: .overhang) }
        let slab = (0..<5).map { _ in ascent(.fontainebleau, "6A", angle: .slab) }
        let s = session(over + slab)
        let rates = ProgressEngine.styleRates([s], discipline: .boulder, monthsBack: nil)
        let angles = rates.filter { $0.category == "Wandwinkel" }
        XCTAssertEqual(angles.count, 1)
        XCTAssertEqual(angles.first?.sample, 5)
    }

    // MARK: - stylePendingGroups / comfortCandidate (MO-4)

    func testStylePendingGroups_belowThresholdAppears_atThresholdMovesToRates() {
        let over = (0..<4).map { _ in ascent(.fontainebleau, "6A", angle: .overhang) }
        let slab = (0..<5).map { _ in ascent(.fontainebleau, "6A", angle: .slab) }
        let s = session(over + slab)
        let pending = ProgressEngine.stylePendingGroups([s], discipline: .boulder, monthsBack: nil)
            .filter { $0.category == "Wandwinkel" }
        XCTAssertEqual(pending.map(\.label), ["Überhang"])   // n=4 im Pending
        XCTAssertEqual(pending.first?.sample, 4)
        let rates = ProgressEngine.styleRates([s], discipline: .boulder, monthsBack: nil)
            .filter { $0.category == "Wandwinkel" }
        XCTAssertEqual(rates.map(\.label), ["Platte"])       // n=5 wandert in die Quoten
    }

    func testComfortCandidate_prefersHigherTotalOverGrade() {
        let s = session(
            repeated(.fontainebleau, "6A", sends: 4, fails: 0)
            + repeated(.fontainebleau, "6C", sends: 2, fails: 0)
        )
        let c = ProgressEngine.comfortCandidate([s], discipline: .boulder, monthsBack: nil)
        XCTAssertEqual(c?.grade, "6A")   // total 4 schlägt den höheren, aber selteneren 6C
        XCTAssertEqual(c?.sample, 4)
    }

    func testComfortCandidate_tieBreaksOnGrade() {
        let s = session(
            repeated(.fontainebleau, "6A", sends: 3, fails: 0)
            + repeated(.fontainebleau, "6C", sends: 3, fails: 0)
        )
        let c = ProgressEngine.comfortCandidate([s], discipline: .boulder, monthsBack: nil)
        XCTAssertEqual(c?.grade, "6C")   // Gleichstand → höherer Grad
    }

    func testComfortCandidate_fullSampleRowNotCandidate() {
        let s = session(repeated(.fontainebleau, "6A", sends: 5, fails: 0))
        XCTAssertNil(ProgressEngine.comfortCandidate([s], discipline: .boulder, monthsBack: nil))
    }

    func testComfortCandidate_nilWhenEmpty() {
        XCTAssertNil(ProgressEngine.comfortCandidate([], discipline: .boulder, monthsBack: nil))
    }

    func testLimiterCounts_periodBoundary() {
        // Session vor dem Fenster fällt raus, Session im Fenster zählt
        let inside = session([ascent(.fontainebleau, "6A")], limiters: [.fingerStrength], day: 0)
        let old = session([ascent(.fontainebleau, "6A")], limiters: [.fingerStrength], day: -400)
        let counts = ProgressEngine.limiterCounts([inside, old], monthsBack: 6, now: date(0))
        XCTAssertEqual(counts.first?.limiter, .fingerStrength)
        XCTAssertEqual(counts.first?.count, 1)   // nur die Session im Zeitraum
    }

    func testSessionsThisWeek_onlyClimbingInCurrentWeek() {
        let now = date(0)
        let today = session([ascent(.fontainebleau, "6A")], day: 0)
        let lastWeek = session([ascent(.fontainebleau, "6A")], day: -10)
        let training = session([], type: .training, day: 0)
        XCTAssertEqual(
            ProgressEngine.sessionsThisWeek([today, lastWeek, training], now: now), 1)
    }

    func testPeriodTotals_sendsAndDays() {
        let s1 = session([
            ascent(.fontainebleau, "6A", result: .top),
            ascent(.fontainebleau, "6B", result: .attempt)   // kein Send
        ], day: 0)
        let s2 = session([ascent(.fontainebleau, "6C", result: .top)], day: 1)
        let totals = ProgressEngine.periodTotals([s1, s2], discipline: .boulder, monthsBack: nil)
        XCTAssertEqual(totals.sends, 2)      // nur Tops
        XCTAssertEqual(totals.climbDays, 2)  // zwei verschiedene Tage
    }

    // MARK: - monthRecap (MO-6)   (Basis-Datum date(0) = 2023-11-14 → Monat November)

    func testMonthRecap_monthBoundariesExclusive() {
        let inMonth = session([ascent(.fontainebleau, "6A", day: 0)], day: 0)     // Nov 14
        let before = session([ascent(.fontainebleau, "7A", day: -14)], day: -14)  // Okt 31
        let after = session([ascent(.fontainebleau, "7B", day: 17)], day: 17)     // Dez 1
        let r = ProgressEngine.monthRecap([inMonth, before, after], month: date(0))
        XCTAssertEqual(r.boulder.climbDays, 1)
        XCTAssertEqual(r.boulder.sends, 1)
        XCTAssertEqual(r.boulder.hardestGrade, "6A")   // nur der November-Send
    }

    func testMonthRecap_disciplineSeparation() {
        let b = session([ascent(.fontainebleau, "6A", day: 0)], type: .boulder, day: 0)
        let r = session([ascent(.french, "6a", day: 1)], type: .lead, day: 1)
        let recap = ProgressEngine.monthRecap([b, r], month: date(0))
        XCTAssertEqual(recap.boulder.climbDays, 1)
        XCTAssertEqual(recap.boulder.sends, 1)
        XCTAssertEqual(recap.rope.climbDays, 1)
        XCTAssertEqual(recap.rope.sends, 1)
    }

    func testMonthRecap_firstSendCountRespectsHistory() {
        let prior = session([ascent(.fontainebleau, "6A", day: -20)], day: -20)  // Okt 25
        let now = session([
            ascent(.fontainebleau, "6A", day: 2),   // Wiederholung → kein Erst-Send
            ascent(.fontainebleau, "7A", day: 3)     // Erst-Send im November
        ], day: 2)
        let r = ProgressEngine.monthRecap([prior, now], month: date(0))
        XCTAssertEqual(r.boulder.firstSendCount, 1)   // nur 7A
    }

    func testMonthRecap_isEmptyWithoutClimbSession() {
        let training = session([], type: .training, day: 0)
        XCTAssertTrue(ProgressEngine.monthRecap([training], month: date(0)).isEmpty)
    }

    func testMonthRecap_notEmptyWithClimbSession() {
        let b = session([ascent(.fontainebleau, "6A", day: 0)], day: 0)
        XCTAssertFalse(ProgressEngine.monthRecap([b], month: date(0)).isEmpty)
    }
}
