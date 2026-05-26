---
topic: Swift Charts 3D — Data Visualization with Chart3D
date: 2026-05-26
platform: iOS 26, macOS 26, visionOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Charts 3D — Data Visualization with Chart3D

WWDC 2025 introduced Chart3D to the Swift Charts framework, bringing interactive 3D data visualization to SwiftUI. Plot data across three axes, render mathematical surfaces, and let users rotate charts with gestures — no third-party libraries needed.

## Getting Started with Chart3D

Chart3D works like the 2D `Chart` view but adds a Z axis:

```swift
import SwiftUI
import Charts

struct SensorReading: Identifiable {
    let id = UUID()
    let temperature: Double
    let humidity: Double
    let pressure: Double
    let category: String
}

struct SensorChartView: View {
    let readings: [SensorReading]

    var body: some View {
        Chart3D(readings) { reading in
            PointMark(
                x: .value("Temperature", reading.temperature),
                y: .value("Humidity", reading.humidity),
                z: .value("Pressure", reading.pressure)
            )
            .foregroundStyle(by: .value("Category", reading.category))
            .symbol(.cube)
            .symbolSize(0.04)
        }
        .chartXScale(domain: 15...40, range: -1.5...1.5)
        .chartYScale(domain: 20...90, range: -0.5...0.5)
        .chartZScale(domain: 980...1040, range: -0.5...0.5)
        .chartXAxisLabel("Temperature (°C)")
        .chartYAxisLabel("Humidity (%)")
        .chartZAxisLabel("Pressure (hPa)")
    }
}
```

Chart3D supports `PointMark`, `RuleMark`, and `RectangleMark` — each extended to accept X, Y, and Z values.

## SurfacePlot — Mathematical Surfaces

SurfacePlot is unique to Chart3D. It renders a continuous surface from a function of two variables:

```swift
Chart3D {
    SurfacePlot(x: "x", y: "height", z: "z") { x, z in
        sin(x) * cos(z)
    }
    .foregroundStyle(
        .heightBased(Gradient(colors: [.blue, .green, .yellow, .red]))
    )
}
.chartXScale(domain: -5...5)
.chartYScale(domain: -1.5...1.5)
.chartZScale(domain: -5...5)
```

The `.heightBased` style colors the surface by Y value, creating a heatmap effect. Use `.normalBased` to color by surface angle instead.

## Camera Projection and Interactive Pose

Chart3D offers orthographic (default) and perspective projections. Perspective makes farther data points appear smaller, emphasizing depth:

```swift
import Spatial

struct InteractiveChartView: View {
    let data: [SensorReading]
    @State private var pose = Chart3DPose(
        azimuth: .degrees(45),
        inclination: .degrees(25)
    )

    var body: some View {
        Chart3D(data) { reading in
            PointMark(
                x: .value("Temp", reading.temperature),
                y: .value("Humidity", reading.humidity),
                z: .value("Pressure", reading.pressure)
            )
        }
        .chart3DPose($pose)
        .chart3DCameraProjection(.perspective)
    }
}
```

Pass a `Binding<Chart3DPose>` to let users rotate the chart with drag gestures. You can also use predefined poses like `.front`, `.top`, or `.side`.

## Animated Rotation

Create a continuously rotating chart for showcases or dashboards:

```swift
@State private var pose = Chart3DPose(
    azimuth: .degrees(0), inclination: .degrees(20)
)
@State private var angle: Angle2D = .degrees(0)
private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

Chart3D(data) { /* marks */ }
    .chart3DPose($pose)
    .onReceive(timer) { _ in
        angle += .degrees(0.5)
        if angle.degrees >= 360 { angle = .degrees(0) }
        pose = Chart3DPose(azimuth: angle, inclination: .degrees(20))
    }
```

## Best Practices

- **Add the Z axis intentionally.** Only use 3D when a third dimension genuinely improves data understanding.
- **Use perspective for spatial data.** Orthographic suits analytical charts; perspective works better for physical or geographic datasets.
- **Label all three axes.** 3D charts are harder to read — clear labels and legends reduce cognitive load.
- **Keep point counts reasonable.** Overlapping 3D marks clutter quickly; filter or sample large datasets.
- **Provide interactive rotation.** Static 3D charts can hide data — let users explore with pose bindings.
- **Consider visionOS.** Chart3D renders natively in spatial environments for immersive data experiences.

## References

- [Chart3D — Apple Developer Documentation](https://developer.apple.com/documentation/charts/chart3d)
- [Bring Swift Charts to the Third Dimension — WWDC25](https://developer.apple.com/videos/play/wwdc2025/313)
- [What's New in SwiftUI — WWDC25](https://developer.apple.com/videos/play/wwdc2025/256)
