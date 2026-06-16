import Foundation

struct WatchLiveStatus: Codable {
    let elapsedSeconds: Int
    let sessionTypeRaw: String
    let attemptCount: Int
    let isPaused: Bool

    static let key = "watchLiveStatus"

    var elapsedFormatted: String {
        let s = elapsedSeconds
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }
}
