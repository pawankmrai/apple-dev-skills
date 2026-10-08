---
topic: SwiftData Model Inheritance — Class Hierarchies and Polymorphic Queries
date: 2026-10-08
platform: iOS 26, macOS 26, iPadOS 26, visionOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftData Model Inheritance — Class Hierarchies and Polymorphic Queries

Starting with iOS 26, SwiftData supports class inheritance: a `@Model` class can subclass another `@Model` class. Subclasses inherit stored properties and relationships, add their own, and can be fetched either through the base type (a *deep* query across the whole hierarchy) or narrowed by type with `is` in a `#Predicate`. This skill covers declaring a hierarchy, registering it, querying polymorphically, and migrating from a flat model.

## Declaring a Hierarchy

Mark the base and every subclass with `@Model`. Subclasses need `@available(iOS 26, *)` (or the matching OS set), even when your deployment target is already 26.

```swift
import SwiftData
import Foundation

@Model
class Trip {
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date

    init(name: String, destination: String, startDate: Date, endDate: Date) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
    }

    var durationInDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}

@available(iOS 26, macOS 26, *)
@Model
final class BusinessTrip: Trip {
    var expenseCode: String
    var perDiemRate: Double

    init(name: String, destination: String, startDate: Date, endDate: Date,
         expenseCode: String, perDiemRate: Double) {
        self.expenseCode = expenseCode
        self.perDiemRate = perDiemRate
        super.init(name: name, destination: destination, startDate: startDate, endDate: endDate)
    }

    var estimatedPerDiem: Double { Double(durationInDays) * perDiemRate }
}

@available(iOS 26, macOS 26, *)
@Model
final class PersonalTrip: Trip {
    enum Reason: String, Codable, CaseIterable { case family, wellness, adventure }
    var reason: Reason

    init(name: String, destination: String, startDate: Date, endDate: Date, reason: Reason) {
        self.reason = reason
        super.init(name: name, destination: destination, startDate: startDate, endDate: endDate)
    }
}
```

Initialize subclass properties first, then call `super.init` — standard Swift two-phase initialization.

## Registering the Schema

List every concrete type in the container so SwiftData knows the full hierarchy:

```swift
@main
struct TripsApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .modelContainer(for: [Trip.self, BusinessTrip.self, PersonalTrip.self])
    }
}
```

## Deep and Type-Filtered Queries

Querying the base type returns instances of every subclass. Use `is` inside `#Predicate` to narrow by class, and compose predicates with `evaluate(_:)`.

```swift
enum TripKind: String, CaseIterable { case all, personal, business }

struct TripListView: View {
    @Query private var trips: [Trip]

    init(kind: TripKind, searchText: String) {
        let kindFilter: Predicate<Trip>? = switch kind {
        case .all:      nil
        case .personal: #Predicate { $0 is PersonalTrip }
        case .business: #Predicate { $0 is BusinessTrip }
        }
        let search = #Predicate<Trip> {
            searchText.isEmpty || $0.name.localizedStandardContains(searchText)
                || $0.destination.localizedStandardContains(searchText)
        }
        let filter: Predicate<Trip> = if let kindFilter {
            #Predicate { kindFilter.evaluate($0) && search.evaluate($0) }
        } else { search }
        _trips = Query(filter: filter, sort: \.startDate)
    }

    var body: some View {
        List(trips) { trip in
            switch trip {
            case let b as BusinessTrip: Label("\(b.name) · \(b.expenseCode)", systemImage: "briefcase")
            case let p as PersonalTrip: Label("\(p.name) · \(p.reason.rawValue)", systemImage: "sun.max")
            default:                    Text(trip.name)
            }
        }
    }
}
```

For a *shallow* query that only needs subclass properties, fetch the subclass directly: `@Query(sort: \BusinessTrip.perDiemRate) var business: [BusinessTrip]`.

## Migrating from a Flat Model

Converting `isBusinessTrip: Bool` into a hierarchy changes the schema. Add a new `VersionedSchema` that includes the subclasses and a migration stage. Because existing rows must become the correct subclass, a custom stage that re-inserts data is usually required rather than a lightweight one; test on a copy of production data.

## When Not to Use Inheritance

- **Only one or two differing fields** — an enum with associated values (`case business(perDiem: Double)`) keeps the model flat.
- **Shared behavior, not shared storage** — prefer a protocol.
- **Wide hierarchies** — all subclasses share one table, so many sibling types mean many sparse columns and slower fetches/inserts.
- **Queries that never touch the base type** — two independent models may be simpler.

## Best Practices

- Keep hierarchies shallow (one level is ideal) and model genuine IS-A relationships.
- Put relationships common to all trips on the base class; subclass-only relationships on the subclass.
- Use `switch`/`as?` on fetched results for type-specific UI instead of a stored "kind" property.
- Watch for early-26.x bugs: predicates on parent properties in a subclass `@Query` have crashed for some developers — test each query and file Feedback if needed.
- Bump your `VersionedSchema` whenever you add, remove, or reparent a subclass.

## References

- [Adopting inheritance in SwiftData — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata/adopting-inheritance-in-swiftdata)
- [Getting Started with SwiftData in iOS 26 — Kodeco](https://www.kodeco.com/49976785-getting-started-with-swiftdata-in-ios-26)
- [SwiftData Inheritance Query Specialized Model — Apple Developer Forums](https://developer.apple.com/forums/thread/797989)
- [SwiftData — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata)
