---
topic: Vision Framework — Interactive Tap-to-Segment Image Analysis
date: 2026-07-24
platform: iOS 27
swift: "6.4"
difficulty: intermediate
---

# Vision Framework — Interactive Tap-to-Segment Image Analysis

WWDC26 introduced tap-to-segment to the Vision framework: instead of running a fixed detector over an entire image, you give Vision a seed point (or a lasso stroke) inside the object you care about, and it returns a precise foreground mask for just that object. This is the same interaction model behind Visual Look Up and Photos' subject lifting, now exposed as a first-class Swift API via `GenerateIterativeSegmentationRequest`. It pairs naturally with the modern Swift Vision API (`ImageRequestHandler`, async `perform`) rather than the older `VNImageRequestHandler`/completion-handler style.

## Why Seed-Based Segmentation

Whole-image segmentation requests like `VNGeneratePersonSegmentationRequest` are great when you know what you're looking for (a person, the general foreground). Tap-to-segment is for the ambiguous case: a photo full of objects where the user tells you, with a tap, which one they mean. It runs entirely on-device using the Neural Engine, so there's no network round trip and no user data leaves the phone.

## Basic Seed Segmentation

```swift
import Vision
import CoreImage

func segmentObject(in image: CGImage, at seedPoint: CGPoint) async throws -> CVPixelBuffer {
    let handler = ImageRequestHandler(image)

    var request = GenerateIterativeSegmentationRequest()
    request.addSeedPoint(seedPoint, label: .foreground)

    let observation = try await handler.perform(request).first
    guard let mask = observation?.mask else {
        throw SegmentationError.noMaskProduced
    }
    return mask
}

enum SegmentationError: Error {
    case noMaskProduced
}
```

`seedPoint` is expressed in normalized coordinates (0...1, origin at bottom-left), matching every other Vision request. The returned mask is a single-channel `CVPixelBuffer` the same aspect ratio as the source image — values close to 1.0 mark pixels belonging to the segmented object.

## Refining a Mask with Additional Points

The real power of the interactive API is iterative refinement: if the first mask over- or under-shoots the object, add more points — foreground to grow the selection, background to carve pixels back out — and re-run the same request.

```swift
func refineSegmentation(
    _ request: inout GenerateIterativeSegmentationRequest,
    handler: ImageRequestHandler,
    addForegroundPoint point: CGPoint? = nil,
    addBackgroundPoint excludePoint: CGPoint? = nil
) async throws -> CVPixelBuffer {
    if let point {
        request.addSeedPoint(point, label: .foreground)
    }
    if let excludePoint {
        request.addSeedPoint(excludePoint, label: .background)
    }

    let observation = try await handler.perform(request).first
    guard let mask = observation?.mask else {
        throw SegmentationError.noMaskProduced
    }
    return mask
}
```

Because `ImageRequestHandler` caches the decoded image internally, repeated `perform` calls on the same handler with updated seed points are fast — this is what makes a live, drag-to-adjust lasso interaction feel responsive rather than like a fresh analysis each time.

## Wiring It to a SwiftUI Tap Gesture

```swift
struct TapToSegmentView: View {
    let uiImage: UIImage
    @State private var maskOverlay: Image?

    var body: some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .overlay(maskOverlay?.opacity(0.5))
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        Task { await segment(at: value.location) }
                    }
            )
    }

    private func segment(at location: CGPoint) async {
        guard let cgImage = uiImage.cgImage else { return }
        // Convert view-space tap location to normalized image coordinates
        // (omitted here: depends on your image's displayed frame).
        let normalizedPoint = CGPoint(x: 0.5, y: 0.5)

        do {
            let mask = try await segmentObject(in: cgImage, at: normalizedPoint)
            maskOverlay = try makeOverlayImage(from: mask)
        } catch {
            print("Segmentation failed: \(error)")
        }
    }

    private func makeOverlayImage(from mask: CVPixelBuffer) throws -> Image {
        let ciImage = CIImage(cvPixelBuffer: mask)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw SegmentationError.noMaskProduced
        }
        return Image(decorative: cgImage, scale: 1.0)
    }
}
```

## Extracting the Cutout

Once you have a mask you're happy with, use it to lift the subject out of the source image — the same primitive behind "Copy Subject" in Photos.

```swift
func cutout(from image: CIImage, mask: CVPixelBuffer) -> CIImage {
    let maskImage = CIImage(cvPixelBuffer: mask)
    let filter = CIFilter.blendWithMask()
    filter.inputImage = image
    filter.maskImage = maskImage
    filter.backgroundImage = CIImage(color: .clear).cropped(to: image.extent)
    return filter.outputImage ?? image
}
```

## Combining with Foundation Models

The new image-input support in the Foundation Models framework accepts `CGImage`, `CVPixelBuffer`, and `CIImage` directly, so a segmented cutout can be handed straight to an on-device language model for classification or description — no round trip through disk or a server.

```swift
import FoundationModels

func describe(cutout: CIImage) async throws -> String {
    let session = LanguageModelSession()
    let response = try await session.respond(
        to: "Briefly describe the object in this image.",
        image: cutout
    )
    return response.content
}
```

## Best Practices

Run segmentation off the main actor path where possible — `perform` is async, but decoding large source images is the expensive part, so downsample images that don't need full resolution before creating the `ImageRequestHandler`. Reuse a single handler across refinement calls instead of recreating it per tap; recreating forces Vision to re-decode and re-analyze the base image. Treat background seed points as first-class input in your UI, not an edge case — most real segmentation tasks need at least one exclusion point to get a clean edge around overlapping objects. Always fall back gracefully when `mask` is `nil` — this happens when a seed point lands on ambiguous background with no clear foreground candidate nearby.

## References

- [What's new in image understanding - WWDC26](https://developer.apple.com/videos/play/wwdc2026/237/)
- [Discover Swift enhancements in the Vision framework - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10163/)
- [Vision | Apple Developer Documentation](https://developer.apple.com/documentation/vision)
- [What's new in the Foundation Models framework - WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/)
