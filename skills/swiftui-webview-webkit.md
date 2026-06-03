---
topic: SwiftUI WebView — Native Web Content with WebKit
date: 2026-06-03
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI WebView — Native Web Content with WebKit

Starting with iOS 26 and macOS 26, Apple provides a first-class SwiftUI API for embedding web content. The new `WebView` and `WebPage` types from the WebKit framework replace the need for `UIViewRepresentable` wrappers around `WKWebView`, bringing web integration fully into the declarative SwiftUI world.

## Getting Started

The simplest usage requires just a URL:

```swift
import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebView(url: URL(string: "https://developer.apple.com")!)
    }
}
```

For anything beyond basic display, pair `WebView` with the `WebPage` observable model:

```swift
struct ArticleView: View {
    @State private var page = WebPage()

    var body: some View {
        NavigationStack {
            WebView(webPage: page)
                .navigationTitle(page.title ?? "Loading…")
                .onAppear {
                    page.load(URLRequest(url: articleURL))
                }
        }
    }
}
```

Because `WebPage` conforms to `Observable`, any SwiftUI view that reads its properties — `title`, `url`, `isLoading`, `estimatedProgress` — re-renders automatically when the page state changes.

## Loading Content

`WebPage` supports several loading strategies beyond remote URLs:

```swift
// Load inline HTML
page.load(html: "<h1>Hello</h1>", baseURL: URL(string: "https://example.com"))

// Load raw data with a MIME type
page.load(
    data: archiveData,
    mimeType: "application/x-webarchive",
    characterEncodingName: "utf-8",
    baseURL: baseURL
)
```

## Custom URL Scheme Handlers

You can register handlers for custom URL schemes to serve bundled or dynamically generated content:

```swift
struct AppSchemeHandler: URLSchemeHandler {
    func reply(to request: URLRequest) -> AsyncSequence<URLSchemeTaskResult> {
        AsyncStream { continuation in
            let response = URLResponse(
                url: request.url!,
                mimeType: "text/html",
                expectedContentLength: -1,
                textEncodingName: "utf-8"
            )
            continuation.yield(.response(response))

            if let data = loadBundledHTML(for: request.url!) {
                continuation.yield(.data(data))
            }
            continuation.finish()
        }
    }
}

// Register at configuration time
let config = WebPage.Configuration()
config.urlSchemeHandlers[URLScheme("myapp")!] = AppSchemeHandler()
let page = WebPage(configuration: config)
```

## Navigation Events

React to page lifecycle events through the observable `currentNavigationEvent` property:

```swift
for await event in page.currentNavigationEvent.values {
    switch event {
    case .startedProvisionalNavigation:
        isLoading = true
    case .finished:
        isLoading = false
    case .failed(let error):
        handleError(error)
    default:
        break
    }
}
```

## Navigation Policies

Control which navigations are allowed with `NavigationDeciding`:

```swift
struct InternalOnlyNavigator: WebPage.NavigationDeciding {
    func policy(
        for action: NavigationAction,
        preferences: inout NavigationPreferences
    ) -> NavigationActionPolicy {
        guard let host = action.request.url?.host else { return .cancel }
        return host.hasSuffix("myapp.com") ? .allow : .cancel
    }
}
```

## JavaScript Communication

Call JavaScript and receive results using Swift concurrency:

```swift
// Read a value
let title = await page.callJavaScript("document.title") as? String

// Pass arguments safely
let headings = await page.callJavaScript("""
    Array.from(document.querySelectorAll(selector))
         .map(h => ({ id: h.id, text: h.textContent }))
""", arguments: ["selector": "h2"]) as? [[String: String]]
```

## View Modifiers

WebKit for SwiftUI ships with purpose-built modifiers:

```swift
WebView(webPage: page)
    // Built-in find-in-page UI
    .findNavigator(isPresented: $showFind)
    // Programmatic scroll position
    .webViewScrollPosition($scrollPosition)
```

On visionOS, enable look-to-scroll for hands-free browsing:

```swift
WebView(webPage: page)
    .webViewScrollInputBehavior(.enabled, for: .look)
```

## Best Practices

- **Configure once.** Set URL scheme handlers and navigation policies when creating `WebPage.Configuration`, not after loading begins.
- **Use `WebPage` for any non-trivial usage.** The URL-only `WebView` initializer is convenient for previews but lacks control over navigation, JavaScript, and loading state.
- **Prefer `callJavaScript` arguments over string interpolation.** Passing data through the `arguments` parameter avoids injection risks and improves performance.
- **Handle navigation events.** Always provide loading indicators and error handling — web content can fail in ways native views cannot.
- **Migrate incrementally.** If you have an existing `UIViewRepresentable` wrapper around `WKWebView`, you can adopt `WebView` screen-by-screen since both coexist in the same app.

## References

- [Meet WebKit for SwiftUI — WWDC25](https://developer.apple.com/videos/play/wwdc2025/231/)
- [What's New in SwiftUI — WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/)
- [WebKit for SwiftUI Documentation](https://developer.apple.com/documentation/webkit/webview)
- [Hacking with Swift — How to Embed Web Content Using WebView](https://www.hackingwithswift.com/quick-start/swiftui/how-to-embed-web-content-using-webview)
