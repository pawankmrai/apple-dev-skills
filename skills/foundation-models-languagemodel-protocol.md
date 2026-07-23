---
topic: Foundation Models Framework — The LanguageModel Protocol for Provider-Agnostic Inference
date: 2026-07-23
platform: iOS 27, macOS 27
swift: "6.2"
difficulty: advanced
---

# Foundation Models Framework — The LanguageModel Protocol for Provider-Agnostic Inference

Until WWDC 2026, Foundation Models had one rule: Apple's on-device model or nothing. Session 339 removed that rule. A new public protocol layer — `LanguageModel` and `LanguageModelExecutor` — lets any provider, cloud or local, back a `LanguageModelSession`. Anthropic and Google shipped conforming Swift packages on day one, so the same session code that talks to Apple's on-device model can talk to Claude or Gemini with a one-argument swap. This skill covers consuming that protocol as an app developer and, briefly, implementing it as a provider. See the `foundation-models-framework` skill for `@Generable` and session basics, and `foundation-models-dynamic-profiles` for multi-model workflows within one conversation.

## The Model Spectrum

Five conforming model types now sit behind one API, ordered roughly by cost and capability:

```swift
import FoundationModels

// Free, private, offline — ~3B parameters, tightly bounded tasks
let onDevice = SystemLanguageModel()

// Free under 2M cumulative first-time downloads, then billed — Apple's cloud model
// let cloud = PrivateCloudComputeLanguageModel()

// Third-party local models on the Apple Neural Engine, shipped via SPM
// let local = try await CoreAILanguageModel(resourcesAt: modelURL)

// Any MLX-format model pulled from Hugging Face, runs on the Mac GPU
// let mlx = MLXLanguageModel(modelID: "mlx-community/my-model")

let session = LanguageModelSession(model: onDevice)
let response = try await session.respond(to: "Summarize this contract.")
```

Every model type conforms to `LanguageModel`; `session.respond(to:)`, `streamResponse(to:)`, structured output via `@Generable`, and client-side tool calling all work identically regardless of which one backs the session.

## Swapping to a Cloud Provider

Anthropic's `ClaudeForFoundationModels` package (targets iOS/macOS/visionOS/watchOS 27) conforms Claude to the same protocol:

```swift
import FoundationModels
import ClaudeForFoundationModels

let cloud = ClaudeLanguageModel(
    name: .sonnet4_6,
    auth: .apiKey(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "")
)

let session = LanguageModelSession(model: cloud)
let response = try await session.respond(to: "Summarize these meeting notes.")
```

Requests go directly from the app to the provider's API — Apple is not in the request path and never sees prompts or responses. `.apiKey` auth is development-only; ship production apps with `.proxied(headers:)`, which sends an opaque header to your own backend, which then attaches the real key server-side. Pair this with App Attest so your proxy can confirm the request came from a legitimate build of your app.

## Routing Between Tiers

Because the session surface is uniform, tiering is a try/catch, not a rewrite:

```swift
let small = SystemLanguageModel()
let big = ClaudeLanguageModel(name: .sonnet4_6, auth: .proxied(headers: authHeaders))

func complete(_ prompt: String) async throws -> String {
    do {
        let session = LanguageModelSession(model: small)
        return try await session.respond(to: prompt).content
    } catch LanguageModelError.contextSizeExceeded {
        let session = LanguageModelSession(model: big)
        return try await session.respond(to: prompt).content
    }
}
```

Use the on-device model for classification, extraction, and short-form generation where you control the prompt tightly. Reach for a cloud model when you need long context, multi-turn reasoning, current world knowledge, or server-side tools like web search. Framing the decision as "what can't run on-device" rather than "which model is biggest" keeps most calls free.

## Implementing a Provider

Shipping your own conformance means two protocols: `LanguageModel` declares capabilities and configuration; `LanguageModelExecutor` does the actual generation.

```swift
public struct MyLanguageModel: LanguageModel {
    typealias Executor = MyLanguageModelExecutor

    public var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities(capabilities: [.toolCalling, .guidedGeneration, .reasoning])
    }

    public var executorConfiguration: Executor.Configuration {
        Executor.Configuration(/* endpoint, auth, model variant */)
    }
}

public struct MyLanguageModelExecutor: LanguageModelExecutor {
    public typealias Model = MyLanguageModel
    public init(configuration: Configuration) throws { }

    public func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: MyLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
        await channel.send(.response(action: .updateMetadata(["modelID": "my-model-2026"])))
        for try await token in modelStream(for: request) {
            await channel.send(.response(action: .appendText(token)))
        }
    }
}
```

The framework passes history as a typed `Transcript` (`.instructions`, `.prompt`, `.toolCalls`, `.toolOutput`, `.response`), not raw role/content strings — map these to your wire format. Implement `prewarm` to load weights or warm a connection pool ahead of the first request. Where a caller asks for something you don't support, approximate if you can (map greedy sampling to `temperature = 0`) and throw a typed `LanguageModelError` (`contextSizeExceeded`, `rateLimited`, `refusal`, `guardrailViolation`) if you can't — callers already know how to handle those.

## Best Practices

Keep server-side tool configuration (web search, code execution) on the model instance via a `serverTools:` parameter rather than on the session — `LanguageModelSession` is Apple's type and has no knowledge of provider-specific capabilities, so construct separate model instances when you need different tool sets. Never ship a raw API key in a binary; route production traffic through a proxy with `.proxied(headers:)` and verify calls with App Attest. When packaging a provider, split the runtime engine from the public `LanguageModel` conformance into separate SPM targets, keep the dependency graph lean, and store credentials in Keychain rather than accepting plain strings. Test locally with `SystemLanguageModel` before wiring in a paid cloud tier, since escalation is meant to be the exception, not the default path.

## References

- [Bring an LLM provider to the Foundation Models framework — WWDC26](https://developer.apple.com/videos/play/wwdc2026/339/)
- [What's new in the Foundation Models framework — WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/)
- [Anthropic: Apple Foundation Models integration](https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/apple-foundation-models)
- [ClaudeForFoundationModels on GitHub](https://github.com/anthropics/ClaudeForFoundationModels)
