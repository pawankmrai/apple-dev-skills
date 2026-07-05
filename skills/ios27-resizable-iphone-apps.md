---
topic: iOS 27 Resizable iPhone Apps — Adaptive Layout Beyond Size Class
date: 2026-07-05
platform: iOS 27
swift: "6.2"
difficulty: intermediate
---

# iOS 27 Resizable iPhone Apps — Adaptive Layout Beyond Size Class

iOS 27 ends the assumption that an iPhone app owns a fixed, phone-shaped canvas. Apps rebuilt against the iOS 27 SDK are opted into resizability automatically: their windows can be freely resized in iPhone Mirroring on Mac, and iPhone-only apps running on iPad now render in a resizable environment instead of a locked, letterboxed frame. This is the same "the device is not the canvas" direction Apple has pushed since Size Classes in iOS 8, but iOS 27 removes the last safe assumption — that an iPhone host implies a narrow, portrait, compact window.

## What Actually Changed

- **`UIScreen.main` and screen bounds are unreliable.** They no longer represent your app's drawable area. Read the effective geometry of the window scene, or the size handed to your root view, instead.
- **`userInterfaceIdiom` is not a layout signal.** An iPhone app mirrored to a Mac, or running on iPad, still reports the phone idiom — even at iPad-sized widths.
- **`horizontalSizeClass` stays `.compact` on an iPhone host**, no matter how wide the window gets. Apple confirmed this in WWDC26 session 278 ("Modernize your UIKit app") as intentional: size class expresses coarse trait-environment semantics (should the sidebar collapse, is a system Tab available), not a continuous width sensor.
- **Orientation is a preference, not a fact.** The system can keep an app in portrait presentation even while the window's aspect ratio has changed underneath it.
- **UIKit apps must adopt scene lifecycle.** `UIScene` is now required to launch at all on the latest SDK; apps still using the app-delegate-only lifecycle will fail to launch.

## Reading Available Space Correctly

Stop asking "what device/idiom am I on?" Ask "how much space do I actually have right now?"

```swift
struct ContentView: View {
    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > 620

            NavigationSplitView {
                SidebarView()
            } detail: {
                DetailView()
            }
            // Drive your own breakpoint instead of trusting horizontalSizeClass
            .environment(\.isWideLayout, isWide)
        }
    }
}
```

In UIKit, observe scene geometry directly rather than polling bounds on rotation:

```swift
func windowScene(
    _ windowScene: UIWindowScene,
    didUpdateEffectiveGeometry: UIWindowScene.Geometry
) {
    let width = didUpdateEffectiveGeometry.systemFrame.width
    updateLayout(forAvailableWidth: width)
}
```

## Expressing Preferences, Not Control

Developers can no longer lock a fixed canvas, but they can express preferences the system will respect where reasonable:

```swift
// SwiftUI: prefer a minimum usable width, don't assume a fixed one
WindowGroup {
    ContentView()
}
.windowResizability(.contentSize)
```

```swift
// UIKit: express a preferred minimum scene size
let restrictions = UISceneSizeRestrictions()
restrictions.minimumSize = CGSize(width: 375, height: 500)
windowScene.sizeRestrictions = restrictions
```

Distinguish an in-progress interactive resize from its final settled state so you don't thrash expensive layout work on every pixel of a drag:

```swift
struct ResizeAwareView: View {
    @State private var isResizing = false

    var body: some View {
        DetailView()
            .onInteractiveResizeChange { resizing in
                isResizing = resizing
            }
    }
}
```

Temporary orientation locks (e.g., during video playback) remain possible via `prefersInterfaceOrientationLocked`, but treat it as a request, not a guarantee.

## Migrating Existing Adaptive Code

If your app already branches on `horizontalSizeClass` or `userInterfaceIdiom` to decide between a Tab Bar and a Sidebar, that logic will silently stop adapting on a resized iPhone host. A practical migration pattern:

```swift
struct RootView: View {
    @State private var selection: Tab = .home

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > 620 {
                // Wide iPhone window or iPad: custom sidebar drives the same
                // selection state a TabView would use
                SidebarLayout(selection: $selection)
            } else {
                TabView(selection: $selection) {
                    HomeView().tag(Tab.home)
                    SettingsView().tag(Tab.settings)
                }
            }
        }
    }
}
```

Keep the underlying navigation state (the `selection`) identical across both presentations — only the chrome around it should change with available width.

## Best Practices

Prefer geometry (`GeometryReader`, `containerRelativeFrame`, scene effective geometry) over identity-based traits (`idiom`, size class, orientation) whenever the decision is about your own layout breakpoints. Reserve size class for the things it still legitimately governs, like whether a system-provided Sidebar or Tab is available at all. Test early with Xcode 27's resizable Simulator and Live Previews, which now expose drag handles for arbitrary window sizes — don't wait for physical foldable or Mac Mirroring hardware. Avoid injecting `\.horizontalSizeClass` globally to fake regular-width behavior on a resized iPhone; it leaks into every system component reading that environment value and produces inconsistent results. Audit any `UIRequiresFullScreen` usage — it's a deprecated compatibility mode the system will increasingly ignore.

## References

- [WWDC 2026 Session 278: Modernize your UIKit app](https://developer.apple.com/videos/play/wwdc2026/278/)
- [WWDC26 SwiftUI Guide](https://developer.apple.com/wwdc26/guides/swiftui/)
- [TN3192: Migrating your app from the deprecated UIRequiresFullScreen key](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)
- Fatbobman, "From Size Class to Available Space: Is horizontalSizeClass Still Reliable?" (June 2026)
