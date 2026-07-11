import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let enabledKey = "notificationsEnabled"
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default: return false
        }
    }

    func scheduleReflectionReminder(for session: ClimbSession) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Session reflektieren"

        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE"
        let day = f.string(from: session.date)
        content.body = "Wie war deine \(session.sessionType.label)-Session am \(day)? Jetzt kurz festhalten."
        content.sound = .default

        // Erinnerung 2 Stunden nach der Session, frühestens 30 Sek. in der Zukunft
        let delay = max(30, session.date.addingTimeInterval(2 * 3600).timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(for: session.id),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder(for sessionID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID(for: sessionID)])
    }

    // ERFOLGE-KONZEPT-V2 EP-11: sichert den Unlock-Moment, wenn die App im
    // Hintergrund ist (Watch-DTO kann jederzeit ankommen). Im Vordergrund
    // übernimmt ausschließlich das Overlay — nie beides.
    func notifyUnlock(title: String, subtitle: String) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Erfolg freigeschaltet"
        content.body = subtitle.isEmpty ? title : "\(title) — \(subtitle)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "achievement-\(UUID().uuidString)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func notificationID(for id: UUID) -> String { "reflect-\(id.uuidString)" }
}
