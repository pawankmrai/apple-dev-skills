---
topic: SwiftUI AsyncImage — HTTP Caching, URLRequest, and Custom URLSession
date: 2026-07-02
platform: iOS 27
swift: "6.2"
difficulty: intermediate
---

# SwiftUI AsyncImage — HTTP Caching, URLRequest, and Custom URLSession

Since iOS 15, `AsyncImage` has been a convenient way to load a remote image, but it offered almost no control over the request or the session behind it — no custom headers, no cache policy, no shared `URLCache`. iOS 27 closes those gaps. `AsyncImage` now respects standard HTTP caching automatically, accepts a `URLRequest` in place of a bare `URL`, and can be pointed at a custom `URLSession` for an entire view subtree.

## Automatic HTTP Caching

No code changes are required to get this: if your server sends `Cache-Control` or `ETag` headers, `AsyncImage` now honors them the way `URLSession` always has. An image that was already fetched can be served from cache on a second appearance instead of being re-downloaded, as long as the response headers allow it.

```swift
// Nothing to opt into — this now caches per standard HTTP semantics.
AsyncImage(url: URL(string: "https://example.com/avatar.png"))
```

If your backend doesn't send cache headers, this has no effect — that's what the `URLRequest` and custom `URLSession` APIs below are for.

## Loading with a URLRequest

`init(request:scale:)` takes a `URLRequest` instead of a `URL`, so you can set headers, a cache policy, and a timeout without writing a custom image loader. This is the key unlock for authenticated image endpoints.

```swift
struct ThumbnailView: View {
    let imageURL: URL
    let accessToken: String

    var request: URLRequest {
        var request = URLRequest(
            url: imageURL,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 15
        )
        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )
        return request
    }

    var body: some View {
        AsyncImage(request: request)
    }
}
```

The request-based initializer has the same content/placeholder overload as the URL-based one:

```swift
AsyncImage(request: request) { image in
    image
        .resizable()
        .scaledToFill()
} placeholder: {
    ProgressView()
}
.frame(width: 120, height: 120)
.clipShape(.rect(cornerRadius: 16))
```

`request` is optional in this form — pass `nil` and `AsyncImage` stays on the placeholder without starting a load, which is handy when a URL depends on state that hasn't resolved yet.

## Responding to Loading Phases

For UI that needs to distinguish "still loading" from "failed", use the phase-based initializer, `init(request:scale:transaction:content:)`:

```swift
AsyncImage(
    request: request,
    transaction: Transaction(animation: .easeInOut)
) { phase in
    switch phase {
    case .empty:
        ProgressView()

    case let .success(image):
        image
            .resizable()
            .scaledToFit()
            .transition(.opacity)

    case .failure:
        ContentUnavailableView(
            "Image unavailable",
            systemImage: "photo.badge.exclamationmark"
        )

    @unknown default:
        EmptyView()
    }
}
```

The phase is `.empty` while the request is `nil` or in flight, and moves to `.success` or `.failure` on completion. The `Transaction` controls the animation applied to that phase change.

## Providing a Custom URLSession

When a group of images should share networking configuration — the same cache size, the same auth handling — attach a `URLSession` to an entire subtree with the new `asyncImageURLSession(_:)` modifier instead of configuring each request individually.

```swift
enum ImageSessions {
    static let gallery: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: configuration)
    }()
}

struct ImageGallery: View {
    let imageURLs: [URL]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))]) {
                ForEach(imageURLs, id: \.self) { url in
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 120)
                    .clipShape(.rect(cornerRadius: 16))
                }
            }
        }
        .asyncImageURLSession(ImageSessions.gallery)
    }
}
```

Every `AsyncImage` inside the modified view — whether URL-based or request-based — uses the supplied session for its download task, so shared cache sizing and per-request headers can be combined freely.

## Best Practices

Set an explicit `URLCache` on any custom session used for image galleries; the system default is small and will evict images sooner than you'd expect on image-heavy screens. Prefer `.returnCacheDataElseLoad` for content that rarely changes (avatars, thumbnails) and `.useProtocolCachePolicy` when you want the server's headers to be the source of truth. Keep authenticated requests on `init(request:)` rather than embedding tokens in query strings — headers don't get logged or cached as part of the URL. Apply `asyncImageURLSession(_:)` at the container level (a list, grid, or gallery) rather than per-image so cache configuration stays in one place. Always handle `.failure` explicitly with `ContentUnavailableView` or similar; the default placeholder-on-failure behavior of the simple initializers is easy to miss during code review.

## References

- [AsyncImage improvements in iOS 27 — Natalia Panferova](https://nilcoalescing.com/blog/AsyncImageImprovementsInSwiftUIOnIOS27/)
- [AsyncImage — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/asyncimage)
- [asyncImageURLSession(_:) — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/view/asyncimageurlsession%28_%3A%29)
- [What's New in SwiftUI — WWDC26 Guide](https://developer.apple.com/wwdc26/guides/swiftui/)
