---
topic: Combine and the Observation Framework
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Combine and the Observation Framework

Apple provides two approaches to reactive programming: the Combine framework (introduced in 2019) and the newer Observation framework (introduced in 2023). Understanding both — and when to use each — is key to modern Apple development.

## The Observation Framework (@Observable)

The `@Observable` macro is the modern, recommended way to make objects observable in SwiftUI:

```swift
import Observation

@Observable
class WeatherViewModel {
    var temperature: Double = 0
    var condition: String = "Unknown"
    var isLoading = false
    var errorMessage: String?

    func refresh(for city: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let weather = try await WeatherService.fetch(city: city)
            temperature = weather.temperature
            condition = weather.condition
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

Use it in SwiftUI with no property wrapper needed:

```swift
struct WeatherView: View {
    var viewModel: WeatherViewModel

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Text("\(viewModel.temperature, specifier: "%.1f")°")
                    .font(.largeTitle)
                Text(viewModel.condition)
            }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .task {
            await viewModel.refresh(for: "San Francisco")
        }
    }
}
```

SwiftUI tracks which properties each view actually reads and only re-renders when those specific properties change.

## Tracking Changes with withObservationTracking

Outside SwiftUI, use `withObservationTracking` to observe changes:

```swift
let model = WeatherViewModel()

withObservationTracking {
    print(model.temperature) // registers access
} onChange: {
    print("Temperature changed!")
}
```

The `onChange` closure fires once the next time any tracked property changes. Re-register to keep observing.

## Combine Basics

Combine is a publisher-subscriber framework for processing values over time:

```swift
import Combine

class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .flatMap { query in
                SearchService.search(query: query)
                    .catch { _ in Just([]) }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$results)
    }
}
```

## Common Combine Operators

```swift
// Transform values
publisher.map { $0.uppercased() }

// Filter values
publisher.filter { $0.count > 3 }

// Combine latest values from two publishers
Publishers.CombineLatest(namePublisher, agePublisher)
    .map { name, age in "\(name), \(age)" }

// Merge multiple publishers into one stream
Publishers.Merge(localResults, remoteResults)

// Handle errors
publisher
    .retry(3)
    .catch { error in Just(fallbackValue) }
```

## Combine with async/await

Bridge Combine publishers into Swift concurrency:

```swift
// Publisher to async sequence
for await value in publisher.values {
    print(value)
}

// Single value from a publisher
let result = try await publisher
    .first()
    .values
    .first(where: { _ in true })
```

## When to Use Which

### Use @Observable when:
- Building SwiftUI views that react to model changes
- You want the simplest possible observation with minimal boilerplate
- You're starting a new project or migrating from `ObservableObject`

### Use Combine when:
- You need complex event stream processing (debounce, throttle, merge, combineLatest)
- Working with time-based operations or event composition
- Integrating with APIs that already return publishers (e.g., `NotificationCenter.publisher`)
- Processing sequences of values with backpressure

```swift
// Observation for simple data flow
@Observable
class UserProfile {
    var name = ""
    var avatar: UIImage?
}

// Combine for complex event processing
class RealTimeSearchController {
    private var cancellables = Set<AnyCancellable>()

    func setupSearch(textField: UITextField) {
        NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: textField)
            .compactMap { ($0.object as? UITextField)?.text }
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { query in
                self.performSearch(query)
            }
            .store(in: &cancellables)
    }
}
```

## Best Practices

- **Default to `@Observable`** for SwiftUI data models — it's simpler and more efficient than `ObservableObject`.
- **Use Combine for event streams** — it excels at time-based operators like `debounce`, `throttle`, and `combineLatest`.
- **Don't mix unnecessarily** — pick one approach per model. Don't make a class both `@Observable` and `ObservableObject`.
- **Cancel subscriptions** — always store `AnyCancellable` tokens and let them clean up. Leaked subscriptions cause retain cycles.
- **Prefer `async/await` over Combine** for one-shot async operations — it's simpler and more readable.
- **Use `.values`** to bridge Combine into async/await when needed.

## References

- [Observation | Apple Developer Documentation](https://developer.apple.com/documentation/observation)
- [Combine | Apple Developer Documentation](https://developer.apple.com/documentation/combine)
- [Discover Observation in SwiftUI — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10149/)
