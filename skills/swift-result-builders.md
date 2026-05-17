---
topic: Swift Result Builders
date: 2026-05-17
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Result Builders

Result builders are one of Swift's most powerful metaprogramming features, enabling you to create expressive domain-specific languages (DSLs) directly in Swift. They power SwiftUI's declarative syntax and can be applied to build custom DSLs for HTML generation, networking pipelines, validation rules, and more.

## How Result Builders Work

A result builder is a type annotated with `@resultBuilder` that implements a set of static methods. The compiler transforms the body of a closure or function into a series of calls to these methods.

```swift
@resultBuilder
struct ArrayBuilder<Element> {
    static func buildBlock(_ components: Element...) -> [Element] {
        components
    }

    static func buildOptional(_ component: [Element]?) -> [Element] {
        component ?? []
    }

    static func buildEither(first component: [Element]) -> [Element] {
        component
    }

    static func buildEither(second component: [Element]) -> [Element] {
        component
    }

    static func buildArray(_ components: [[Element]]) -> [Element] {
        components.flatMap { $0 }
    }
}
```

## Building a Validation DSL

A practical example is a validation framework where rules compose declaratively:

```swift
struct ValidationRule<Value> {
    let validate: (Value) -> [String]
}

@resultBuilder
struct ValidationBuilder<Value> {
    static func buildBlock(_ rules: ValidationRule<Value>...) -> [ValidationRule<Value>] {
        rules
    }

    static func buildOptional(_ rule: [ValidationRule<Value>]?) -> [ValidationRule<Value>] {
        rule ?? []
    }

    static func buildEither(first rules: [ValidationRule<Value>]) -> [ValidationRule<Value>] {
        rules
    }

    static func buildEither(second rules: [ValidationRule<Value>]) -> [ValidationRule<Value>] {
        rules
    }
}

struct Validator<Value> {
    let rules: [ValidationRule<Value>]

    init(@ValidationBuilder<Value> _ content: () -> [ValidationRule<Value>]) {
        self.rules = content()
    }

    func validate(_ value: Value) -> [String] {
        rules.flatMap { $0.validate(value) }
    }
}
```

Usage reads naturally:

```swift
let emailValidator = Validator<String> {
    ValidationRule { value in
        value.contains("@") ? [] : ["Must contain @"]
    }
    ValidationRule { value in
        value.count >= 5 ? [] : ["Must be at least 5 characters"]
    }
}

let errors = emailValidator.validate("test")
// ["Must contain @", "Must be at least 5 characters"]
```

## Advanced: buildExpression and Type Erasure

Use `buildExpression` to accept heterogeneous types and convert them into a uniform intermediate type:

```swift
@resultBuilder
struct AttributeBuilder {
    static func buildExpression(_ pair: (String, String)) -> [HTMLAttribute] {
        [HTMLAttribute(name: pair.0, value: pair.1)]
    }

    static func buildExpression(_ attribute: HTMLAttribute) -> [HTMLAttribute] {
        [attribute]
    }

    static func buildBlock(_ components: [HTMLAttribute]...) -> [HTMLAttribute] {
        components.flatMap { $0 }
    }
}
```

## Combining with Swift Concurrency

Result builders integrate with async/await for building asynchronous pipelines:

```swift
@resultBuilder
struct PipelineBuilder {
    static func buildBlock(_ steps: Step...) -> Pipeline {
        Pipeline(steps: steps)
    }
}

struct Pipeline {
    let steps: [Step]

    func execute() async throws {
        for step in steps {
            try await step.run()
        }
    }
}

func deployPipeline(@PipelineBuilder content: () -> Pipeline) -> Pipeline {
    content()
}

let pipeline = deployPipeline {
    Step("Build") { try await build() }
    Step("Test") { try await runTests() }
    Step("Deploy") { try await deploy() }
}
```

## Best Practices

- **Use result builders when structure is hierarchical** — they shine for tree-like or sequential compositions, not flat data transformations.
- **Implement all conditional methods** — always provide `buildOptional`, `buildEither(first:)`, and `buildEither(second:)` so users can write `if/else` and `switch` inside the builder.
- **Keep `buildBlock` variadic** — accept variadic parameters to allow any number of expressions.
- **Provide `buildArray` for loops** — without it, `for...in` loops won't compile inside the builder body.
- **Prefer type safety over stringly-typed APIs** — leverage Swift's type system within your DSL to catch errors at compile time.
- **Document the DSL grammar** — result builders create implicit contracts; make the expected usage explicit in documentation.

## References

- [SE-0289: Result Builders](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0289-result-builders.md)
- [WWDC21: Write a DSL in Swift Using Result Builders](https://developer.apple.com/videos/play/wwdc2021/10253/)
- [Swift Documentation: Result Builders](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/#Result-Builders)
