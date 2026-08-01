---
topic: Swift Package Traits — Feature Flags and Optional Dependencies
date: 2026-08-01
platform: iOS 26, macOS 26 (SwiftPM 6.1+)
swift: "6.2"
difficulty: intermediate
---

# Swift Package Traits — Feature Flags and Optional Dependencies

Package traits (SE-0450) let a Swift package declare named, opt-in capabilities that consumers enable or disable at build time. A trait can gate conditional compilation, pull in optional dependencies only when needed, or expose experimental APIs without committing to them as stable. Think of traits as compile-time feature flags that live in `Package.swift` rather than scattered environment variables or forked repos. They shipped in SwiftPM 6.1 and are increasingly used by cross-platform packages (like swift-openapi-generator's transport backends) to keep binaries lean.

## Why Traits Exist

Before traits, package authors solved "optional dependency" problems in awkward ways: splitting one logical library into several repos (one per backend), reading environment variables inside `Package.swift` (unsupported under sandboxing), or hiding unstable APIs behind underscored names. Traits replace all three with a first-class mechanism that Xcode, `swift build`, and `swift test` understand natively.

## Declaring Traits

Traits are declared on the `Package` initializer. Each trait has a name, an optional description, and can enable other traits transitively:

```swift
// Package.swift
let package = Package(
    name: "NetworkKit",
    traits: [
        .trait(name: "Logging", description: "Enables OSLog-based request/response logging"),
        .trait(name: "Mocking", description: "Bundles a URLProtocol-based mock transport for tests"),
        .trait(
            name: "Full",
            enabledTraits: ["Logging", "Mocking"]
        ),
        .default(enabledTraits: ["Logging"]),
    ],
    products: [
        .library(name: "NetworkKit", targets: ["NetworkKit"]),
    ],
    targets: [
        .target(name: "NetworkKit"),
    ]
)
```

Consumers who add this package as a dependency get the `Logging` trait automatically because it's in `.default`. `Full` isn't enabled unless a consumer opts in explicitly.

## Gating Optional Dependencies

The real payoff is conditional dependencies. A trait can pull in a package product only when enabled, so consumers who don't need it never fetch or link it:

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
]
targets: [
    .target(
        name: "NetworkKit",
        dependencies: [
            .product(
                name: "Logging",
                package: "swift-log",
                condition: .when(traits: ["Logging"])
            ),
        ]
    ),
]
```

If a consumer disables the `Logging` trait, `swift-log` is never resolved into the build graph for that target.

## Conditional Compilation with Traits

Inside source files, each enabled trait becomes a compilation flag you check with `#if`:

```swift
func send(_ request: URLRequest) async throws -> Data {
    #if Logging
    Logger(subsystem: "NetworkKit", category: "transport").debug("→ \(request.url?.absoluteString ?? "?")")
    #endif

    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}
```

The trait name is treated exactly like a custom compilation condition (`-D Logging` under the hood), so it composes with existing `#if os(...)` and `#if DEBUG` checks.

## Enabling Traits as a Consumer

When declaring a dependency, pass the traits you want. `.defaults` keeps the package's default set, and you can layer additional traits on top:

```swift
dependencies: [
    .package(
        url: "https://github.com/example/NetworkKit.git",
        from: "2.0.0",
        traits: [.defaults, "Mocking"]
    ),
]
```

Pass an empty set to opt out of every trait, including defaults:

```swift
.package(url: "https://github.com/example/NetworkKit.git", from: "2.0.0", traits: [])
```

From the command line, `swift build`, `swift test`, and `swift run` accept the same controls for the root package:

```bash
swift test --traits Logging,Mocking
swift build --enable-all-traits
swift build --disable-default-traits
```

This is especially useful in CI, where you can run a build matrix across trait combinations to catch code that only compiles under one configuration.

## Cascading Traits Across Dependencies

Traits can cascade: enabling a trait on your package can conditionally enable a trait on a dependency, which is how packages like swift-openapi-generator let one root trait (say, `VaporTransport`) light up the right transport package without the consumer wiring up multiple dependencies by hand.

```swift
dependencies: [
    .package(
        url: "https://github.com/example/SomePackage.git",
        from: "1.0.0",
        traits: [.trait(name: "SomeOtherTrait", condition: .when(traits: ["Foo"]))]
    ),
]
```

## Best Practices

Traits should always be additive — enabling one should never remove API or change existing behavior, since the whole point is that any combination of traits across a dependency graph must build. Never move existing, already-shipped API behind a new trait; that breaks consumers who didn't ask for the change. Keep default traits minimal so that packages stay lean for the common case, and document what each trait costs (extra dependencies, binary size, platform restrictions) in its `description`. Because trait names are namespaced per package, you're free to reuse common names like `Logging` across your own packages without collisions. Finally, remember documentation generators build with all traits enabled by default, so gated APIs still need doc comments even if most consumers never see them compiled in.

## References

- [SE-0450: Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)
- [Swift Forums: Conditional compilation using traits](https://forums.swift.org/t/conditional-compilation-using-traits/83035)
- [Swift Package Manager documentation](https://www.swift.org/documentation/package-manager/)
