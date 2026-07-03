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
                        day: Int = 0) -> Ascent {
        Ascent(gradeSystem: system, grade: grade, result: result, style: style, date: date(day))
    }

    private func session(_ ascents: [Ascent], type: SessionType = .boulder, day: Int = 0) -> ClimbSession {
        let s = ClimbSession(date: date(day), durationSeconds: 3600, sessionType: type)
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
}
