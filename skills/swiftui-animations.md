---
topic: SwiftUI Animations — From Implicit to Keyframe
date: 2026-05-31
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI Animations — From Implicit to Keyframe

SwiftUI provides a layered animation system that scales from single-property fades to choreographed, multi-track motion sequences. This skill walks through each layer — implicit animations, explicit animations, transitions, `PhaseAnimator`, and `KeyframeAnimator` — with compilable examples.

## Implicit Animations

The simplest approach: attach `.animation(_:value:)` to a view. SwiftUI watches the value and animates any visual change that results.

```swift
struct PulseView: View {
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .frame(width: isExpanded ? 120 : 80,
                   height: isExpanded ? 120 : 80)
            .foregroundStyle(.blue)
            .animation(.easeInOut(duration: 0.4), value: isExpanded)
            .onTapGesture { isExpanded.toggle() }
    }
}
```

Use implicit animations when a single state change drives a single visual effect.

## Explicit Animations

Wrap state mutations in `withAnimation` when you need one gesture to animate multiple views or want to choose the curve at the call site.

```swift
func handleTap() {
    withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
        selectedCard = card
        showDetail = true
    }
}
```

## Transitions

Transitions define how a view enters and exits the hierarchy. Combine them for richer effects.

```swift
struct ToastView: View {
    var body: some View {
        Text("Saved!")
            .padding()
            .background(.green.gradient, in: .capsule)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                )
            )
    }
}
```

Build custom transitions by conforming to `Transition`:

```swift
struct SlideAndFade: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .offset(y: phase == .willAppear ? -30 : (phase == .didDisappear ? 30 : 0))
    }
}
```

## PhaseAnimator

`PhaseAnimator` cycles through a sequence of phases automatically, applying animations between each step. It is ideal for looping or multi-step effects that don't require precise timing control.

```swift
enum BouncePhase: CaseIterable {
    case rest, up, down
}

struct BouncingDot: View {
    var body: some View {
        PhaseAnimator(BouncePhase.allCases) { phase in
            Circle()
                .frame(width: 40, height: 40)
                .foregroundStyle(.orange)
                .offset(y: phase == .up ? -30 : (phase == .down ? 10 : 0))
                .scaleEffect(phase == .up ? 1.2 : 1.0)
        } animation: { phase in
            switch phase {
            case .rest: .easeInOut(duration: 0.3)
            case .up:   .easeOut(duration: 0.25)
            case .down: .spring(duration: 0.4, bounce: 0.5)
            }
        }
    }
}
```

Pass a `trigger` value to start the animation on demand instead of looping.

## KeyframeAnimator

`KeyframeAnimator` gives you timeline-based control with multiple independent tracks. Each track animates a single property using keyframes with distinct interpolation methods.

```swift
struct AnimationValues {
    var scale: Double = 1.0
    var yOffset: Double = 0.0
    var rotation: Angle = .zero
}

struct RocketLaunch: View {
    @State private var launch = false

    var body: some View {
        KeyframeAnimator(initialValue: AnimationValues(),
                         trigger: launch) { values in
            Image(systemName: "airplane")
                .font(.system(size: 48))
                .scaleEffect(values.scale)
                .offset(y: values.yOffset)
                .rotationEffect(values.rotation)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(1.3, duration: 0.3)
                SpringKeyframe(1.0, duration: 0.2)
            }
            KeyframeTrack(\.yOffset) {
                LinearKeyframe(0, duration: 0.2)
                CubicKeyframe(-200, duration: 0.8)
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(.degrees(-15), duration: 0.3)
                CubicKeyframe(.degrees(0), duration: 0.5)
            }
        }
        .onTapGesture { launch.toggle() }
    }
}
```

Keyframe interpolation types at a glance: `LinearKeyframe` (constant velocity), `SpringKeyframe` (physics-based), `CubicKeyframe` (Bézier curves), and `MoveKeyframe` (instant jump, no interpolation).

## Best Practices

Start with implicit animations and escalate only when you need more control. Implicit and explicit animations cover most UI polish; reach for `PhaseAnimator` for looping multi-step effects and `KeyframeAnimator` for choreographed, timeline-precise sequences.

Always specify a `value:` parameter with implicit animations to avoid animating unrelated state changes. Prefer `spring` curves for interactive gestures — they feel natural and handle interrupted animations gracefully. Use `withAnimation(nil)` to suppress animation for state changes that should be instant.

Profile animations with Instruments' Animation Hitches template if frame drops appear on older devices. Keep animated view hierarchies shallow to reduce layout recalculation during each frame.

## References

- [Animations — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/animations)
- [Wind your way through advanced animations in SwiftUI — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10157/)
- [Controlling the timing and movements of your animations](https://developer.apple.com/documentation/SwiftUI/Controlling-the-timing-and-movements-of-your-animations)
