---
topic: SwiftUI Adaptive Toolbars — Visibility Priority, Overflow Menus, and Pinned Actions
date: 2026-06-18
platform: iOS 27, macOS 27
swift: "6.3"
difficulty: intermediate
---

# SwiftUI Adaptive Toolbars — Visibility Priority, Overflow Menus, and Pinned Actions

Before iOS 27, toolbar overflow was entirely the system's call. As a window or device narrowed, SwiftUI decided which `ToolbarItem`s collapsed into the overflow menu and in what order — useful as a default, unworkable the moment a "Share" button needed to survive every width or a secondary action needed to always live in the overflow menu rather than randomly migrating there. WWDC 2026 adds four toolbar modifiers that hand that decision back to you: `visibilityPriority`, `toolbarOverflowMenu`, `topBarPinnedTrailing`, and `toolbarMinimizeBehavior`.

## The Problem They Solve

A toolbar with five items on an iPad looks fine in landscape and crowded in a Split View. The system's overflow heuristic is reasonable but opaque — you can't say "this button is essential" or "this one should never appear in the bar itself." That's exactly the gap these APIs close.

## visibilityPriority: Keep Key Items Visible Longer

`visibilityPriority` ranks a `ToolbarItem` or group against its siblings. Higher-priority items are the last to move into overflow as space shrinks.

```swift
struct EditorToolbar: View {
    var body: some View {
        EditorCanvas()
            .toolbar {
                ToolbarItem {
                    Button("Format", systemImage: "textformat") { }
                }
                .visibilityPriority(.standard)

                ToolbarItem {
                    Button("Save", systemImage: "tray.and.arrow.down") { }
                }
                .visibilityPriority(.high)
            }
    }
}
```

`Save` now outlasts `Format` as the bar narrows. Priority is relative — it only matters in comparison to the other items competing for the same space.

## toolbarOverflowMenu: Permanent, Explicit Overflow

Sometimes an action belongs in the overflow menu unconditionally — a "Print" or "Export PDF" command you don't want competing for primary bar space at any width. `toolbarOverflowMenu` declares content that always lives in the overflow menu, instead of leaving that placement to the system's resizing heuristic.

```swift
.toolbar {
    ToolbarItem {
        Button("Share", systemImage: "square.and.arrow.up") { }
    }

    ToolbarOverflowMenu {
        Button("Export as PDF") { exportPDF() }
        Button("Print…") { print() }
        Button("Duplicate") { duplicate() }
    }
}
```

This also documents intent in code: a reviewer can see at a glance which actions are primary and which are deliberately secondary, rather than inferring it from layout behavior.

## topBarPinnedTrailing: Actions That Never Move

Some controls — a share sheet trigger, a "Done" button ending a modal flow — must never disappear into overflow, no matter how cramped the bar gets. `topBarPinnedTrailing` pins an item to the trailing edge of the top bar permanently.

```swift
.toolbar {
    ToolbarItem(placement: .topBarPinnedTrailing) {
        Button("Share", systemImage: "square.and.arrow.up") {
            isSharing = true
        }
    }

    ToolbarItem {
        Button("Add Tag", systemImage: "tag") { }
    }
    .visibilityPriority(.standard)
}
```

A `ToolbarItem` placed with `.topBarPinnedTrailing` is exempt from the overflow calculation entirely — it's not competing for space, it's guaranteed space.

## toolbarMinimizeBehavior: Collapsing on Scroll

`toolbarMinimizeBehavior` automatically shrinks the navigation bar as the user scrolls down content, then restores it on scroll-up — the same pattern Apple's own apps use to maximize reading space without a hand-rolled scroll observer.

```swift
NavigationStack {
    ArticleBody()
        .toolbarMinimizeBehavior(.onScrollDown)
        .navigationTitle("Article")
}
```

## Putting It Together

A realistic note-editor toolbar: a pinned share action, a high-priority save action, a standard-priority formatting action, and two commands permanently in overflow.

```swift
struct NoteEditorView: View {
    @State private var note = Note()
    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            NoteTextView(note: $note)
                .toolbarMinimizeBehavior(.onScrollDown)
                .toolbar {
                    ToolbarItem(placement: .topBarPinnedTrailing) {
                        Button("Share", systemImage: "square.and.arrow.up") {
                            isSharing = true
                        }
                    }

                    ToolbarItem {
                        Button("Save", systemImage: "tray.and.arrow.down") {
                            save(note)
                        }
                    }
                    .visibilityPriority(.high)

                    ToolbarItem {
                        Button("Format", systemImage: "textformat") { }
                    }
                    .visibilityPriority(.standard)

                    ToolbarOverflowMenu {
                        Button("Move to Folder…") { }
                        Button("Delete", role: .destructive) { }
                    }
                }
                .sheet(isPresented: $isSharing) {
                    ShareSheet(note: note)
                }
        }
    }
}
```

At full width, every item shows in the bar. As the window narrows — say, the app enters Split View — `Format` is the first to fold into the system overflow menu, `Save` follows only if space gets tighter still, `Share` never moves, and `Move to Folder…`/`Delete` were never bar candidates to begin with.

## Best Practices

Reserve `topBarPinnedTrailing` for the one or two actions a user genuinely cannot lose access to — pinning everything defeats the purpose and just recreates a crowded bar that never adapts.

Use `visibilityPriority` relatively: decide which items matter most to the *current screen*, not a global ranking applied everywhere. A photo editor's "Save" deserves high priority on the edit screen; it has no reason to outrank anything in settings.

Prefer `toolbarOverflowMenu` over hiding actions behind a custom `Menu` button when the action genuinely belongs in the system overflow surface — it keeps your overflow content consistent with platform conventions and accessible the same way users already expect.

Pair `toolbarMinimizeBehavior(.onScrollDown)` with content that benefits from the reclaimed space — long-form reading, photo grids — rather than applying it everywhere; short screens just get a jumpy bar.

Test at every width class you support, including Split View and Slide Over on iPad and a resized window on macOS. Overflow priority interactions are easiest to get wrong at the boundary where an item is right on the edge of folding.

## References

- [What's new in SwiftUI — WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/)
- [WWDC26 SwiftUI guide — Apple Developer](https://developer.apple.com/wwdc26/guides/swiftui/)
- [Toolbars — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Toolbars)
