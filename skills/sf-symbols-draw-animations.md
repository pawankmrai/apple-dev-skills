---
topic: SF Symbols Draw Animations — Bringing Icons to Life in SwiftUI
date: 2026-07-28
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: intermediate
---

# SF Symbols Draw Animations — Bringing Icons to Life in SwiftUI

SF Symbols 7 introduced draw animations: instead of fading, scaling, or bouncing, a symbol appears to be traced by a pen, stroke by stroke, and can be reversed to "undraw" itself. SwiftUI exposes this through two new members of the symbol effect family, `.drawOn` and `.drawOff`, alongside the existing `.bounce`, `.pulse`, `.wiggle`, `.rotate`, and `.breathe` effects. Draw animations work best on symbols with clear linework — outline styles, multicolor glyphs, and custom SF Symbols authored with draw-compatible paths in the SF Symbols app.

## The Basics: drawOn and drawOff

`symbolEffect(_:options:isActive:)` drives a discrete, one-shot animation whenever the bound state flips.

```swift
import SwiftUI

struct DownloadStatusView: View {
    @State private var isComplete = false

    var body: some View {
        Image(systemName: isComplete ? "checkmark.circle" : "arrow.down.circle")
            .font(.system(size: 48))
            .symbolEffect(.drawOn, isActive: !isComplete)
            .onTapGesture {
                withAnimation {
                    isComplete.toggle()
                }
            }
    }
}
```

`.drawOn` animates the symbol tracing itself into view; `.drawOff` reverses the stroke, erasing it as if undrawn. Both respect the symbol's natural stroke order, so glyphs with multiple paths (like `wifi` or `checklist`) animate segment by segment.

## Three Animation Scopes

Draw effects can target the whole glyph, its layers, or individual paths, using the `options` parameter:

```swift
struct ScopedDrawView: View {
    @State private var trigger = false

    var body: some View {
        VStack(spacing: 32) {
            // Whole symbol traced as one continuous stroke
            Image(systemName: "signature")
                .symbolEffect(.drawOn.wholeSymbol, value: trigger)

            // Each layer draws independently, in sequence
            Image(systemName: "cloud.sun.rain")
                .symbolEffect(.drawOn.byLayer, value: trigger)

            // Every sub-path animates on its own timeline
            Image(systemName: "checklist")
                .symbolEffect(.drawOn.individually, value: trigger)
        }
        .font(.system(size: 44))
        .onTapGesture { trigger.toggle() }
    }
}
```

`.byLayer` is the right default for multicolor or hierarchical symbols where each visual layer should feel like a distinct stroke pass. `.individually` is best for symbols composed of many small, discrete shapes, like `checklist` or `list.bullet`.

## Combining Draw with Content Transitions

Draw animations pair naturally with `contentTransition(.symbolEffect(...))` when swapping between two related symbols, so the outgoing glyph erases while the incoming one draws:

```swift
struct FavoriteToggleView: View {
    @State private var isFavorited = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.4)) {
                isFavorited.toggle()
            }
        } label: {
            Image(systemName: isFavorited ? "star.fill" : "star")
                .contentTransition(.symbolEffect(.replace.offUp.byLayer))
                .symbolEffect(.drawOn, isActive: isFavorited)
                .font(.system(size: 36))
                .foregroundStyle(isFavorited ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
    }
}
```

`.replace.offUp.byLayer` controls the direction the outgoing symbol exits while the new one draws in, giving a coherent transition rather than two effects fighting each other.

## Repeating and Looping Draw Effects

For loading or "in progress" states, drive the effect indefinitely with `.repeating`:

```swift
struct SyncingIndicatorView: View {
    @State private var isSyncing = true

    var body: some View {
        Image(systemName: "arrow.trianglehead.2.clockwise")
            .font(.system(size: 40))
            .symbolEffect(.drawOn.individually.repeating, isActive: isSyncing)
    }
}
```

Turn `isActive` off in response to a completion callback so the animation settles cleanly rather than freezing mid-stroke.

## Custom Symbols and Draw Compatibility

Not every custom SF Symbol supports draw animations out of the box. In the SF Symbols app, open the symbol's variant inspector and confirm "Draw" is listed under Animation compatibility; if it isn't, the paths need to be re-annotated with explicit stroke order in the Symbol's layer editor before exporting the `.svg` for Xcode's asset catalog. System symbols shipped in SF Symbols 7 are draw-compatible by default.

```swift
// Custom symbol added via Assets.xcassets as a template image
Image("custom.route.marker")
    .symbolRenderingMode(.hierarchical)
    .symbolEffect(.drawOn.byLayer, isActive: true)
```

## Best Practices

Reserve draw animations for moments that deserve emphasis — completion states, first appearances, and empty-to-filled transitions — rather than applying them to every icon on screen, since the tracing effect reads as a deliberate, attention-grabbing gesture. Prefer `.byLayer` over `.individually` unless a symbol is specifically composed of many small independent glyphs, since over-segmenting simple icons can make the animation look jittery rather than fluid. Always pair a `.drawOn` trigger with a corresponding `.drawOff` or content transition so the icon has a clear resting state instead of getting stuck mid-animation, and test with Reduce Motion enabled — SwiftUI automatically shortens symbol effect durations under that setting, but visually busy `.individually` animations should be swapped for a simple `.appear` in your own Reduce Motion checks.

## References

- [Animating symbols in SwiftUI — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/animating-symbols-in-swiftui)
- [SF Symbols — Apple Developer](https://developer.apple.com/sf-symbols/)
- [What's New in SF Symbols 7 — WWDC25 Session 337](https://developer.apple.com/videos/play/wwdc2025/337/)
- [Implementing draw animations for SF Symbols in SwiftUI — Create with Swift](https://www.createwithswift.com/implementing-draw-animations-for-sf-symbols-in-swiftui/)
