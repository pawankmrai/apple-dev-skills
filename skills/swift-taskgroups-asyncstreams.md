---
topic: Swift Concurrency — TaskGroups and AsyncSequence/AsyncStream
date: 2026-07-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Concurrency — TaskGroups and AsyncSequence/AsyncStream

Actors solve isolated mutable state, but most real apps also need to fan out dynamic batches of work and consume asynchronous streams of values over time. `TaskGroup` and `AsyncSequence`/`AsyncStream` are the structured-concurrency tools for exactly that, and both compose cleanly with `async`/`await`.

## Task Groups for Dynamic Fan-Out

Use `withTaskGroup` when the number of child tasks isn't known until runtime — for example, downloading a list of URLs of arbitrary length:

```swift
func downloadAll(_ urls: [URL]) async throws -> [Data] {
    try await withThrowingTaskGroup(of: (Int, Data).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask {
                let (data, _) = try await URLSession.shared.data(from: url)
                return (index, data)
            }
        }

        var results = [Data?](repeating: nil, count: urls.count)
        for try await (index, data) in group {
            results[index] = data
        }
        return results.compactMap { $0 }
    }
}
```

Child tasks run on Swift's cooperative thread pool, so adding hundreds of tasks doesn't create hundreds of threads — the runtime schedules them across a bounded pool sized to the machine.

## Respecting Cancellation

Task groups use cooperative cancellation: cancelling the parent task marks all children cancelled, but each child must check `Task.isCancelled` (or let a cancellable API like `URLSession` throw `CancellationError` for it). Use `addTaskUnlessCancelled` to avoid spinning up new work once the group is already cancelled:

```swift
try await withThrowingTaskGroup(of: Void.self) { group in
    for job in jobs {
        let added = group.addTaskUnlessCancelled {
            try Task.checkCancellation()
            try await job.run()
        }
        if !added { break }
    }
    try await group.waitForAll()
}
```

## AsyncStream for Bridging Callbacks

`AsyncStream` turns callback- or delegate-based APIs into something you can `for await` over. It's the go-to bridge for location updates, sensor readings, or notification streams:

```swift
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    func updates() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            let manager = CLLocationManager()
            manager.delegate = self
            manager.startUpdatingLocation()

            continuation.onTermination = { _ in
                manager.stopUpdatingLocation()
            }

            self.onUpdate = { location in
                continuation.yield(location)
            }
        }
    }

    private var onUpdate: ((CLLocation) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locations.forEach { onUpdate?($0) }
    }
}
```

Always set `onTermination` to release underlying resources when the consumer stops iterating or the task is cancelled — otherwise the delegate keeps firing into a stream nobody reads.

## Consuming and Transforming AsyncSequence

`AsyncSequence` supports the same combinators you'd expect from `Sequence`, all lazily and asynchronously:

```swift
func recentErrors(from stream: AsyncStream<LogEvent>) async -> [LogEvent] {
    var results: [LogEvent] = []
    for await event in stream.filter({ $0.level == .error }).prefix(50) {
        results.append(event)
    }
    return results
}
```

For custom producers, conform to `AsyncSequence` directly by implementing `AsyncIteratorProtocol` when you need full control over buffering or backpressure rather than the callback-driven `AsyncStream`.

## TaskGroup + AsyncSequence Together

Task groups themselves conform to `AsyncSequence`, so you can iterate results as they complete rather than waiting for the whole batch:

```swift
await withTaskGroup(of: ImageResult.self) { group in
    for asset in assets {
        group.addTask { await process(asset) }
    }

    for await result in group {
        updateUI(with: result) // shows each thumbnail as it finishes
    }
}
```

## Best Practices

Prefer `withThrowingTaskGroup` over manually collecting an array of `Task` handles — the group guarantees structured cleanup and propagates cancellation automatically when any child throws. Always drain a task group fully (`waitForAll()` or iterate to completion) even after an error, since an unconsumed group leaves orphaned child tasks running until the enclosing scope exits. Keep child task closures `@Sendable` and avoid capturing mutable state directly; return values through the group instead of writing into shared arrays from multiple tasks. For `AsyncStream`, always wire up `onTermination` to avoid leaking timers, delegates, or sockets, and prefer bounded buffering policies (`AsyncStream(bufferingPolicy:)`) when producers can outpace consumers.

## References

- [Swift Concurrency — TaskGroup documentation](https://developer.apple.com/documentation/swift/taskgroup)
- [AsyncSequence documentation](https://developer.apple.com/documentation/swift/asyncsequence)
- [AsyncStream documentation](https://developer.apple.com/documentation/swift/asyncstream)
- [WWDC: Explore structured concurrency in Swift](https://developer.apple.com/videos/play/wwdc2021/10134/)
- [Mastering TaskGroups in Swift — Swift with Majid](https://swiftwithmajid.com/2025/02/04/mastering-task-groups-in-swift/)
