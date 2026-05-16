---
topic: Foundation Models Framework — On-Device AI in Swift
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Foundation Models Framework — On-Device AI in Swift

Apple's Foundation Models framework provides direct access to the on-device large language model powering Apple Intelligence. With a native Swift API, you can integrate text generation, structured output, and tool calling into your apps — all running locally with no network dependency.

## Getting Started

Import the framework and create a session to begin generating text:

```swift
import FoundationModels

let session = LanguageModelSession()

let response = try await session.respond(to: "Summarize the benefits of on-device AI")
print(response.content)
```

The session manages context across multiple turns, making conversational interactions straightforward.

## Structured Output with @Generable

The framework's most powerful feature is guided generation — getting structured Swift types back from the model using the `@Generable` macro:

```swift
import FoundationModels

@Generable
struct RecipeSuggestion {
    @Guide(description: "Name of the recipe")
    var name: String

    @Guide(description: "List of ingredients with quantities")
    var ingredients: [String]

    @Guide(description: "Estimated cooking time in minutes")
    var cookingTimeMinutes: Int

    @Guide(description: "Difficulty level: easy, medium, or hard")
    var difficulty: String
}

let session = LanguageModelSession()
let recipe: RecipeSuggestion = try await session.respond(
    to: "Suggest a quick pasta recipe",
    generating: RecipeSuggestion.self
)
print(recipe.name) // e.g., "Garlic Butter Linguine"
```

The compiler generates a schema from your type, and the model constrains its output to match.

## Streaming Responses

For real-time UI updates, stream partial results as the model generates:

```swift
let stream = session.streamResponse(to: "Write a haiku about Swift programming")

for try await partial in stream {
    // Update UI with each token
    textView.text = partial.content
}
```

## Tool Calling

Define tools that the model can invoke autonomously during generation:

```swift
@Tool
struct WeatherLookup {
    @Argument(description: "City name to check weather for")
    var city: String

    func call() async throws -> String {
        let weather = try await WeatherService.current(for: city)
        return "\(city): \(weather.temperature)°F, \(weather.condition)"
    }
}

let session = LanguageModelSession(tools: [WeatherLookup()])
let response = try await session.respond(
    to: "What's the weather like in San Francisco today?"
)
```

The model decides when to call your tool and incorporates the result into its response.

## Managing Sessions and Context

Sessions maintain conversational history. You can configure context limits and system instructions:

```swift
let instructions = "You are a helpful cooking assistant. Keep responses concise."

let session = LanguageModelSession(
    instructions: instructions
)

// Multi-turn conversation
let r1 = try await session.respond(to: "What's a good dinner for two?")
let r2 = try await session.respond(to: "Make it vegetarian")
// r2 has context from r1
```

## Best Practices

- **Check availability** before using the framework — it requires Apple Intelligence-capable hardware (A17 Pro or later, M1 or later).
- **Use structured output** (`@Generable`) whenever you need to parse model responses programmatically. It eliminates fragile string parsing.
- **Stream for UX** — always prefer streaming for user-facing text to reduce perceived latency.
- **Keep prompts focused** — the on-device model (3B parameters) works best with specific, constrained tasks rather than open-ended creative generation.
- **Leverage tools** for dynamic data — rather than stuffing context with information, let the model call tools to fetch what it needs.
- **Handle errors gracefully** — model generation can fail if the device is under resource pressure. Always use try/catch.

## Availability Check

```swift
import FoundationModels

if LanguageModelSession.isAvailable {
    // Proceed with model features
} else {
    // Fall back to alternative UX
}
```

## References

- [Foundation Models | Apple Developer Documentation](https://developer.apple.com/documentation/FoundationModels)
- [Meet the Foundation Models framework — WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Deep dive into the Foundation Models framework — WWDC25](https://developer.apple.com/videos/play/wwdc2025/301/)
- [Code-along: Bring on-device AI to your app — WWDC25](https://developer.apple.com/videos/play/wwdc2025/259/)
