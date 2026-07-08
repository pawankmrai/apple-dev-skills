---
topic: Swift Iterable Protocol — Borrowing Iteration for Non-Copyable Types
date: 2026-07-08
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: advanced
---

# Swift Iterable Protocol — Borrowing Iteration for Non-Copyable Types

Every `for`-`in` loop in Swift has, until now, been powered by `Sequence` and `IteratorProtocol`. That machinery works by *copying* each element out of the collection into the loop variable, then relying on ARC or copy-on-write to make the copy cheap. It's an assumption that breaks down for `~Copyable` types: a `Span`, an `InlineArray` of a noncopyable element, or a hand-rolled resource handle can't be copied at all, so it could never appear as the element type of a `Sequence`. Swift 6.4 introduces a second, parallel protocol — `Iterable` — that a `for`-`in` loop can use instead. The difference is one word: `Iterable` *borrows* elements rather than copying them.

## Why Sequence Wasn't Enough

`Sequence.makeIterator()` and `IteratorProtocol.next() -> Element?` both return the element by value. For a class instance that means a retain; for a copy-on-write struct like `Array` it means an uniqueness check; for a `~Copyable` type it's simply illegal — the compiler has nothing to hand back. Workarounds before 6.4 meant dropping into manual indexing with `withUnsafeBufferPointer`, losing the readability of `for`-`in` entirely.

## The Protocol Shape

`Iterable` is deliberately close to `Sequence` in spirit but borrow-based under the hood. Conceptually:

```swift
public protocol Iterable<Element> {
    associatedtype Element: ~Copyable
    associatedtype Iterator: IterableIterator<Element>
    borrowing func makeIterator() -> Iterator
}

public protocol IterableIterator<Element>: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func next() -> borrowing Element?
}
```

The loop borrows the collection for the duration of iteration and borrows each element as it's produced — nothing is copied, nothing is retained. Internally, the standard library implementation is built around handing out `Span`s of contiguous elements rather than one element at a time where possible, which is what lets tight loops over `InlineArray` and `Span` compile down to pointer walks with no ARC traffic at all.

## Adopting Iterable

```swift
struct RingBuffer<Element: ~Copyable>: ~Copyable {
    private var storage: [Element?]
    private var head = 0
    private var count = 0

    mutating func push(_ element: consuming Element) {
        // ... store at (head + count) % storage.count
    }
}

extension RingBuffer: Iterable {
    borrowing func makeIterator() -> Iterator {
        Iterator(buffer: self, index: 0)
    }

    struct Iterator: ~Copyable, IterableIterator {
        let buffer: borrowing RingBuffer
        var index: Int

        mutating func next() -> borrowing Element? {
            guard index < buffer.count else { return nil }
            defer { index += 1 }
            return buffer.storage[(buffer.head + index) % buffer.storage.count]
        }
    }
}

func drain(_ buffer: borrowing RingBuffer<Job>) {
    for job in buffer {   // borrows each Job; no copies, no ARC churn
        job.run()
    }
}
```

Because `Element` can be `~Copyable`, a `RingBuffer<Job>` where `Job` holds a unique file handle or GPU resource now works with ordinary `for`-`in` syntax — something a `Sequence` conformance couldn't express.

## Throwing Iteration

Unlike `Sequence`, `IterableIterator.next()` is allowed to `throw`, matching the ergonomics `AsyncSequence` already has for async work:

```swift
protocol IterableIterator<Element>: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Failure: Error = Never
    mutating func next() throws(Failure) -> borrowing Element?
}

for try record in csvReader {
    process(record)   // a malformed row can throw mid-iteration
}
```

This removes a long-standing gap where validating input during iteration meant buffering results into an array first just to get error propagation.

## The Exclusivity Rule

Because the loop holds a borrow on the whole collection, Swift's exclusivity checker forbids mutating the collection from inside the loop body — the same rule that already applies to `withContiguousStorageIfAvailable`. Code like this fails to compile:

```swift
for item in buffer {
    buffer.push(item)   // error: overlapping access to 'buffer'
}
```

This used to be a runtime trap with `Array` (an exclusivity crash or silently stale iteration); with `Iterable` it's a compile-time diagnostic instead. Collect indices or elements you need to mutate into a separate buffer first, then apply the mutation after the loop.

## How `for`-`in` Chooses

`for`-`in` prefers `Iterable` conformance when both `Iterable` and `Sequence` are visible, so migrating an existing type is additive: keep your `Sequence` conformance for source compatibility with generic code that constrains on `Sequence`, and add `Iterable` alongside it for the loop-performance win. The standard library ships `Iterable` conformances for `Array`, `Span`, `InlineArray`, and `ContiguousArray` already, so most call sites benefit without any source changes.

## Best Practices

Reach for a custom `Iterable` conformance when your element type is `~Copyable`, when profiling shows ARC traffic from repeated `Sequence` iteration over reference types, or when a loop needs to throw partway through. Don't bother retrofitting `Iterable` onto plain value types like small structs of integers — the compiler already optimizes those `Sequence` loops well, and `Sequence` remains the right protocol to constrain generic APIs against unless you specifically need borrow semantics. When a type must support both mutation-during-traversal and iteration, expose an explicit index-based API instead of fighting the exclusivity checker.

## References

- [SE-0516: Borrowing Sequence (Iterable)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0516-borrowing-sequence.md)
- [SE-0493: Async Defer](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0493-async-defer.md)
- [What's New in Swift — WWDC26](https://developer.apple.com/videos/play/wwdc2026/262/)
- [Swift.org — What's New in Swift, June 2026](https://www.swift.org/blog/whats-new-in-swift-june-2026/)
