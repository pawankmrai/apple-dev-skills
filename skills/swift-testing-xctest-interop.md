---
topic: Swift Testing and XCTest Interoperability — Migrating with Confidence
date: 2026-07-03
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: intermediate
---

# Swift Testing and XCTest Interoperability — Migrating with Confidence

Most real-world apps can't flip a switch and migrate every test file from XCTest to Swift Testing overnight. The recommended path has always been "leave existing XCTests alone, write new tests with Swift Testing" — but until Swift 6.4, mixing the two frameworks in the same helper functions was quietly dangerous. An `XCTAssertEqual` called from inside a `@Test` function was a silent no-op. An `#expect` called from inside an `XCTestCase` method did nothing either. Swift 6.4 and Xcode 27 ship **targeted interoperability** (Swift Evolution ST-0021) to close that gap, so cross-framework calls behave the way you'd naturally expect.

## The Problem It Solves

Before interop, a shared assertion helper silently lost its teeth depending on which framework called it:

```swift
func assertUnique(_ elements: [Int]) {
    XCTAssertEqual(Set(elements).count, elements.count,
                    "\(elements) has duplicate elements")
}

class LegacyTests: XCTestCase {
    func testDups() {
        assertUnique([1, 2, 1])   // Fails as expected
    }
}

@Test func modernDups() {
    assertUnique([1, 2, 1])       // Passed silently — a false negative!
}
```

That's a **false negative**: the test reports green while the assertion inside it failed. Swift Evolution calls this class of bug "lossy without interop," and it's exactly what discourages teams from migrating incrementally.

## What Interop Actually Does

Two directions, two different guarantees:

**XCTest API called inside a Swift Testing `@Test`** now reports failures correctly, plus a runtime warning nudging you toward the modern equivalent:

```swift
@Test func duplicateElements() {
    assertUnique([1, 2, 1])
    // Test Failure: "[1, 2, 1] has duplicate elements"
    // Runtime warning: consider adopting #expect
}
```

Supported XCTest APIs include `XCTAssert*`, `XCTFail`, `XCTExpectFailure`, and issue-handling traits. `XCTestExpectation` and `XCTWaiter` are explicitly excluded — they don't mix safely with Swift Concurrency, so use `confirmation()` or `withCheckedContinuation` instead when writing async Swift Testing code.

**Swift Testing API called inside an `XCTestCase` method** works immediately, because `#expect`, `#require`, `Issue.record()`, and exit testing all have no ambiguity — they just report through the XCTest issue-reporting pipeline:

```swift
class LegacyTests: XCTestCase {
    func testInline() {
        #expect(2 + 2 == 4)          // Works — reports as XCTest would
        Issue.record("needs a fix")  // Works — becomes an XCTest failure
    }
}
```

Traits, parameterized tests, and other Swift Testing–only concepts have no XCTest equivalent, so they remain unsupported in that direction — there's nothing to translate them to.

## Interoperability Modes

Interop severity is configurable, because "everything is suddenly a failure" is a rough landing for a large existing suite.

| Mode | XCTest API used inside `@Test` |
|------|-------------------------------|
| `none` | No interop — pre-6.4 behavior, silent no-ops |
| `limited` | Previously-ignored failures become runtime warnings |
| `complete` (default for new projects) | Previously-ignored failures become real test failures, plus warnings |
| `strict` | Any XCTest API usage in a Swift Testing context triggers `fatalError` |

Set it with an environment variable, which takes precedence over toolchain defaults:

```bash
SWIFT_TESTING_XCTEST_INTEROP_MODE=strict swift test
```

New Swift packages (`swift-tools-version` at or above the Swift 6.4 toolchain) default to `complete`. Existing packages default to `limited`, so upgrading your toolchain won't suddenly turn a pile of dormant false negatives into a red CI pipeline overnight — you opt into `complete` deliberately.

## A Practical Migration Pattern

Update shared helpers to use Swift Testing's `Issue.record()` instead of `XCTFail`, and they'll work correctly from both kinds of tests:

```swift
func assertUnique(_ elements: [Int], sourceLocation: SourceLocation = #_sourceLocation) {
    guard Set(elements).count == elements.count else {
        Issue.record("\(elements) has duplicate elements", sourceLocation: sourceLocation)
        return
    }
}
```

Because `Issue.record` is a Swift Testing API with a direct XCTest mapping, calling it from an `XCTestCase` test still produces a proper XCTest failure — you get one helper that serves both worlds during the transition.

One hard constraint doesn't change: a `@Test` function still cannot live inside an `XCTestCase` subclass. Interop governs *calls* across frameworks, not *declarations* — the two test styles still live in separate functions, just in the same target or even the same file.

## Best Practices

Write new tests in Swift Testing and leave passing XCTest suites where they are; interop exists to make the overlap period safe, not to eliminate the need to eventually migrate. Turn on `complete` mode as soon as you adopt Swift 6.4, even on existing packages, so old helper functions stop lying to you about coverage. Treat the runtime warnings as a punch list — each one marks a spot where a shared helper still speaks XCTest and could be moved to `#expect`/`Issue.record`. Reserve `strict` mode for targets that are fully migrated, since it turns any regression (even a stray `XCTFail` reintroduced by a merge) into a hard crash rather than a graceful failure. Avoid `XCTestExpectation`/`XCTWaiter` in new async code entirely — reach for `confirmation()` regardless of which framework the surrounding test uses.

## References

- [ST-0021: Targeted Interoperability between Swift Testing and XCTest](https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0021-targeted-interoperability-swift-testing-and-xctest.md)
- [Migrating a test from XCTest — Apple Developer Documentation](https://developer.apple.com/documentation/testing/migratingfromxctest)
- [What's new in Swift — WWDC26](https://developer.apple.com/videos/play/wwdc2026/262/)
- [Migrate to Swift Testing — WWDC26](https://developer.apple.com/videos/play/wwdc2026/267/)
