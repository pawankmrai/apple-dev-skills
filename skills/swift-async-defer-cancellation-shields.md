---
topic: Swift 6.4 Concurrency Refinements — Async Defer, Cancellation Shields, and Sendable Ergonomics
date: 2026-06-27
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: intermediate
---

# Swift 6.4 Concurrency Refinements — Async Defer, Cancellation Shields, and Sendable Ergonomics

Swift 6's strict concurrency model bought real correctness guarantees but introduced friction: cleanup code that couldn't `await`, cancellation that arrived at inconvenient moments, and `Sendable` checks that forced awkward workarounds. Swift 6.4, shipping with Xcode 27 at WWDC26, doesn't change the concurrency model — it sands down the rough edges accumulated since Swift 6 shipped. Four changes matter most day-to-day: async `defer`, task cancellation shields, a new warning for ignored throwing tasks, and friendlier `Sendable` ergonomics.

## Async Calls in `defer` (SE-0493)

Before 6.4, `defer` bodies were synchronous even inside an `async` function — a real problem when cleanup itself needed to await something.

```swift
func importArticles() async throws {
    let importer = ArticleImporter()
    await importer.open()

    defer {
        await importer.close()   // now valid in Swift 6.4
    }

    try await importer.importLatestArticles()
}
```

The compiler implicitly awaits the deferred work before the function actually returns, so teardown still runs on every exit path — success, early return, or thrown error — exactly like synchronous `defer` always did. One caveat: async `defer` does not shield you from cancellation. If the enclosing task is already cancelled, code inside the `defer` body observes that just like any other `await`.

## Task Cancellation Shields (SE-0504)

That caveat is exactly what `withTaskCancellationShield` solves. It wraps a closure where `Task.isCancelled` always reports `false`, so cleanup or rollback work can run to completion even after the surrounding task was cancelled.

```swift
func writeArticles(_ articles: [Article]) async throws {
    let transaction = await database.beginTransaction()

    defer {
        await withTaskCancellationShield {
            // Runs to completion even if the task was cancelled mid-write.
            await transaction.rollbackIfNeeded()
        }
    }

    try await transaction.insert(articles)
    try await transaction.commit()
}
```

If the task was cancelled *before* entering the shield, that fact isn't erased — it's just suppressed for the duration of the closure. Once the closure returns, `Task.isCancelled` reports the real state again. Keep shielded regions short and limited to finishing or unwinding work you've already started; they're the wrong tool for hiding cancellation from long-running operations.

## Warnings for Ignored Throwing Tasks (SE-0520)

Unstructured `Task { }` blocks that throw have always been a quiet way to drop errors on the floor:

```swift
Task {
    try await importArticles()   // error silently disappears if this throws
}
```

Swift 6.4 now warns on this pattern: *"Unstructured throwing task was not used, which may accidentally ignore errors thrown inside the task."* Fix it by handling the error inside the task, or by keeping the handle and awaiting it:

```swift
// Handle inline
Task {
    do {
        try await importArticles()
    } catch {
        logger.error("Import failed: \(error)")
    }
}

// Or keep the handle
let importTask = Task {
    try await importArticles()
}
try await importTask.value
```

If dropping the result really is intentional, silence the warning explicitly with `_ = Task { ... }`. The same proposal also lets `Task` initializers carry typed throws, so a task's failure type can be as specific as any other async function: `Task<String, URLError> { throw URLError(.badURL) }`.

## Async `Result` Support (SE-0530)

`Result.init(catching:)` finally has an async counterpart, removing the manual do/catch-to-Result boilerplate:

```swift
let result = await Result {
    try await importArticles()
}

switch result {
case .success(let articles):
    render(articles)
case .failure(let error):
    logger.error("Import failed: \(error)")
}
```

Reach for this when you want to store an outcome as a value — in a view model, a log, or a collection of results — rather than propagating the error immediately.

## Sendable Ergonomics: `weak let` and `~Sendable`

Two changes make `Sendable` adoption less painful. `weak let` (SE-0481, Swift 6.3) lets a `Sendable` class hold a weak reference without falling back to `@unchecked Sendable`:

```swift
final class ArticlePreviewController: Sendable {
    weak let delegate: ArticlePreviewDelegate?

    init(delegate: ArticlePreviewDelegate?) {
        self.delegate = delegate
    }
}
```

A `weak var` is a mutable stored property, which `Sendable` classes can't have. `weak let` is still allowed to become `nil` when the referenced object deallocates — that's not the same as being reassigned — so it satisfies `Sendable` checking honestly instead of requiring an escape hatch.

`~Sendable` (SE-0518) does the opposite job: it documents that a type was deliberately *not* made `Sendable`, rather than leaving readers to guess whether someone forgot.

```swift
enum ExecutionResult: ~Sendable {
    case success
    case failure(NonSendableError)
}
```

Write `~Sendable` on the declaration itself (not in an extension), and note that a subclass can still add `Sendable` back if it independently makes itself thread-safe.

## Best Practices

Reach for async `defer` for any cleanup that itself needs to await — closing files, connections, or importers — instead of duplicating teardown calls on every return and throw path. Pair it with a cancellation shield only when the cleanup must finish even after cancellation, such as rolling back a half-written transaction; don't shield routine work just to silence `Task.isCancelled` checks. Take the new throwing-task warning seriously rather than blanket-suppressing it with `_ =` — it usually means an error path was never designed. Prefer `weak let` over `weak var` wherever you don't actually reassign the reference, since it both satisfies `Sendable` and documents intent. Use `~Sendable` on public types you've audited and intentionally kept non-`Sendable`, so downstream developers don't waste time wondering whether the conformance was simply missed.

## References

- [SE-0493: Support async calls in defer bodies](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0493-defer-async.md)
- [SE-0504: Task Cancellation Shields](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0504-task-cancellation-shields.md)
- [SE-0520: Discardable result use in Task initializers](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0520-discardableresult-task-initializers.md)
- [SE-0530: Async Result Support](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0530-async-result-support.md)
- [SE-0481: weak let](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0481-weak-let.md)
- [SE-0518: ~Sendable for explicitly marking non-Sendable types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0518-tilde-sendable.md)
- [What's new in Swift — WWDC26](https://developer.apple.com/videos/play/wwdc2026/262/)
