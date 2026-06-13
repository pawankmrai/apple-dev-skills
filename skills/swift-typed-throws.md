---
topic: Swift Typed Throws
date: 2026-06-13
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Typed Throws

Swift 6.0 introduced *typed throws*, allowing functions to declare the precise error type they throw rather than the untyped `any Error`. This makes error handling more expressive, eliminates unwanted `catch` branches, and enables the compiler to verify exhaustive handling — all without boxing errors into existentials.

## The Problem with Untyped Throws

Before typed throws every throwing function erased its error to `any Error`, forcing callers to cast or use catch-all clauses:

```swift
enum NetworkError: Error {
    case timeout
    case unauthorized
    case serverError(Int)
}

// Old style — callee says "some error, trust me"
func fetchUser(id: String) throws -> User {
    // …
}

do {
    let user = try fetchUser(id: "42")
} catch let e as NetworkError {
    // must downcast; compiler can't guarantee exhaustion
    switch e { /* … */ }
} catch {
    // forced catch-all even if NetworkError is the only possibility
    fatalError("Unexpected: \(error)")
}
```

The catch-all is noise — the compiler has no idea whether it's reachable.

## Declaring a Typed Throw

Attach the concrete error type in parentheses after `throws`:

```swift
func fetchUser(id: String) throws(NetworkError) -> User {
    guard id != "" else { throw NetworkError.unauthorized }
    // …
    return User(id: id)
}
```

The caller now knows exactly what can go wrong:

```swift
do {
    let user = try fetchUser(id: "42")
    print(user)
} catch {
    // `error` is inferred as NetworkError — no cast needed
    switch error {
    case .timeout:         handleTimeout()
    case .unauthorized:    handleAuth()
    case .serverError(let code): handleServer(code)
    }
}
```

No `catch let e as NetworkError`, no catch-all — the compiler enforces exhaustiveness.

## Typed Throws and Generics

Typed throws pair naturally with generic error parameters, letting library authors write zero-cost abstractions:

```swift
struct Repository<Failure: Error> {
    let fetch: () throws(Failure) -> [Item]

    func load() throws(Failure) -> [Item] {
        try fetch()
    }
}

// Specialised to a concrete error — no existential boxing
let repo = Repository<NetworkError> { try fetchItems() }
```

If the generic error is `Never`, the function is non-throwing. If it's `any Error`, behaviour reverts to classic untyped throws. Both edges are deduced automatically.

## Mapping Errors Between Layers

When you bridge typed-throwing APIs you can re-type errors with `mapError`:

```swift
func loadProfile(id: String) throws(AppError) -> Profile {
    do {
        let user = try fetchUser(id: id)   // throws(NetworkError)
        return Profile(user: user)
    } catch {
        // `error` is NetworkError here
        throw AppError.network(error)
    }
}
```

Or use `Result.mapError` for a functional style:

```swift
func result(for id: String) -> Result<User, AppError> {
    Result { try fetchUser(id: id) }
        .mapError { AppError.network($0) }
}
```

## async/await Integration

Typed throws compose with `async` — order of keywords is `async throws(E)`:

```swift
func fetchFeed() async throws(NetworkError) -> [FeedItem] {
    let data = try await URLSession.shared.data(from: feedURL)  // throws(NetworkError)
    return try JSONDecoder().decode([FeedItem].self, from: data.0)
}

Task {
    do {
        let items = try await fetchFeed()
        render(items)
    } catch {
        // error: NetworkError — exhaustive switch compiles cleanly
        switch error {
        case .timeout: scheduleRetry()
        case .unauthorized: presentLogin()
        case .serverError(let c): logError(c)
        }
    }
}
```

## Interop with Untyped APIs

Any `throws(ConcreteError)` function is implicitly convertible to `throws` (untyped), so typed and untyped APIs interoperate:

```swift
func legacyWrapper() throws {
    try fetchUser(id: "1")  // typed → untyped, always valid
}
```

Going the other way requires explicit re-wrapping because the compiler cannot verify the untyped error is actually your concrete type.

## Best Practices

- **Use typed throws at module boundaries** where callers need to handle every case — networking, persistence, and parsing layers are prime candidates.
- **Keep error enums small and focused.** One enum per subsystem (e.g., `NetworkError`, `ParseError`) avoids catch switches that are too wide to be useful.
- **Avoid typed throws for truly unexpected errors.** Reserve `throws` (untyped) or `fatalError` for programmer mistakes; typed throws are for *expected* failure modes.
- **Don't over-type library APIs.** Public APIs that may evolve their errors benefit from a stable protocol-typed error (`throws(any LibraryError)`) rather than a concrete enum that becomes a binary compatibility concern.
- **Let the compiler guide you.** If the exhaustive switch starts feeling painful, that's a signal your error enum is modelling too many unrelated cases.

## References

- [SE-0413: Typed throws](https://github.com/apple/swift-evolution/blob/main/proposals/0413-typed-throws.md)
- [Swift 6 Migration Guide — Typed Throws](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/)
- [Swift Language Reference — Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
