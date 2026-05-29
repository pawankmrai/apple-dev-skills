---
topic: "visionOS Spatial Computing — Persistence, Surfaces, and Spatial Scenes"
date: 2026-05-29
platform: visionOS 26
swift: "6.2"
difficulty: intermediate
---

# visionOS Spatial Computing — Persistence, Surfaces, and Spatial Scenes

visionOS 26 introduced powerful APIs that let apps anchor content to physical surfaces, persist placements across sessions, and create immersive spatial scenes. These capabilities move beyond floating windows and into true mixed-reality experiences where digital content feels part of the physical world.

## Surface Alignment and Locking

Apps can now align volumetric content to detected surfaces — walls, tables, and floors — then lock that content in place so it persists even after restarting Apple Vision Pro.

```swift
import RealityKit
import SwiftUI

struct SurfaceAlignedView: View {
    @State private var anchor: AnchorEntity?

    var body: some View {
        RealityView { content in
            // Create an anchor aligned to a horizontal surface
            let tableAnchor = AnchorEntity(.plane(.horizontal, classification: .table, minimumBounds: [0.3, 0.3]))

            let model = try! await ModelEntity(named: "DeskWidget")
            model.position = SIMD3(0, 0.05, 0)
            tableAnchor.addChild(model)
            content.add(tableAnchor)
            anchor = tableAnchor
        }
    }
}
```

## Persistence APIs

The new `SpatialPersistence` framework lets you save and restore anchor placements across app launches. Content stays exactly where the user placed it.

```swift
import RealityKit
import SpatialPersistence

struct PersistentContentView: View {
    @Environment(\.spatialPersistenceManager) private var persistenceManager

    var body: some View {
        RealityView { content in
            // Restore previously saved anchors
            let savedAnchors = try await persistenceManager.loadAnchors()
            for descriptor in savedAnchors {
                let anchor = AnchorEntity()
                anchor.transform = descriptor.transform
                let model = try await ModelEntity(named: descriptor.modelName)
                anchor.addChild(model)
                content.add(anchor)
            }
        }
    }

    func saveCurrentPlacement(_ anchor: AnchorEntity, modelName: String) async throws {
        let descriptor = SpatialAnchorDescriptor(
            transform: anchor.transform,
            modelName: modelName
        )
        try await persistenceManager.save(descriptor)
    }
}
```

## Spatial Scene API

The Spatial Scene API allows apps to create rich 3D scenes that users can view in Photos, Spatial Gallery, and Safari.

```swift
import SpatialScene

struct ProductShowcase {
    func createSpatialScene() async throws -> SpatialSceneContent {
        var scene = SpatialSceneContent()

        // Add a 3D product model with environment lighting
        let product = try await scene.addModel(
            named: "Sneaker",
            position: SIMD3(0, 0, -0.5),
            scale: .one * 0.3
        )

        // Add an orbital camera path
        scene.camera = .orbital(
            target: product.position,
            radius: 1.0,
            elevation: .degrees(15)
        )

        // Configure environment
        scene.environment = .realistic(
            lighting: .studio,
            background: .transparent
        )

        return scene
    }
}
```

## Enhanced Hand Tracking

visionOS 26 supports hand tracking at up to 90 Hz with no additional code changes, enabling fast-paced interactions for games and creative apps.

```swift
import ARKit
import RealityKit

class HandTrackingSystem: System {
    static let query = EntityQuery(where: .has(HandTrackingComponent.self))
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()

    func setup() async throws {
        try await session.run([handTracking])
    }

    func update(context: SceneUpdateContext) {
        guard let leftHand = handTracking.latestAnchors.leftHand else { return }

        // Access high-frequency joint data (up to 90 Hz in visionOS 26)
        let indexTip = leftHand.handSkeleton?.joint(.indexFingerTip)
        if let tip = indexTip, tip.isTracked {
            let position = leftHand.originFromAnchorTransform
                * tip.anchorFromJointTransform
            // Use position for precise interaction
        }
    }
}
```

## Embedding 3D on the Web

visionOS 26 supports the HTML `<model>` element, letting developers embed 3D models directly in web pages that render spatially in Safari on Vision Pro.

```html
<!-- 3D model rendered spatially in Safari on Vision Pro -->
<model
  src="sneaker.usdz"
  interactive
  style="width: 400px; height: 300px;"
>
  <source src="sneaker.usdz" type="model/vnd.usdz+zip">
</model>
```

## Best Practices

- **Test on device.** The Simulator approximates spatial features but cannot replicate real surface detection or persistence behavior — always verify on hardware.
- **Handle anchor loss gracefully.** Physical environments change; saved anchors may fail to re-localize. Provide fallback placement or let users reposition content.
- **Respect the user's space.** Avoid placing persistent content aggressively. Let users explicitly choose where and when to lock content.
- **Optimize 3D assets.** Use Reality Composer Pro to compress meshes and textures. Large assets degrade frame rates and drain battery.
- **Use the increased memory limits wisely.** visionOS 26 raises memory caps for immersive apps, but monitor allocations with Instruments to avoid thermal throttling.

## References

- [What's New in visionOS 26 — Apple Developer](https://developer.apple.com/visionos/whats-new/)
- [visionOS 26 Newsroom Announcement — Apple](https://www.apple.com/newsroom/2025/06/visionos-26-introduces-powerful-new-spatial-experiences-for-apple-vision-pro/)
- [Explore Enhancements to Spatial Business Apps — WWDC25](https://developer.apple.com/videos/play/wwdc2025/223/)
- [RealityKit Documentation — Apple Developer](https://developer.apple.com/documentation/realitykit)
