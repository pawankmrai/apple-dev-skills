---
topic: MLX Swift — Custom On-Device ML with Metal 4 Neural Accelerators
date: 2026-08-02
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: advanced
---

# MLX Swift — Custom On-Device ML with Metal 4 Neural Accelerators

MLX is Apple's open-source, NumPy-inspired array framework built specifically for Apple Silicon. Unlike Core AI — which targets pre-converted generative models through a curated `LanguageModelSession` API — MLX Swift is the tool for when you're shipping *your own* model architecture, doing custom numerical computation, or need low-level control over training and inference. With WWDC 2026's Metal 4, MLX gained direct support for Tensor Operations (TensorOps) and Metal Performance Primitives, letting array workloads route through each Apple Silicon GPU's dedicated Neural Accelerators instead of general-purpose compute shaders — Apple reports 2-3x throughput gains over the previous Metal 3 path for common ML workloads.

## Why Reach for MLX Instead of Core AI

- **Core AI** — pre-optimized, ahead-of-time-compiled generative models (LLMs, SAM3) via a high-level session API. No conversion, no custom ops.
- **Core ML** — classic supervised models: tabular data, small vision classifiers, converted from PyTorch/TensorFlow.
- **MLX Swift** — you own the graph. Custom layers, novel training loops, research prototypes, or numerical code that has nothing to do with a chat model.

If your work is "run this open model," use Core AI. If it's "I designed this architecture and need it fast on-device," reach for MLX.

## Adding MLX Swift to a Project

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.25.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "MLX", package: "mlx-swift"),
            .product(name: "MLXNN", package: "mlx-swift"),
            .product(name: "MLXOptimizers", package: "mlx-swift"),
            .product(name: "MLXRandom", package: "mlx-swift"),
        ]
    )
]
```

## Arrays and Lazy Evaluation

`MLXArray` mirrors NumPy semantics, but every operation is lazy — nothing runs on the GPU until you force evaluation with `eval(_:)` or read a value back:

```swift
import MLX
import MLXRandom

let weights = MLXRandom.normal([784, 128])
let input = MLXArray(0..<784, [1, 784]).asType(.float32)

// Builds a computation graph; no GPU work has happened yet.
let hidden = matmul(input, weights)
let activated = maximum(hidden, MLXArray(0.0))

eval(activated) // Triggers execution, routed through Metal 4 TensorOps.
print(activated.shape) // [1, 128]
```

Unified memory means the same buffer is addressable from CPU and GPU without a copy — critical on memory-constrained devices when iterating on batch sizes.

## Defining a Model with MLXNN

```swift
import MLXNN

class SimpleClassifier: Module, UnaryLayer {
    let fc1: Linear
    let fc2: Linear

    init(inputDim: Int, hiddenDim: Int, outputDim: Int) {
        fc1 = Linear(inputDim, hiddenDim)
        fc2 = Linear(hiddenDim, outputDim)
        super.init()
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        var x = fc1(x)
        x = relu(x)
        x = fc2(x)
        return x
    }
}

let model = SimpleClassifier(inputDim: 784, hiddenDim: 128, outputDim: 10)
```

## Training Loop with an Optimizer

```swift
import MLXOptimizers

let optimizer = Adam(learningRate: 1e-3)

func lossFn(model: SimpleClassifier, x: MLXArray, y: MLXArray) -> MLXArray {
    let logits = model(x)
    return crossEntropy(logits: logits, targets: y, reduction: .mean)
}

let lossAndGrad = valueAndGrad(model: model, lossFn)

for (batchX, batchY) in trainBatches {
    let (loss, grads) = lossAndGrad(model, batchX, batchY)
    optimizer.update(model: model, gradients: grads)
    eval(model.parameters(), optimizer.state)
}
```

`valueAndGrad` builds an automatic-differentiation graph over the model's parameters — no manual backward pass required.

## Targeting Metal 4 Neural Accelerators

MLX detects Metal 4 availability at runtime and automatically dispatches matmul-heavy ops (linear layers, attention, convolutions) through TensorOps when the device's GPU exposes Neural Accelerator hardware (M5-class and newer, plus the corresponding A-series). No API changes are required — but you can confirm the active backend for diagnostics:

```swift
import MLX

if GPU.metal4TensorOpsAvailable {
    print("Routing through Metal 4 Neural Accelerators")
} else {
    print("Falling back to Metal 3 compute shaders")
}
```

On older hardware, MLX transparently falls back to the Metal 3 path, so the same code ships across your full device matrix.

## Best Practices

Batch `eval()` calls rather than forcing evaluation after every operation — MLX's lazy graph lets it fuse and schedule ops more efficiently when you defer evaluation until you actually need a result (end of a training step, or when reading output for display). Keep large intermediate arrays out of Swift's ARC-managed memory longer than needed; call `eval` and let MLX release GPU buffers once a step completes. Profile with Instruments' Metal System Trace to confirm TensorOps dispatch on Metal 4 devices — the "GPU Compute" track will show dedicated Neural Accelerator counters distinct from general shader occupancy. For production inference (rather than research/training), prefer Core AI or Core ML unless you specifically need MLX's flexibility — its Swift API trades some of Core AI's AOT-compiled performance for the ability to define arbitrary architectures.

## References

- [MLX Swift on GitHub](https://github.com/ml-explore/mlx-swift)
- [MLX: An Array Framework for Apple Silicon](https://github.com/ml-explore/mlx)
- [On-device ML research with MLX and Swift — Swift.org](https://www.swift.org/blog/mlx-swift/)
- [MLX Framework documentation](https://mlx-framework.org/)
- [What's New in Metal — WWDC26](https://developer.apple.com/videos/wwdc2026/)
