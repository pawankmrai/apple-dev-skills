---
topic: Swift Testing Framework — Modern Unit Testing in Swift
date: 2026-05-15
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Testing Framework — Modern Unit Testing in Swift

Swift Testing is Apple's modern testing framework, shipping with Swift 6 and Xcode 16+. It replaces many XCTest patterns with a more expressive, Swift-native approach using macros, traits, and parameterized tests. If you're still writing `XCTAssertEqual` everywhere, it's time to level up.

## Getting Started

Swift Testing is built into the Swift toolchain — no package dependency needed. Import it and start writing tests using the `@Test` macro:

```swift
import Testing

@Test("Addition produces correct results")
func addition() {
    let result = 2 + 3
    #expect(result == 5)
}
```

The `#expect` macro replaces the family of `XCTAssert` functions. It captures the full expression, so failures produce rich diagnostics showing each operand's value.

## Organizing Tests with Suites

Group related tests using `@Suite` on a struct. Unlike XCTest classes, suites are value types, eliminating shared mutable state between tests:

```swift
@Suite("ShoppingCart Tests")
struct ShoppingCartTests {
    let cart = ShoppingCart()

    @Test("Empty cart has zero total")
    func emptyCartTotal() {
        #expect(cart.total == 0)
    }

    @Test("Adding item updates count")
    func addItem() {
        var cart = cart
        cart.add(Item(name: "Widget", price: 9.99))
        #expect(cart.items.count == 1)
    }
}
```

Each test gets its own instance of the struct, so tests are fully isolated and safe to run in parallel.

## Parameterized Tests

One of the most powerful features is parameterized testing. Instead of duplicating test logic, pass a collection of inputs:

```swift
@Test("Validates email formats", arguments: [
    ("user@example.com", true),
    ("invalid-email", false),
    ("name@domain.co.uk", true),
    ("@missing-local.com", false)
])
func emailValidation(email: String, isValid: Bool) {
    let validator = EmailValidator()
    #expect(validator.validate(email) == isValid)
}
```

For multiple argument lists, use `zip` to pair them or let the framework compute the Cartesian product:

```swift
@Test("Discount calculation", arguments: zip(
    [100.0, 200.0, 50.0],
    [0.1, 0.2, 0.05],
    [90.0, 160.0, 47.5]
))
func discount(price: Double, rate: Double, expected: Double) {
    let result = applyDiscount(price: price, rate: rate)
    #expect(result == expected)
}
```

## Traits for Test Configuration

Traits annotate tests with metadata and behavior. Common built-in traits include:

```swift
// Conditionally disable a test
@Test(.disabled("Waiting on server migration"))
func syncTest() { /* ... */ }

// Skip at runtime based on a condition
@Test(.enabled(if: ProcessInfo.processInfo.environment["CI"] != nil))
func ciOnlyTest() { /* ... */ }

// Set a time limit
@Test(.timeLimit(.minutes(2)))
func longRunningOperation() async {
    let result = await processor.analyze(largeDataset)
    #expect(result.isComplete)
}

// Mark as a known issue
@Test("Flaky network test")
func networkTest() async throws {
    withKnownIssue {
        try await fetchData()
    }
}
```

## Tags for Cross-Cutting Organization

Tags let you group tests across suites for selective execution:

```swift
extension Tag {
    @Tag static var networking: Self
    @Tag static var persistence: Self
    @Tag static var ui: Self
}

@Test(.tags(.networking))
func apiCallSucceeds() async throws {
    let response = try await api.fetchUsers()
    #expect(!response.isEmpty)
}

@Test(.tags(.networking, .persistence))
func cacheAfterFetch() async throws {
    let users = try await api.fetchUsers()
    try cache.store(users)
    let cached = try cache.load()
    #expect(cached == users)
}
```

Run only networking tests from the command line: `swift test --filter .tags:networking`

## Async and Throwing Tests

Swift Testing has first-class support for async/await and error handling:

```swift
@Test("Fetching user profile succeeds")
func fetchProfile() async throws {
    let service = UserService()
    let profile = try await service.fetchProfile(id: "user-123")
    #expect(profile.name == "Pawan")
}

@Test("Invalid ID throws notFound error")
func invalidID() async {
    let service = UserService()
    await #expect(throws: ServiceError.notFound) {
        try await service.fetchProfile(id: "nonexistent")
    }
}
```

## Migrating from XCTest

You can run XCTest and Swift Testing side by side. Migrate incrementally:

| XCTest | Swift Testing |
|---|---|
| `XCTestCase` subclass | `@Suite` struct |
| `func testSomething()` | `@Test func something()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `setUpWithError()` | Struct initializer |
| `tearDown()` | `deinit` (use a class suite) |

## Best Practices

Write tests as structs, not classes — value semantics eliminate shared state bugs. Embrace parallel execution by default; serialize with `.serialized` trait only when tests genuinely share resources. Use parameterized tests to maximize coverage with minimal code duplication. Apply tags for cross-cutting concerns like "slow" or "integration" so CI can run subsets efficiently. Keep test names descriptive using the string parameter of `@Test` — these appear in Xcode's test navigator and CI logs.

## References

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [Meet Swift Testing — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10179/)
- [Go Further with Swift Testing — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10195/)
- [swift-testing on GitHub](https://github.com/swiftlang/swift-testing)
