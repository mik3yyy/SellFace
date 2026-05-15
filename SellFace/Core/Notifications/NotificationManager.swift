import UIKit
import UserNotifications

final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return granted
        } catch {
            return false
        }
    }

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        Task { await registerTokenWithBackend(token) }
    }

    private func registerTokenWithBackend(_ token: String) async {
        guard !APIClient.shared.mockMode else { return }
        do {
            _ = try await APIClient.shared.request(
                endpoint: .registerDeviceToken,
                body: DeviceTokenRequest(token: token),
                responseType: EmptyResponse.self
            )
        } catch {
            // Non-fatal — push notifications will still work on next launch if this fails.
            print("[NotificationManager] Failed to register device token: \(error)")
        }
    }

    func scheduleLocalNotification(title: String, body: String, delay: TimeInterval = 1) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleImagesReadyNotification(personaName: String) {
        scheduleLocalNotification(
            title: "Your photos are ready!",
            body: "\(personaName)'s generated images are ready to view.",
            delay: 2
        )
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
