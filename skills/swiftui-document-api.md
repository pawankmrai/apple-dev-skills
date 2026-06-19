---
topic: SwiftUI Document API — WritableDocument, ReadableDocument, and Snapshot-Based Diffing
date: 2026-06-19
platform: iOS 27, macOS 27
swift: "6.4"
difficulty: intermediate
---

# SwiftUI Document API — WritableDocument, ReadableDocument, and Snapshot-Based Diffing

`FileDocument` and `ReferenceFileDocument` have been the only options for document-based SwiftUI apps since `DocumentGroup` shipped, and both load and save the entire file as one in-memory blob. That works for small files but falls apart for a multi-megabyte project file where a single keystroke shouldn't rewrite the whole thing to disk. WWDC 2026 introduces a new layer on top: `WritableDocument` and `ReadableDocument`, paired with dedicated reader and writer types that get direct, incremental access to the file URL. The old protocols still work — this is additive, not a replacement you're forced into.

## Why a New Layer

The core idea is separating the in-memory model from the on-disk representation. Your document object stays `@Observable` and reference-typed, so SwiftUI doesn't recreate it on every edit and a bound `TextEditor` doesn't lose focus on each keystroke. Saving and loading go through a `Snapshot` — an immutable value capturing exactly what needs to be written — rather than the live model. Because the writer receives both the new snapshot and the previous one, it can diff them and write only what changed instead of serializing everything every time.

## Declaring Creation Sources

`DocumentCreationSource` lets a document type expose more than one way to start a new file, each wired to its own `NewDocumentButton` in the launch scene.

```swift
extension DocumentCreationSource {
    static let blank = Self(id: "blank")
    static let imported = Self(id: "imported")
}

@main
struct JournalApp: App {
    var body: some Scene {
        DocumentGroupLaunchScene("New Journal Entry") {
            NewDocumentButton("Blank Entry", source: .blank)
            NewDocumentButton("Import from Photos…", source: .imported)
        }

        DocumentGroup { document in
            EntryView(document: document)
        } { configuration, context in
            JournalEntry(configuration: configuration, context: context)
        }
    }
}
```

`context.source` inside the document initializer tells you which button the person tapped, so a single type can branch its setup logic instead of needing a separate document type per entry point.

## WritableDocument and DocumentWriter

A document opts into saving by conforming to `WritableDocument` and supplying a `snapshot()` method plus a nested type conforming to `DocumentWriter`. The writer's `write` method is `nonisolated` and `async`, so serialization runs off the main actor without you managing a background queue yourself.

```swift
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class JournalEntry: WritableDocument {
    var title: String = ""
    var body: String = ""
    var attachments: [Attachment] = []

    struct PageSnapshot: Sendable {
        let title: String
        let body: String
        let attachments: [Attachment]
    }

    func snapshot() -> PageSnapshot {
        PageSnapshot(title: title, body: body, attachments: attachments)
    }

    static var writableContentTypes: [UTType] { [.journalEntry, .plainText] }

    struct Writer: DocumentWriter {
        typealias Snapshot = PageSnapshot
        let contentType: UTType

        nonisolated func write(
            snapshot: sending PageSnapshot,
            to destination: URL,
            previous: sending PageSnapshot?,
            progress: consuming Subprogress
        ) async throws {
            if contentType.conforms(to: .journalEntry) {
                // Only rewrite the attachments folder if it actually changed.
                if previous?.attachments != snapshot.attachments {
                    try writeAttachments(snapshot.attachments, to: destination, progress: progress)
                }
                try writeManifest(title: snapshot.title, body: snapshot.body, to: destination)
            } else if contentType.conforms(to: .plainText) {
                try snapshot.body.write(to: destination, atomically: true, encoding: .utf8)
            }
        }
    }
}
```

Comparing `previous` against the incoming `snapshot` is what makes the write incremental — skip the expensive parts of the save when their inputs haven't moved, and let `Subprogress` report granular progress for the parts that do run.

## ReadableDocument and DocumentReader

`ReadableDocument` mirrors the same shape for loading. Conform to it alone for a read-only viewer, or conform to both protocols — Apple ships a `Document` typealias that bundles them — for a full read/write type.

```swift
extension JournalEntry: ReadableDocument {
    struct Reader: DocumentReader {
        typealias Snapshot = PageSnapshot

        nonisolated func read(
            from source: URL,
            progress: consuming Subprogress
        ) async throws -> PageSnapshot {
            let manifest = try readManifest(at: source)
            let attachments = try readAttachments(at: source, progress: progress)
            return PageSnapshot(title: manifest.title, body: manifest.body, attachments: attachments)
        }
    }

    convenience init(snapshot: PageSnapshot) {
        self.init()
        title = snapshot.title
        body = snapshot.body
        attachments = snapshot.attachments
    }
}
```

SwiftUI calls the reader off the main actor, applies the resulting snapshot to a fresh or existing document instance, and only republishes the `@Observable` properties that actually changed — a view bound to `document.title` doesn't redraw when only `attachments` updates.

## Best Practices

Keep `Snapshot` a plain `Sendable` value type — structs and enums of value types — so it can cross actor boundaries into the writer without copies or isolation checks. Make the diff in `write` cheap: comparing a few fields or a hash is the point, so avoid deep, expensive comparisons that erase the benefit of skipping work. Reserve multiple `writableContentTypes` for genuine export formats (a native format plus PDF or plain text export) rather than as a substitute for versioning. Migrate incrementally — `FileDocument` keeps working, so move a document type to the new protocols when its save performance or multi-format needs actually call for it, not as a blanket rewrite.

## References

- [What's new in SwiftUI - WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/)
- [DocumentGroup - Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/DocumentGroup)
- [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/)
