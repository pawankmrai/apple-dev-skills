---
topic: String Catalogs — Modern Localization in Swift
date: 2026-06-01
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# String Catalogs — Modern Localization in Swift

String Catalogs (`.xcstrings`) replace the legacy `Localizable.strings` and `.stringsdict` files with a single, unified localization workflow. Introduced in Xcode 15 and refined through Xcode 26, they automatically discover localizable strings from your code after each build, eliminating manual key management.

## Setting Up a String Catalog

Add a new **String Catalog** file to your target via File → New → File → String Catalog. Name it `Localizable.xcstrings`. Once added, Xcode extracts every `LocalizedStringKey`, `LocalizedStringResource`, and `String(localized:)` call it finds during compilation.

```swift
// These are all automatically picked up by the String Catalog
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to the app")          // LocalizedStringKey literal
            Text("item_count", tableName: "Shop") // Explicit table
            Button("Sign In") { signIn() }       // Button label
        }
    }
}
```

No manual key registration is required — build once and the keys appear in the catalog editor.

## Using String(localized:) in Code

For non-View contexts, use `String(localized:)` instead of `NSLocalizedString`:

```swift
func greetUser(name: String) -> String {
    String(localized: "Hello, \(name)! Welcome back.",
           comment: "Greeting shown after login with the user's first name")
}
```

The `comment` parameter appears in the String Catalog editor, giving translators essential context.

## Pluralization and String Variation

String Catalogs handle pluralization natively — no `.stringsdict` needed. In the catalog editor, select a key, click **Vary by Plural**, and provide forms for each grammatical number:

```swift
func unreadLabel(count: Int) -> String {
    String(localized: "\(count) unread messages",
           comment: "Badge label for unread message count")
}
```

In the catalog, you define variations:

| Plural Category | Value |
|----------------|-------|
| one            | 1 unread message |
| other          | %lld unread messages |

Xcode substitutes the correct form at runtime based on the user's locale.

## Device and Width Variations

Beyond plurals, String Catalogs support **device** variations (iPhone vs iPad vs Mac vs Apple Watch) and **width** variations for adaptive layouts:

```swift
// The catalog can hold different translations per device class
Text("Get started with your project")
```

In the editor, click **Vary by Device** to provide shorter copy for Apple Watch and longer copy for iPad.

## Localizing Swift Packages

As of Xcode 26, String Catalogs work seamlessly with Swift Packages using the updated 1.1 catalog format:

```swift
// Package.swift
let package = Package(
    name: "SharedUI",
    defaultLocalization: "en",
    targets: [
        .target(
            name: "SharedUI",
            resources: [.process("Resources")]
        )
    ]
)
```

Place your `Localizable.xcstrings` inside the target's `Resources` directory. Xcode 26 resolves previous issues with string extraction across package boundaries.

## Migrating from Localizable.strings

Xcode offers a one-click migration: right-click your existing `.strings` or `.stringsdict` file and choose **Migrate to String Catalog**. The migrator preserves all existing translations and converts pluralization rules automatically.

```swift
// Before (legacy)
// Localizable.strings:  "welcome_title" = "Welcome";
// After (String Catalog handles it automatically)
Text("Welcome")  // Key is the literal string itself
```

## Extracting and Exporting for Translators

Use Xcode's **Product → Export Localizations** to generate `.xcloc` bundles that translators can open in Xcode or any XLIFF-compatible tool. After translation, import back via **Product → Import Localizations**.

```bash
# Command-line export
xcodebuild -exportLocalizations -project MyApp.xcodeproj \
    -localizationPath ./Localizations
```

## Best Practices

- **Use string literals as keys** in SwiftUI — they read naturally and reduce indirection compared to opaque key names.
- **Always add comments** to `String(localized:)` calls so translators understand the context.
- **Build frequently** — the catalog only discovers new strings after a successful build.
- **Review the catalog's state column** — it flags untranslated, stale, or needs-review strings with clear indicators.
- **Leverage pluralization** through the catalog editor rather than writing conditional logic in code.
- **Test with pseudo-languages** — enable double-length pseudo-language in the scheme editor to catch layout issues before real translations arrive.

## References

- [Localizing and Varying Text with a String Catalog — Apple Documentation](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Code-along: Explore Localization with Xcode — WWDC25](https://developer.apple.com/videos/play/wwdc2025/225/)
- [String Catalogs in Swift Packages — Daniel Saidi](https://danielsaidi.com/blog/2025/12/02/a-better-way-to-localize-swift-packages-with-xcode-string-catalogs)
