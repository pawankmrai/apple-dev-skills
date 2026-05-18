---
topic: SwiftUI Liquid Glass — Building with the New Design Language
date: 2026-05-18
platform: iOS 26, macOS Tahoe 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI Liquid Glass — Building with the New Design Language

Liquid Glass is Apple's most significant design evolution since iOS 7, introduced at WWDC 2025. It applies translucent, light-refracting materials to controls and navigation elements, creating depth between foreground UI and background content. SwiftUI in iOS 26 provides first-class support through the `glassEffect` modifier and `GlassEffectContainer`.

## The glassEffect Modifier

The primary entry point is the `.glassEffect()` view modifier, accepting a glass style, shape, and enabled flag.

```swift
import SwiftUI

struct GlassButtonView: View {
    var body: some View {
        Button("Get Started") { }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
    }
}
```

The `.regular` style is the default general-purpose glass. Use `.clear` for high-transparency over media-heavy backgrounds, and `.identity` to programmatically disable the effect.

## Glass Tinting and Interactivity

Tinting adjusts the hue of the material without making it fully opaque.

```swift
struct TintedControls: View {
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 16) {
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .glassEffect(.regular.tint(.blue))

            Button { } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .glassEffect(.regular.tint(.blue.opacity(0.6)))
        }
    }
}
```

Mark glass as touch-responsive with `.interactive()`:

```swift
Button("Subscribe") { }
    .glassEffect(.regular.tint(.purple).interactive())
```

## GlassEffectContainer and Morphing

`GlassEffectContainer` groups glass elements so they morph into a unified shape when close together. The `spacing` parameter controls the proximity threshold.

```swift
struct MorphingToolbar: View {
    let icons = ["house.fill", "magnifyingglass", "bell.fill", "person.fill"]

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    Button { } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect()
                }
            }
        }
    }
}
```

When the HStack spacing is within the container's threshold, individual glass shapes merge into one continuous surface. Exceeding it separates them into distinct elements.

## Morphing Transitions with glassEffectID

For animated transitions between glass elements, use `glassEffectID` with a shared namespace.

```swift
struct ExpandableMenu: View {
    @State private var isExpanded = false
    @Namespace private var ns

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                if isExpanded {
                    menuButton("Camera", icon: "camera.fill", id: "camera")
                    menuButton("Photos", icon: "photo.fill", id: "photos")
                }

                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                }
                .glassEffect(.regular.tint(.orange).interactive())
                .glassEffectID("toggle", in: ns)
            }
        }
    }

    private func menuButton(_ title: String, icon: String, id: String) -> some View {
        Button { } label: {
            Label(title, systemImage: icon).frame(width: 140)
        }
        .glassEffect()
        .glassEffectID(id, in: ns)
    }
}
```

The namespace ties glass shapes together so the system interpolates between positions and sizes during state changes.

## Navigation and Automatic Adoption

Standard SwiftUI navigation elements adopt Liquid Glass automatically in iOS 26. Navigation bars, tab bars, and toolbars inherit the translucent material — content scrolls beneath these surfaces, providing natural depth cues without additional code.

```swift
NavigationStack {
    ScrollView {
        // content
    }
    .navigationTitle("Feed")
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            Button { } label: {
                Image(systemName: "square.and.pencil")
            }
        }
    }
}
```

## Best Practices

Reserve glass for the **navigation layer** — toolbars, tab bars, floating controls, and overlays. Applying glass to content cards undermines the intended visual hierarchy.

Keep glass surfaces **minimal and purposeful**. Overusing tints or stacking multiple glass layers creates visual noise and hurts readability.

Test with **varied backgrounds**. Glass adapts to content behind it, so verify legibility across light images, dark images, and solid colors.

Use `GlassEffectContainer` for **related controls** that should feel unified. The morphing behavior communicates grouping without explicit chrome.

Avoid combining glass with heavy `shadow` or `blur` modifiers — the glass material already includes these effects.

## References

- [Build a SwiftUI app with the new design — WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)
- [GlassEffectContainer — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [Apple introduces a delightful and elegant new software design](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
