---
topic: Swift Regex and RegexBuilder — Type-Safe Pattern Matching
date: 2026-06-30
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Regex and RegexBuilder — Type-Safe Pattern Matching

Swift's `Regex` type brings pattern matching into the language with full Unicode
correctness, compile-time literals, and a result-builder DSL that reads like
ordinary Swift. Unlike `NSRegularExpression`, captures are *strongly typed*: the
compiler knows how many groups a pattern has and what type each one produces, so
you destructure matches without stringly-typed index juggling. This guide covers
literals, the `RegexBuilder` DSL, typed captures, and the algorithms that consume
them.

## Regex Literals and the Basics

A regex literal is written between slashes. The compiler validates the syntax and
infers the `Output` type from the capture groups.

```swift
import RegexBuilder

let semver = /(\d+)\.(\d+)\.(\d+)/
// Output is (Substring, Substring, Substring, Substring)

if let match = "App version 4.2.1 shipped".firstMatch(of: semver) {
    let (whole, major, minor, patch) = match.output
    print(whole)               // 4.2.1
    print(major, minor, patch) // 4 2 1
}
```

Use `wholeMatch(of:)` when the entire string must match, `firstMatch(of:)` for the
first occurrence, and `matches(of:)` for every occurrence as a lazy collection.

## The RegexBuilder DSL

For anything beyond a trivial pattern, the DSL is far more readable than a dense
literal. Components like `Capture`, `ZeroOrMore`, `OneOrMore`, `Optionally`, and
`ChoiceOf` compose declaratively, and you can embed literals inside.

```swift
import RegexBuilder

let logLine = Regex {
    "["
    Capture { OneOrMore(.digit) }      // timestamp
    "] "
    Capture {                          // log level
        ChoiceOf { "INFO"; "WARN"; "ERROR" }
    }
    ": "
    Capture { OneOrMore(.any) }        // message
}

if let m = "[1719700000] ERROR: disk full".firstMatch(of: logLine) {
    let (_, ts, level, message) = m.output
    print(ts, level, message)          // 1719700000 ERROR disk full
}
```

## Typed Captures with Transforms

A `Capture` can carry a transform closure that converts the matched substring into
a domain type. The transform's return type flows into `Output`, so downstream code
gets `Int`, `Date`, or your own model instead of `Substring`.

```swift
let pricePattern = Regex {
    "$"
    Capture {
        OneOrMore(.digit)
        "."
        Repeat(.digit, count: 2)
    } transform: { Double($0)! }
}

let price = "$19.99".firstMatch(of: pricePattern)?.output.1
// price is Double? == 19.99
```

For named, position-independent access use `Reference`:

```swift
let yearRef = Reference(Int.self)
let datePattern = Regex {
    TryCapture(as: yearRef) {
        Repeat(.digit, count: 4)
    } transform: { Int($0) }
    "-"
    Repeat(.digit, count: 2)
}

if let m = "2026-06".firstMatch(of: datePattern) {
    print(m[yearRef])                  // 2026
}
```

`TryCapture` drops the match entirely when the transform returns `nil`, which keeps
invalid input from producing a half-parsed result.

## Consuming Matches

`Regex` plugs into the standard string algorithms: `replacing(_:with:)`,
`split(separator:)`, `trimmingPrefix(_:)`, and `ranges(of:)` all accept a regex.

```swift
let cleaned = "a,,b, ,c".replacing(/,\s*,?/, with: ",")
let words = "one\t two   three".split(separator: /\s+/)
```

You can also match patterns directly in `case` labels:

```swift
switch userInput {
case let s where s.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil:
    print("looks like a date")
case let s where s.wholeMatch(of: /\w+@\w+\.\w+/) != nil:
    print("looks like an email")
default:
    print("unrecognized")
}
```

## Best Practices

- Prefer regex literals for short, fixed patterns and the `RegexBuilder` DSL for
  anything with multiple captures or alternation — readability compounds quickly.
- Push parsing into `Capture`/`TryCapture` transforms so the rest of your code
  works with typed values, not substrings.
- Use `Reference` instead of positional tuple indices when a pattern has many
  captures or is likely to change; it keeps call sites stable.
- Reach for `RegexComponent`-conforming parsers (`.iso8601`, `.localizedCurrency`,
  `.localizedInteger`) rather than hand-rolling number and date patterns.
- Compile a `Regex` once and reuse it; building from a literal is cheap, but doing
  it inside a tight loop is wasteful.
- Validate untrusted patterns built at runtime with `try Regex(_:)` and handle the
  thrown error; never force-unwrap a user-supplied pattern.

## References

- [Apple Developer — Regex](https://developer.apple.com/documentation/swift/regex)
- [Apple Developer — RegexBuilder](https://developer.apple.com/documentation/regexbuilder)
- [Swift Evolution SE-0351 — Regex builder DSL](https://github.com/apple/swift-evolution/blob/main/proposals/0351-regex-builder.md)
- [WWDC22 — Meet Swift Regex](https://developer.apple.com/videos/play/wwdc2022/110357/)
- [WWDC22 — Swift Regex: Beyond the basics](https://developer.apple.com/videos/play/wwdc2022/110358/)
