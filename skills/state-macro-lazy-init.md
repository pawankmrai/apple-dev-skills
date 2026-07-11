---
topic: SwiftUI's @State Macro — Lazy Initialization for Observable Models
date: 2026-07-11
platform: iOS 27, macOS 27
swift: "6.2"
difficulty: intermediate
---

# SwiftUI's @State Macro — Lazy Initialization for Observable Models

In Xcode 27, `@State` stopped being a property wrapper conforming to `DynamicProperty` and became a Swift macro. The externally visible syntax is unchanged — you still write `@State private var viewModel = Model()` — but the semantics of *when* the initial value expression runs changed in a way that fixes a long-standing SwiftUI performance trap.

## The Problem It Fixes

Before Xcode 27, the initial value expression assigned to a `@State` property ran every time the owning view struct was recreated, not just the first time. SwiftUI discarded every instance after the first to preserve state, but the initializer's side effects — network setup, expensive computation, print statements — still executed on every recreation.

```swift
@Observable
class CounterViewModel {
    var count = 0

    init() {
        print("CounterViewModel initialized")
    }

    func increment() { count += 1 }
}

struct ContentView: View {
    @State private var tint: Color = .accentColor

    var body: some View {
        NavigationStack {
            CounterView()
                .tint(tint)
                .toolbar {
                    ColorPicker("Tint Color", selection: $tint)
                        .labelsHidden()
                }
        }
    }
}

struct CounterView: View {
    @State private var viewModel = CounterViewModel()

    var body: some View {
        VStack {
            Text("Count: \(viewModel.count)")
            Button("Increment") { viewModel.increment() }
        }
    }
}
```

Pre-Xcode 27: changing the tint color reevaluates `ContentView`, which recreates the `CounterView` struct, which re-runs `CounterViewModel()` — printing "CounterViewModel initialized" on every color change, even though `viewModel.count` correctly persists.

## What Changes With the Macro

Because `@State` is now a macro, the compiler can defer evaluation of the initial value expression. SwiftUI evaluates it lazily and runs the observable's initializer exactly once — the moment it sets up state storage for that view identity. Subsequent struct recreations skip the expression entirely.

Same code, Xcode 27: the print statement fires once, on first insertion into the hierarchy. Every later tint change recreates `CounterView` without touching `CounterViewModel.init()` again.

No source changes are required to get this. It back-deploys to every OS version where the Observation framework exists — iOS 17, macOS 14, tvOS 17, watchOS 10, and visionOS 1 — but you must build with Xcode 27 to get the new codegen.

## The Anti-Pattern That Still Applies

Lazy evaluation only covers the *default value expression* on the property declaration. It does not rescue assignments made inside a view's `init()`:

```swift
struct CounterView: View {
    @State private var viewModel: CounterViewModel

    init() {
        viewModel = CounterViewModel()   // still runs on every init() call
    }

    var body: some View { /* ... */ }
}
```

Here `CounterViewModel()` still executes every time `CounterView.init()` runs, even though SwiftUI throws away all but the first instance. This matters most when the model depends on a value the parent passes in — SwiftUI only honors the `init()` assignment the first time the view is inserted; on every later recreation it keeps the existing state and silently ignores the new assignment, so the model can end up holding stale data relative to its dependencies.

## Recommended Pattern for Dependent Models

When a model's initial value depends on data from a parent, don't fight this by fiddling with `init()`. Keep the model uninitialized (or nil) as the default, then hydrate it with `task(id:priority:_:)` so it stays in sync with the identity/value it depends on:

```swift
struct DetailView: View {
    let itemID: Item.ID
    @State private var viewModel: DetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                DetailContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task(id: itemID) {
            viewModel = DetailViewModel(itemID: itemID)
        }
    }
}
```

This is the same recommended shape as before Xcode 27 — the `@State` macro change removes the need for the *unrelated* workaround people used purely to dodge repeated allocation (wrapping the model in an optional and assigning it inside `task(priority:_:)` just to avoid the old eager re-init cost). If your only reason for that pattern was performance, you can now drop it and assign the model directly as a default value; if your reason is a genuine dependency on parent-provided data, keep using `task(id:)`.

## Migration Checklist

Search your codebase for `@State` properties holding `@Observable` models and check each one against these cases.

Simple default value with no external dependency — no change needed, you get the lazy-init benefit for free after recompiling with Xcode 27.

Optional `@State` wrapped only to avoid repeated allocation, hydrated in `task(priority:_:)` with no `id:` — safe to simplify back to a plain non-optional default value.

Model assigned inside a custom `init()` and depending on a property passed into that `init()` — this was already an anti-pattern and remains one; migrate it to the `task(id:)` pattern shown above.

## Best Practices

Rebuild with Xcode 27 before assuming you have the new lazy behavior — the runtime OS versions support it, but codegen depends on the compiler that built your binary.

Don't assign observable models inside a view's custom `init()` when the model depends on parent-provided data; use `task(id:)` so the model re-syncs on identity changes instead of silently going stale.

Keep initializer side effects (print, logging, expensive setup) in mind when auditing performance-sensitive view hierarchies — this fix only eliminates *redundant* re-initialization, not the cost of the first one.

Treat `@State`'s new macro nature as an internal implementation detail; the public API and property-wrapper-style syntax (`$viewModel`, `viewModel.wrappedValue`) are unchanged.

## References

- [Initializing @Observable classes with the @State macro in Xcode 27 — Nil Coalescing](https://nilcoalescing.com/blog/InitializingObservableClassesWithTheStateMacroInXcode27/)
- [Apple Developer: State](https://developer.apple.com/documentation/swiftui/state())
- [WWDC26 SwiftUI guide — Apple Developer](https://developer.apple.com/wwdc26/guides/swiftui/)
