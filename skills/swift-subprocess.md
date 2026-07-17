---
topic: Swift Subprocess — Structured Concurrency for Process Execution
date: 2026-07-17
platform: iOS 26, macOS 26
swift: "6.4"
difficulty: intermediate
---

# Swift Subprocess — Structured Concurrency for Process Execution

`Subprocess` is the Swift-native replacement for `Foundation.Process`, built from the ground up on structured concurrency. It reached a stable 1.0-track API this year with refined error handling, line-by-line async streaming, and full cross-platform parity (macOS, Linux, Windows, Android). For macOS and Mac Catalyst tools, agents, and CLI helpers, it's now the recommended way to spawn and interact with child processes.

## Adding the Dependency

```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", .upToNextMinor(from: "0.4.0"))
]
```

```swift
.target(
    name: "MyTool",
    dependencies: [.product(name: "Subprocess", package: "swift-subprocess")]
)
```

The `SubprocessFoundation` package trait is on by default and adds `Data`-based overloads for input and output.

## Running a Process and Collecting Output

The simplest form awaits a result directly, no delegates or completion handlers:

```swift
import Subprocess

let result = try await run(.name("git"), arguments: ["rev-parse", "HEAD"], output: .string(limit: 4096))

print(result.terminationStatus)      // .exited(0)
print(result.standardOutput ?? "")   // the commit SHA
```

Every collecting output option requires a `limit`, so a runaway process can never balloon memory: `Subprocess` throws if the child exceeds it.

## Streaming Output Line by Line

For long-running or chatty processes, pass a closure and opt into `.sequence` output. The closure — and everything handed to it — is only valid for its duration, so don't let `Execution` escape it:

```swift
let result = try await run(
    .path("/usr/bin/tail"),
    arguments: ["-f", "/var/log/build.log"],
    output: .sequence,
    error: .discarded
) { execution in
    for try await line in execution.standardOutput.lines() {
        if line.contains("error:") {
            print("Build failure: \(line)")
        }
    }
}
```

`.lines()` respects grapheme cluster boundaries, so multi-byte characters never get split mid-stream. You can specify an explicit encoding and buffering policy too:

```swift
for try await line in execution.standardOutput.lines(encoding: UTF8.self, bufferingPolicy: .maxLineLength(2048)) {
    // ...
}
```

## Writing to Standard Input

Opt into `.inputWriter` to feed a process interactively, then combine it with concurrent output reading via a task group:

```swift
try await run(.name("cat"), input: .inputWriter, output: .sequence, error: .discarded) { execution in
    async let reading: Void = {
        for try await line in execution.standardOutput.lines() {
            print(line)
        }
    }()

    try await execution.standardInputWriter.write("Hello, Subprocess!\n")
    try await execution.standardInputWriter.finish()
    try await reading
}
```

Mixed use is common: stream standard output from the closure while collecting standard error as a plain string via `error: .string(limit:)`, or merge both streams with `error: .combinedWithOutput` (equivalent to shell's `2>&1`).

## Graceful Teardown on Cancellation

When the parent `Task` is cancelled, `PlatformOptions.teardownSequence` lets you shut a child process down politely before force-killing it:

```swift
var platformOptions = PlatformOptions()
platformOptions.teardownSequence = [
    .send(signal: .interrupt, allowedDurationToNextStep: .seconds(2)),
    .gracefulShutDown(allowedDurationToNextStep: .seconds(5))
]

let serverTask = Task {
    try await run(.name("dev-server"), platformOptions: platformOptions, output: .discarded)
}

// Later:
serverTask.cancel()
// Subprocess sends SIGINT, waits up to 2s, sends SIGTERM equivalent,
// waits up to 5s, then SIGKILLs if the process is still alive.
```

On macOS you also get a `preSpawnProcessConfigurator` escape hatch for raw `posix_spawn` attributes when you need behavior `PlatformOptions` doesn't expose directly.

## Best Practices

Prefer `.string(limit:)` or `.bytes(limit:)` over unbounded reads for any process whose output size you don't fully control — the limit is your safety net against a misbehaving child. Reach for the closure-based `run` with `.sequence` output only when you need to react to output as it arrives (log tailing, progress parsing); use the simple collecting `run` for everything else, since it's harder to misuse. Always pair `.inputWriter` with `finish()` — an unfinished writer leaves the child process blocked waiting for EOF. When launching long-lived helper processes from an app or agent, set a `teardownSequence` so cancellation doesn't leave orphaned processes behind. Because `Subprocess` is cross-platform, avoid `Darwin`-only escape hatches like `preSpawnProcessConfigurator` unless the tool is macOS-only.

## References

- [swift-subprocess on GitHub](https://github.com/swiftlang/swift-subprocess)
- [Swift Evolution: Subprocess proposal](https://github.com/swiftlang/swift-foundation/blob/main/Proposals/0007-swift-subprocess.md)
- [Swift.org Blog](https://www.swift.org/blog/)
