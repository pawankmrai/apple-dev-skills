---
topic: Core Data — Background Contexts, Batch Operations, and Migrations
date: 2026-07-19
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Core Data — Background Contexts, Batch Operations, and Migrations

SwiftData covers most new persistence work, but Core Data remains the right choice when you need `NSFetchedResultsController`, fine-grained batch operations, complex CloudKit sharing, or you're maintaining an app that predates iOS 17. This skill focuses on the three areas where Core Data still requires the most care: keeping heavy work off the main thread, updating large data sets efficiently, and evolving your schema without losing user data.

## Setting Up Background Contexts

Every write that isn't tied to UI should happen on a background `NSManagedObjectContext`, not `viewContext`:

```swift
import CoreData

final class DataController {
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "RecipeModel")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load store: \(error)")
            }
        }
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
```

Use `performBackgroundTask` for one-off writes — it hands you a context already scoped to a background queue and saves you from manually managing its lifetime:

```swift
func importRecipes(_ payloads: [RecipePayload]) async throws {
    try await container.performBackgroundTask { context in
        for payload in payloads {
            let recipe = Recipe(context: context)
            recipe.name = payload.name
            recipe.cookingTime = Int16(payload.cookingTime)
        }
        try context.save()
    }
}
```

Never pass `NSManagedObject` instances between contexts or threads. Pass `NSManagedObjectID` instead, then re-fetch with `object(with:)` on the receiving context.

## Batch Operations

For large-scale inserts, updates, or deletes, skip loading objects into memory entirely and use the batch request APIs, which operate directly on the SQLite store:

```swift
func markAllFavoritesStale(in context: NSManagedObjectContext) throws {
    let batchUpdate = NSBatchUpdateRequest(entityName: "Recipe")
    batchUpdate.predicate = NSPredicate(format: "isFavorite == YES")
    batchUpdate.propertiesToUpdate = ["needsSync": true]
    batchUpdate.resultType = .updatedObjectIDsResultType

    let result = try context.execute(batchUpdate) as? NSBatchUpdateResult
    let objectIDs = result?.result as? [NSManagedObjectID] ?? []

    // Merge the changes into any in-memory contexts that might hold stale copies.
    let changes = [NSUpdatedObjectsKey: objectIDs]
    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
}

func purgeExpiredCacheEntries(olderThan date: Date, in context: NSManagedObjectContext) throws {
    let batchDelete = NSBatchDeleteRequest(
        fetchRequest: CacheEntry.fetchRequest(NSPredicate(format: "expiresAt < %@", date as NSDate))
    )
    batchDelete.resultType = .resultTypeObjectIDs

    let result = try context.execute(batchDelete) as? NSBatchDeleteResult
    let objectIDs = result?.result as? [NSManagedObjectID] ?? []
    let changes = [NSDeletedObjectsKey: objectIDs]
    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [container.viewContext])
}
```

Batch requests bypass validation rules, relationship delete rules, and `willSave`/`didSave` callbacks — they're fast precisely because they skip the object graph. Always merge the resulting object IDs back into any live contexts, or the UI will show stale data until the next fetch.

## Lightweight and Custom Migrations

Core Data infers lightweight migrations automatically when changes are additive and unambiguous (new optional attributes, renamed entities with a rename identifier). Enable it explicitly:

```swift
let description = container.persistentStoreDescriptions.first
description?.shouldInferMappingModelAutomatically = true
description?.shouldMigrateStoreAutomatically = true
```

When a change is structurally ambiguous — splitting one entity into two, transforming a string into a relationship — write a custom mapping model with a migration policy:

```swift
final class RecipeToStructuredIngredientsPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        guard let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else { return }

        let rawIngredients = sInstance.value(forKey: "ingredientsText") as? String ?? ""
        let parsed = rawIngredients.split(separator: "\n").map(String.init)
        destination.setValue(parsed, forKey: "ingredientLines")
    }
}
```

Create versioned `.xcdatamodel` files inside an `.xcdatamodeld` bundle, mark the new version as current, and reference the policy in a mapping model's "Custom Policy" field so `NSMigrationManager` picks it up during the staged migration.

## Best Practices

Keep `viewContext` read-mostly and reserve it for driving `NSFetchedResultsController` and SwiftUI bindings; route every import, sync, or bulk edit through a background context. Set a `mergePolicy` on every context you create — the default `NSErrorMergePolicy` throws on conflicts, which is rarely what you want for background writes racing a user edit. Batch requests are a last resort for correctness-sensitive code: because they skip `NSManagedObjectContext` entirely, cascading deletes and computed properties won't run, so double-check your delete rules still hold. Version your model early — even a single unnecessary lightweight migration is cheap, but discovering you need a custom mapping after shipping several versions without one is not. Test migrations with a copy of production-shaped data, not just an empty store, since inferred mappings can succeed on a fresh store while failing on one with real relationships.

## References

- [Core Data Programming Guide](https://developer.apple.com/documentation/coredata)
- [Setting Up Core Data with CloudKit](https://developer.apple.com/documentation/coredata/mirroring-a-core-data-store-with-cloudkit)
- [NSBatchUpdateRequest](https://developer.apple.com/documentation/coredata/nsbatchupdaterequest)
- [NSBatchDeleteRequest](https://developer.apple.com/documentation/coredata/nsbatchdeleterequest)
- [Heavyweight Migration](https://developer.apple.com/documentation/coredata/heavyweight-migration)
