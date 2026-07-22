---
topic: MapKit for SwiftUI — Building Location-Aware Apps
date: 2026-07-22
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# MapKit for SwiftUI — Building Location-Aware Apps

MapKit for SwiftUI has matured past a thin wrapper around `MKMapView`. The modern `Map` view is a first-class SwiftUI citizen built with `ViewBuilder` composition — annotations, overlays, and controls are declared as content rather than configured through delegates. Combined with the newer Geocoding APIs and `GeoToolbox`, it's now practical to build rich, interactive maps without touching UIKit at all.

## Building a Basic Map

`Map` takes a `MapCameraPosition` binding and a `@MapContentBuilder` closure, mirroring how `List` composes rows:

```swift
import SwiftUI
import MapKit

struct StoreLocatorView: View {
    @State private var position: MapCameraPosition = .automatic
    let stores: [Store]

    var body: some View {
        Map(position: $position) {
            ForEach(stores) { store in
                Marker(store.name, systemImage: "bag.fill", coordinate: store.coordinate)
                    .tint(.orange)
            }
            UserAnnotation()
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }
}
```

`Marker`, `MapPolyline`, `MapPolygon`, and `MapCircle` replace the older `MapAnnotation`, `MapMarker`, and `MapPin` types, which are deprecated. Each supports view modifiers like `.tint` directly.

## Custom Annotation Content

For anything beyond a pin, use `Annotation` with a trailing view builder:

```swift
Map(position: $position) {
    ForEach(stores) { store in
        Annotation(store.name, coordinate: store.coordinate) {
            VStack(spacing: 4) {
                Image(systemName: "storefront.fill")
                    .padding(6)
                    .background(.thinMaterial, in: Circle())
                Text(store.name).font(.caption2).fixedSize()
            }
        }
        .annotationTitles(.hidden)
    }
}
```

## Selection and Item Detail

`MapItemDetailSheet` shows Apple Maps–style detail cards for a selected `MKMapItem` without custom UI:

```swift
struct SearchResultsMap: View {
    @State private var position: MapCameraPosition = .automatic
    @State private var selection: MKMapItem?
    let results: [MKMapItem]

    var body: some View {
        Map(position: $position, selection: $selection) {
            ForEach(results, id: \.self) { Marker(item: $0) }
        }
        .sheet(item: $selection) { item in
            MapItemDetailSheet(mapItem: item)
                .presentationDetents([.medium, .large])
        }
    }
}
```

## Geocoding with async/await

`CLGeocoder` now pairs naturally with structured concurrency — no completion handlers required:

```swift
func coordinate(for address: String) async throws -> CLLocationCoordinate2D {
    let geocoder = CLGeocoder()
    let placemarks = try await geocoder.geocodeAddressString(address)
    guard let location = placemarks.first?.location else {
        throw GeocodingError.notFound
    }
    return location.coordinate
}
```

For search-as-you-type experiences, prefer `MKLocalSearchCompleter` over raw geocoding — it's tuned for partial queries and ranks results by relevance to the current map region.

## Overlays: Drawing Routes

Draw a route from `MKDirections` onto the map with `MapPolyline`, using the resulting `MKRoute.polyline`:

```swift
func fetchRoute(from source: MKMapItem, to destination: MKMapItem) async throws -> MKRoute {
    let request = MKDirections.Request()
    request.source = source
    request.destination = destination
    request.transportType = .automobile
    let response = try await MKDirections(request: request).calculate()
    guard let route = response.routes.first else { throw RoutingError.noRouteFound }
    return route
}

// In the view:
Map(position: $position) {
    MapPolyline(route.polyline).stroke(.blue, lineWidth: 5)
}
```

## Responding to Camera Changes

Use `onMapCameraChange` to react to panning and zooming — useful for re-querying when the visible region changes:

```swift
Map(position: $position) { /* content */ }
    .onMapCameraChange(frequency: .onEnd) { context in
        visibleRegion = context.region
        Task { await refreshResults(in: context.region) }
    }
```

`frequency: .onEnd` avoids firing on every frame of a drag; use `.continuous` only for live feedback like a custom scale readout.

## Best Practices

Prefer `Marker` and `Annotation` over manually managing `MKAnnotation` objects — SwiftUI diffs `ForEach` content for you, so identity should come from `Identifiable` models rather than array indices. Keep camera position in `@State` at the view that owns the map and pass a binding down rather than duplicating region state. Batch geocoding requests and cache resolved coordinates locally instead of re-geocoding the same address on every appearance. When showing routes, decode `MKRoute.steps` for turn-by-turn text rather than parsing polyline points yourself. Always request location permission with a clear, specific `NSLocationWhenInUseUsageDescription` string, and gracefully degrade to a region-based map when authorization is denied.

## References

- [MapKit for SwiftUI — Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)
- [Meet MapKit for SwiftUI — WWDC](https://developer.apple.com/videos/play/wwdc2023/10043/)
- [MKLocalSearchCompleter — Apple Developer Documentation](https://developer.apple.com/documentation/mapkit/mklocalsearchcompleter)
