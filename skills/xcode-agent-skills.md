---
topic: Xcode 27 Agent Skills — Apple's Built-In AI Guidance for Swift Developers
date: 2026-06-25
platform: iOS 27, Xcode 27
swift: "6.4"
difficulty: intermediate
---

# Xcode 27 Agent Skills — Apple's Built-In AI Guidance for Swift Developers

Xcode 27, announced at WWDC26, ships with seven Agent Skills written by Apple itself — Markdown files that encode the company's own guidance for modern Swift, SwiftUI, UIKit migration, testing, and security. They power Xcode's built-in coding agents, but you can export them and use them in any agent-compatible IDE, including Claude Code, Cursor, and Codex.

## What an Agent Skill Actually Is

A skill is a folder containing a `SKILL.md` file: a description that tells an agent when to load it, plus instructions, examples, and sometimes scripts the agent can run. Unlike a one-off prompt, skills are reusable, version-controlled, and scoped — an agent only pulls one in when the task matches its description. Apple's skills follow this same open format, which is why they work outside Xcode at all.

## The Seven Built-In Skills

```
$ xcrun agent skills export ~/.agents/skills
Exported 7 skills to ~/.agents/skills
  ✓ swiftui-specialist
  ✓ swiftui-whats-new-27
  ✓ uikit-app-modernization
  ✓ test-modernizer
  ✓ audit-xcode-security-settings
  ✓ c-bounds-safety
  ✓ device-interaction
```

- **swiftui-specialist** — idiomatic SwiftUI: view structure, data flow, environment usage, `ForEach` identity, and soft-deprecated APIs to avoid.
- **swiftui-whats-new-27** — this cycle's SwiftUI changes: the `@State` macro migration, drag-to-reorder containers, new toolbar APIs, and other source-breaking changes agents weren't trained on.
- **uikit-app-modernization** — moves legacy UIKit code (`UIScreen.main`, fixed `interfaceOrientation` checks) toward scene-based, multi-window-safe patterns.
- **test-modernizer** — migrates XCTest suites to Swift Testing: maps assertions to `#expect`, converts `setUp`/`tearDown` to initializers, and introduces traits and parameterized tests.
- **audit-xcode-security-settings** — reviews and hardens build settings: pointer authentication, typed allocators, stack zero-initialization, Enhanced Security entitlements.
- **c-bounds-safety** — guides adoption of the C `-fbounds-safety` extension for pointer-heavy interop code.
- **device-interaction** — drives a real device or simulator through screenshots, view-hierarchy inspection, and synthesized touch to verify a change actually works.

## Exporting Skills for Other IDEs

Most agent-capable IDEs look for skills under `~/.agents/skills` by convention. Run the export once per Xcode update, then relaunch your IDE of choice:

```bash
xcrun agent skills export ~/.agents/skills
# Re-run after every Xcode update — skills ship updates between releases too
```

Not every skill is portable. Knowledge-only skills — `swiftui-specialist`, `swiftui-whats-new-27`, `test-modernizer` — just read and edit source files, so they work anywhere. `audit-xcode-security-settings` expects Xcode's project model and falls back to manual `.pbxproj` edits elsewhere. `device-interaction` is the strongest case: it calls device and simulator tools that only Xcode's agent exposes, so outside Xcode there's nothing for it to call.

## test-modernizer in Practice

Given this XCTest suite:

```swift
import XCTest

final class UserStoreTests: XCTestCase {
    var sut: UserStore!

    override func setUpWithError() throws {
        sut = UserStore(persistence: InMemoryUserPersistence())
    }

    func testAddingUserIncreasesCount() throws {
        try sut.add(User(name: "Ada"))
        XCTAssertEqual(sut.count, 1)
    }

    func testDuplicateUserThrows() {
        XCTAssertThrowsError(try {
            try sut.add(User(name: "Ada"))
            try sut.add(User(name: "Ada"))
        }())
    }
}
```

`test-modernizer` rewrites it as a Swift Testing suite, replacing the class and lifecycle methods with a value-type initializer and parameterized cases:

```swift
import Testing

struct UserStoreTests {
    let sut = UserStore(persistence: InMemoryUserPersistence())

    @Test("Adding a user increases the count")
    func addingUserIncreasesCount() throws {
        try sut.add(User(name: "Ada"))
        #expect(sut.count == 1)
    }

    @Test("Duplicate users are rejected")
    func duplicateUserThrows() {
        #expect(throws: UserStore.Error.duplicate) {
            try sut.add(User(name: "Ada"))
            try sut.add(User(name: "Ada"))
        }
    }

    @Test("Several distinct names all succeed", arguments: ["Ada", "Grace", "Margaret"])
    func distinctNamesSucceed(name: String) throws {
        try sut.add(User(name: name))
        #expect(sut.count == 1)
    }
}
```

## Verifying with device-interaction

Inside Xcode, `device-interaction` runs as a subagent after a code change: it builds, launches the app in the Device Hub, takes a screenshot, walks the accessibility tree, and taps through the affected flow to confirm nothing broke visually. You don't write code for this — you describe the flow to verify, and the agent reports back with screenshots and a pass/fail summary, which is what lets Xcode 27's agents run unattended for longer stretches between check-ins.

## Best Practices

Re-run the export command after every Xcode update; Apple ships skill revisions between major releases, not just once a year. Treat Apple's skills as a baseline, not a ceiling — they're intentionally compact, so pair them with your team's own skills for project-specific conventions the generic guidance can't know about. Prefer the knowledge-only skills when working outside Xcode, and don't expect `device-interaction` or `audit-xcode-security-settings` to do anything useful in an IDE that isn't Xcode itself. Review an agent's plan before it acts — Xcode 27 surfaces plans as editable Markdown, and that review step is where you catch a misapplied skill before it touches your codebase.

## References

- [Apple accelerates app development with new intelligence frameworks and advanced tools — Apple Newsroom](https://www.apple.com/newsroom/2026/06/apple-aids-app-development-with-new-intelligence-frameworks-and-advanced-tools/)
- [Xcode, agents, and you — WWDC26](https://developer.apple.com/videos/play/wwdc2026/259/)
- [What's new in Xcode 27 — WWDC26](https://developer.apple.com/videos/play/wwdc2026/258/)
- [Using Xcode 27's Agent Skills in Claude, Codex, and Cursor — SwiftLee](https://www.avanderlee.com/ai-development/using-xcode-27s-agent-skills-in-claude-codex-and-cursor/)
