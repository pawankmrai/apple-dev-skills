---
topic: Performance — Memory Management and Profiling
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Performance — Memory Management and Profiling

Understanding how Swift manages memory and how to profile your app is critical for building responsive, resource-efficient applications. This skill covers ARC, common memory pitfalls, and profiling techniques.

## Automatic Reference Counting (ARC)

Swift uses ARC to track and manage memory for class instances. Each strong reference increments the count; when it reaches zero, the instance is deallocated:

```swift
class ImageCache {
    var images: [String: UIImage] = [:]

    deinit {
        print("ImageCache deallocated")
    }
}

var cache: ImageCache? = ImageCache()
cache = nil // deinit called, memory freed
```

## Retain Cycles and How to Break Them

A retain cycle occurs when two objects hold strong references to each other:

```swift
// Retain cycle — neither object is ever freed
class Parent {
    var child: Child?
    deinit { print("Parent freed") }
}

class Child {
    var parent: Parent?  // Strong reference back
    deinit { print("Child freed") }
}

var parent: Parent? = Parent()
var child: Child? = Child()
parent?.child = child
child?.parent = parent
parent = nil  // Neither deinit fires
child = nil
```

Fix with `weak` or `unowned`:

```swift
class Child {
    weak var parent: Parent?  // Weak breaks the cycle
    deinit { print("Child freed") }
}
```

### weak vs. unowned

- **`weak`** — optional, automatically set to `nil` when the referenced object is deallocated. Use when the reference might outlive the object.
- **`unowned`** — non-optional, crashes if accessed after deallocation. Use when you're certain the reference will always be valid during use.

```swift
class NetworkRequest {
    unowned let session: URLSession  // Session always outlives requests
    init(session: URLSession) { self.session = session }
}
```

## Closure Capture Lists

Closures are the most common source of retain cycles:

```swift
class ViewModel {
    var data: [String] = []
    var onUpdate: (() -> Void)?

    func startMonitoring() {
        // Retain cycle: closure → self → onUpdate → closure
        onUpdate = {
            print(self.data.count) // captures self strongly
        }

        // Fix: use capture list
        onUpdate = { [weak self] in
            guard let self else { return }
            print(self.data.count)
        }
    }
}
```

## Value Types for Performance

Prefer structs over classes when you don't need reference semantics:

```swift
// Struct — stack allocated, no ARC overhead
struct Point {
    var x: Double
    var y: Double
}

// Array of 1000 Points: no heap allocation per element
let points = (0..<1000).map { Point(x: Double($0), y: 0) }
```

Structs avoid reference counting overhead and enable compiler optimizations like copy-on-write.

## Copy-on-Write Optimization

Swift collections use copy-on-write — copies share storage until one is mutated:

```swift
var original = Array(0..<10_000)
var copy = original  // No data copied yet — shared storage

copy.append(10_000)  // NOW the data is copied
```

For custom types, implement COW manually when needed:

```swift
struct LargeData {
    private var storage: StorageRef

    var items: [Int] {
        get { storage.items }
        set {
            if !isKnownUniquelyReferenced(&storage) {
                storage = StorageRef(items: newValue)
            } else {
                storage.items = newValue
            }
        }
    }

    private class StorageRef {
        var items: [Int]
        init(items: [Int]) { self.items = items }
    }
}
```

## Lazy Initialization

Defer expensive work until actually needed:

```swift
class DataProcessor {
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    lazy var heavyModel: MLModel = {
        try! MLModel(contentsOf: modelURL)
    }()
}
```

## Autorelease Pool for Batch Operations

When creating many temporary objects in a loop, use `autoreleasepool` to limit peak memory:

```swift
func processImages(_ urls: [URL]) -> [UIImage] {
    var results: [UIImage] = []

    for url in urls {
        autoreleasepool {
            let data = try? Data(contentsOf: url)
            if let data, let image = UIImage(data: data) {
                let thumbnail = image.preparingThumbnail(of: CGSize(width: 100, height: 100))
                if let thumbnail {
                    results.append(thumbnail)
                }
            }
            // Temporary Data and full-size UIImage freed here
        }
    }
    return results
}
```

## Measuring Performance with Swift

```swift
import os

let signpost = OSSignposter()

func loadData() async throws -> [Item] {
    let state = signpost.beginInterval("DataLoad")
    defer { signpost.endInterval("DataLoad", state) }

    let items = try await api.fetchItems()
    return items
}
```

Signpost intervals appear in Instruments' Points of Interest track for precise timing.

## Quick Benchmarking

```swift
func measure(_ label: String, block: () -> Void) {
    let start = CFAbsoluteTimeGetCurrent()
    block()
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    print("\(label): \(String(format: "%.4f", elapsed))s")
}

measure("Sort 100k items") {
    _ = largeArray.sorted()
}
```

## Best Practices

- **Use structs by default** — only use classes when you need reference semantics, inheritance, or identity.
- **Always use `[weak self]` in closures** stored as properties or passed to long-lived objects.
- **Profile with Instruments**, not guesswork — use the Allocations and Leaks instruments to find actual memory issues.
- **Use `OSSignposter`** for production-quality performance measurement that shows up in Instruments.
- **Wrap batch processing in `autoreleasepool`** to prevent memory spikes.
- **Avoid premature optimization** — measure first, then optimize the actual bottleneck.
- **Watch for hidden retain cycles** in Combine (`.sink` captures), NotificationCenter observers, and timer callbacks.

## References

- [Automatic Reference Counting — The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)
- [Reducing your app's memory use — Apple Developer](https://developer.apple.com/documentation/xcode/reducing-your-app-s-memory-use)
- [Getting started with Instruments — WWDC](https://developer.apple.com/videos/play/wwdc2019/411/)
