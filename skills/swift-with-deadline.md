---
topic: Swift withDeadline — Composable, Drift-Free Timeouts for Structured Concurrency
date: 2026-08-12
platform: iOS 26, macOS 26
swift: "6.4"
difficulty: intermediate
---

# Swift withDeadline — Composable, Drift-Free Timeouts for Structured Concurrency

SE-0526 was accepted with modifications in August 2026, bringing `withDeadline` to the
Concurrency module. It replaces the roll-your-own `withThrowingTaskGroup` + `Task.sleep`
race most codebases accumulate for timeouts, and fixes a bug duration-based timeouts can't:
drift across nested calls. Rather than passing a relative duration down through layers of
async calls — losing time to scheduling overhead at each layer — `withDeadline` operates on
an absolute `Clock.Instant`, so every layer agrees on exactly when the operation must finish.

## The Problem With Duration-Based Timeouts

A function that applies a 10-second timeout and calls two sub-operations, each with "the
remaining time," silently erodes its own budget: scheduling, argument evaluation, and
function prologues all eat into the duration before it reaches the next layer. The second
sub-operation ends up with less time than intended. Absolute deadlines avoid this — every
nested scope sees the same instant.

## Basic Usage

```swift
let clock = ContinuousClock()

do {
    let result = try await withDeadline(clock.now.advanced(by: .seconds(5)), clock: clock) {
        try await fetchDataFromServer()
    }
    print("Data received: \(result)")
} catch {
    print("Request failed: \(error)")
}
```

A shorthand overload skips the manual instant construction:

```swift
let result = try await withDeadline(in: .seconds(5)) {
    try await fetchDataFromServer()
}
```

If the operation finishes first, `withDeadline` returns or throws whatever it returned or
threw. If the deadline expires first, the operation is cancelled, and `withDeadline` waits
for it to return before propagating the result — it never abandons work, so `defer` blocks
and other cleanup still run.

## Coordinating Multiple Operations

Because the deadline is an absolute instant rather than a duration, independent operations
can share one without recomputing anything:

```swift
let clock = ContinuousClock()
let deadline = clock.now.advanced(by: .seconds(10))

async let user = withDeadline(deadline, clock: clock) {
    try await fetchUser()
}
async let prefs = withDeadline(deadline, clock: clock) {
    try await fetchPreferences()
}

let (userData, prefsData) = try await (user, prefs)
```

## Nesting Takes the Minimum

Nested `withDeadline` calls compose by taking the minimum expiration — no comparison code
required. An inner deadline of 2 seconds inside an outer deadline of 3 seconds always fires
at 2 seconds; swap the numbers and the outer bound still governs. This holds even across
library boundaries where neither side knows about the other's deadline.

## Actor-Isolated Closures

Unlike hand-rolled timeout helpers that require `@Sendable` and `@escaping` closures —
which can't touch actor-isolated state — `withDeadline`'s operation closure is
`nonisolated(nonsending)`. It runs in the caller's isolation domain, so it can read and
mutate actor state directly:

```swift
actor DataProcessor {
    var cache: [String: Data] = [:]

    func fetchWithDeadline(url: String) async throws {
        let data = try await withDeadline(in: .seconds(5)) {
            if let cached = cache[url] { return cached }
            return try await URLSession.shared.data(from: URL(string: url)!).0
        }
        cache[url] = data
    }
}
```

## Telling Deadline Expiry Apart From Manual Cancellation

`CancellationError` gains a `reason`, an open enum so future cancellation causes can be
added without breaking exhaustive switches:

```swift
public struct CancellationError: Error {
    @nonexhaustive
    public enum Reason {
        case unspecified
        case deadlineExpired
    }
    public var reason: Reason { get }
}
```

Catch it to distinguish a slow server from an explicit `Task.cancel()`:

```swift
do {
    try await withDeadline(in: .seconds(5)) { try await fetchDataFromServer() }
} catch let error as CancellationError where error.reason == .deadlineExpired {
    print("Timed out — server too slow")
} catch {
    print("Failed for another reason: \(error)")
}
```

`Task.cancel(reason:)`, `TaskGroup.cancelAll(reason:)`, and `Task.cancellationReason` ship
alongside it. Library code can also check `Task.hasActiveDeadline` and
`Task.activeDeadline(for:)` to see whether it's already running under a caller-supplied
deadline.

## Best Practices

Prefer `withDeadline` over manual `withThrowingTaskGroup` timeout races — it handles the
cancel/wait/error-propagation ordering correctly, even when the operation ignores
cancellation and keeps running past the deadline. Pass a shared deadline instant into
fan-out work (`async let`, task groups) instead of a fresh duration per branch, so sibling
operations don't drift apart. Match on `CancellationError.reason` with `@unknown default`
rather than assuming every cancellation was deadline-driven. Remember `withDeadline` waits
for cancelled work to return, so non-cooperative code (synchronous I/O, tight loops without
`Task.yield()`) can still overrun the deadline.

## References

- [SE-0526: withDeadline](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0526-deadline.md)
- [Accepted with modifications: SE-0526](https://forums.swift.org/t/accepted-with-modifications-se-0526-withdeadline/88645)
- [What's new in Swift: July 2026 Edition](https://www.swift.org/blog/whats-new-in-swift-july-2026/)
- [SE-0304: Structured Concurrency](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
- [SE-0504: Task Cancellation Shields](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0504-task-cancellation-shields.md)
