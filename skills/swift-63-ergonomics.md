---
topic: Swift 6.3 Daily Ergonomics — Module Selectors, anyAppleOS, and @diagnose
date: 2026-07-13
platform: iOS 26, macOS 26
swift: "6.3"
difficulty: intermediate
---

# Swift 6.3 Daily Ergonomics — Module Selectors, anyAppleOS, and @diagnose

Swift 6.3 doesn't headline with a single flagship feature. Instead it ships a batch of small
ergonomics wins that developers hit every day: resolving name collisions between modules,
collapsing repetitive multi-platform availability checks, and getting per-declaration control
over which warnings are errors. None of these change how your app behaves — they change how
much boilerplate you write to express the same intent.

## Module Selectors (`::`)

As dependency graphs grow, it's common for two imported modules to vend a type with the same
name. Swift previously resolved this with verbose disambiguation tricks (typealiases, wrapper
namespaces). Swift 6.3 adds a `::` module selector that unambiguously names which module a
symbol comes from:

```swift
import Rocket
import GiftShopToys

// Both modules vend a `Rocket` type — this is ambiguous and
// resolves to whichever the compiler prefers (usually the last import).
let toy = Rocket.SaturnV()

// `::` always treats the left-hand side as a module name, not a type.
// This is unambiguous: definitely GiftShopToys.Rocket.SaturnV.
let toy2 = GiftShopToys::Rocket.SaturnV()

// And the real rocket, from the Rocket module:
let launch = Rocket::SaturnV()
```

This matters most in large apps that pull in many third-party packages, or when you're
migrating code and two modules temporarily shadow the same type name. You don't need `::`
everywhere — only at the specific call sites where the compiler can't already tell modules
apart.

## `anyAppleOS` Availability Shorthand

Cross-platform Apple availability checks tend to repeat the same version number five times:

```swift
// Before Swift 6.3
@available(macOS 27, iOS 27, watchOS 27, tvOS 27, visionOS 27, *)
func showLiveStatus() {
    // ...
}
```

Swift 6.3 collapses this into a single `anyAppleOS` token that expands to "this version, on
whichever Apple platform is compiling":

```swift
// Swift 6.3
@available(anyAppleOS 27, *)
func showLiveStatus() {
    // ...
}
```

`anyAppleOS` is purely sugar — it expands to the same set of platform checks the compiler
already understood. Use it whenever a declaration should be available at the same OS version
across every Apple platform your package targets; fall back to explicit per-platform
`@available` when versions genuinely diverge (e.g. a feature that shipped in iOS 26 but not
until watchOS 27).

## `@diagnose` — Per-Declaration Diagnostic Control

Swift's compiler warnings are normally controlled at the module or target level via build
settings. `@diagnose` lets you override diagnostic behavior for a single declaration, which is
useful for legacy code you can't fix yet, or for promoting a specific risk to a hard error
locally before it's the default project-wide:

```swift
// Silence a deprecation warning you can't address yet, with a paper trail.
@diagnose(DeprecatedDeclaration, as: ignored, reason: "Flying with surplus hardware")
func makeApolloSoyuzMission() -> Mission {
    legacyMissionBuilder()
}

// Turn a normally-suppressed strict-concurrency note into a visible warning
// for a function you know is safety-sensitive.
@diagnose(StrictMemorySafety, as: warning)
func uplinkCommand(from receiver: inout Receiver, to computer: inout Computer) {
    // ...
}

// Treat a future Swift version's diagnostic as an error today, so you catch
// the migration issue before upgrading the toolchain.
@diagnose(ErrorInFutureSwiftVersion, as: error)
func fetchPosition() -> (x: Double, y: Double, z: Double) {
    // ...
}
```

`@diagnose` takes a diagnostic group name, the desired severity (`ignored`, `warning`, or
`error`), and an optional `reason` string that shows up in build logs and code review diffs —
so a silenced warning is documented instead of silently forgotten.

## Best Practices

Reach for `::` only at genuine collision sites; sprinkling it everywhere makes code harder to
skim. Prefer `anyAppleOS` for the common case of "same version, every platform," but don't
force it where platform availability actually differs — that just reintroduces bugs the old
verbose syntax caught. Use `@diagnose(..., as: ignored, reason:)` instead of bare
`// swiftlint:disable` style comments, since the reason is compiler-visible and searchable
across the codebase. Reserve `as: error` promotions for code paths where a regression would be
costly (concurrency safety, security-sensitive APIs) rather than applying it broadly, which
just recreates whatever friction `-warnings-as-errors` already causes.

## References

- [What's new in Swift — WWDC26](https://developer.apple.com/videos/play/wwdc2026/262/)
- [Swift 6.3 Released — Swift.org](https://www.swift.org/blog/swift-6.3-released/)
- [Module Selectors in Swift 6.3 — Swift Forums](https://forums.swift.org/t/module-selectors-in-swift-6-3/87785)
- [What's new in Swift: June 2026 Edition — Swift.org](https://www.swift.org/blog/whats-new-in-swift-june-2026/)
