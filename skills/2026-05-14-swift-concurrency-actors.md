---
topic: Swift Concurrency — Actors
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Concurrency — Actors

Actors are reference types that protect their mutable state from data races by ensuring only one task accesses their internals at a time.

## Defining an Actor

```swift
actor BankAccount {
    let id: UUID
    private(set) var balance: Decimal

    init(id: UUID, initialBalance: Decimal) {
        self.id = id
        self.balance = initialBalance
    }

    func deposit(_ amount: Decimal) {
        balance += amount
    }

    func withdraw(_ amount: Decimal) throws {
        guard balance >= amount else {
            throw BankError.insufficientFunds
        }
        balance -= amount
    }
}
```

## Calling Actor Methods

Because actors isolate state, calls from outside the actor are `async`:

```swift
let account = BankAccount(id: UUID(), initialBalance: 1000)
try await account.withdraw(200)
let current = await account.balance
```

## nonisolated Members

Use `nonisolated` for properties or methods that don't touch mutable state:

```swift
actor UserSession {
    let userId: String          // let is implicitly nonisolated
    var lastActive: Date

    nonisolated func displayName() -> String {
        "User-\(userId.prefix(6))"
    }
}
```

## @MainActor

`@MainActor` is a global actor that runs on the main thread — essential for UI work:

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func load() async {
        let fetched = await service.fetchItems()  // runs off main
        items = fetched  // back on main, safe to update @Published
    }
}
```

In Swift 6.2, you can opt into default main-actor isolation at the module level, reducing the need for explicit `@MainActor` annotations on every view model.

## Best Practices

- Prefer actors over classes with manual locks for shared mutable state.
- Keep actor methods small — long-running work inside an actor blocks other callers.
- Use `nonisolated` liberally for read-only or computed properties.
- Leverage `@MainActor` for all UI-bound types.

## References

- [Swift Concurrency — The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [WWDC23: Beyond the basics of structured concurrency](https://developer.apple.com/videos/play/wwdc2023/10170/)
