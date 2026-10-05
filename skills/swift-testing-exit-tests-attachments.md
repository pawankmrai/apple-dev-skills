---
topic: Swift Testing Exit Tests and Attachments — Testing Crashes and Capturing Diagnostics
date: 2026-10-05
platform: macOS 26, iOS 26, Xcode 26
swift: "6.2"
difficulty: intermediate
---

# Swift Testing Exit Tests and Attachments — Testing Crashes and Capturing Diagnostics

Swift 6.2 adds two features to Swift Testing that cover gaps XCTest never handled well. **Exit tests** let you check that code calls `precondition`, `fatalError`, or `exit()`. Before, that kind of code would crash the whole test run. **Attachments** let a test save data such as JSON payloads, logs, or rendered images. That data shows up in Xcode's test report, so a failure on CI comes with the evidence you need to debug it.

## Exit Tests: Verifying That Code Terminates

An exit test runs its closure in a **separate child process**. Swift Testing then checks how that process ended. The parent test process keeps running whether the child succeeds or crashes.

```swift
import Testing

struct Ledger {
    private(set) var balance: Int
    mutating func withdraw(_ amount: Int) {
        precondition(amount > 0, "Withdrawal must be positive")
        precondition(amount <= balance, "Insufficient funds")
        balance -= amount
    }
}

@Test func withdrawingNegativeAmountTraps() async {
    await #expect(processExitsWith: .failure) {
        var ledger = Ledger(balance: 100)
        ledger.withdraw(-5)
    }
}
```

Exit tests are `async` because the framework launches the child process and waits for it to finish. Platform support: **macOS, Linux, FreeBSD, and Windows**. They are **not** available on iOS, tvOS, watchOS, or visionOS because those platforms can't spawn processes. Put this logic in a Swift package or framework that you can test on macOS.

## Matching Specific Exit Conditions

`.failure` matches any abnormal exit. When you need to be more specific, match on an exit code or a signal such as `.signal(SIGABRT)`:

```swift
@Test func cliExitsWithUsageError() async {
    await #expect(processExitsWith: .exitCode(64)) {   // EX_USAGE
        CommandLineTool.run(arguments: ["--bogus"])
    }
}
```

Swift traps such as `precondition` and `fatalError` usually end with `SIGTRAP` or `SIGILL`, depending on the platform. Prefer `.failure` for those so the test doesn't depend on the platform.

## Inspecting Output with `observing:`

Use `#require` together with `observing:` to get back an `ExitTest.Result` you can inspect. This lets you check the actual error message:

```swift
@Test func trapMessageMentionsFunds() async throws {
    let result = try await #require(
        processExitsWith: .failure,
        observing: [\.standardErrorContent]
    ) {
        var ledger = Ledger(balance: 10)
        ledger.withdraw(50)
    }
    let stderr = String(decoding: result.standardErrorContent, as: UTF8.self)
    #expect(stderr.contains("Insufficient funds"))
}
```

Only the key paths you list are collected. Leave out `observing:` when you don't need the output so you don't pay to capture it.

## Capturing State in Exit Tests

The closure runs in another process, so it can't silently capture local variables. With Swift 6.3 toolchains, you list captured values explicitly. Each captured value must be **`Sendable & Codable`** so it can be serialized into the child process:

```swift
@Test(arguments: [0, -1, -100])
func invalidAmountsTrap(amount: Int) async {
    await #expect(processExitsWith: .failure) { [amount] in
        var ledger = Ledger(balance: 100)
        ledger.withdraw(amount)
    }
}
```

On Swift 6.2, build any state you need inside the closure instead.

## Attachments: Recording Diagnostic Data

`Attachment.record(_:named:)` saves a value with the current test. The base `Testing` module supports `String` and `[UInt8]`. Importing Foundation adds `Data`, file `URL`s, and any `Encodable` type that also conforms to `Attachable`:

```swift
import Testing
import Foundation

struct Invoice: Codable, Attachable {
    var id: UUID
    var lines: [Line]
    struct Line: Codable { var sku: String; var cents: Int }
}

@Test func invoiceTotalsMatchServer() async throws {
    let invoice = try await InvoiceService.mock.fetchLatest()
    Attachment.record(invoice, named: "invoice.json")   // encoded as JSON

    let total = invoice.lines.reduce(0) { $0 + $1.cents }
    #expect(total == 12_499)
}
```

In Xcode 26, attachments appear in the **test report** next to the test, whether it passed or failed. With `xcodebuild`, you find them in the `.xcresult` bundle. With `swift test`, pass `--attachments-path <dir>` to write them to disk.

## Image Attachments

On Apple platforms, the UIKit, AppKit, Core Graphics, and Core Image overlays let you attach images directly. This works well for rendering checks:

```swift
import SwiftUI
import Testing

@MainActor
@Test func badgeRendersAtLargeDynamicType() throws {
    let renderer = ImageRenderer(content: BadgeView(count: 99)
        .environment(\.dynamicTypeSize, .accessibility3))
    let image = try #require(renderer.cgImage)
    Attachment.record(image, named: "badge-ax3")
    #expect(image.width > 0)
}
```

## Best Practices

- **Prefer `.failure` over specific signals** for Swift traps. The signal can differ between architectures and platforms.
- **Keep exit-test bodies small.** Each one launches a process, so they cost much more than normal tests.
- **Move code that can trap into a package** so you can run exit tests on macOS even if your app only ships on iOS.
- **Use `observing:` only when you'll check the output.** Capturing stdout and stderr adds overhead.
- **Record attachments before your assertions** so the data is still saved when a `#require` stops the test early.
- **Give attachments descriptive names with extensions** (`.json`, `.txt`, `.png`) so Xcode and CI tools open them correctly.
- **Don't attach secrets or personal data.** Attachments are stored in result bundles and CI artifacts.

## References

- [Swift Testing — Exit testing (Apple Developer Documentation)](https://developer.apple.com/documentation/testing/exit-testing)
- [Swift Testing — Attachments (Apple Developer Documentation)](https://developer.apple.com/documentation/testing/attachments)
- [ST-0008: Exit Tests (swift-evolution)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0008-exit-tests.md)
- [ST-0009: Attachments (swift-evolution)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/testing/0009-attachments.md)
- [WWDC25: What's new in Swift](https://developer.apple.com/videos/play/wwdc2025/245/)
- [Swift Testing: The Complete Guide from Swift 6.0 to 6.2](https://www.atelier-socle.com/en/articles/swift-testing-guide)
