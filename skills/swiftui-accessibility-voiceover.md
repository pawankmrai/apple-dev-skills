---
topic: "SwiftUI Accessibility: VoiceOver, Dynamic Type, and Custom Actions"
date: 2026-05-16
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI Accessibility: VoiceOver, Dynamic Type, and Custom Actions

Building accessible apps is a core part of delivering a great user experience. SwiftUI provides a rich set of accessibility modifiers that make it straightforward to support VoiceOver, Dynamic Type, and custom interactions.

## Accessibility Labels, Values, and Hints

Every interactive element should have a clear accessibility label. SwiftUI infers labels from `Text` views automatically, but custom views need explicit annotations.

```swift
struct RatingView: View {
    let score: Int
    let maxScore: Int

    var body: some View {
        HStack {
            ForEach(1...maxScore, id: \.self) { index in
                Image(systemName: index <= score ? "star.fill" : "star")
                    .foregroundStyle(index <= score ? .yellow : .gray)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(score) out of \(maxScore) stars")
    }
}
```

`.accessibilityElement(children: .ignore)` collapses the star images into one element so VoiceOver reads a single coherent description.

## Grouping and Hiding Elements

Combine related views into a single accessibility element and hide decorative content.

```swift
struct ContactCard: View {
    let name: String
    let role: String

    var body: some View {
        HStack {
            Image("avatar")
                .accessibilityHidden(true) // decorative

            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(role).font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
```

`.combine` tells VoiceOver to read the name and role as one element. `.accessibilityHidden(true)` removes the decorative image from the accessibility tree entirely.

## Custom Accessibility Actions

Replace complex gestures with named actions so VoiceOver users can discover and trigger them by swiping up and down.

```swift
struct MessageRow: View {
    let message: Message
    var onArchive: () -> Void
    var onFlag: () -> Void

    var body: some View {
        Text(message.body)
            .accessibilityAction(named: "Archive") { onArchive() }
            .accessibilityAction(named: "Flag") { onFlag() }
    }
}
```

This replaces swipe-to-delete or long-press gestures that are invisible to assistive technologies.

## Managing Accessibility Focus

Programmatically move VoiceOver focus when content changes using `@AccessibilityFocusState`.

```swift
struct SearchResultsView: View {
    @State private var results: [String] = []
    @AccessibilityFocusState private var isResultsFocused: Bool

    var body: some View {
        VStack {
            Button("Search") {
                results = performSearch()
                isResultsFocused = true
            }
            List(results, id: \.self) { Text($0) }
                .accessibilityFocused($isResultsFocused)
        }
    }

    func performSearch() -> [String] { ["Result A", "Result B"] }
}
```

## Supporting Dynamic Type

SwiftUI handles Dynamic Type automatically with system fonts. For custom dimensions, use `@ScaledMetric` so they scale proportionally.

```swift
struct BadgeView: View {
    let count: Int
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 24

    var body: some View {
        Text("\(count)")
            .font(.caption)
            .frame(minWidth: size, minHeight: size)
            .background(.red)
            .clipShape(Circle())
            .foregroundStyle(.white)
    }
}
```

## Best Practices

- **Test with VoiceOver regularly.** Use the Accessibility Inspector in Xcode to audit views without leaving the simulator.
- **Use `.combine` generously.** Fewer, more descriptive elements are better than many granular ones.
- **Provide `.accessibilityHint` sparingly.** Hints explain non-obvious behavior — don't repeat the label.
- **Replace custom gestures** with accessibility actions for discoverability.
- **Test at the largest Dynamic Type sizes** using Xcode's Environment Overrides.
- **Announce dynamic changes** with `AccessibilityNotification.Announcement` when content updates silently.

## References

- [Apple: Supporting VoiceOver in Your App](https://developer.apple.com/documentation/uikit/supporting-voiceover-in-your-app)
- [Apple: Accessibility Modifiers (SwiftUI)](https://developer.apple.com/documentation/swiftui/view-accessibility)
- [Hacking with Swift: Accessibility Checklist](https://www.hackingwithswift.com/articles/91/checklist-how-to-make-your-ios-app-more-accessible)
