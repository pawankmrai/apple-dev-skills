---
topic: BGContinuedProcessingTask — Finishing User-Initiated Work in the Background
date: 2026-10-02
platform: iOS 26, iPadOS 26
swift: "6.2"
difficulty: intermediate
---

# BGContinuedProcessingTask — Finishing User-Initiated Work in the Background

Before iOS 26, an export or upload started by the user died roughly 30 seconds after they
swiped away, unless you abused `beginBackgroundTask` or rewrote it as a background
`URLSession`. `BGContinuedProcessingTask` fills that gap: the foreground app asks the system
to keep running a **visible, user-initiated** job, and the system shows a Live Activity-style
progress UI the user can monitor or cancel. It is not for prefetching, syncing, or
maintenance — use `BGAppRefreshTask` / `BGProcessingTask` for those.

## Info.plist Setup

Add the identifier to `BGTaskSchedulerPermittedIdentifiers`. Continued-processing tasks
accept a trailing wildcard, so each job can carry a unique suffix:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.example.photos.export.*</string>
</array>
```

## Registering and Submitting

Unlike other BGTask types, continued-processing handlers can be registered dynamically —
right before you submit — rather than at launch.

```swift
import BackgroundTasks

@MainActor
final class ExportController {
    func startExport(of assets: [Asset]) throws {
        let identifier = "com.example.photos.export.\(UUID().uuidString)"

        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGContinuedProcessingTask else { return }
            Task { await Self.run(task, assets: assets) }
        }

        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: "Exporting Photos",
            subtitle: "\(assets.count) items"
        )
        request.strategy = .fail   // default: reject if it can't start now
        try BGTaskScheduler.shared.submit(request)
    }
}
```

`.fail` gives immediate feedback so you can fall back to foreground work; `.queue` lets the
system start the job as soon as resources allow.

## Doing the Work and Reporting Progress

Progress is mandatory: the system watches `task.progress` and may terminate tasks that stop
advancing. Handle expiration by cancelling cooperatively and always call
`setTaskCompleted(success:)`.

```swift
extension ExportController {
    nonisolated static func run(_ task: BGContinuedProcessingTask, assets: [Asset]) async {
        let work = Task {
            task.progress.totalUnitCount = Int64(assets.count)
            for (index, asset) in assets.enumerated() {
                try Task.checkCancellation()
                try await Exporter.export(asset)
                task.progress.completedUnitCount = Int64(index + 1)
                task.updateTitle("Exporting Photos",
                                 subtitle: "\(index + 1) of \(assets.count)")
            }
        }

        task.expirationHandler = { work.cancel() }   // user tapped cancel or system reclaimed

        do {
            try await work.value
            task.setTaskCompleted(success: true)
        } catch {
            await Exporter.cleanUpPartialOutput()
            task.setTaskCompleted(success: false)
        }
    }
}
```

## Requesting GPU Access

On supported devices, continued-processing tasks can use the GPU in the background. Add the
`com.apple.developer.background-tasks.continued-processing.gpu` entitlement and check
support at runtime:

```swift
if BGTaskScheduler.supportedResources.contains(.gpu) {
    request.requiredResources = .gpu
}
```

Only request GPU when the workload truly needs it — it narrows when the system can run you.

## Handling Submission Failure

```swift
do {
    try controller.startExport(of: selection)
} catch let error as BGTaskScheduler.Error {
    // .unavailable, .tooManyPendingTaskRequests, .notPermitted, ...
    logger.warning("Continued processing unavailable: \(error.code.rawValue)")
    await controller.exportInForeground(selection)
}
```

## Best Practices

- Submit only in direct response to a user action (a tap on "Export"), never speculatively.
- Report granular progress; long silent stretches look like a hung task and get killed.
- Give titles and subtitles that make sense out of context — the user sees them system-wide.
- Make work resumable: persist checkpoints so a cancelled export can pick up where it left off.
- Treat `expirationHandler` as cooperative cancellation; finish quickly and clean up temp files.
- Use background `URLSession` for pure network transfers — it survives app termination.
- Test with the debugger: background time is generous while attached, so verify on device unplugged.

## References

- [Finish tasks in the background — WWDC25](https://developer.apple.com/videos/play/wwdc2025/227/)
- [BGContinuedProcessingTask — Apple Developer Documentation](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask)
- [Performing long-running tasks on iOS and iPadOS](https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados)
- [Keep a User-Started Export Alive with BGContinuedProcessingTask](https://www.theswift.dev/posts/bgcontinuedprocessingtask-background-urlsession/)
