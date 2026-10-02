---
topic: SwiftUI Focus Management — @FocusState, defaultFocus, and Keyboard Navigation
date: 2026-10-02
platform: iOS 26, iPadOS 26, macOS 26, tvOS 26
swift: "6.2"
difficulty: intermediate
---

# SwiftUI Focus Management — @FocusState, defaultFocus, and Keyboard Navigation

Focus decides which view receives keyboard input, which control the Siri Remote highlights, and where VoiceOver and hardware-keyboard users land. SwiftUI gives you a declarative focus system: `@FocusState` to read and drive focus, `defaultFocus` for initial placement, `focusable(interactions:)` for custom controls, `onKeyPress` for key handling, and `@FocusedValue` so menu commands can act on whatever is focused. With iPad windowing and hardware keyboards now common, getting focus right is a core usability requirement.

## Modelling Focus with an Enum

Use an optional `Hashable` enum rather than several `Bool`s — only one field can be focused, and `nil` means "dismiss the keyboard".

```swift
struct SignUpForm: View {
    enum Field: Hashable { case name, email, password }

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focused: Field?

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .focused($focused, equals: .name)
                .submitLabel(.next)
            TextField("Email", text: $email)
                .focused($focused, equals: .email)
                .keyboardType(.emailAddress)
                .submitLabel(.next)
            SecureField("Password", text: $password)
                .focused($focused, equals: .password)
                .submitLabel(.done)
        }
        .onSubmit(advance)
        .defaultFocus($focused, .name)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
            }
        }
    }

    private func advance() {
        switch focused {
        case .name:     focused = .email
        case .email:    focused = .password
        default:        focused = nil   // dismiss keyboard, then submit
        }
    }
}
```

`defaultFocus` is preferred over setting focus in `onAppear`, which races with presentation and often silently fails inside sheets.

## Custom Focusable Controls and Key Presses

Non-text views can join the focus system. `interactions: .activate` makes a view behave like a button (Tab/Space on macOS and iPad), while `.edit` is for views that capture typing.

```swift
struct RatingControl: View {
    @Binding var rating: Int
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
            }
        }
        .padding(6)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 2))
        .focusable(interactions: .edit)
        .focused($isFocused)
        .focusEffectDisabled()          // we draw our own ring
        .onKeyPress(.rightArrow) { rating = min(rating + 1, 5); return .handled }
        .onKeyPress(.leftArrow)  { rating = max(rating - 1, 1); return .handled }
        .onKeyPress(characters: .decimalDigits) { press in
            guard let value = Int(press.characters), (1...5).contains(value) else { return .ignored }
            rating = value
            return .handled
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) of 5")
        .accessibilityAdjustableAction { direction in
            rating = direction == .increment ? min(rating + 1, 5) : max(rating - 1, 1)
        }
    }
}
```

Return `.ignored` for keys you don't consume so they continue up the hierarchy.

## Exposing the Focused Item to Commands

`@FocusedValue` lets app-level menus and keyboard shortcuts operate on the focused scene's selection. Declare the key with `@Entry` on `FocusedValues`.

```swift
extension FocusedValues {
    @Entry var selectedNote: Binding<Note>?
}

struct NoteDetail: View {
    @Binding var note: Note
    var body: some View {
        TextEditor(text: $note.body)
            .focusedSceneValue(\.selectedNote, $note)
    }
}

struct NoteCommands: Commands {
    @FocusedValue(\.selectedNote) private var note

    var body: some Commands {
        CommandMenu("Note") {
            Button("Toggle Pin") { note?.wrappedValue.isPinned.toggle() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(note == nil)
        }
    }
}
```

Use `focusedSceneValue` when the command should work regardless of which control inside the window has focus; use `focusedValue` when it should only apply while that specific view is focused.

## Best Practices

- Model focus as one optional enum per screen; `nil` dismisses the keyboard. On validation failure, move focus to the first invalid field.
- Prefer `defaultFocus` over `onAppear { focused = ... }`; if you must set it later, do it after presentation completes.
- Pair `.submitLabel` with `.onSubmit` so Return advances logically through the form.
- Always offer a way to dismiss the keyboard: a keyboard toolbar button or `.scrollDismissesKeyboard`.
- If you disable the system focus effect, draw a clearly visible replacement — never leave focus invisible.
- Give custom focusable controls accessibility labels, values, and adjustable actions to match their key handling.
- On tvOS and macOS, wrap misaligned columns in `focusSection()` so directional movement lands sensibly.
- Test with a hardware keyboard (Tab, arrows, Return, Escape) on iPad and with Full Keyboard Access enabled.

## References

- [FocusState — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/focusstate)
- [defaultFocus(_:_:priority:)](https://developer.apple.com/documentation/swiftui/view/defaultfocus(_:_:priority:))
- [The SwiftUI cookbook for focus — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10162/)
- [FocusedValues](https://developer.apple.com/documentation/swiftui/focusedvalues)
