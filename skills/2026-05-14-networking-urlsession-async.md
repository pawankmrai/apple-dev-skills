---
topic: Networking with URLSession and async/await
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Networking with URLSession and async/await

URLSession is Apple's networking stack. Combined with Swift's async/await, it provides a clean, readable API for making HTTP requests, handling responses, and managing downloads.

## Basic GET Request

```swift
struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
}

func fetchUser(id: Int) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkError.invalidResponse
    }

    return try JSONDecoder().decode(User.self, from: data)
}
```

## POST with JSON Body

```swift
func createUser(_ user: User) async throws -> User {
    var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    request.httpBody = try encoder.encode(user)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...201).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(User.self, from: data)
}
```

## Building a Reusable API Client

```swift
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid response from server"
        case .httpError(let code, _): "HTTP error \(code)"
        case .decodingFailed(let error): "Decoding failed: \(error.localizedDescription)"
        }
    }
}

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
```

Usage:

```swift
let client = APIClient(baseURL: URL(string: "https://api.example.com")!)

let users: [User] = try await client.request(path: "/users")
let user: User = try await client.request(path: "/users", method: .post, body: newUser)
```

## Downloading Files with Progress

```swift
func downloadFile(from url: URL) -> AsyncThrowingStream<DownloadProgress, Error> {
    AsyncThrowingStream { continuation in
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            guard let localURL else {
                continuation.finish(throwing: NetworkError.invalidResponse)
                return
            }
            continuation.yield(.completed(localURL))
            continuation.finish()
        }

        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            continuation.yield(.inProgress(progress.fractionCompleted))
        }

        continuation.onTermination = { _ in
            observation.invalidate()
            task.cancel()
        }

        task.resume()
    }
}

enum DownloadProgress {
    case inProgress(Double)
    case completed(URL)
}
```

## Request Retry with Exponential Backoff

```swift
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: Duration = .seconds(1),
    operation: () async throws -> T
) async throws -> T {
    var delay = initialDelay
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            if attempt == maxAttempts { throw error }
            try await Task.sleep(for: delay)
            delay *= 2
        }
    }
    fatalError("Unreachable")
}

// Usage
let users: [User] = try await withRetry {
    try await client.request(path: "/users")
}
```

## Best Practices

- **Use `actor` for API clients** — this guarantees thread safety for shared mutable state like auth tokens.
- **Configure `JSONDecoder` once** — set `keyDecodingStrategy` and `dateDecodingStrategy` at init, not per-request.
- **Handle HTTP status codes explicitly** — don't assume every response is success. Map error codes to meaningful errors.
- **Use `async/await` over completion handlers** — it's more readable and integrates with structured concurrency (cancellation, task groups).
- **Cancel requests** when views disappear — use `.task` in SwiftUI, which cancels automatically.
- **Don't block the main thread** — all `URLSession.data(for:)` calls are already async; just make sure decoding heavy payloads happens off-main too.
- **Use `URLCache`** and HTTP caching headers to avoid redundant network calls.

## References

- [URLSession | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/urlsession)
- [Fetching website data into memory — Apple Developer](https://developer.apple.com/documentation/foundation/url_loading_system/fetching_website_data_into_memory)
