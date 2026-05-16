---
topic: Swift Protocols and Generics — Building Flexible Abstractions
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Protocols and Generics — Building Flexible Abstractions

Protocols and generics are the backbone of Swift's type system. Together they let you write code that is both flexible and type-safe, enabling patterns like dependency injection, testable architecture, and reusable data structures.

## Protocol Basics

A protocol defines a contract that conforming types must fulfill:

```swift
protocol DataFetching {
    associatedtype Model: Decodable
    func fetch(id: String) async throws -> Model
}
```

Associated types make protocols generic — each conforming type decides the concrete `Model`.

## Conforming to Protocols

```swift
struct UserFetcher: DataFetching {
    typealias Model = User

    func fetch(id: String) async throws -> User {
        let url = URL(string: "https://api.example.com/users/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
}
```

## Generic Functions

Write a single function that works across any conforming type:

```swift
func loadAndDisplay<F: DataFetching>(
    fetcher: F,
    id: String
) async throws -> String where F.Model: CustomStringConvertible {
    let model = try await fetcher.fetch(id: id)
    return model.description
}
```

The `where` clause adds constraints without sacrificing flexibility.

## Opaque Types with `some`

When returning protocol types from functions, use `some` to preserve the concrete type for the compiler:

```swift
func makeDefaultFetcher() -> some DataFetching {
    UserFetcher()
}
```

This enables the compiler to optimize while hiding implementation details.

## Existential Types with `any`

When you need to store heterogeneous protocol-conforming values, use `any`:

```swift
var fetchers: [any DataFetching] = [UserFetcher(), PostFetcher()]
```

Swift 6 enforces the `any` keyword for existentials, making the performance cost explicit.

## Primary Associated Types

Introduced in Swift 5.7, primary associated types let you constrain existentials concisely:

```swift
protocol Repository<Model> {
    associatedtype Model: Identifiable & Codable
    func getAll() async throws -> [Model]
    func save(_ item: Model) async throws
    func delete(id: Model.ID) async throws
}

// Use it with constraints
func sync(repo: some Repository<User>) async throws {
    let users = try await repo.getAll()
    print("Syncing \(users.count) users")
}
```

## Protocol Extensions — Default Implementations

Add shared behavior without subclassing:

```swift
extension Repository {
    func deleteAll() async throws {
        let items = try await getAll()
        for item in items {
            try await delete(id: item.id)
        }
    }
}
```

Every conforming type gets `deleteAll()` for free.

## Generic Types

```swift
struct Cache<Key: Hashable, Value> {
    private var storage: [Key: (value: Value, expiry: Date)] = [:]

    mutating func set(_ value: Value, forKey key: Key, ttl: TimeInterval = 300) {
        storage[key] = (value, Date().addingTimeInterval(ttl))
    }

    func get(_ key: Key) -> Value? {
        guard let entry = storage[key], entry.expiry > Date() else {
            return nil
        }
        return entry.value
    }
}

var cache = Cache<String, Data>()
cache.set(imageData, forKey: "avatar")
```

## Best Practices

- **Prefer `some` over `any`** — opaque types are faster because the compiler knows the concrete type. Use `any` only when you need heterogeneous collections.
- **Use primary associated types** to make protocols with associated types ergonomic at call sites.
- **Keep protocols small and focused** — compose multiple small protocols rather than one large one.
- **Add default implementations** via extensions for common behavior, but document which methods are customization points.
- **Constrain generics minimally** — only require the protocols you actually use in the function body.
- **Test with protocol mocks** — protocols make dependency injection natural, enabling clean unit tests.

## References

- [Protocols — The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [Generics — The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [Embrace Swift Generics — WWDC22](https://developer.apple.com/videos/play/wwdc2022/110352/)
