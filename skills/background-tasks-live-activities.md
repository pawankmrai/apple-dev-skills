---
topic: Background Tasks and Live Activities
date: 2026-06-02
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Background Tasks and Live Activities

Modern iOS apps need to perform work even when they're not in the foreground — syncing data, updating widgets, or keeping users informed through Live Activities on the Lock Screen. This skill covers `BGTaskScheduler` for deferred background work and the `ActivityKit` framework for real-time updates via Live Activities.

## Background Tasks with BGTaskScheduler

iOS provides two types of background tasks: **app refresh** tasks for short updates and **processing** tasks for longer operations like database maintenance.

### Registering Background Tasks

Register task identifiers in your `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`, then handle them at launch:

```swift
import BackgroundTasks

@main
struct MyApp: App {
    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.example.refresh",
            using: nil
        ) { task in
            handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### Scheduling and Handling Tasks

```swift
func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(
        identifier: "com.example.refresh"
    )
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

func handleAppRefresh(task: BGAppRefreshTask) {
    scheduleAppRefresh() // reschedule for next time

    let refreshTask = Task {
        do {
            let data = try await DataService.shared.fetchLatest()
            await MainActor.run { DataStore.shared.update(with: data) }
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    task.expirationHandler = {
        refreshTask.cancel()
    }
}
```

### Processing Tasks for Heavy Work

```swift
func scheduleProcessing() {
    let request = BGProcessingTaskRequest(
        identifier: "com.example.cleanup"
    )
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = true
    try? BGTaskScheduler.shared.submit(request)
}
```

## Live Activities with ActivityKit

Live Activities display real-time information on the Lock Screen and Dynamic Island without requiring constant push notifications.

### Defining the Activity

```swift
import ActivityKit

struct DeliveryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var estimatedArrival: Date
        var driverName: String
    }

    var orderNumber: String
    var restaurantName: String
}
```

### Starting a Live Activity

```swift
func startTracking(order: Order) throws -> Activity<DeliveryAttributes> {
    let attributes = DeliveryAttributes(
        orderNumber: order.id,
        restaurantName: order.restaurant
    )

    let initialState = DeliveryAttributes.ContentState(
        status: "Preparing",
        estimatedArrival: order.eta,
        driverName: "Assigned soon"
    )

    let content = ActivityContent(
        state: initialState,
        staleDate: Date(timeIntervalSinceNow: 30 * 60)
    )

    return try Activity.request(
        attributes: attributes,
        content: content,
        pushType: .token // enables push updates
    )
}
```

### Updating and Ending Activities

```swift
func updateDelivery(activity: Activity<DeliveryAttributes>,
                    newState: DeliveryAttributes.ContentState) async {
    let content = ActivityContent(
        state: newState,
        staleDate: Date(timeIntervalSinceNow: 15 * 60)
    )
    await activity.update(content)
}

func endDelivery(activity: Activity<DeliveryAttributes>) async {
    let finalState = DeliveryAttributes.ContentState(
        status: "Delivered",
        estimatedArrival: .now,
        driverName: "Complete"
    )
    let content = ActivityContent(
        state: finalState,
        staleDate: nil
    )
    await activity.end(content, dismissalPolicy: .after(.now + 3600))
}
```

## Best Practices

- **Reschedule immediately**: Always reschedule the next background task inside the handler to maintain a regular cadence.
- **Respect expiration**: Hook into `expirationHandler` and cancel in-flight work cleanly using Swift concurrency's `Task.cancel()`.
- **Minimize processing tasks**: Request external power for heavy work to preserve battery; the system will schedule it overnight.
- **Keep Live Activities lightweight**: Update only the data that changed. Stale dates tell the system when to dim the activity.
- **Use push tokens for remote updates**: After starting a Live Activity with `.token`, send the token to your server and use Apple Push Notification service to update it remotely.
- **Test in Xcode**: Use `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.example.refresh"]` in the debugger to trigger background tasks on demand.

## References

- [Apple Developer: Updating your app with background tasks](https://developer.apple.com/documentation/backgroundtasks)
- [Apple Developer: ActivityKit](https://developer.apple.com/documentation/activitykit)
- [WWDC 2023: Update Live Activities with push notifications](https://developer.apple.com/videos/play/wwdc2023/10185/)
- [WWDC 2022: Meet ActivityKit](https://developer.apple.com/videos/play/wwdc2022/10018/)
