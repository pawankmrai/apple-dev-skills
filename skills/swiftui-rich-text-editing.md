---
topic: SwiftUI Rich Text Editing with TextEditor and AttributedString
date: 2026-05-27
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI Rich Text Editing with TextEditor and AttributedString

Starting with iOS 26, SwiftUI's `TextEditor` gained first-class support for `AttributedString`, enabling rich text editing natively. Combined with `AttributedTextSelection` and `FontResolutionContext`, you can build fully featured text editors with bold, italic, colors, and links — all in pure SwiftUI.

## Enabling Rich Text Editing

Bind `TextEditor` to an `AttributedString` instead of a plain `String`:

```swift
struct RichTextEditor: View {
    @State private var text: AttributedString = "Start typing here..."

    var body: some View {
        TextEditor(text: $text)
    }
}
```

This single change enables built-in formatting shortcuts (⌘B for bold, ⌘I for italic) and menu controls automatically.

## Building Attributed Strings Programmatically

Construct styled text by combining `AttributedString` instances:

```swift
func buildGreeting() -> AttributedString {
    var greeting = AttributedString("Welcome ")
    var name = AttributedString("Developer")
    name.font = .title.bold()
    name.foregroundColor = .blue
    greeting.append(name)
    greeting += AttributedString("!")
    return greeting
}
```

`AttributedString` also parses Markdown natively:

```swift
let styled = try AttributedString(
    markdown: "**Bold** and *italic* with a [link](https://developer.apple.com)."
)
```

## Tracking Selection

To inspect or modify formatting at the cursor, bind an `AttributedTextSelection`:

```swift
struct SelectableEditor: View {
    @State private var text: AttributedString = "Select some text."
    @State private var selection = AttributedTextSelection()

    var body: some View {
        TextEditor(text: $text, selection: $selection)
    }
}
```

## Building a Formatting Toolbar

Combine selection tracking with `transformAttributes` and `FontResolutionContext` for interactive controls:

```swift
struct FormattableEditor: View {
    @State private var text: AttributedString = "Format me!"
    @State private var selection = AttributedTextSelection()
    @Environment(\.fontResolutionContext) private var fontContext

    var body: some View {
        VStack {
            HStack {
                Toggle("B", systemImage: "bold", isOn: boldBinding)
                    .toggleStyle(.button)
                Toggle("I", systemImage: "italic", isOn: italicBinding)
                    .toggleStyle(.button)
            }
            .padding(.horizontal)
            TextEditor(text: $text, selection: $selection)
        }
    }

    private var boldBinding: Binding<Bool> {
        Binding(
            get: {
                let font = selection.typingAttributes(in: text).font
                return (font ?? .default).resolve(in: fontContext).isBold
            },
            set: { isBold in
                text.transformAttributes(in: &selection) {
                    $0.font = ($0.font ?? .default).bold(isBold)
                }
            }
        )
    }

    private var italicBinding: Binding<Bool> {
        Binding(
            get: {
                let font = selection.typingAttributes(in: text).font
                return (font ?? .default).resolve(in: fontContext).isItalic
            },
            set: { isItalic in
                text.transformAttributes(in: &selection) {
                    $0.font = ($0.font ?? .default).italic(isItalic)
                }
            }
        )
    }
}
```

`FontResolutionContext` resolves adaptive SwiftUI fonts into concrete values, ensuring your toolbar state matches what the user sees — including Dynamic Type and accessibility settings.

## Applying Multiple Attributes

The `transformAttributes` closure gives full control over an `AttributeContainer`:

```swift
text.transformAttributes(in: &selection) { attributes in
    attributes.foregroundColor = .white
    attributes.backgroundColor = .systemBlue
    attributes.font = .system(size: 16, weight: .semibold, design: .rounded)
    attributes.underlineStyle = .single
}
```

The `selection` is passed as `inout` — SwiftUI adjusts ranges automatically when attribute runs merge or split.

## Best Practices

- **Start simple.** Switching from `String` to `AttributedString` enables rich text with zero extra code — add toolbar controls incrementally.
- **Use `FontResolutionContext`.** Always resolve fonts through the environment to respect Dynamic Type and accessibility preferences.
- **Pass selection as `inout`.** The `transformAttributes(in:)` method requires `&selection` so SwiftUI can adjust ranges when attribute runs merge.
- **Leverage Markdown parsing.** Use `AttributedString(markdown:)` to handle formatted content from APIs without manual attribute setup.
- **Test with accessibility.** Verify your editor works with VoiceOver and different Dynamic Type sizes.

## References

- [TextEditor — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/texteditor)
- [Building rich SwiftUI text experiences — Apple Developer](https://developer.apple.com/documentation/swiftui/building-rich-swiftui-text-experiences)
- [WWDC25 Session 280: Cook up a rich text experience in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/280/)
