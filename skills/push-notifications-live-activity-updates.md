---
topic: Push Notifications — Rich Payloads, Actions, and Live Activity Updates
date: 2026-07-01
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: intermediate
---

# Push Notifications — Rich Payloads, Actions, and Live Activity Updates

Remote push notifications remain the primary way apps re-engage users outside the app, and the `UserNotifications` framework has grown well beyond simple alert banners. Modern notifications carry rich media, interactive actions, priority hints for Apple Intelligence ranking, and — via ActivityKit push channels — can start or update a Live Activity without the app ever launching. This skill covers building a complete, current push pipeline: registration, rich payloads, actions, service extensions, and Live Activity push updates.

## Registering for Remote Notifications

```swift
import UserNotifications
import UIKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let granted = try await center.requestAuthorization(
            options: [.alert, .sound, .badge, .providesAppNotificationSettings]
        )
        if granted {
            await UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }
}
```

Handle the device token in your `AppDelegate` (or `UIApplicationDelegateAdaptor` in a SwiftUI app) and forward it to your server over HTTPS — never log it in plaintext in production builds.

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    Task { await PushRegistrar.shared.upload(token: token) }
}
```

## Rich Remote Payloads

A rich push combines `mutable-content` with a Notification Service Extension to download and attach media before the banner renders:

```json
{
  "aps": {
    "alert": { "title": "Order Shipped", "body": "Your order #4821 is on the way." },
    "mutable-content": 1,
    "category": "ORDER_UPDATE",
    "sound": "default",
    "interruption-level": "active",
    "relevance-score": 0.8
  },
  "order-id": "4821",
  "image-url": "https://example.com/orders/4821/thumb.jpg"
}
```

`interruption-level` (`passive`, `active`, `time-sensitive`, `critical`) and `relevance-score` feed Apple Intelligence's on-device priority ranking, which promotes time-sensitive, high-relevance notifications to the top of the stack and demotes generic marketing pushes. Set these deliberately — inflating relevance for low-value pushes gets your app's notifications demoted over time.

## Notification Service Extension

The service extension intercepts the payload before display, letting you download attachments or decrypt content:

```swift
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else { return }
        bestAttemptContent = content

        guard let urlString = request.content.userInfo["image-url"] as? String,
              let url = URL(string: urlString) else {
            contentHandler(content)
            return
        }

        Task {
            do {
                let (localURL, _) = try await URLSession.shared.download(from: url)
                let attachment = try UNNotificationAttachment(identifier: "image", url: localURL)
                content.attachments = [attachment]
            } catch {
                // Fall back to the text-only notification on any failure.
            }
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let bestAttemptContent {
            contentHandler?(bestAttemptContent)
        }
    }
}
```

Service extensions run under a strict ~30-second budget — always call the handler in `serviceExtensionTimeWillExpire`, or the system delivers the original, unmodified payload.

## Actionable Notifications

Register categories with actions at launch so the notification center can render buttons without waiting on your app:

```swift
let confirm = UNNotificationAction(identifier: "CONFIRM", title: "Confirm", options: [.authenticationRequired])
let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze", options: [])
let category = UNNotificationCategory(
    identifier: "ORDER_UPDATE",
    actions: [confirm, snooze],
    intentIdentifiers: [],
    options: [.customDismissAction]
)
UNUserNotificationCenter.current().setNotificationCategories([category])
```

Handle the response in your delegate:

```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    switch response.actionIdentifier {
    case "CONFIRM":
        await OrderStore.shared.confirm(orderId: response.notification.request.content.userInfo["order-id"] as? String)
    case "SNOOZE":
        await OrderStore.shared.snooze()
    default:
        break
    }
}
```

## Push-Driven Live Activity Updates

Live Activities started with `Activity.request` can be updated — or even started and ended — entirely from your server via APNs, without the app running in the foreground. Enroll for push updates when starting the activity:

```swift
import ActivityKit

let activity = try Activity<DeliveryAttributes>.request(
    attributes: DeliveryAttributes(orderId: "4821"),
    content: .init(state: .init(status: "Preparing", eta: .now.addingTimeInterval(1800)), staleDate: nil),
    pushType: .channel
)

for await pushToken in activity.pushTokenUpdates {
    let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
    await PushRegistrar.shared.uploadLiveActivityToken(tokenString, for: activity.id)
}
```

`pushType: .channel` opts into broadcast-capable delivery: your server sends one push to a channel and every subscribed device's Live Activity updates in real time, which scales far better than sending a discrete push per device token for high-frequency updates (sports scores, delivery tracking, live event status).

The server-side payload updates `content-state` directly:

```json
{
  "aps": {
    "timestamp": 1751328000,
    "event": "update",
    "content-state": { "status": "Out for delivery", "eta": 1751331600 },
    "alert": { "title": "Order Update", "body": "Your order is out for delivery." }
  }
}
```

Use `"event": "end"` with a `dismissal-date` to retire the activity remotely once the order is delivered, so you never leave stale Live Activities pinned to the Lock Screen.

## Best Practices

Request notification authorization only after explaining the value to the user in context — a bare permission prompt on first launch has a materially lower opt-in rate than one shown after a relevant action. Set `interruption-level` and `relevance-score` honestly; the system's on-device ranking model learns from dismissal and engagement patterns, and inflated relevance scores lead to long-term demotion. Keep service extensions fast and defensive — always provide a text fallback and never block on a slow network call without a timeout. Prefer `pushType: .channel` for Live Activities that update frequently or fan out to many subscribers, and reserve per-token pushes for low-frequency, single-device updates. Test the full pipeline, including expired tokens and background delivery, using APNs' sandbox environment before shipping.

## References

- [User Notifications — Apple Developer Documentation](https://developer.apple.com/documentation/usernotifications)
- [Notifications Overview — Apple Developer](https://developer.apple.com/notifications/)
- [ActivityKit — Apple Developer Documentation](https://developer.apple.com/documentation/activitykit)
- [Updating Live Activities with ActivityKit push notifications — Apple Developer Documentation](https://developer.apple.com/documentation/activitykit/updating-and-ending-your-live-activity-with-activitykit-push-notifications)
