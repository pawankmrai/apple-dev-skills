---
topic: "App Intents — Interactive Snippets and Visual Intelligence"
date: 2026-05-30
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# App Intents — Interactive Snippets and Visual Intelligence

App Intents is Apple's unified framework for exposing your app's actions and content to the system — Siri, Spotlight, Shortcuts, and now Visual Intelligence. iOS 26 brings major additions: Interactive Snippets let intents present live SwiftUI views inline in system surfaces, Visual Intelligence integration lets users point their camera at real-world objects and get results from your app, and Deferred Properties keep entity resolution fast by lazily loading expensive fields.

## Defining an App Intent

An App Intent is a struct conforming to `AppIntent`. It declares parameters, a title, and a `perform()` method.

```swift
import AppIntents

struct OpenArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Article"
    static var description: IntentDescription = "Opens a specific article in the reader."

    @Parameter(title: "Article")
    var article: ArticleEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ArticleEntity> {
        let loaded = try await ArticleStore.shared.load(article.id)
        return .result(value: loaded)
    }

    static var openAppWhenRun: Bool { true }
}
```

## App Entities

Entities represent the objects your intents operate on. Conform to `AppEntity` and provide a query.

```swift
struct ArticleEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Article")
    static var defaultQuery = ArticleQuery()

    var id: String
    var title: String

    @DeferredProperty
    var fullContent: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
```

The `@DeferredProperty` wrapper tells the system to skip `fullContent` during initial resolution and only fetch it when explicitly needed — keeping Spotlight and Siri responses snappy.

## Building an Entity Query

Queries tell the system how to find and resolve your entities.

```swift
struct ArticleQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ArticleEntity] {
        try await ArticleStore.shared.articles(for: identifiers)
    }

    func suggestedEntities() async throws -> [ArticleEntity] {
        try await ArticleStore.shared.recentArticles(limit: 10)
    }
}
```

## Interactive Snippets

Interactive Snippets are the headline iOS 26 feature for App Intents. When your intent returns a result, you can attach a SwiftUI view that the system displays inline — in Spotlight, Siri, or the Shortcuts app — with full interactivity.

```swift
struct CheckWeatherIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Weather"

    @Parameter(title: "City")
    var city: CityEntity

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let forecast = try await WeatherService.shared.forecast(for: city.id)

        return .result {
            WeatherSnippetView(forecast: forecast)
        }
    }
}

struct WeatherSnippetView: View {
    let forecast: Forecast

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(forecast.cityName)
                .font(.headline)
            HStack {
                Image(systemName: forecast.conditionSymbol)
                    .font(.largeTitle)
                Text("\(forecast.temperature)°")
                    .font(.system(size: 48, weight: .thin))
            }
            Text(forecast.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
```

The snippet view stays live — users can tap buttons, scroll, or interact without leaving the system surface.

## Visual Intelligence Integration

iOS 26 lets users point the camera at objects and find results from your app. Implement a query conforming to `IntentValueQuery` that accepts a `SemanticContentDescriptor`.

```swift
struct PlantSearchQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PlantEntity] {
        try await PlantDatabase.shared.plants(for: identifiers)
    }

    func entities(matching descriptor: SemanticContentDescriptor) async throws -> [PlantEntity] {
        guard let imageData = descriptor.imageData else { return [] }
        return try await PlantDatabase.shared.identify(from: imageData)
    }
}
```

When a user activates Visual Intelligence and points at a plant, the system calls your query with the captured image data, and your results appear alongside system results.

## App Intents in Swift Packages

iOS 26 allows defining App Intents in Swift Packages and static libraries — previously they had to live in the main app target.

```swift
// In your package's Sources/MyIntents/Intents.swift
import AppIntents

public struct SearchRecipesIntent: AppIntent {
    public static var title: LocalizedStringResource = "Search Recipes"

    @Parameter(title: "Ingredient")
    public var ingredient: String

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let results = try await RecipeService.search(ingredient: ingredient)
        return .result(value: results)
    }
}
```

This enables sharing intents across app targets, extensions, and packages cleanly.

## Best Practices

- **Keep `perform()` fast.** Use `@DeferredProperty` for expensive fields so entity resolution stays under a second.
- **Provide good `suggestedEntities()`.** The system calls this for proactive suggestions — return the most relevant items, not everything.
- **Design Snippet views for compact spaces.** Interactive Snippets render in constrained system surfaces. Keep views narrow, avoid scroll views, and test at multiple Dynamic Type sizes.
- **Support multiple intents per domain.** Expose granular actions (open, create, search, share) rather than one monolithic intent.
- **Add `IntentDescription` and parameter summaries.** Clear descriptions improve discoverability in Shortcuts and Siri.
- **Test with Siri, Spotlight, and Shortcuts.** Each surface has different layout constraints and interaction models.

## References

- [App Intents Documentation](https://developer.apple.com/documentation/appintents)
- [Explore new advances in App Intents — WWDC25](https://developer.apple.com/videos/play/wwdc2025/275/)
- [What's new in iOS 26](https://developer.apple.com/ios/whats-new/)
