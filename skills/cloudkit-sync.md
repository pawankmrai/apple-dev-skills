---
topic: CloudKit — iCloud Data Sync for Apple Apps
date: 2026-06-15
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# CloudKit — iCloud Data Sync for Apple Apps

CloudKit is Apple's cloud database service that lets your apps store and sync data across a user's devices via iCloud. It requires no server-side code, integrates natively with Swift, and respects Apple's privacy model. CloudKit is the backbone of first-party apps like Notes and Photos, and it's the recommended path for user data sync on Apple platforms.

## Core Concepts

CloudKit organizes data into three key pieces:

- **Container** (`CKContainer`) — the top-level namespace for your app's iCloud data. Each app has a default container identified by its bundle ID.
- **Database** — each container has a **public** (all users), **private** (per-user, stored in the user's iCloud account), and **shared** database.
- **Record** (`CKRecord`) — a dictionary-like object with a type name and key-value fields. Think of it as a row in a table.

```swift
import CloudKit

// Access the default container and the user's private database
let container = CKContainer.default()
let privateDB = container.privateCloudDatabase
```

## Saving a Record

```swift
struct Note {
    var title: String
    var body: String
}

func saveNote(_ note: Note) async throws {
    let record = CKRecord(recordType: "Note")
    record["title"] = note.title as CKRecordValue
    record["body"] = note.body as CKRecordValue

    let db = CKContainer.default().privateCloudDatabase
    try await db.save(record)
}
```

`CKRecord` values must conform to `CKRecordValue`. Supported types include `String`, `Int`, `Double`, `Date`, `Data`, `CKAsset`, `CKRecord.Reference`, and arrays of those types.

## Fetching Records with a Query

Use `CKQuery` to search records by type and filter with `NSPredicate`.

```swift
func fetchNotes(matching searchText: String) async throws -> [CKRecord] {
    let predicate = searchText.isEmpty
        ? NSPredicate(value: true)
        : NSPredicate(format: "title CONTAINS[cd] %@", searchText)

    let query = CKQuery(recordType: "Note", predicate: predicate)
    query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

    let db = CKContainer.default().privateCloudDatabase
    let (results, _) = try await db.records(matching: query)

    return results.compactMap { _, result in
        try? result.get()
    }
}
```

> **Tip:** For queries other than `NSPredicate(value: true)`, you must create a queryable index for the field in the CloudKit Dashboard (iCloud.developer.apple.com).

## Updating and Deleting Records

```swift
// Update: fetch first, modify, then save
func updateNote(recordID: CKRecord.ID, newBody: String) async throws {
    let db = CKContainer.default().privateCloudDatabase
    let record = try await db.record(for: recordID)
    record["body"] = newBody as CKRecordValue
    try await db.save(record)
}

// Delete by record ID
func deleteNote(recordID: CKRecord.ID) async throws {
    let db = CKContainer.default().privateCloudDatabase
    try await db.deleteRecord(withID: recordID)
}
```

## CloudKit + SwiftUI: A Minimal Notes App

```swift
import SwiftUI
import CloudKit

@Observable
final class NotesViewModel {
    var notes: [CKRecord] = []
    var errorMessage: String?

    private let db = CKContainer.default().privateCloudDatabase

    func loadNotes() async {
        do {
            let query = CKQuery(recordType: "Note", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let (results, _) = try await db.records(matching: query)
            notes = results.compactMap { _, result in try? result.get() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addNote(title: String, body: String) async {
        let record = CKRecord(recordType: "Note")
        record["title"] = title as CKRecordValue
        record["body"] = body as CKRecordValue
        do {
            let saved = try await db.save(record)
            notes.insert(saved, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(record: CKRecord) async {
        do {
            try await db.deleteRecord(withID: record.recordID)
            notes.removeAll { $0.recordID == record.recordID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NotesView: View {
    @State private var viewModel = NotesViewModel()
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List(viewModel.notes, id: \.recordID) { record in
                VStack(alignment: .leading) {
                    Text(record["title"] as? String ?? "Untitled")
                        .font(.headline)
                    Text(record["body"] as? String ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(record: record) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("iCloud Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { showingAdd = true }
                }
            }
            .task { await viewModel.loadNotes() }
            .sheet(isPresented: $showingAdd) {
                AddNoteView { title, body in
                    Task { await viewModel.addNote(title: title, body: body) }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
```

## Handling iCloud Account Status

Always check whether the user is signed into iCloud before performing CloudKit operations.

```swift
func checkAccountStatus() async throws -> CKAccountStatus {
    try await CKContainer.default().accountStatus()
}

// Usage
Task {
    let status = try? await checkAccountStatus()
    switch status {
    case .available:
        print("iCloud available — proceed")
    case .noAccount:
        print("User not signed in to iCloud")
    case .restricted:
        print("iCloud restricted (parental controls or MDM)")
    case .couldNotDetermine, .temporarilyUnavailable:
        print("Try again later")
    default:
        break
    }
}
```

## Subscribing to Remote Changes

CloudKit push notifications let your app react when another device modifies data.

```swift
func subscribeToNoteChanges() async throws {
    let subscription = CKQuerySubscription(
        recordType: "Note",
        predicate: NSPredicate(value: true),
        subscriptionID: "note-changes",
        options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
    )

    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true  // silent push
    subscription.notificationInfo = notificationInfo

    let db = CKContainer.default().privateCloudDatabase
    try await db.save(subscription)
}
```

Handle the incoming push in your `AppDelegate` or `UNUserNotificationCenterDelegate`, then call `loadNotes()` to refresh.

## Best Practices

**Check account status before every operation.** iCloud sign-in state can change at any time; catching `CKError.notAuthenticated` gracefully is essential.

**Use `CKRecord.Reference` for relationships.** Reference one record from another by storing a `CKRecord.Reference` field, which can cascade-delete child records automatically.

**Batch operations with `CKModifyRecordsOperation`.** For bulk saves or deletes, use the operation API instead of individual `save`/`delete` calls — it's more efficient and supports atomic transactions.

**Index fields before querying.** Any field used in a query predicate (other than `recordName` or `creationDate`) must be marked as queryable in the CloudKit Dashboard.

**Handle `CKError.serverRecordChanged` for conflicts.** When two devices modify the same record offline, CloudKit returns this error. Use `error.userInfo[CKRecordChangedErrorServerRecordKey]` to access the server version and merge intelligently.

**Respect rate limits.** CloudKit enforces per-user and per-app quotas. Implement exponential back-off when retrying after `CKError.requestRateLimited`.

## References

- [CloudKit — Apple Developer Documentation](https://developer.apple.com/documentation/cloudkit)
- [iCloud Design Guide](https://developer.apple.com/icloud/documentation/)
- [WWDC: CloudKit Best Practices](https://developer.apple.com/videos/play/wwdc2016/231/)
- [CloudKit Dashboard](https://icloud.developer.apple.com/)
