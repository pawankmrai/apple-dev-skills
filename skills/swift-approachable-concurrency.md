---
topic: Swift 6.2 Approachable Concurrency
date: 2026-06-04
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift 6.2 Approachable Concurrency

Swift 6 introduced strict concurrency checking that prevents data races at compile time — but it came with significant friction. Swift 6.2 refines the model with several targeted improvements that make concurrent code dramatically easier to write while preserving the same safety guarantees.

## The Problem Swift 6.2 Solves

In Swift 6.0 and 6.1, developers frequently hit walls of concurrency errors around:

- `nonisolated` async methods unexpectedly hopping to the global executor
- Needing `@MainActor` annotations on every view model property and method
- Verbose boilerplate for code that runs almost exclusively on the main thread

Swift 6.2 addresses these pain points with three key changes.

## 1. Default Isolation: Main Actor

A new compiler setting isolates all code in a module to the main actor by default. Enable it in `Package.swift`:

```swift
// Package.swift
.target(
    name: "MyApp",
    swiftSettings: [
        .defaultIsolation(MainActor.self)
    ]
)
```

With this setting, view models no longer need `@MainActor` sprinkled everywhere:

```swift
// Before Swift 6.2 — verbose
@MainActor
class ProfileViewModel: ObservableObject {
    @MainActor var username: String = ""

    @MainActor func loadProfile() async {
        username = await fetchUsername()
    }
}

// With defaultIsolation — clean
class ProfileViewModel: ObservableObject {
    var username: String = ""

    func loadProfile() async {
        username = await fetchUsername()
    }
}
```

The safety guarantees are identical — the compiler enforces main-actor isolation implicitly.

## 2. Nonisolated Async Inherits Caller Context

Previously, `nonisolated async` functions always jumped to the global cooperative thread pool, even when called from the main actor. In Swift 6.2, they inherit the caller's isolation context by default.

```swift
// Swift 6.1 — always hops to global executor
nonisolated func parseJSON(_ data: Data) async throws -> [Item] {
    return try JSONDecoder().decode([Item].self, from: data)
}

// Swift 6.2 — inherits caller's isolation
// Called from @MainActor? Runs on main actor.
// Called from a background task? Runs there.
nonisolated func parseJSON(_ data: Data) async throws -> [Item] {
    return try JSONDecoder().decode([Item].self, from: data)
}
```

To explicitly run on the global executor regardless of caller, use the new `@concurrent` attribute:

```swift
@concurrent
nonisolated func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
    // CPU-intensive work — always runs off main actor
    return image.byPreparingThumbnail(ofSize: size) ?? image
}
```

## 3. The @concurrent Attribute

`@concurrent` makes it explicit that a function escapes the caller's isolation and runs on the global executor:

```swift
class ImageProcessor {
    // @concurrent = safe to call from main actor, will always run off it
    @concurrent func generateThumbnails(for assets: [PHAsset]) async -> [UIImage] {
        return await withTaskGroup(of: UIImage?.self) { group in
            for asset in assets {
                group.addTask {
                    await self.loadImage(for: asset)
                }
            }
            return await group.reduce(into: []) { result, image in
                if let image { result.append(image) }
            }
        }
    }
}

// Call site — reads naturally, no @MainActor awkwardness
struct GalleryViewModel {
    let processor = ImageProcessor()

    func loadGallery(assets: [PHAsset]) async {
        thumbnails = await processor.generateThumbnails(for: assets)
        // Automatically back on main actor here
    }
}
```

## Typed Throws

Swift 6.2 also stabilizes typed throws, enabling exhaustive error handling at call sites:

```swift
enum NetworkError: Error {
    case timeout
    case unauthorized
    case serverError(Int)
}

func fetchUser(id: String) async throws(NetworkError) -> User {
    let response = try await perform(request(for: id))
    switch response.statusCode {
    case 200: return try decode(response.data)
    case 401: throw NetworkError.unauthorized
    case let code: throw NetworkError.serverError(code)
    }
}

// Exhaustive catch — no `catch { }` catch-all needed
do {
    let user = try await fetchUser(id: "42")
    display(user)
} catch NetworkError.timeout {
    showRetryPrompt()
} catch NetworkError.unauthorized {
    redirectToLogin()
} catch let NetworkError.serverError(code) {
    log("Server error: \(code)")
}
```

## Migration Strategy

Adopt improvements incrementally using upcoming feature flags:

```swift
// Package.swift
.target(
    name: "MyModule",
    swiftSettings: [
        // Step 1: inherit isolation in nonisolated async functions
        .enableUpcomingFeature("InferIsolatedConformances"),

        // Step 2 (later): default entire module to main actor
        .defaultIsolation(MainActor.self)
    ]
)
```

For mixed codebases, migrate one module at a time. Targets that haven't opted in continue to behave exactly as before.

## Best Practices

- **Enable `defaultIsolation(MainActor.self)`** for SwiftUI app targets — it removes most `@MainActor` boilerplate with zero runtime cost.
- **Mark CPU-heavy functions `@concurrent`** to make their off-main-actor intent explicit and visible at every call site.
- **Prefer `typed throws`** in new service-layer APIs where callers benefit from exhaustive error handling.
- **Keep `@MainActor` on public API boundaries** even with default isolation — external callers may not share your module's isolation defaults.
- **Profile before optimizing** — the concurrency model's goal is correctness first; reach for `@concurrent` only when you've measured a real bottleneck.

## References

- [Swift 6.2 Released — Swift.org](https://www.swift.org/blog/swift-6.2-released/)
- [What's new in Swift 6.2 — Hacking with Swift](https://www.hackingwithswift.com/articles/277/whats-new-in-swift-6-2)
- [Adopting Strict Concurrency — Apple Developer](https://developer.apple.com/documentation/swift/adoptingswift6)
- [What's new in Swift: April 2026 — Swift.org](https://www.swift.org/blog/whats-new-in-swift-april-2026/)
