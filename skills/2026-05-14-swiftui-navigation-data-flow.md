---
topic: SwiftUI Navigation and Data Flow
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI Navigation and Data Flow

SwiftUI's navigation system and data flow model determine how your app moves between screens and how state propagates through the view hierarchy. Mastering both is essential for building maintainable apps.

## NavigationStack

`NavigationStack` replaced the deprecated `NavigationView` and supports value-based, type-safe navigation:

```swift
struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(recipes) { recipe in
                NavigationLink(value: recipe) {
                    RecipeRow(recipe: recipe)
                }
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}
```

The `NavigationPath` is type-erased, allowing mixed types in a single stack.

## Programmatic Navigation

Push and pop views by manipulating the path directly:

```swift
struct RecipeDetailView: View {
    let recipe: Recipe
    @Binding var path: NavigationPath

    var body: some View {
        VStack {
            Text(recipe.name)
            Button("View Author") {
                path.append(recipe.author) // Push author view
            }
            Button("Back to Root") {
                path.removeLast(path.count) // Pop to root
            }
        }
        .navigationDestination(for: Author.self) { author in
            AuthorView(author: author)
        }
    }
}
```

## TabView

Organize top-level sections with tabs. iOS 26 supports the new `Tab` API:

```swift
struct MainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: 0) {
                HomeView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: 1) {
                SearchView()
            }
            Tab("Profile", systemImage: "person", value: 2) {
                ProfileView()
            }
        }
    }
}
```

## Data Flow: @State and @Binding

`@State` owns mutable value-type data. `@Binding` passes a read-write reference down:

```swift
struct ParentView: View {
    @State private var isEditing = false

    var body: some View {
        ChildView(isEditing: $isEditing)
    }
}

struct ChildView: View {
    @Binding var isEditing: Bool

    var body: some View {
        Toggle("Edit Mode", isOn: $isEditing)
    }
}
```

## @Observable and the Observation Framework

The modern replacement for `ObservableObject` — simpler, more performant:

```swift
import Observation

@Observable
class RecipeStore {
    var recipes: [Recipe] = []
    var isLoading = false

    func load() async {
        isLoading = true
        recipes = try await RecipeService.fetchAll()
        isLoading = false
    }
}
```

Use it in views without any property wrapper — just pass it in:

```swift
struct RecipeListView: View {
    var store: RecipeStore

    var body: some View {
        List(store.recipes) { recipe in
            Text(recipe.name)
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
        .task {
            await store.load()
        }
    }
}
```

Views only re-render when the specific properties they read change.

## @Environment for Dependency Injection

Share data across the view hierarchy without explicit passing:

```swift
@Observable
class AppSettings {
    var accentColor: Color = .blue
    var fontSize: CGFloat = 16
}

// Provide at the root
@main
struct MyApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
    }
}

// Consume anywhere
struct DetailView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Text("Hello")
            .font(.system(size: settings.fontSize))
    }
}
```

## Best Practices

- **Use `NavigationStack` with `NavigationPath`** for any non-trivial navigation. It supports deep linking, state restoration, and programmatic control.
- **Prefer `@Observable` over `ObservableObject`** — it's more efficient (tracks per-property access) and requires less boilerplate (no `@Published`).
- **Keep `@State` local** — if data needs to be shared, lift it to a parent or use `@Environment`.
- **Avoid deeply nested `@Binding` chains** — use `@Environment` or pass the model directly.
- **Use `.task` for async loading** — it ties the work to the view's lifecycle and cancels automatically.
- **Separate navigation state from business logic** — keep `NavigationPath` in a coordinator or root view, not buried in child views.

## References

- [NavigationStack | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Managing model data in your app — Apple Developer](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Observation | Apple Developer Documentation](https://developer.apple.com/documentation/observation)
