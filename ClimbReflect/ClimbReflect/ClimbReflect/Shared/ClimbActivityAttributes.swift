import ActivityKit
import Foundation

struct ClimbActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startedAt: Date
        var isPaused: Bool
        var pausedElapsed: Int
        var sessionTypeRaw: String
    }

    var sportLabel: String
    var sportSymbol: String
}
