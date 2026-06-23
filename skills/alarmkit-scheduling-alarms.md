---
topic: AlarmKit — Scheduling System Alarms and Timers
date: 2026-06-23
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# AlarmKit — Scheduling System Alarms and Timers

AlarmKit, introduced at WWDC 2025 and shipping with iOS 26, gives apps a native way to schedule one-time alarms, weekly repeating alarms, and countdown timers that behave like the built-in Clock app. Unlike a notification scheduled through `UserNotifications`, an AlarmKit alert cuts through silent mode and Focus with a persistent banner and sound — without requiring the rarely-granted Critical Alerts entitlement. That makes it the right tool whenever a reminder absolutely must surface at the right moment: cooking timers, workout intervals, medication reminders, or wake-up alarms.

## Why Not Just Use UserNotifications?

`UNNotificationRequest` is great for messages, badges, and silenceable reminders, but it respects Focus and silent mode unless your app holds Critical Alerts — an entitlement Apple grants sparingly. AlarmKit alerts are designed to always break through, render a dedicated full-screen presentation on the Lock Screen, and integrate with the Dynamic Island via a Live Activity. Reach for AlarmKit specifically when missing the alert has real consequences for the user.

## Requesting Authorization

Add `NSAlarmKitUsageDescription` to `Info.plist` with a short explanation of why your app needs to schedule alarms. The system prompt appears the first time you call `requestAuthorization()`:

```swift
import AlarmKit

private let manager = AlarmManager.shared

private func checkForAuthorization() async -> Bool {
    switch manager.authorizationState {
    case .notDetermined:
        do {
            return try await manager.requestAuthorization() == .authorized
        } catch {
            return false
        }
    case .authorized: return true
    case .denied: return false
    @unknown default: return false
    }
}
```

## Defining Presentation, Metadata, and Attributes

Every alarm needs an `AlarmPresentation.Alert` (what the user sees) and `AlarmAttributes`, which is generic over a metadata type conforming to `AlarmMetadata`. Even with no custom data, you must supply a concrete type:

```swift
nonisolated struct TimerData: AlarmMetadata {}

private func makeAttributes() -> AlarmAttributes<TimerData> {
    let alert = AlarmPresentation.Alert(
        title: "Ready!",
        stopButton: AlarmButton(text: "Done", textColor: .pink, systemImageName: "checkmark")
    )
    return AlarmAttributes(
        presentation: AlarmPresentation(alert: alert),
        tintColor: .pink
    )
}
```

Mark the metadata type `nonisolated` — in Xcode 26 projects, types are `MainActor`-isolated by default, which breaks `AlarmMetadata` conformance otherwise.

## Scheduling a Countdown Timer

```swift
private func scheduleTimer(seconds: TimeInterval) async {
    guard await checkForAuthorization() else { return }
    do {
        _ = try await manager.schedule(
            id: UUID(),
            configuration: .timer(duration: seconds, attributes: makeAttributes())
        )
    } catch {
        print("Scheduling error: \(error)")
    }
}
```

## Scheduling a Recurring Wake-Up Alarm

For a fixed time of day with weekday recurrence, build an `Alarm.Schedule.Relative` and wrap it in `AlarmConfiguration`:

```swift
private func scheduleWeekdayAlarm() async throws {
    let time = Alarm.Schedule.Relative.Time(hour: 7, minute: 30)
    let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    )
    let schedule = Alarm.Schedule.relative(
        Alarm.Schedule.Relative(time: time, repeats: recurrence)
    )
    let configuration = AlarmConfiguration(schedule: schedule, attributes: makeAttributes())
    try await manager.schedule(id: UUID(), configuration: configuration)
}
```

A one-off alarm at an exact date uses `Alarm.Schedule.fixed(myDate)` instead of `.relative(...)`.

## Observing and Canceling Active Alarms

`AlarmManager` exposes an `AsyncSequence` of the full alarm set, so the UI can stay in sync without polling:

```swift
struct ActiveAlarmsList: View {
    @State private var alarms: [Alarm] = []

    var body: some View {
        List(alarms) { alarm in
            HStack {
                Text("\(alarm.id)").font(.caption)
                Spacer()
                Button(role: .cancel) {
                    try? AlarmManager.shared.cancel(id: alarm.id)
                } label: {
                    Image(systemName: "xmark.circle")
                }
            }
        }
        .task {
            for await updated in AlarmManager.shared.alarmUpdates {
                alarms = updated
            }
        }
    }
}
```

`Alarm` only reports static info (id, configured duration, state such as `.countdown`, `.alerting`, or `.paused`) — for a live countdown value, render the presentation state inside a Live Activity widget driven by `AlarmAttributes<TimerData>`.

## Best Practices

- Request authorization lazily, the first time the user actually schedules an alarm — not at app launch.
- Keep alert titles to 4–5 words; the compact Lock Screen banner truncates aggressively.
- Always supply a `nonisolated` `AlarmMetadata` type, even an empty one — the generic parameter can't be inferred otherwise.
- Pair countdown timers with a Live Activity widget extension so users see a running countdown, not just the final alert.
- Don't replace every notification with AlarmKit — reserve it for alerts where being silenced by Focus or Do Not Disturb would defeat the feature's purpose.

## References

- [AlarmKit Documentation](https://developer.apple.com/documentation/alarmkit)
- [Wake up to the AlarmKit API — WWDC25](https://developer.apple.com/videos/play/wwdc2025/230/)
- [Scheduling and Managing Alarms in SwiftUI with AlarmKit](https://www.createwithswift.com/scheduling-and-managing-alarms-in-swiftui-with-alarmkit/)
- [Schedule a countdown timer with AlarmKit](https://nilcoalescing.com/blog/CountdownTimerWithAlarmKit)
