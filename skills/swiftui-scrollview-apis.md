---
topic: SwiftUI ScrollView APIs — Position, Target Behavior, and Scroll Transitions
date: 2026-06-29
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI ScrollView APIs — Position, Target Behavior, and Scroll Transitions

For years, fine-grained scroll control in SwiftUI meant dropping down to `UIScrollView` through `UIViewRepresentable`. The modern declarative scroll APIs — `scrollPosition`, `scrollTargetBehavior`, `scrollTargetLayout`, and `scrollTransition` — remove that need. This skill covers how they fit together to build snapping carousels, programmatic scrolling, and offset-driven visual effects entirely in SwiftUI.

## Tracking and Setting Position with `scrollPosition`

`ScrollPosition` is a semantic value describing where a scroll view sits within its content. Bind it to read the topmost visible view's ID and to scroll programmatically. Pair it with `scrollTargetLayout()` on the lazy stack so SwiftUI knows which subviews to track.

```swift
struct FeedView: View {
    let items: [Item]
    @State private var position = ScrollPosition(idType: Item.ID.self)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(items) { item in
                    ItemCard(item: item)
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($position)
        .overlay(alignment: .bottomTrailing) {
            Button("Top") {
                withAnimation { position.scrollTo(edge: .top) }
            }
            .padding()
        }
    }
}
```

`scrollTo` accepts an edge, a specific view ID (`position.scrollTo(id: item.id)`), or a point. Reading `position.viewID(type:)` tells you what's currently anchored — useful for pagination triggers or "currently reading" indicators.

## Snapping with `scrollTargetBehavior`

`scrollTargetBehavior` controls where the scroll view comes to rest. Built-in options cover the common cases: `.paging` snaps a full container width/height at a time, and `.viewAligned` snaps to the nearest target in a `scrollTargetLayout`.

```swift
struct Carousel: View {
    let pages: [Page]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages) { page in
                    PageView(page: page)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}
```

`containerRelativeFrame(.horizontal)` sizes each page to the scroll container, giving a clean full-width carousel. For a custom rest position, conform a type to `ScrollTargetBehavior`:

```swift
struct SnapToHundreds: ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.y = (target.rect.origin.y / 100).rounded() * 100
    }
}
```

## Offset-Driven Effects with `scrollTransition`

`scrollTransition` applies effects as a view moves through the visible area. The closure receives a `content` proxy and a `phase` that is one of three values: `.topLeading` (entering), `.identity` (fully visible), and `.bottomTrailing` (leaving). Use `phase.isIdentity` and `phase.value` (a normalized −1…1 position) to interpolate.

```swift
ForEach(items) { item in
    ItemCard(item: item)
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.3)
                .scaleEffect(phase.isIdentity ? 1 : 0.85)
                .blur(radius: phase.isIdentity ? 0 : 4)
        }
}
```

Because the transition is derived from scroll offset rather than a timed animation, effects track the user's finger precisely and reverse smoothly. Keep the modifier list short — heavy effects (blur, shadow) on many simultaneously visible cells can cost frame time.

## Detecting Scroll Phase and Geometry

`onScrollPhaseChange` reports transitions between `.idle`, `.interacting`, `.decelerating`, and `.animating`, which is ideal for pausing video or deferring expensive work while the user drags. `onScrollGeometryChange` observes properties like `contentOffset` or `contentSize` and fires only when a value you select actually changes.

```swift
.onScrollPhaseChange { _, newPhase in
    isScrolling = newPhase != .idle
}
.onScrollGeometryChange(for: Bool.self) { geometry in
    geometry.contentOffset.y > 200
} action: { _, pastThreshold in
    showScrollToTop = pastThreshold
}
```

## Best Practices

Apply `scrollTargetLayout()` to the lazy container (the `LazyVStack`/`LazyHStack`), not to the `ScrollView` itself, or alignment targets won't be detected. Prefer `.viewAligned` over manual offset math for snapping lists, and reserve custom `ScrollTargetBehavior` conformances for genuinely non-standard rest positions. Mutate `ScrollPosition` inside `withAnimation` for animated jumps and without it for instant ones. Keep `scrollTransition` effect chains lightweight since they evaluate continuously during scrolling, and choose `onScrollGeometryChange` over a `GeometryReader`-in-background hack — it's cheaper and only fires on real changes. Always test these layouts with Dynamic Type and across size classes, because `containerRelativeFrame` and snapping behavior interact with the container's measured size.

## References

- [Beyond scroll views — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10159/)
- [ScrollPosition — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/scrollposition)
- [ScrollTargetBehavior — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior)
- [The Evolution of SwiftUI Scroll Control APIs — fatbobman](https://fatbobman.com/en/posts/the-evolution-of-swiftui-scroll-control-apis/)
