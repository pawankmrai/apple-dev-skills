---
topic: "Swift InlineArray and Span — Safe, High-Performance Memory"
date: 2026-05-25
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift InlineArray and Span — Safe, High-Performance Memory

Swift 6.2 introduced two powerful types for working with contiguous memory: `InlineArray` for fixed-size, stack-allocated collections and `Span` for safe, non-owning views over memory. Together, they eliminate common performance pitfalls and memory safety issues without requiring unsafe code.

## InlineArray

`InlineArray` stores elements inline — on the stack or directly inside a struct — rather than heap-allocating like a standard `Array`. This makes it ideal for small, known-size collections.

### Declaration and Initialization

```swift
// Using the sugared syntax
var pixel: InlineArray<4, UInt8> = [255, 128, 64, 255]

// Repeating initializer
var matrix: InlineArray<9, Float> = InlineArray(repeating: 0.0)

// Sugar syntax with "of" keyword
var buffer: [16 of UInt8] = .init(repeating: 0)
```

### Practical Usage

```swift
struct Color {
    var components: InlineArray<4, Float>
    
    static let red = Color(components: [1.0, 0.0, 0.0, 1.0])
    static let clear = Color(components: [0.0, 0.0, 0.0, 0.0])
}

struct Transform3D {
    // 4x4 matrix stored entirely on the stack
    var elements: InlineArray<16, Double>
    
    static var identity: Transform3D {
        var t = Transform3D(elements: .init(repeating: 0.0))
        t.elements[0] = 1.0
        t.elements[5] = 1.0
        t.elements[10] = 1.0
        t.elements[15] = 1.0
        return t
    }
}
```

## Span — Safe Memory Views

`Span` provides a safe, non-owning, read-only view over contiguous memory. It replaces many uses of `UnsafeBufferPointer` with compile-time lifetime guarantees.

### Creating and Using Spans

```swift
let numbers = [10, 20, 30, 40, 50]
let span: Span<Int> = numbers.span

// Span in function signatures — accepts any contiguous storage
func dotProduct(_ a: Span<Float>, _ b: Span<Float>) -> Float {
    precondition(a.count == b.count)
    var result: Float = 0
    for i in 0..<a.count {
        result += a[i] * b[i]
    }
    return result
}

// Works with Array, InlineArray, or any contiguous source
let array: [Float] = [1.0, 2.0, 3.0]
let inline: InlineArray<3, Float> = [4.0, 5.0, 6.0]
let result = dotProduct(array.span, inline.span)
```

### Lifetime Safety

The compiler enforces that a `Span` cannot outlive the memory it references:

```swift
func safeUsage() {
    let data = [1, 2, 3, 4, 5]
    let span = data.span
    print(span[0]) // ✅ Safe — used within data's lifetime
}

// ❌ Compiler error — cannot return a span borrowing local memory
// func broken() -> Span<Int> {
//     let data = [1, 2, 3]
//     return data.span  // Error: escapes lifetime of 'data'
// }
```

### MutableSpan for In-Place Mutation

```swift
func normalize(_ values: inout MutableSpan<Float>) {
    guard let maxVal = values.max(), maxVal > 0 else { return }
    for i in 0..<values.count {
        values[i] /= maxVal
    }
}

var samples: [Float] = [2.0, 4.0, 8.0, 6.0]
normalize(&samples.mutableSpan)
// samples is now [0.25, 0.5, 1.0, 0.75]
```

## Combining InlineArray and Span

The two types work together naturally — `InlineArray` provides stack storage while `Span` enables safe sharing:

```swift
struct AudioFrame {
    var samples: InlineArray<512, Float>
    
    func process(with filter: (Span<Float>) -> [Float]) -> [Float] {
        filter(samples.span)
    }
    
    mutating func applyGain(_ gain: Float) {
        for i in 0..<samples.count {
            samples[i] *= gain
        }
    }
}
```

## Best Practices

- Use `InlineArray` for small, fixed-size data like colors, vectors, or matrices where size is known at compile time. Avoid it for large or variable-size collections.
- Prefer `Span` over `UnsafeBufferPointer` in APIs that only need to read contiguous memory — you get zero-copy performance with compile-time safety.
- Never store a `Span` in a property. Spans are for transient, borrowed access within a function scope.
- Use `MutableSpan` sparingly and only in performance-critical inner loops.
- Leverage `Span` at interop boundaries when bridging C buffers or network data for safe downstream processing.

## References

- [Swift 6.2 Release Blog](https://www.swift.org/blog/swift-6.2-released/)
- [SE-0453: InlineArray](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md)
- [SE-0447: Span — Safe Access to Contiguous Storage](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md)
- [WWDC25: What's New in Swift](https://developer.apple.com/videos/play/wwdc2025/245/)
