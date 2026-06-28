---
topic: SwiftUI Custom Layout Protocol — Building Your Own Stacks
date: 2026-06-28
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI Custom Layout Protocol — Building Your Own Stacks

`HStack`, `VStack`, and `Grid` cover most layouts, but sometimes you need views arranged in a flow, a radial dial, or a justified row. The `Layout` protocol gives you direct access to SwiftUI's layout engine so your custom container behaves exactly like a built-in stack — it composes, animates, and respects the environment without `GeometryReader` hacks.

A conforming type implements two required methods: `sizeThatFits(proposal:subviews:cache:)` reports how much space the container wants, and `placeSubviews(in:proposal:subviews:cache:)` positions each child. SwiftUI hands you a `ProposedViewSize` and a `Subviews` collection of opaque proxies you can measure and place.

## A Flow Layout

This layout wraps subviews onto new lines when they run out of horizontal room — the classic "tag cloud" arrangement.

```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: maxWidth)
        let height = rows.last.map { $0.y + $0.rowHeight } ?? 0
        return CGSize(width: maxWidth == .infinity ? rows.maxX : maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, in: bounds.width)
        for row in rows {
            for item in row.items {
                let point = CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y)
                subviews[item.index].place(at: point, anchor: .topLeading, proposal: .unspecified)
            }
        }
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row(y: rows.reduce(0) { $0 + $1.rowHeight + spacing })
                x = 0
            }
            current.items.append(.init(index: index, x: x, width: size.width))
            current.rowHeight = max(current.rowHeight, size.height)
            x += size.width + spacing
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

private struct Row {
    struct Item { let index: Int; let x: CGFloat; let width: CGFloat }
    var items: [Item] = []
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat { items.map { $0.x + $0.width }.max() ?? 0 }
}

private extension Array where Element == Row {
    var maxX: CGFloat { map(\.maxX).max() ?? 0 }
}
```

Use it like any container:

```swift
FlowLayout(spacing: 10) {
    ForEach(tags, id: \.self) { tag in
        Text(tag)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.tint.opacity(0.2), in: .capsule)
    }
}
```

## Caching Expensive Measurements

When `sizeThatFits` and `placeSubviews` both compute the same arrangement, hoist the work into the `cache`. SwiftUI calls `makeCache` once and reuses the result across both passes, invalidating it when subviews change.

```swift
struct CachedFlow: Layout {
    struct Cache { var rows: [Row] = []; var width: CGFloat = -1 }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? .infinity
        if cache.width != width {            // only recompute when the proposal changes
            cache.rows = layoutRows(subviews, width: width)
            cache.width = width
        }
        let height = cache.rows.last.map { $0.y + $0.rowHeight } ?? 0
        return CGSize(width: width, height: height)
    }
    // placeSubviews reads cache.rows directly...
}
```

## Reading Per-Subview Values with LayoutValueKey

Pass layout-specific data from a child up to its container using `LayoutValueKey` — the mechanism behind a grid's column span or a custom priority.

```swift
private struct RankKey: LayoutValueKey {
    static let defaultValue: Int = 0
}

extension View {
    func layoutRank(_ rank: Int) -> some View { layoutValue(key: RankKey.self, value: rank) }
}

// Inside a Layout method:
let rank = subviews[index][RankKey.self]   // read it back during placement
```

## Best Practices

Keep layout math pure and deterministic; SwiftUI may call `sizeThatFits` multiple times per frame with different proposals, so avoid side effects. Always honor `ProposedViewSize`'s three states — a concrete value, `nil` (unspecified, meaning "use your ideal size"), and `.infinity` — rather than assuming a finite width. Measure children with `subviews[i].sizeThatFits(_:)` instead of guessing, and respect each subview's reported size when placing it. Move shared computation into `cache` whenever both passes need it, and implement `makeCache`/`updateCache` so the work runs once. Prefer the `Layout` protocol over nested `GeometryReader`s — it animates correctly, participates in the layout pass, and is far cheaper. For animation, conform your layout's parameters to `Animatable` to interpolate between configurations smoothly.

## References

- [Composing custom layouts with SwiftUI](https://developer.apple.com/documentation/swiftui/composing-custom-layouts-with-swiftui)
- [Layout protocol — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/layout)
- [LayoutValueKey — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/layoutvaluekey)
- [WWDC22: Compose custom layouts with SwiftUI](https://developer.apple.com/videos/play/wwdc2022/10056/)
