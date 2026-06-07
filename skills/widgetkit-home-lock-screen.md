---
topic: WidgetKit — Home Screen, Lock Screen, and Interactive Widgets
date: 2026-06-07
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# WidgetKit — Home Screen, Lock Screen, and Interactive Widgets

WidgetKit lets you build glanceable, up-to-date content surfaces across the Home Screen, Lock Screen, StandBy, and the Mac Desktop. Widgets are driven by a `TimelineProvider` that pre-computes entries; the system decides when to render them. Since iOS 17, widgets also support **interactive controls** (buttons and toggles) powered by App Intents — no extension round-trip required.

## Project Setup

Add a **Widget Extension** target in Xcode (**File › New › Target › Widget Extension**). Link the shared model code via a Swift package or framework rather than duplicating it. The extension's `Info.plist` automatically includes the `NSExtension` key; you don't need to hand-edit it.

```swift
// WidgetBundle declares all widgets your extension exposes
import WidgetKit
import SwiftUI

@main
struct MyWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskCounterWidget()
        TaskListWidget()
    }
}
```

## Timeline Provider

The `TimelineProvider` protocol has three requirements:

```swift
import WidgetKit

struct TaskEntry: TimelineEntry {
    let date: Date
    let pendingCount: Int
    let nextTask: String?
}

struct TaskTimelineProvider: TimelineProvider {
    // Placeholder shown while real data loads (keep it fast, use static data)
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: .now, pendingCount: 3, nextTask: "Design review")
    }

    // Snapshot used in the widget gallery — should return quickly
    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        let entry = TaskEntry(date: .now, pendingCount: 5, nextTask: "Stand-up")
        completion(entry)
    }

    // Real timeline: return a sequence of entries and a reload policy
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let store = TaskStore.shared  // shared via App Group
        var entries: [TaskEntry] = []

        let now = Date.now
        for hourOffset in 0..<6 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: now)!
            let entry = TaskEntry(
                date: entryDate,
                pendingCount: store.pendingCount,
                nextTask: store.nextTask
            )
            entries.append(entry)
        }

        // .atEnd asks the system to refresh after the last entry elapses
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}
```

### Reload Policies

| Policy | When to use |
|--------|-------------|
| `.atEnd` | After the last entry — good for periodic refreshes |
| `.after(Date)` | Refresh at a specific future time |
| `.never` | Widget is static; refresh only on explicit `WidgetCenter` call |

Trigger an explicit reload from your main app when data changes:

```swift
// In your main app after mutating data:
WidgetCenter.shared.reloadTimelines(ofKind: "TaskCounterWidget")
// Or reload everything:
WidgetCenter.shared.reloadAllTimelines()
```

## Widget View

Views are plain SwiftUI. Use `containerBackground` (required since iOS 17) instead of a plain `Color` or `ZStack` background:

```swift
struct TaskCounterWidgetView: View {
    let entry: TaskEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(entry.pendingCount) tasks", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(.primary)

            if let next = entry.nextTask {
                Text("Next: \(next)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(entry.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .containerBackground(Color.accentColor.gradient, for: .widget)
    }
}
```

## Supported Families and Configuration

```swift
struct TaskCounterWidget: Widget {
    let kind = "TaskCounterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            TaskCounterWidgetView(entry: entry)
        }
        .configurationDisplayName("Task Counter")
        .description("Shows your pending task count at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,      // Lock Screen / StandBy circular
            .accessoryRectangular,   // Lock Screen rectangular
            .accessoryInline,        // Lock Screen inline / Apple Watch
        ])
    }
}
```

Check the current family in your view to adapt the layout:

```swift
@Environment(\.widgetFamily) private var family

var body: some View {
    switch family {
    case .accessoryCircular:
        CircularTaskView(entry: entry)
    case .accessoryRectangular:
        RectangularTaskView(entry: entry)
    default:
        TaskCounterWidgetView(entry: entry)
    }
}
```

## Interactive Widgets (iOS 17+)

Interactive widgets use `Button` and `Toggle` backed by App Intents. The intent runs in a lightweight extension process — no full app launch.

```swift
// 1. Define the App Intent
import AppIntents

struct CompleteTopTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Top Task"
    static let isDiscoverable = false  // widget-only; hide from Shortcuts

    func perform() async throws -> some IntentResult {
        await TaskStore.shared.completeTopTask()
        return .result()
    }
}

// 2. Use Button in your widget view
Button(intent: CompleteTopTaskIntent()) {
    Label("Done", systemImage: "checkmark.circle.fill")
        .font(.caption.bold())
}
.buttonStyle(.plain)
.tint(.green)
```

Toggles work the same way — provide a `SetValueIntent` conforming to `SetValueIntent<Bool>`:

```swift
struct SetTaskPinnedIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Pin Task"
    var value: Bool  // automatically bound to the toggle

    func perform() async throws -> some IntentResult {
        await TaskStore.shared.setPinned(value)
        return .result()
    }
}

Toggle(isOn: entry.isPinned, intent: SetTaskPinnedIntent()) {
    Label("Pinned", systemImage: "pin.fill")
}
```

## Sharing Data via App Groups

The widget extension runs in a separate process; use an **App Group** container:

```swift
// In both your app and the extension:
let defaults = UserDefaults(suiteName: "group.com.example.myapp")!
defaults.set(pendingCount, forKey: "pendingCount")
```

For larger or structured data, use a shared SQLite / SwiftData store pointing at the group container URL:

```swift
let groupURL = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.myapp")!
    .appending(path: "tasks.sqlite")
```

## Configurable (User-Customizable) Widgets

Replace `StaticConfiguration` with `AppIntentConfiguration` to let users customize the widget via long-press:

```swift
struct FilteredTaskWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "FilteredTaskWidget",
            intent: TaskFilterIntent.self,
            provider: FilteredTaskProvider()
        ) { entry in
            FilteredTaskView(entry: entry)
        }
        .configurationDisplayName("Task List")
        .description("Shows tasks filtered by project.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// The intent drives the configuration UI automatically
struct TaskFilterIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Task Filter"
    @Parameter(title: "Project") var project: ProjectEntity?
}
```

## Best Practices

- **Keep timelines lean.** The system budgets widget refreshes; prefer 5–10 entries per timeline and realistic policies. Avoid `.never` unless the data truly never changes.
- **Use `containerBackground` properly.** Omitting it causes a crash on iOS 17+. Apply it to the outermost view, not an inner container.
- **Avoid network calls in `placeholder`.** Return static mock data immediately; do any async work only in `getTimeline`.
- **Test all families.** Use the Xcode widget simulator (hold Option when clicking the widget size picker) to preview every family your widget claims to support.
- **Gracefully handle missing data.** The widget may render before your App Group is populated; show a sensible placeholder state rather than crashing.
- **Respect privacy.** Mark sensitive entries with `relevance` and redact them using `.privacySensitive()` modifier — the system blurs them on the Lock Screen when the device is locked.

```swift
Text(entry.confidentialNote)
    .privacySensitive()  // blurred when device is locked
```

## References

- [WidgetKit documentation](https://developer.apple.com/documentation/widgetkit)
- [Creating a widget extension — Apple tutorials](https://developer.apple.com/tutorials/swiftui/creating-a-widget-extension)
- [App Intents for interactive widgets](https://developer.apple.com/documentation/appintents/making-your-app-content-discoverable)
- [WWDC23: Bring widgets to life](https://developer.apple.com/videos/play/wwdc2023/10028/)
- [WWDC22: Complications and widgets — reloaded](https://developer.apple.com/videos/play/wwdc2022/10051/)
