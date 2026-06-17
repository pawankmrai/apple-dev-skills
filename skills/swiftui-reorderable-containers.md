---
topic: SwiftUI Reorderable Containers — Drag-to-Reorder for Lists, Grids, and Custom Layouts
date: 2026-06-17
platform: iOS 27, macOS 27
swift: "6.3"
difficulty: intermediate
---

# SwiftUI Reorderable Containers — Drag-to-Reorder for Lists, Grids, and Custom Layouts

Before iOS 27, drag-to-reorder was effectively a `List` feature: implement `onMove` and get index-set-based moves for free. Any other container — a `LazyVGrid`, an `HStack` of cards, a custom layout — meant building the gesture, drop target, and animation yourself. WWDC 2026 introduces a container-agnostic pair of modifiers, `reorderable()` and `reorderContainer(for:)`, bringing native drag interaction and animation to any dynamic content, including `LazyVStack`, `LazyVGrid`, stacks, and custom `Layout` types. Reordering also reaches watchOS for the first time.

## The Basic Shape

`reorderable()` goes on the `ForEach` to mark its generated views as reorder participants. `reorderContainer(for:)` goes on the parent container, defining the interaction's scope and a closure for applying the resulting move to your data.

```swift
ForEach(items) { item in
    ItemRow(item: item)
}
.reorderable()
```

```swift
.reorderContainer(for: Item.self) { difference in
    items.apply(difference: difference)
}
```

`reorderable()` is declared on `DynamicViewContent`, so it attaches to the `ForEach`, not an individual row. `reorderContainer` sits on the enclosing container — `List`, `LazyVStack`, `LazyVGrid`, or a custom `Layout` — and SwiftUI handles the drag gesture, live reordering preview, and settle animation automatically.

## A Working Example

A vertical playlist built on `LazyVStack` instead of `List`, with the same reordering behavior `List.onMove` used to provide:

```swift
import SwiftUI

struct PlaylistItem: Identifiable, Sendable {
    let id: UUID
    var title: String
}

struct PlaylistView: View {
    @State private var items: [PlaylistItem] = [
        PlaylistItem(id: UUID(), title: "Intro"),
        PlaylistItem(id: UUID(), title: "Main theme"),
        PlaylistItem(id: UUID(), title: "Outro")
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    Text(item.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .reorderable()
            }
            .padding()
            .reorderContainer(for: PlaylistItem.self) { difference in
                items.apply(difference: difference)
            }
        }
    }
}
```

The model still belongs to you. The closure hands back a `ReorderDifference`, and `apply(difference:)` is a convenience for mutating an `Array` in place — nothing persists automatically. That closure is exactly where you'd also write through to SwiftData, a view model, or a server-backed order.

## Handling ReorderDifference Manually

When the move isn't a plain array splice — sectioned data, rejected moves, a persisted `sortIndex` — inspect `ReorderDifference` directly instead of calling `apply`.

```swift
.reorderContainer(for: Card.self) { difference in
    guard let source = difference.sources.first,
          let sourceIndex = cards.firstIndex(where: { $0.id == source }) else {
        return
    }

    let removedCard = cards.remove(at: sourceIndex)

    switch difference.destination.position {
    case .before(let beforeID):
        if let destinationIndex = cards.firstIndex(where: { $0.id == beforeID }) {
            cards.insert(removedCard, at: destinationIndex)
        } else {
            cards.insert(removedCard, at: min(sourceIndex, cards.endIndex))
        }
    case .end:
        cards.insert(removedCard, at: cards.endIndex)
    }
}
```

`difference.sources` holds the moved item's identity; `difference.destination` describes where it landed — either `.before(id:)` an existing item, or `.end`. More code than `apply(difference:)`, but it's the escape hatch for app-specific move rules.

## Enabling and Disabling Reordering

`reorderContainer` takes an `isEnabled` parameter, so you can scope dragging to an edit mode without conditionally attaching gestures per row.

```swift
.reorderContainer(
    for: PlaylistItem.self,
    isEnabled: isEditing
) { difference in
    items.apply(difference: difference)
}
```

## Beyond List: Grids and Custom Layouts

The same shape works unchanged on `LazyVGrid`, making dashboards, photo grids, and board-style UIs first-class reordering targets without third-party drag libraries.

```swift
LazyVGrid(columns: columns) {
    ForEach(stickers) { sticker in
        StickerView(sticker)
    }
    .reorderable()
}
.reorderContainer(for: Sticker.self) { difference in
    stickers.apply(difference: difference)
}
```

## Multiple Collections

For UIs where items move between collections — a Solitaire-style tableau with multiple piles — a collection-identifier overload exists. The container declares both the element type and a collection ID type; reorderable content tags itself with a specific collection.

```swift
.reorderContainer(for: CardValue.self, in: Card.Group.self) { difference in
    game.moveCards(difference: difference)
}
```

```swift
ForEach(cards, id: \.value) { card in
    CardView(card: card)
}
.reorderable(collectionID: Card.Group.pile(index))
```

The `difference` now also identifies source and destination collections, so one handler can move a card from one pile to another.

## Best Practices

Keep model mutation in the closure, not scattered across views — `reorderContainer` describes the move; it doesn't own your data.

Reach for `apply(difference:)` first; drop to manual `ReorderDifference` handling only for real constraints like sectioned data or persisted sort order.

Use `isEnabled` to gate reordering behind edit mode rather than disabling the underlying gesture per row.

This API solves native reordering specifically — it isn't a general drag-and-drop replacement. For accepting external data, copy-versus-move behavior, or drop validation, pair it with `dragContainer`, `dropDestination`, and the broader drag-and-drop API family.

Test on watchOS if you support it — reordering containers are new to the platform this release, and watch gesture timing can feel different from iOS.

## References

- [What's new in SwiftUI — WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/)
- [Code-along: Build powerful drag and drop in SwiftUI — WWDC26](https://developer.apple.com/videos/play/wwdc2026/271/)
- [Reordering items in lists, stacks, grids, and custom layouts — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Reordering-items-in-lists-stacks-grids-and-custom-layouts)
- [SwiftUI reorderable containers in iOS 27 — Livsy Code](https://livsycode.com/swiftui/swiftui-reorderable-containers-in-ios-27/)
