---
topic: Xcode Previews — #Preview, @Previewable, and PreviewModifier
date: 2026-10-03
platform: iOS 26, macOS 26, Xcode 26
swift: "6.2"
difficulty: intermediate
---

# Xcode Previews — #Preview, @Previewable, and PreviewModifier

Previews are the fastest feedback loop in SwiftUI development, but many projects still carry `PreviewProvider` boilerplate, wrapper views just to hold `@State`, and duplicated setup code for sample data. Modern Xcode replaces all of that with three tools: the `#Preview` macro, `@Previewable` for inline dynamic properties, and `PreviewModifier` for shared, cached preview environments. This skill shows how to combine them into previews that are short, interactive, and cheap to maintain.

## The #Preview Macro

`#Preview` takes an optional name, optional traits, and a view builder. It works for SwiftUI views, `UIView`/`UIViewController`, and `NSView`/`NSViewController`.

```swift
import SwiftUI

#Preview("Default") {
    ProfileCard(user: .sample)
}

#Preview("Compact", traits: .sizeThatFitsLayout) {
    ProfileCard(user: .sample)
        .padding()
}

#Preview("Landscape", traits: .landscapeLeft) {
    ProfileCard(user: .sample)
}

// UIKit works too — return a view or view controller.
#Preview("Legacy settings") {
    let vc = SettingsViewController()
    vc.title = "Settings"
    return UINavigationController(rootViewController: vc)
}
```

Each named `#Preview` appears as its own tab in the canvas, so use names to document states ("Empty", "Error", "Long title").

## @Previewable: State Without Wrapper Views

Views that take a `Binding` used to require a throwaway container struct. `@Previewable` lets you declare dynamic properties directly inside the preview body. It must appear at the top level of the `#Preview` closure.

```swift
struct RatingControl: View {
    @Binding var rating: Int
    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .onTapGesture { rating = star }
            }
        }
        .foregroundStyle(.yellow)
    }
}

#Preview("Interactive") {
    @Previewable @State var rating = 3
    VStack {
        RatingControl(rating: $rating)
        Text("Rating: \(rating)")
    }
}
```

`@Previewable` works with any dynamic property: `@State`, `@Environment`, `@FocusState`, and `@Query` for SwiftData.

## PreviewModifier: Shared, Cached Environments

When many previews need the same model container, mock services, or environment objects, put the setup in a `PreviewModifier`. `makeSharedContext()` runs once and its result is cached across every preview that uses the modifier — ideal for expensive work like seeding an in-memory SwiftData store.

```swift
import SwiftData

struct SampleLibrary: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Book.self, configurations: config)
        for book in Book.samples {
            container.mainContext.insert(book)
        }
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content
            .modelContainer(context)
            .environment(LibraryStore(mock: true))
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleLibrary: Self = .modifier(SampleLibrary())
}
```

Now any preview opts in with a single trait, and `@Previewable @Query` reads the seeded data:

```swift
#Preview("Library", traits: .sampleLibrary) {
    @Previewable @Query(sort: \Book.title) var books: [Book]
    NavigationStack {
        BookList(books: books)
    }
}

#Preview("Detail", traits: .sampleLibrary, .sizeThatFitsLayout) {
    @Previewable @Query var books: [Book]
    if let first = books.first {
        BookRow(book: first)
    }
}
```

Modifiers with no expensive setup can omit `makeSharedContext()`; the context type defaults to `Void`.

## Previewing Widgets and Live Activities

WidgetKit has dedicated `#Preview` overloads that render a timeline you can scrub through in the canvas.

```swift
#Preview(as: .systemSmall) {
    StepsWidget()
} timeline: {
    StepsEntry(date: .now, steps: 1_200)
    StepsEntry(date: .now.addingTimeInterval(3600), steps: 6_800)
}

#Preview("Island", as: .dynamicIsland(.expanded), using: DeliveryAttributes.preview) {
    DeliveryLiveActivity()
} contentStates: {
    DeliveryAttributes.ContentState(status: .preparing)
    DeliveryAttributes.ContentState(status: .outForDelivery)
}
```

## Best Practices

- **Name every preview after the state it shows** — the canvas becomes living documentation of edge cases.
- **Keep sample data in a `#if DEBUG` extension** or a Preview Content folder so it never ships.
- **Use `PreviewModifier` for anything async or expensive**; the shared context is cached, keeping canvas refreshes fast.
- **Inject mocks, not live services.** Previews that hit the network are slow and flaky.
- **Place `@Previewable` declarations first** in the closure; the macro rejects them nested inside other views.
- **Split large modules** — previews build the whole target, so smaller packages mean faster previews.
- **Combine traits** (`.sampleLibrary, .landscapeLeft`) rather than writing bespoke wrapper views.

## References

- [Previews in Xcode — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/previews-in-xcode)
- [PreviewModifier — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/previewmodifier)
- [Previewable() — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/previewable())
- [The power of previews in Xcode — Swift with Majid](https://swiftwithmajid.com/2024/11/26/the-power-of-previews-in-xcode/)
- [@Previewable: Dynamic SwiftUI Previews Made Easy — SwiftLee](https://www.avanderlee.com/swiftui/previewable-macro-usage-in-previews/)
