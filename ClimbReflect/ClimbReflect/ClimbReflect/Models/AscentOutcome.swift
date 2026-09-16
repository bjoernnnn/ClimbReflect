import Foundation

/// EF-1/E6/E7: Ergebnis + Stil als eine Auswahl für das Quick-Log – Boulder
/// bekommt Flash/Top/Versuch, Seil zusätzlich Onsight/Rotpunkt. „Abgebrochen"
/// und Stil „Projekt" leben nur noch unter „Details" (AddAscentView).
struct AscentOutcome: Hashable, Identifiable {
    let result: AscentResult
    let style: AscentStyle?
    var id: String { result.rawValue + (style?.rawValue ?? "") }

    var label: String { style?.label ?? result.label }
    var symbol: String { style?.symbol ?? result.symbol }

    static func quick(for discipline: ProgressEngine.Discipline) -> [AscentOutcome] {
        discipline.isBoulder
            ? [.init(result: .top, style: .flash), .init(result: .top, style: nil), .init(result: .attempt, style: nil)]
            : [.init(result: .top, style: .onsight), .init(result: .top, style: .flash),
               .init(result: .top, style: .redpoint), .init(result: .attempt, style: nil)]
    }
}
