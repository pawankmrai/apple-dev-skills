---
topic: Xcode Debugging and Instruments
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Xcode Debugging and Instruments

Effective debugging and profiling separate good developers from great ones. Xcode provides a rich set of tools — from LLDB breakpoints to Instruments profiling — that help you find and fix issues fast.

## LLDB Breakpoints

Beyond basic line breakpoints, LLDB supports conditional and action-based breakpoints:

```
# Break only when count exceeds 100
breakpoint set --name fetchData --condition 'count > 100'

# Print a value and continue without stopping
breakpoint set --name viewDidLoad --command 'po self.title' --auto-continue true
```

In Xcode, right-click any breakpoint to add conditions, actions (log message, shell command, debugger command), or set it to continue after evaluating.

## Symbolic Breakpoints

Catch framework events without knowing the exact line:

- **Exception Breakpoint** — pauses on any thrown Objective-C or Swift exception. Add via the Breakpoint navigator (+) → Exception Breakpoint.
- **Symbolic Breakpoint** — break on any function by name:
  - `UIViewAlertForUnsatisfiableConstraints` — catches Auto Layout issues
  - `swift_willThrow` — pauses before any Swift error is thrown
  - `-[UIApplication sendAction:to:from:forEvent:]` — tracks every UI action

## The `po` and `p` Commands

```
(lldb) po myArray           // Pretty-print with description
(lldb) p myArray.count      // Print with type info
(lldb) e myVariable = 42    // Modify state at runtime
(lldb) frame variable       // Show all local variables
```

For custom types, conform to `CustomDebugStringConvertible` to improve `po` output:

```swift
extension Recipe: CustomDebugStringConvertible {
    var debugDescription: String {
        "Recipe(\(name), \(ingredients.count) ingredients)"
    }
}
```

## View Debugging

Click the **Debug View Hierarchy** button (stacked rectangles icon) during a paused debug session to get a 3D exploded view of your UI. This reveals hidden views, ambiguous layouts, and constraint issues visually.

For SwiftUI, enable **Environment Overrides** in the debug bar to test Dynamic Type, Dark Mode, and accessibility settings live.

## Memory Graph Debugger

Click the **Memory Graph** button to inspect all live objects and their references. Use it to find retain cycles — look for strong reference loops between objects that should have been deallocated.

```swift
// Common retain cycle — closure captures self strongly
class ViewModel {
    var onComplete: (() -> Void)?

    func start() {
        onComplete = { [weak self] in  // Fix: capture weakly
            self?.finish()
        }
    }
}
```

## Instruments Profiling

Launch Instruments from Xcode via **Product → Profile** (⌘I). Key instruments:

### Time Profiler
Identifies where your app spends CPU time. Look for hot paths — functions with high "self weight" are optimization targets.

### Allocations
Tracks every heap allocation. Filter by your app's classes to find objects that grow unboundedly (memory leaks) or allocate excessively.

### Leaks
Detects unreachable memory — objects that are allocated but have no remaining references.

### Network
Shows all HTTP/HTTPS requests with timing, size, and response codes. Identify redundant or slow API calls.

### SwiftUI Instrument
Profiles SwiftUI view body evaluations. Find views whose bodies are called too often and optimize with `@Observable` or `EquatableView`.

## Structured Logging with os.log

Replace `print()` with structured logging for production diagnostics:

```swift
import os

let logger = Logger(subsystem: "com.myapp", category: "networking")

func fetchRecipes() async throws -> [Recipe] {
    logger.info("Starting recipe fetch")
    let start = CFAbsoluteTimeGetCurrent()

    let recipes = try await api.getRecipes()

    let elapsed = CFAbsoluteTimeGetCurrent() - start
    logger.debug("Fetched \(recipes.count) recipes in \(elapsed, format: .fixed(precision: 2))s")

    return recipes
}
```

View logs in Console.app with subsystem/category filtering — even from production devices.

## Best Practices

- **Use symbolic breakpoints** for framework-level debugging — they work without modifying code.
- **Profile on real devices** — Simulator performance is not representative of actual hardware.
- **Use `os.log` over `print()`** — it survives release builds, supports filtering, and has negligible performance cost.
- **Run the Memory Graph Debugger** periodically during development to catch retain cycles early.
- **Set conditional breakpoints** in loops or frequently-called code to avoid drowning in stops.
- **Profile before optimizing** — don't guess where the bottleneck is; let Instruments tell you.

## References

- [Debugging with Xcode | Apple Developer Documentation](https://developer.apple.com/documentation/xcode/debugging)
- [Instruments | Apple Developer Documentation](https://developer.apple.com/documentation/instruments)
- [LLDB Debugging Guide — Apple](https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/gdb_to_lldb_transition_guide/)
