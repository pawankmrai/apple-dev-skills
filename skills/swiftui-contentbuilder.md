---
topic: SwiftUI ContentBuilder — One Result Builder for All Content Types
date: 2026-06-26
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: intermediate
---

# SwiftUI ContentBuilder — One Result Builder for All Content Types

SwiftUI has quietly accumulated a builder for every flavor of declarative content: `@ViewBuilder` for views, `@ToolbarContentBuilder` for toolbars, `@CommandsBuilder` for menu commands, `@TabContentBuilder` for tabs, `@KeyframeTrackContentBuilder` for keyframe animations, and `@CompositorContentBuilder` for compositor layers. Each one is precise, but the precision came at a cost — API authors had to pick a builder name tied to a specific framework concept, and the compiler had to type-check each one through its own overload set. WWDC 2026 (Xcode 27 SDK) introduces `@ContentBuilder`, a single unified attribute that's meant to replace most of those specialized builders going forward.

## The Declaration Is Deceptively Small

```swift
typealias ContentBuilder = ViewBuilder
```

`ContentBuilder` is technically just a type alias for `ViewBuilder`. It isn't a new result builder mechanism — it's a renaming and generalization of the one SwiftUI already had. The interesting part is everything built around that alias: SwiftUI now lets the *generated content types* conditionally conform to whatever protocol the context needs (`View`, `ToolbarContent`, `Commands`, `TabContent`), instead of relying on a separate, type-specific builder to enforce that conformance.

## Ordinary View Content

For plain views, `@ContentBuilder` reads exactly like `@ViewBuilder` did:

```swift
@ContentBuilder
private func header() -> some View {
    Text("Library")
        .font(.title)

    Text("Recently updated")
        .foregroundStyle(.secondary)
}
```

It works the same way on custom containers:

```swift
struct Card<Content: View>: View {
    private let content: Content

    init(@ContentBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
}
```

## Non-View Content: Toolbars and Commands

The real motivation shows up where the closure isn't producing views at all. A toolbar builder used to require `@ToolbarContentBuilder` by name:

```swift
@ContentBuilder
private var editingToolbarItems: some ToolbarContent {
    ToolbarItem {
        Button("Undo") {}
    }

    ToolbarItem {
        Button("Redo") {}
    }
}
```

The same attribute drives menu commands, too — the declared return type (`some ToolbarContent`, `some Commands`) is what tells the compiler which content protocol applies, not the builder's name:

```swift
@ContentBuilder
var editMenuCommands: some Commands {
    CommandGroup(replacing: .undoRedo) {
        Button("Undo") { undoManager?.undo() }
            .keyboardShortcut("z", modifiers: .command)
    }
}
```

## The Safety Boundary Doesn't Move

Unifying the builder name doesn't unify the content types themselves. A `ToolbarItem` still isn't a `View`, and a `Commands` block still can't be dropped into a `body`. The compiler enforces this through conditional conformances on the builder's generated types rather than through a dedicated builder type:

```swift
@ContentBuilder
private var toolbar: some ToolbarContent {
    ToolbarItem {
        Button("Save") {}
    }
}
// toolbar cannot be assigned where `some View` is expected — the
// result type still gates what the content can be used for.
```

## Why This Actually Speeds Up Builds

Before `ContentBuilder`, SwiftUI shipped a separate overloaded initializer on types like `Group`, `ForEach`, and `Section` for every specialized builder — one path for view content, another for toolbar content, another for tab content. Each additional overload widened the set of candidates the type checker had to consider for every call site, which is part of why deeply nested SwiftUI view hierarchies could get slow to compile.

`ContentBuilder` collapses that into a single shared initializer per container, with the resulting content type conditionally conforming to whatever protocol fits:

```swift
// One Group initializer now serves both of these, instead of two
// separately-overloaded versions tied to different builders.
Group {
    Text("Plain view content")
}

Group {
    ToolbarItem { Button("Share") {} }
}
```

Fewer overloads to weigh per call site means less constraint-solving work, which Apple reports as a measurable compile-time win on large SwiftUI targets — independent of your app's minimum deployment target.

## Availability and Migration

`ContentBuilder` is available back to iOS 13, iPadOS 13, macOS 10.15, tvOS 13, watchOS 6, and visionOS 1, because it's built entirely on the existing `ViewBuilder` machinery. Adopting it only requires building with the Xcode 27 toolchain — it does not require raising your deployment target.

Existing code using `@ViewBuilder`, `@ToolbarContentBuilder`, or `@CommandsBuilder` keeps compiling unchanged; none of those attributes are deprecated. For new APIs and new call sites, prefer `@ContentBuilder` when the closure's job is "build SwiftUI content of some kind" rather than specifically "build a view":

```swift
// Prefer this spelling for new, content-type-agnostic APIs:
func contextMenu<MenuItems: View>(
    @ContentBuilder menuItems: () -> MenuItems
) -> some View
```

## Best Practices

Reach for `@ContentBuilder` on new public APIs whose closures might reasonably produce more than one kind of SwiftUI content — it reads better than borrowing `@ViewBuilder` for something that isn't strictly a view.

Don't bulk-rename existing `@ToolbarContentBuilder` or `@CommandsBuilder` usages just for the sake of it; the migration only pays off where it removes a hard dependency on a specific builder name, and the old attributes aren't going away.

Let the declared return type, not the builder attribute, communicate what kind of content an API produces — `some ToolbarContent` versus `some View` is still the contract callers rely on.

If you maintain a library with public builder-taking APIs, check whether switching to `@ContentBuilder` changes inferred generic constraints for existing callers before shipping it as a minor-version change.

Profile build times on your largest SwiftUI targets after adopting Xcode 27 — the compile-time benefit from `ContentBuilder`'s conditional-conformance design is automatic and doesn't require touching call sites that don't use builders directly.

## References

- [What's new in SwiftUI — WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/)
- [ContentBuilder — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/contentbuilder)
- [SwiftUI ContentBuilder: one builder name for different content — Livsy Code](https://livsycode.com/swiftui/swiftui-contentbuilder-one-builder-name-for-different-swiftui-content/)
- [Unification builder to ContentBuilder — SwiftUISnippets](https://swiftuisnippets.wordpress.com/2026/06/09/unification-builder-to-contentbuilder/)
