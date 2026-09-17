import XCTest
@testable import ClimbReflect

final class GradeDefaultsTests: XCTestCase {

    // MARK: - Helpers

    private func date(_ offsetDays: Int) -> Date {
        let base = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
        return Calendar.current.date(byAdding: .day, value: offsetDays, to: base)!
    }

    private func ascent(_ system: GradeSystem, _ grade: String, day: Int = 0) -> Ascent {
        Ascent(gradeSystem: system, grade: grade, result: .top, date: date(day))
    }

    private func session(_ ascents: [Ascent], type: SessionType = .boulder, day: Int = 0) -> ClimbSession {
        let s = ClimbSession(date: date(day), durationSeconds: 3600, sessionType: type)
        for a in ascents { a.session = s; s.ascents.append(a) }
        return s
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "boulderScale")
        UserDefaults.standard.removeObject(forKey: "routeScale")
        super.tearDown()
    }

    // MARK: - Fälle

    func testProjectGradeWins() {
        let project = Project(name: "Testprojekt")
        project.gradeSystemRaw = GradeSystem.fontainebleau.rawValue
        project.targetGradeRaw = "7A"

        let s = session([ascent(.fontainebleau, "6A")])
        let result = GradeDefaults.initial(session: s, project: project, allSessions: [s])
        XCTAssertEqual(result.grade, "7A")
        XCTAssertEqual(result.system, .fontainebleau)
    }

    func testSessionAscentWinsOverHistory() {
        let s = session([ascent(.fontainebleau, "6B", day: 0)], day: 0)
        let older = session([ascent(.fontainebleau, "7A", day: -10)], day: -10)
        let result = GradeDefaults.initial(session: s, project: nil, allSessions: [older, s])
        XCTAssertEqual(result.grade, "6B")
    }

    func testHistoryUsedWhenSessionEmpty() {
        let empty = session([])
        let older = session([ascent(.fontainebleau, "6C", day: -5)], day: -5)
        let result = GradeDefaults.initial(session: empty, project: nil, allSessions: [older, empty])
        XCTAssertEqual(result.grade, "6C")
    }

    func testRopeSessionWithoutDataFallsBackToFrenchFirstGrade() {
        let s = session([], type: .lead)
        let result = GradeDefaults.initial(session: s, project: nil, allSessions: [s])
        XCTAssertEqual(result.system, .french)
        XCTAssertEqual(result.grade, GradeSystem.french.grades.first)
    }

    func testBoulderProjectInRopeSessionIsIgnored() {
        let project = Project(name: "Boulder-Projekt")
        project.gradeSystemRaw = GradeSystem.fontainebleau.rawValue
        project.targetGradeRaw = "6B"

        let s = session([ascent(.french, "6a")], type: .lead)
        let result = GradeDefaults.initial(session: s, project: project, allSessions: [s])
        XCTAssertEqual(result.system, .french)
        XCTAssertEqual(result.grade, "6a")
    }

    func testBoulderScalePreferenceRespected() {
        UserDefaults.standard.set(GradeSystem.vScale.rawValue, forKey: "boulderScale")
        let s = session([])
        let result = GradeDefaults.initial(session: s, project: nil, allSessions: [s])
        XCTAssertEqual(result.system, .vScale)
        XCTAssertEqual(result.grade, GradeSystem.vScale.grades.first)
    }
}
