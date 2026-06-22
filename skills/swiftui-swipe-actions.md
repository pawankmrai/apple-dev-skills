---
topic: SwiftUI Swipe Actions Beyond List — swipeActionsContainer in iOS 27
date: 2026-06-22
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: intermediate
---

# SwiftUI Swipe Actions Beyond List — swipeActionsContainer in iOS 27

Swipe-to-delete and swipe-to-complete were one of the strongest remaining reasons to reach for `List` in SwiftUI. The `swipeActions(edge:allowsFullSwipe:content:)` modifier looked like a general-purpose `View` modifier, but it only ever did anything inside a `List` row — attach it to a `Text` in a `LazyVStack` and nothing happened. iOS 27 removes that restriction with a new modifier, `swipeActionsContainer()`, which activates swipe action support for any container inside a `ScrollView`: `LazyVStack`, `LazyVGrid`, and even custom `Layout` types.

## The Basic Shape

`swipeActionsContainer()` goes on the `ScrollView`; `swipeActions` stays exactly where it always was, on each row.

```swift
ScrollView {
    LazyVStack {
        Text("Hello, World!")
            .swipeActions {
                Button(role: .destructive) {
                    // delete action
                }
            }
    }
}
.swipeActionsContainer()
```

`List` doesn't need `swipeActionsContainer()` — it has always enabled swiping internally. Every other scrollable container does, as of iOS 27.

## A Working Example

A task list built on `LazyVStack` instead of `List`, with leading and trailing actions on each row:

```swift
import SwiftUI

struct AppTask: Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool = false
}

struct TaskListView: View {
    @State private var tasks: [AppTask] = [
        AppTask(id: UUID(), title: "Review pull request"),
        AppTask(id: UUID(), title: "Write release notes"),
        AppTask(id: UUID(), title: "Ship 2.4.0")
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                        .swipeActions(edge: .leading) {
                            Button {
                                complete(task)
                            } label: {
                                Label("Complete", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(task)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
        .swipeActionsContainer()
    }

    func complete(_ task: AppTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted = true
    }

    func delete(_ task: AppTask) {
        tasks.removeAll { $0.id == task.id }
    }
}
```

## How the Container Coordinates Behavior

`swipeActionsContainer()` isn't just a flag that turns swiping on — it owns the interaction across the whole container. It allows only one row's actions to stay revealed at a time, closing any previously opened row when a new one is swiped. It watches scroll events and dismisses open actions as soon as the user scrolls, and dismisses actions when the user taps anywhere outside the active row. None of this needs to be written by hand; it's the same behavior `List` always provided, now factored out into a standalone modifier.

## Tracking Presentation State

iOS 27 also adds an overload, `swipeActions(edge:allowsFullSwipe:content:onPresentationChanged:)`, that calls a closure whenever a row's actions are revealed or hidden — useful for syncing row-open state elsewhere in the UI, like disabling a toolbar button while a row is swiped open:

```swift
TaskRow(task: task)
    .swipeActions(edge: .trailing) {
        Button(role: .destructive) {
            delete(task)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    } onPresentationChanged: { isPresented in
        activeTaskID = isPresented ? task.id : nil
    }
```

## Grids and Custom Layouts

The same modifier pair works unchanged on `LazyVGrid` and on custom `Layout` conformances, since `swipeActionsContainer()` attaches to the enclosing `ScrollView` regardless of what's laid out inside it:

```swift
ScrollView {
    LazyVGrid(columns: columns) {
        ForEach(albums) { album in
            AlbumCell(album: album)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        remove(album)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
        }
    }
}
.swipeActionsContainer()
```

Whether a swipe gesture makes sense in a grid or flow layout is a design call, not a technical one — the API no longer stops you from trying.

## Availability

Both `swipeActionsContainer()` and the `onPresentationChanged` overload require iOS 27. Gate them on apps with a lower deployment target:

```swift
ScrollView {
    LazyVStack {
        // rows with .swipeActions(...)
    }
}
.modifier {
    if #available(iOS 27, *) {
        $0.swipeActionsContainer()
    } else {
        $0
    }
}
```

## Best Practices

Apply `swipeActionsContainer()` once, on the `ScrollView` itself, not on individual rows — it's the container that owns gesture coordination and dismissal.

Keep using `List` when you rely on its other built-ins — section headers, separators, accessibility row semantics. Reach for `swipeActionsContainer()` when a grid, flow layout, or custom card stack needs swipe affordances `List` can't give you.

Pair destructive actions with `role: .destructive` rather than a custom red tint; SwiftUI uses the role for VoiceOver announcements and full-swipe confirmation, not just color.

Use `onPresentationChanged` for syncing external UI state, not for driving deletion or completion logic — that belongs in the button's own action closure.

Test scroll-to-dismiss on a real device. Simulator trackpad scrolling can mask timing differences in when an open row's actions get dismissed mid-gesture.

## References

- [What's new in SwiftUI — WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/)
- [swipeActionsContainer() — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/View/swipeActionsContainer())
- [Custom scroll layouts with swipe actions in SwiftUI on iOS 27 — Nil Coalescing](https://nilcoalescing.com/blog/CustomScrollLayoutsWithSwipeActionsInSwiftUIOnIOS27/)
- [Swipe actions outside of List in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2026/06/16/swipe-actions-outside-of-list-in-swiftui/)
