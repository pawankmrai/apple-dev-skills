---
topic: "Swift Macros — Compile-Time Code Generation"
date: 2026-05-28
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Macros — Compile-Time Code Generation

Swift macros let you generate repetitive code at compile time, eliminating boilerplate while preserving full type safety. Unlike C preprocessor macros, Swift macros operate on the syntax tree and produce code that the compiler validates just like hand-written source. They power key APIs such as `@Observable`, `#Predicate`, and `@Test`.

## Freestanding Macros

Freestanding macros begin with `#` and expand inline. The simplest example is the built-in `#warning` macro, but you can create your own.

```swift
// A freestanding expression macro that builds a URL at compile time,
// producing a compiler error if the string is malformed.
let url = #URL("https://developer.apple.com/swift")
```

To define `#URL`, create a macro declaration and its implementation:

```swift
// Declaration (in your main target)
@freestanding(expression)
public macro URL(_ stringLiteral: String) -> URL =
    #externalMacro(module: "MyMacros", type: "URLMacro")
```

```swift
// Implementation (in a compiler-plugin target)
import SwiftSyntax
import SwiftSyntaxMacros

public struct URLMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression,
              let literal = argument.as(StringLiteralExprSyntax.self),
              let segment = literal.segments.first?.as(
                  StringSegmentSyntax.self
              ) else {
            throw MacroError.requiresStringLiteral
        }

        let urlString = segment.content.text
        guard URL(string: urlString) != nil else {
            throw MacroError.invalidURL(urlString)
        }

        return "URL(string: \(literal))!"
    }
}
```

## Attached Macros

Attached macros begin with `@` and modify the declaration they are attached to. Apple's `@Observable` is the most prominent example, but you can build your own.

```swift
// A peer macro that generates a mock for a protocol
@GenerateMock
protocol NetworkService {
    func fetchUser(id: Int) async throws -> User
    func updateProfile(_ profile: Profile) async throws
}

// Expands to:
// class MockNetworkService: NetworkService {
//     var fetchUserHandler: ((Int) async throws -> User)?
//     func fetchUser(id: Int) async throws -> User { ... }
//     var updateProfileHandler: ((Profile) async throws -> Void)?
//     func updateProfile(_ profile: Profile) async throws { ... }
// }
```

### Attached Macro Roles

Macros declare one or more roles that determine where their expansion appears:

```swift
// @attached(member)       — adds new members inside a type
// @attached(peer)         — creates new declarations alongside
// @attached(accessor)     — adds get/set accessors to a property
// @attached(memberAttribute) — adds attributes to existing members
// @attached(conformance)  — adds protocol conformances
// @attached(body)         — provides a function body

// Roles can be combined:
@attached(member, names: arbitrary)
@attached(conformance)
public macro AutoCodable() = #externalMacro(
    module: "MyMacros", type: "AutoCodableMacro"
)
```

## Setting Up a Macro Package

Macros live in a dedicated compiler-plugin target. Swift Package Manager makes this straightforward:

```swift
// Package.swift
let package = Package(
    name: "MyMacros",
    platforms: [.macOS(.v13), .iOS(.v17)],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "600.0.0"
        )
    ],
    targets: [
        .macro(
            name: "MyMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(name: "MyMacros", dependencies: ["MyMacrosPlugin"]),
        .testTarget(
            name: "MyMacrosTests",
            dependencies: [
                "MyMacrosPlugin",
                .product(
                    name: "SwiftSyntaxMacrosTestSupport",
                    package: "swift-syntax"
                ),
            ]
        ),
    ]
)
```

## Testing Macros

`SwiftSyntaxMacrosTestSupport` provides `assertMacroExpansion` to verify expansions without compiling the result:

```swift
import SwiftSyntaxMacrosTestSupport
import XCTest

final class URLMacroTests: XCTestCase {
    let macros: [String: Macro.Type] = ["URL": URLMacro.self]

    func testValidURL() throws {
        assertMacroExpansion(
            #"""
            #URL("https://apple.com")
            """#,
            expandedSource: #"""
            URL(string: "https://apple.com")!
            """#,
            macros: macros
        )
    }

    func testInvalidURLProducesError() throws {
        assertMacroExpansion(
            #"""
            #URL("not a url ://")
            """#,
            expandedSource: #"""
            #URL("not a url ://")
            """#,
            diagnostics: [
                DiagnosticSpec(message: "Invalid URL: not a url ://",
                               line: 1, column: 1)
            ],
            macros: macros
        )
    }
}
```

## Best Practices

- **Keep expansions minimal.** Generate only the code that is truly repetitive. Complex logic belongs in regular functions, not macro output.
- **Emit clear diagnostics.** Use `context.diagnose()` to produce warnings and errors that point to the exact source location, just like the compiler would.
- **Test expansions thoroughly.** `assertMacroExpansion` catches regressions early without a full build cycle.
- **Pin your SwiftSyntax version** to match the Swift toolchain you target. SwiftSyntax follows the compiler's release cadence.
- **Avoid side effects.** Macro implementations run in a sandbox — file I/O and network access are not permitted.
- **Document the expanded code.** Users cannot see the generated output unless they explicitly expand macros in Xcode, so document what your macro produces.

## References

- [Macros — The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
- [Applying Macros — Apple Developer Documentation](https://developer.apple.com/documentation/swift/applying-macros)
- [Packages with Macros — Swift.org](https://www.swift.org/packages/macros.html)
- [swift-syntax on GitHub](https://github.com/swiftlang/swift-syntax)
