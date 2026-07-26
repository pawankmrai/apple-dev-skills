---
topic: SwiftUI @Entry Macro — Simplifying Custom Environment Values
date: 2026-07-26
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI @Entry Macro — Simplifying Custom Environment Values

Custom environment values used to require a full `EnvironmentKey` conformance just to expose one property. The `@Entry` macro collapses that boilerplate into a single annotated declaration, and it also works for `Transaction`, `ContainerValues`, and `FocusedValues`. This skill covers the macro's mechanics, how it interacts with Swift 6 concurrency checking, and patterns for using it well in larger apps.

## The old way

Before `@Entry`, every custom environment value meant three moving parts: a key type, a default value, and an `EnvironmentValues` extension.

```swift
private struct UserThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .system
}

extension EnvironmentValues {
    var userTheme: Theme {
        get { self[UserThemeKey.self] }
        set { self[UserThemeKey.self] = newValue }
    }
}
```

Multiply that by every custom value in a mid-sized app and it becomes a lot of repeated ceremony for very little logic.

## The @Entry way

```swift
extension EnvironmentValues {
    @Entry var userTheme: Theme = .system
}
```

That's the entire declaration. The macro synthesizes the private key type and the computed property for you, and the result is used exactly like a built-in environment value:

```swift
struct ProfileView: View {
    @Environment(\.userTheme) private var userTheme

    var body: some View {
        Text("Current theme: \(userTheme.rawValue)")
    }
}

struct RootView: View {
    var body: some View {
        ProfileView()
            .environment(\.userTheme, .dark)
    }
}
```

## Defaults that require initialization work

`@Entry` accepts any default expression, including one that calls a function or initializer, not just static literals:

```swift
extension EnvironmentValues {
    @Entry var analyticsLogger: AnalyticsLogging = AnalyticsLogger()
    @Entry var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
```

Each default is evaluated lazily on first access per environment, so an expensive default doesn't run unless something actually reads that key.

## Optional values and reference types

`@Entry` handles optionals cleanly, which is useful for values that legitimately have no sensible default:

```swift
extension EnvironmentValues {
    @Entry var selectedItemID: Item.ID?
}
```

For reference types under Swift 6 strict concurrency, the macro reduces friction because it generates the storage in a way that avoids the extra `Sendable` conformance ceremony you'd otherwise hit when hand-writing an `EnvironmentKey` for a class-based default.

## Beyond EnvironmentValues: Transaction and FocusedValues

The same macro works for animation-adjacent transaction data and focus-based values, which previously needed their own boilerplate patterns too.

```swift
extension Transaction {
    @Entry var isSlowAnimation = false
}

extension FocusedValues {
    @Entry var activeDocument: Document?
}
```

Reading a transaction entry inside an animation:

```swift
withAnimation {
    var transaction = Transaction(animation: .easeInOut)
    transaction.isSlowAnimation = true
    withTransaction(transaction) {
        expanded.toggle()
    }
}
```

## Container values for custom layout containers

`@Entry` also backs `ContainerValues`, which lets custom `Layout` or `Group`-like containers expose per-child configuration without inventing a bespoke preference key:

```swift
extension ContainerValues {
    @Entry var badgeCount: Int = 0
}

ForEach(items) { item in
    ItemRow(item: item)
        .containerValue(\.badgeCount, item.unreadCount)
}
```

## Best Practices

Keep entry declarations grouped in a single file per feature area (for example `Environment+Theming.swift`) rather than scattering them next to unrelated views — it keeps the "what can this view read from its environment" surface easy to audit. Prefer value types for environment entries where possible; when a reference type is unavoidable, mark it `Sendable` or `@MainActor`-isolated explicitly rather than relying on the macro to paper over a real isolation gap. Don't use `@Entry` as a substitute for proper dependency injection at the app's composition root — it's best suited to view-tree-scoped configuration (theming, feature flags, formatting), not app-wide services that also need testability via protocols. Name entries after what they represent, not how they're used, so `userTheme` rather than `themeForProfileScreen`.

## References

- [Environment - Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/environment)
- [Entry Macro for Custom SwiftUI Environment Values - Use Your Loaf](https://useyourloaf.com/blog/entry-macro-for-custom-swiftui-environment-values/)
- [@Entry macro: Creating custom environment values in SwiftUI - avanderlee.com](https://www.avanderlee.com/swiftui/entry-macro-custom-environment-values/)
- [What's new in SwiftUI - WWDC sessions - Apple Developer](https://developer.apple.com/videos/play/wwdc2026/269/)
