---
topic: Core AI — Running Open-Weight LLMs On-Device
date: 2026-07-20
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: advanced
---

# Core AI — Running Open-Weight LLMs On-Device

WWDC 2026 introduced **Core AI**, Apple's successor to Core ML for generative workloads. Where Core ML answers "how do I run a model on Apple hardware," Core AI answers "how do I run a chatty, stateful, memory-hungry generative model on Apple hardware without melting the battery." It ships with a memory-safe Swift API, ahead-of-time compilation, and a curated set of pre-converted open-weight models — letting apps run everything from compact vision models up to 70B-parameter reasoning models entirely on iPhone, iPad, Mac, and Apple Vision Pro, with zero server dependency and zero per-token cost.

## Core AI vs. Core ML vs. MLX

Apple now offers three ways to run ML/AI on-device, each with a distinct sweet spot:

- **Core ML** — classic, non-neural ML: decision trees, tabular feature engineering, small vision classifiers.
- **Core AI** — neural networks and transformers built for generative work: LLMs, streaming token output, KV-cache-style stateful execution.
- **MLX Swift** — flexible experimentation with custom model weights, at the cost of some runtime performance versus Core AI's AOT-compiled path.

Reach for Core AI specifically when a model is generative, needs to stream output, or carries state between tokens — that's the workload Core ML was never designed for.

## Adding a Pre-Converted Model

Apple ships pre-optimized open-weight models — including Qwen and Mistral for text, and SAM3 for image segmentation — as Swift packages in `apple/coreai-models`. No conversion required:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/coreai-models", from: "1.0.0")
]
```

## Running a Model with the Swift API

The best part of Core AI's design is that it plugs into the same `LanguageModelSession` API introduced by the Foundation Models framework. The same streaming, structured output, and session model you already know for Apple's on-device model works unchanged with a Core AI model underneath:

```swift
import FoundationModels
import CoreAILanguageModels

// Load a pre-packaged or converted model from disk
let model = try await CoreAILanguageModel(resourcesAt: qwenModelURL)

// Drive it with the familiar Foundation Models session API
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: "Summarize this changelog in 3 bullets.")
print(response.content)
```

Structured output works identically to a native Foundation Models session — annotate a type with `@Generable` and get a typed value back instead of a string to parse:

```swift
@Generable
struct ReleaseNote {
    let title: String
    let summary: String
    let breakingChange: Bool
}

let response = try await session.respond(
    to: "Turn this raw commit log into a release note",
    generating: ReleaseNote.self
)
let note: ReleaseNote = response.content
```

## Converting Your Own PyTorch Model

For custom models, `coreai-torch` bridges PyTorch and Core AI in three steps: export, decompose, convert.

```python
import torch
from coreai_torch import TorchConverter, get_decomp_table

# 1. Export the PyTorch graph with torch.export
model = MyModel().eval()
ep = torch.export.export(model, args=(torch.randn(1, 10),))

# 2. Lower composite ATen ops into primitives Core AI understands
ep = ep.run_decompositions(get_decomp_table())

# 3. Convert to a Core AI program, then specialize for Apple Silicon
coreai_program = TorchConverter().add_exported_program(ep).to_coreai()
coreai_program.optimize()
```

For unsupported ops, `register_torch_lowering()` registers a custom lowering, and `TorchMetalKernel` lets you author an inline Metal kernel. A built-in composite-ops library already covers common transformer building blocks: RoPE, RMSNorm, SDPA, and attention.

## Compressing Models to Fit on Device

A model that runs comfortably on an M-series Mac won't necessarily fit an iPhone's memory budget. `coreai-optimization` provides:

- **Quantization** — lowers weight precision (e.g. 16-bit float to 4-bit int), shrinking memory and speeding up Neural Engine execution.
- **Palettization** — maps weights to a small shared lookup table for further compression.

Both trade a little accuracy for footprint. Treat it as a tuning loop: quantize, measure output quality against a held-out set, back off if quality drops too far.

## Specialization and Caching

Every `AIModel` is automatically **specialized** for the current hardware and OS version the first time it's loaded — this is why the first inference after install is noticeably slower than subsequent runs, once the specialized artifact lands in the model cache. Control this behavior explicitly:

```swift
import CoreAI

var options = SpecializationOptions()
options.prewarm = true

let model = try await CoreAILanguageModel(
    resourcesAt: qwenModelURL,
    specialization: options
)

// Inspect or clear cached artifacts, or share the cache across an app group
let cache = AIModelCache.shared
if await cache.contains(model.identifier) {
    // already specialized — skip prewarming
}
```

## Debugging and Profiling

Because a Core AI model is a compiled artifact rather than a service you can curl, Xcode 27 adds graph inspection and per-op profiling across CPU, GPU, and Neural Engine, plus a standalone Core AI Debugger app for deeper visibility. Profile before optimizing — a model that looks slow because of "one big layer" is often actually paying for a memory copy or an op that silently fell back to the CPU.

## Best Practices

Prefer a pre-converted model from `apple/coreai-models` before reaching for a custom PyTorch conversion — it eliminates an entire compression-and-validation cycle. When you do convert your own model, budget real time for the quantize-measure-adjust loop; "ship the smallest model that still passes your quality bar" beats guessing a compression level up front. Treat Core AI and cloud models as complementary, not competing: route privacy-sensitive, offline, high-volume, or latency-critical requests on-device, and escalate requests that need frontier reasoning or large context windows to a cloud API. Always prewarm and cache specialization artifacts for models your app uses on a critical path (like app launch), since the first specialization pass can take multiple seconds. Share a model cache across an app group when several targets in your app family use the same model, to avoid redundant specialization work and duplicated disk usage.

## References

- [Meet Core AI — WWDC26 session 324](https://developer.apple.com/videos/play/wwdc2026/324/)
- [Integrate on-device AI models — WWDC26 session 326](https://developer.apple.com/videos/play/wwdc2026/326/)
- [Core AI documentation](https://developer.apple.com/documentation/coreai)
- [coreai-torch on GitHub](https://github.com/apple/coreai-torch)
- [coreai-optimization on GitHub](https://github.com/apple/coreai-optimization)
- [Apple Newsroom: Apple accelerates app development with new intelligence frameworks and advanced tools](https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/)
