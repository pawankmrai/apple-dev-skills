---
topic: Swift Observations — Streaming @Observable Changes as an AsyncSequence
date: 2026-10-06
platform: iOS 26, macOS 26, watchOS 26, tvOS 26, visionOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Observations — Streaming @Observable Changes as an AsyncSequence

SwiftUI tracks `@Observable` models automatically, but outside a view body you used to need
`withObservationTracking`, which fires once, with `willSet` semantics, and must be re-armed
by hand. SE-0475 (Swift 6.2, iOS 26+) adds `Observations`: an `AsyncSequence` that re-runs a
closure whenever any tracked property changes and emits the result with `didSet` semantics.
Changes made in the same synchronous run are coalesced into one value ("transactional"
observation), so you see consistent snapshots instead of half-applied updates.

## The Basics

```swift
import Observation

@Observable @MainActor
final class CartModel {
    var items: [String] = []
    var discount: Double = 0
}

let cart = CartModel()

let summaries = Observations {
    "\(cart.items.count) items, \(Int(cart.discount * 100))% off"
}

Task { @MainActor in
    for await summary in summaries {
        print(summary) // emits the current value first, then each transaction
    }
}
```

Key rules:

- **Tracking is implicit.** Every `@Observable` property read inside the closure is tracked.
  You may read properties you don't return; reading is enough to trigger re-evaluation.
- **First iteration yields the current value** immediately, then values after each change.
- **The closure is `@isolated(any) @Sendable`.** It runs on the isolation it was formed in
  (here `@MainActor`), so it can safely touch main-actor models.
- **Element must be `Sendable`.** Return value types or snapshots, not mutable references.

## Transactions: Why Values Coalesce

```swift
@MainActor func applyPromo() {
    cart.items.append("Gift card")
    cart.discount = 0.2
    // One emission: "N items, 20% off" — never "N items, 0% off" in between.
}
```

A transaction spans from the first `willSet` to the next suspension point on the observed
isolation. Multiple synchronous mutations produce a single value. The flip side: if the
consumer is slow, intermediate values are **dropped**; the iterator always delivers the
latest snapshot, not a backlog. If every value matters (e.g. an audit log), push events into
an `AsyncStream` with an explicit buffering policy instead.

## Finite Observation with `untilFinished`

Use `untilFinished` when the sequence should end on a condition, such as waiting for an
upload to complete:

```swift
@Observable @MainActor
final class Upload {
    var progress: Double = 0
    var isComplete = false
}

@MainActor
func trackProgress(of upload: Upload) async {
    let progress = Observations.untilFinished {
        upload.isComplete ? .finish : .next(upload.progress)
    }
    for await value in progress {
        print("Uploaded \(Int(value * 100))%")
    }
    print("Done") // loop exits once .finish is returned
}
```

## Owning Observations in a Controller

`Observations` retains its closure, and an infinite `for await` loop retains whatever it
captures. Capture weakly and unwrap *inside* the loop, and keep the `Task` so you can cancel:

```swift
@MainActor
final class AnalyticsBridge {
    private let cart: CartModel
    private var task: Task<Void, Never>?

    init(cart: CartModel) { self.cart = cart }

    func start() {
        let totals = Observations { [weak cart] in cart?.items.count ?? 0 }
        task = Task { [weak self] in
            for await count in totals {
                guard let self else { return }
                self.log(itemCount: count)
            }
        }
    }

    func stop() { task?.cancel() }

    private func log(itemCount: Int) { print("cart_size=\(itemCount)") }
}
```

Unwrapping `self` *before* the loop (`guard let self` at the top of the `Task`) keeps the
object alive for as long as the sequence runs, which for `Observations` is forever.

## Migrating from Combine and withObservationTracking

| Old pattern | With `Observations` |
|---|---|
| `$property.sink { }` on `ObservableObject` | `for await v in Observations { model.property }` |
| `Publishers.CombineLatest(a, b)` | Read both properties in one closure, return a tuple/struct |
| `.removeDuplicates()` | Return an `Equatable` value and compare to the last one in the loop |
| Recursive `withObservationTracking` re-arm | One `Observations` sequence |
| `.debounce(for:)` | Combine with `AsyncAlgorithms`' `debounce` |

## Best Practices

- Keep closures cheap and side-effect free; they re-run on every transaction.
- Read only the properties you depend on to avoid spurious emissions.
- Return `Sendable` snapshots (structs, enums, value types), never the model itself.
- Store and cancel the consuming `Task`; tie it to a lifecycle (`.task` modifier, `deinit`
  of an owner, or explicit `stop()`).
- Don't rely on seeing every intermediate value; design consumers around latest state.
- In SwiftUI views, prefer normal body tracking or `onChange(of:)`; reach for
  `Observations` in services, controllers, UIKit/AppKit code, and server-side Swift.
- Gate usage with `if #available(iOS 26, macOS 26, *)` when back-deploying.

## References

- [SE-0475: Transactional Observation of Values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0475-observed.md)
- [Apple Documentation — Observations](https://developer.apple.com/documentation/observation/observations)
- [Donny Wals — Using Observations to observe @Observable model properties](https://www.donnywals.com/using-observations-to-observe-observable-model-properties/)
- [Use Your Loaf — Swift Observations AsyncSequence for State Changes](https://useyourloaf.com/blog/swift-observations-asyncsequence-for-state-changes/)
