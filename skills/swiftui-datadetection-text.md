---
topic: SwiftUI DataDetection — Turning Text into Tappable Phone Numbers, Dates, and Addresses
date: 2026-08-05
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: intermediate
---

# SwiftUI DataDetection — Turning Text into Tappable Phone Numbers, Dates, and Addresses

`UITextView` and `NSTextView` have offered automatic data detectors — phone numbers, links, dates, addresses — since long before SwiftUI existed, but `Text` never got the same treatment. Any app that wanted a tappable phone number or an "add to Calendar" date inside a `Text` view had to hand-roll its own regex matching and tap targets, or drop down to a `UIViewRepresentable` wrapper around `UITextView` just to get detector behavior on a few lines of copy. iOS 27 ships a new `DataDetection` framework that brings the same detectors to native SwiftUI `Text`, with a Swift-first API for reading matches and reacting to taps.

## Enabling Detection on Text

Import `DataDetection` and apply the `dataDetection(types:)` modifier to any `Text` view. Detected substrings render with the system's standard highlight style and become tappable automatically:

```swift
import SwiftUI
import DataDetection

struct MessageBubble: View {
    let message: String

    var body: some View {
        Text(message)
            .dataDetection(types: [.phoneNumber, .link, .calendarDate, .postalAddress])
    }
}
```

No closures, no state — for the common case of "make phone numbers dial and addresses open in Maps," this one modifier is the entire implementation.

## Reading Matches Before They Render

Sometimes you need to know *what* was detected before deciding how to present it — for example, to show a badge count of upcoming dates in a message, or to skip detection on text you've already linkified yourself. `DataDetector` exposes a synchronous scan that returns typed matches:

```swift
import DataDetection

func upcomingDateCount(in text: String) -> Int {
    let detector = DataDetector(types: [.calendarDate])
    let matches = detector.matches(in: text)
    return matches.filter { match in
        if case .calendarDate(let date) = match.kind {
            return date > .now
        }
        return false
    }.count
}
```

`DataDetector.Match` wraps a `kind` enum (`.phoneNumber`, `.link`, `.calendarDate`, `.postalAddress`, `.trackingNumber`, `.flightNumber`) alongside the matched `range` in the source string, so you can cross-reference detected spans against your own `AttributedString` styling.

## Custom Tap Handling

The default modifier opens the system handler for each type — dialer for phone numbers, Maps for addresses, Calendar for dates. To intercept taps yourself, use `onDataDetectorTap`:

```swift
struct ReceiptRow: View {
    let line: String
    @State private var trackedPackage: String?

    var body: some View {
        Text(line)
            .dataDetection(types: [.trackingNumber, .link])
            .onDataDetectorTap { match in
                switch match.kind {
                case .trackingNumber(let number):
                    trackedPackage = number
                default:
                    return .systemDefault
                }
                return .handled
            }
            .sheet(item: Binding(
                get: { trackedPackage.map { PackageID(value: $0) } },
                set: { trackedPackage = $0?.value }
            )) { package in
                TrackingDetailView(trackingNumber: package.value)
            }
    }
}

struct PackageID: Identifiable { var value: String; var id: String { value } }
```

Returning `.handled` suppresses the system action; returning `.systemDefault` falls through to the same behavior as the plain `dataDetection(types:)` modifier, so you can intercept only the types you care about and let everything else behave normally.

## Combining with AttributedString

`DataDetection` composes with `AttributedString` rather than replacing it. If you're already building styled text, run detection over the plain string first and merge the results into your attribute runs:

```swift
func styledMessage(_ raw: String) -> AttributedString {
    var attributed = AttributedString(raw)
    let detector = DataDetector(types: [.link, .phoneNumber])
    for match in detector.matches(in: raw) {
        if let range = Range(match.range, in: attributed) {
            attributed[range].foregroundColor = .accentColor
            attributed[range].underlineStyle = .single
        }
    }
    return attributed
}
```

This is the pattern to reach for when detected spans need custom colors, fonts, or accessibility labels beyond the system's default highlight.

## Performance Notes

`DataDetector.matches(in:)` runs synchronously and scales with string length, not view count — cache results keyed by the source string rather than recomputing on every body evaluation. For chat-style lists with hundreds of messages, detect once when a message is received or decoded, store the matches (or a pre-built `AttributedString`) on the model, and let `Text` render from that rather than re-scanning on each scroll pass.

```swift
struct ChatMessage {
    let id: UUID
    let rawText: String
    let styledText: AttributedString

    init(id: UUID = UUID(), rawText: String) {
        self.id = id
        self.rawText = rawText
        self.styledText = ChatMessage.styledMessage(rawText)
    }
}
```

## Best Practices

Scope `types:` to what the surface actually needs — detecting `.postalAddress` on a chat bubble that never contains addresses just spends cycles highlighting nobody will tap.

Prefer the plain `dataDetection(types:)` modifier over `onDataDetectorTap` until you have a concrete reason to override system behavior; the built-in handlers already do the right platform-appropriate thing (dial, open in Maps, create a Calendar event).

Precompute matches for any text that's rendered repeatedly — list rows, chat bubbles, feed items — instead of calling `DataDetector.matches(in:)` inside `body`.

Don't run detection on text the user is actively editing; apply `dataDetection(types:)` to `Text` display views, not to the live contents of a `TextField` or `TextEditor`, where highlighting would fight the cursor and selection.

Test detector coverage against real user content in each supported locale — date and address formats vary by region, and a detector tuned for US phone numbers won't automatically catch every international format.

## References

- [What's new in SwiftUI — WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/)
- [DataDetection framework — Apple Developer Documentation](https://developer.apple.com/documentation/datadetection)
- [NSDataDetector — Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsdatadetector)
- [Fatbobman's Swift Weekly #139 — First Impressions of WWDC 2026](https://fatbobman.com/en/weekly/issue-139/)
