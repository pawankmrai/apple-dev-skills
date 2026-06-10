---
topic: TipKit — Contextual User Tips in SwiftUI
date: 2026-06-10
platform: iOS 17+, macOS 14+, watchOS 10+
swift: "6.2"
difficulty: intermediate
---

# TipKit — Contextual User Tips in SwiftUI

TipKit is Apple's framework for surfacing contextual, non-intrusive tips that teach users about features they haven't discovered yet. Tips respect user privacy (no server required) and support eligibility rules so users only see them at the right moment.

## Defining a Tip

Conform a struct to the `Tip` protocol:

```swift
import TipKit

struct FavoriteButtonTip: Tip {
    var title: Text { Text("Save to Favorites") }
    var message: Text? { Text("Tap the star to save articles for later.") }
    var image: Image? { Image(systemName: "star.fill") }
}
```

## Configure at App Launch

Call `Tips.configure()` once in your `App` struct:

```swift
@main
struct MyApp: App {
    init() {
        #if DEBUG
        try? Tips.resetDatastore()   // Always show tips during development
        #endif
        try? Tips.configure([
            .displayFrequency(.immediate),   // or .daily, .weekly
            .datastoreLocation(.applicationDefault)
        ])
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

## Showing Tips in SwiftUI

**Inline card** with `TipView`:

```swift
struct ArticleRow: View {
    let article: Article
    private let tip = FavoriteButtonTip()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title).font(.headline)
            TipView(tip, arrowEdge: .top)
            Text(article.summary).font(.caption)
        }
    }
}
```

**Popover** anchored to a button:

```swift
Button { article.isFavorited.toggle() } label: {
    Image(systemName: article.isFavorited ? "star.fill" : "star")
}
.popoverTip(FavoriteButtonTip(), arrowEdge: .bottom)
```

## Eligibility Rules

Control when a tip is eligible using `@Parameter` properties or `Event` donations.

**Parameter rule** — tip only appears once onboarding is complete:

```swift
struct AdvancedSearchTip: Tip {
    @Parameter static var hasCompletedOnboarding: Bool = false

    var title: Text { Text("Try Advanced Search") }
    var message: Text? { Text("Filter by date, source, and topic.") }

    var rules: [Rule] {
        #Rule(Self.$hasCompletedOnboarding) { $0 == true }
    }
}

// Set when appropriate:
AdvancedSearchTip.hasCompletedOnboarding = true
```

**Event rule** — tip appears after the user has viewed 3 articles:

```swift
struct SwipeToArchiveTip: Tip {
    static let articleViewed = Event(id: "article.viewed")

    var title: Text { Text("Swipe to Archive") }
    var message: Text? { Text("Swipe left to archive an article quickly.") }

    var rules: [Rule] {
        #Rule(Self.articleViewed) { $0.donations.count >= 3 }
    }
}

// Donate each time the user views an article:
await SwipeToArchiveTip.articleViewed.donate()
```

## Invalidating Tips

Dismiss tips programmatically when they're no longer relevant:

```swift
TipView(tip) { action in
    if action.id == "learnMore" {
        tip.invalidate(reason: .actionPerformed)
    }
}
```

You can add action buttons by implementing `var actions: [Action]` on your `Tip`.

## Best Practices

- Show **one tip at a time** per surface — too many tips are noise.
- Use **event rules** over timers: "user performed action N times" is more meaningful than "N days since install."
- Keep copy short: a 4–5 word title and one-sentence message is ideal.
- Never call `resetDatastore()` in production — it wipes all tip display history.
- Call `tip.invalidate(reason: .actionPerformed)` when the user completes the hinted action so the tip never reappears.

## References

- [TipKit Documentation](https://developer.apple.com/documentation/tipkit)
- [Make features discoverable with TipKit — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10229/)
- [Bring your tips to life — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10168/)
