---
topic: "Swift Parameter Packs — Variadic Generics for Type-Safe APIs"
date: 2026-07-12
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Parameter Packs — Variadic Generics for Type-Safe APIs

Before parameter packs, writing a generic function that accepted "any number of arguments with distinct types" meant either boxing everything into `[Any]` or hand-rolling overloads for 2, 3, 4... parameters. Parameter packs (SE-0393, SE-0398, SE-0399) let you abstract over an *arbitrary-length list of types* while keeping full type safety. They're also the reason SwiftUI's `ViewBuilder` no longer caps out at 10 children — variadic generics replaced the old block of magic overloads.

## The Problem They Solve

```swift
// Before: overload explosion, capped arity
func makePair<A, B>(_ a: A, _ b: B) -> (A, B) { (a, b) }
func makeTriple<A, B, C>(_ a: A, _ b: B, _ c: C) -> (A, B, C) { (a, b, c) }
// ...and so on, forever
```

Parameter packs collapse this family of overloads into one declaration.

## Basic Syntax

A type parameter pack is declared with `each`, and expanded with `repeat each`:

```swift
func makeTuple<each Value>(_ value: repeat each Value) -> (repeat each Value) {
    return (repeat each value)
}

let point = makeTuple(3, "y", 4.5)   // (Int, String, Double)
```

- `each Value` — the pack itself, standing in for a list of types.
- `repeat each Value` — a *pack expansion*: "do this for every element in the pack."
- The same pattern applies to parameters, return types, and tuples simultaneously, so arity always lines up.

## Constraining Packs

Packs can carry protocol conformances, just like a single generic parameter:

```swift
func logAll<each T: CustomStringConvertible>(_ items: repeat each T) {
    repeat print((each items).description)
}

logAll(42, "hello", 3.14, true)
```

Every element in the pack must independently satisfy `CustomStringConvertible` — the compiler checks each expansion.

## Pack Iteration (Swift 6.0+)

Swift 6 added direct iteration support so you don't need recursive helper functions to "loop" over a pack:

```swift
func sumLengths<each T: Collection>(_ collections: repeat each T) -> Int {
    var total = 0
    repeat total += (each collections).count
    return total
}

sumLengths([1, 2, 3], "hello", Set([1, 2]))   // 3 + 5 + 2 = 10
```

`repeat` here compiles to a loop over the pack at compile time — each iteration is fully type-checked against its own element type, not erased to a common supertype.

## Real-World Example: A Type-Safe Event Dispatcher

```swift
struct Event<each Payload> {
    let name: String
    let handler: (repeat each Payload) -> Void

    func fire(_ payload: repeat each Payload) {
        handler(repeat each payload)
    }
}

let loginEvent = Event<String, Date>(name: "login") { user, timestamp in
    print("\(user) logged in at \(timestamp)")
}

loginEvent.fire("pkrai", .now)
```

This scales from zero-argument events to five-argument events with the same struct — no `Event0`, `Event1`, `Event2` proliferation, and every call site is checked against the exact payload types.

## Where SwiftUI Uses This

`ViewBuilder`'s `buildBlock` methods used to be manually overloaded up to 10 views. With parameter packs, the framework can express "one or more views of any types" generically:

```swift
// Conceptually, SwiftUI's builder now looks like:
static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<(repeat each Content)>
```

Practical effect: `VStack`, `Group`, and similar containers no longer silently break when you pass an 11th child — the old workaround of nesting `Group { }` blocks to dodge the limit is unnecessary today.

## Same-Type Requirements Across Packs

You can require two packs to line up element-for-element, which is useful for zip-like APIs:

```swift
func zip<each A, each B>(
    _ first: repeat each A,
    _ second: repeat each B
) -> (repeat (each A, each B)) {
    (repeat (each first, each second))
}

zip(1, "a", true, 2, "b", false)
```

The compiler enforces that both packs expand to the same length at each call site — mismatched arity is a compile error, not a runtime crash.

## Best Practices

- Reach for parameter packs when you're tempted to write near-identical overloads for 2, 3, 4+ arguments — that's the exact pattern they replace.
- Keep pack constraints as narrow as possible (`each T: Sendable`, `each T: Equatable`) so call sites get useful compiler errors instead of generic "no exact matches" noise.
- Don't force packs where a plain array (`[T]`) would do — packs exist specifically for *heterogeneous, fixed-arity* lists, not homogeneous collections of unknown length.
- Pair packs with `repeat` pack iteration instead of writing recursive "first + rest" helper functions; it's clearer and the compiler optimizes the expansion at compile time.
- When debugging pack-heavy generic code, isolate one arity (e.g., test with exactly 2 elements) before generalizing — compiler diagnostics on packs are still less precise than on single generic parameters.

## References

- [SE-0393: Value and Type Parameter Packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md)
- [SE-0398: Variadic Generic Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0398-variadic-types.md)
- [Pack Iteration — Swift.org Blog](https://www.swift.org/blog/pack-iteration/)
- [Value and Type Parameter Packs — Hacking with Swift](https://www.hackingwithswift.com/swift/5.9/variadic-generics)
