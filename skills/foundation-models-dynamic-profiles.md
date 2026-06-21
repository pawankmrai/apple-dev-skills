---
topic: Foundation Models Framework — Dynamic Profiles and Multi-Agent Workflows
date: 2026-06-21
platform: iOS 26.6, macOS 26.6
swift: "6.3"
difficulty: advanced
---

# Foundation Models Framework — Dynamic Profiles and Multi-Agent Workflows

WWDC 2026 expanded the Foundation Models framework well past the single-session, single-model design introduced a year earlier. Three additions stand out: image input alongside text prompts, server-side model targets that let Anthropic and Google plug their models into the same Swift API, and **Dynamic Profiles** — a first-class primitive for composing multi-agent workflows inside one continuous session. This skill focuses on Dynamic Profiles; see the `foundation-models-framework` skill for the session and `@Generable` basics they build on.

## Why Dynamic Profiles Exist

Before WWDC26, switching an app's AI behavior — say, from drafting notes to summarizing them to translating them — meant tearing down a `LanguageModelSession` and starting a fresh one, losing conversational context in the process. A Dynamic Profile bundles a set of tools, a model target, and an instruction string into a single swappable unit, so the session itself stays alive while its "role" changes underneath.

## Defining Profiles

```swift
import FoundationModels

let noteTaking = DynamicProfile(
    name: "note-taking",
    instructions: "Capture concise, well-structured notes from what the user describes.",
    tools: [NoteSaveTool()],
    model: .onDevice
)

let summarizer = DynamicProfile(
    name: "summarizer",
    instructions: "Summarize the notes gathered so far into three bullet points.",
    tools: [NoteFetchTool()],
    model: .privateCloudCompute
)

let translator = DynamicProfile(
    name: "translator",
    instructions: "Translate the provided summary into the user's preferred language.",
    tools: [],
    model: .server(.anthropic(model: "claude-sonnet"))
)
```

Each profile picks the cheapest or most capable model for its job — on-device for fast, private note capture; Private Cloud Compute for heavier summarization; a third-party server model for translation quality.

## Transitioning Mid-Session

```swift
let session = LanguageModelSession(initialProfile: noteTaking)

let r1 = try await session.respond(to: "Jot down: ship the v2 API by Friday")

try await session.transition(to: summarizer)
let r2 = try await session.respond(to: "Summarize today's notes")

try await session.transition(to: translator)
let r3 = try await session.respond(to: "Now in Spanish")
```

`transition(to:)` swaps instructions, tools, and the model target without discarding conversation history — `r3` can still reference what was captured under the `noteTaking` profile. This is the core win: continuity across roles instead of three disconnected sessions stitched together by your own state-passing code.

## Server-Side Model Targets

The `model` property on a profile accepts the same `ModelTarget` enum regardless of provider:

```swift
enum ModelTarget {
    case onDevice
    case privateCloudCompute
    case server(ServerProvider)
}
```

Anthropic and Google ship Swift packages that conform to `ServerProvider`, so swapping `.server(.anthropic(model: "claude-sonnet"))` for `.server(.gemini(model: "gemini-2.5"))` is a one-line change — no rewrites to prompts, tool definitions, or response parsing, since `@Generable` structured output works identically across targets.

## Adding Image Input

Profiles can also receive multimodal prompts. Image input ships with Vision-backed tools the model can invoke directly:

```swift
let prompt = Prompt {
    "What's written on this receipt, and what's the total?"
    Image(receiptPhoto)
}

let response = try await session.respond(to: prompt)
```

Apple bundles barcode and text-recognition tools alongside image input, so the model can call into Vision itself rather than your code pre-processing the image and stuffing OCR results into the prompt as text.

## Best Practices

- **Keep profiles single-purpose.** A profile that tries to take notes, summarize, and translate at once defeats the point — compose several narrow profiles instead.
- **Match the model target to the job.** Reserve server targets for tasks that genuinely need frontier-model quality; on-device and PCC stay faster and cheaper for everything else.
- **Reuse context deliberately.** `transition(to:)` keeps history by default — call `session.reset()` first if a new profile shouldn't see prior turns (e.g., switching users).
- **Treat `ServerProvider` as untrusted by default for sensitive data.** Route anything privacy-sensitive through `.onDevice` or `.privateCloudCompute` profiles only.
- **Test each profile's tool set in isolation** before wiring up transitions — a tool error inside a mid-workflow profile is harder to debug once several handoffs have occurred.

## References

- [What's new in the Foundation Models framework — WWDC26](https://developer.apple.com/videos/play/wwdc2026/241/)
- [WWDC26 Apple Intelligence guide](https://developer.apple.com/wwdc26/guides/apple-intelligence/)
- [Foundation Models | Apple Developer Documentation](https://developer.apple.com/documentation/FoundationModels)
