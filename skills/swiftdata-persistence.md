---
topic: SwiftData — Modern Persistence for Apple Apps
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftData — Modern Persistence for Apple Apps

SwiftData is Apple's modern persistence framework, built on top of Core Data but with a pure Swift API. It uses macros to eliminate boilerplate and integrates seamlessly with SwiftUI's data flow.

## Defining Models with @Model

The `@Model` macro transforms a Swift class into a persistent model:

```swift
import SwiftData

@Model
class Recipe {
    var name: String
    var summary: String
    var cookingTime: Int // minutes
    var isFavorite: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var ingredients: [Ingredient]

    init(name: String, summary: String, cookingTime: Int) {
        self.name = name
        self.summary = summary
        self.cookingTime = cookingTime
        self.isFavorite = false
        self.createdAt = .now
        self.ingredients = []
    }
}

@Model
class Ingredient {
    var name: String
    var quantity: String
    var recipe: Recipe?

    init(name: String, quantity: String) {
        self.name = name
        self.quantity = quantity
    }
}
```

`@Model` automatically makes all stored properties persistent. Use `@Relationship` to define how models connect and how deletions cascade.

## Setting Up the Model Container

Configure the container at the app level:

```swift
@main
struct RecipeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Recipe.self, Ingredient.self])
    }
}
```

For custom configuration (e.g., in-memory for previews or testing):

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: Recipe.self, Ingredient.self,
    configurations: config
)
```

## Querying with @Query

`@Query` fetches and observes model data in SwiftUI views:

```swift
struct RecipeListView: View {
    @Query(sort: \Recipe.name) var recipes: [Recipe]
    @Environment(\.modelContext) private var context

    var body: some View {
        List(recipes) { recipe in
            RecipeRow(recipe: recipe)
        }
    }
}
```

Add filtering and sorting:

```swift
@Query(
    filter: #Predicate<Recipe> { $0.isFavorite == true },
    sort: [SortDescriptor(\Recipe.createdAt, order: .reverse)]
)
var favoriteRecipes: [Recipe]
```

## CRUD Operations

Insert, update, and delete through the model context:

```swift
struct RecipeListView: View {
    @Query(sort: \Recipe.name) var recipes: [Recipe]
    @Environment(\.modelContext) private var context

    func addRecipe() {
        let recipe = Recipe(name: "New Recipe", summary: "A tasty dish", cookingTime: 30)
        context.insert(recipe)
        // SwiftData auto-saves; explicit save is optional
    }

    func deleteRecipe(_ recipe: Recipe) {
        context.delete(recipe)
    }

    func updateRecipe(_ recipe: Recipe) {
        recipe.name = "Updated Name"
        // Changes are tracked automatically
    }
}
```

## Complex Predicates

Build type-safe queries with `#Predicate`:

```swift
let searchText = "pasta"
let maxTime = 30

let predicate = #Predicate<Recipe> { recipe in
    recipe.name.localizedStandardContains(searchText) &&
    recipe.cookingTime <= maxTime
}

let descriptor = FetchDescriptor<Recipe>(
    predicate: predicate,
    sortBy: [SortDescriptor(\.cookingTime)]
)
descriptor.fetchLimit = 20

let results = try context.fetch(descriptor)
```

## Schema Migration

Handle model changes with versioned schemas:

```swift
enum RecipeSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Recipe.self] }

    @Model class Recipe {
        var name: String
        var summary: String
    }
}

enum RecipeSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Recipe.self] }

    @Model class Recipe {
        var name: String
        var summary: String
        var cookingTime: Int // new field
    }
}

enum RecipeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RecipeSchemaV1.self, RecipeSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: RecipeSchemaV1.self,
        toVersion: RecipeSchemaV2.self
    )
}
```

## Best Practices

- **Use `@Model` classes, not structs** — SwiftData requires reference types for identity tracking and change observation.
- **Let SwiftData auto-save** — avoid calling `context.save()` manually unless you need transactional guarantees.
- **Use `#Predicate` for queries** — they're type-checked at compile time, unlike Core Data's string-based predicates.
- **Set `fetchLimit`** on large datasets to avoid loading everything into memory.
- **Use `@Relationship(deleteRule:)`** — explicitly define cascade vs. nullify behavior for related models.
- **Use `isStoredInMemoryOnly`** for SwiftUI previews and unit tests so they run fast and don't pollute the real store.
- **Plan migrations early** — use `VersionedSchema` from the start so you don't have to retrofit it later.

## References

- [SwiftData | Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata)
- [Meet SwiftData — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10187/)
- [Model your schema with enumerations — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10189/)
