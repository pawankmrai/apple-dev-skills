---
topic: App Architecture — MVVM, TCA, and Coordinator Patterns
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# App Architecture — MVVM, TCA, and Coordinator Patterns

Choosing the right architecture shapes how your app handles complexity as it grows. This skill covers three popular patterns in the Apple ecosystem: MVVM, The Composable Architecture (TCA), and the Coordinator pattern.

## MVVM (Model-View-ViewModel)

MVVM is the most common architecture for SwiftUI apps. The ViewModel mediates between business logic and the view layer:

```swift
// Model
struct Task: Identifiable, Codable {
    let id: UUID
    var title: String
    var isComplete: Bool
    var dueDate: Date?
}

// ViewModel
import Observation

@Observable
class TaskListViewModel {
    var tasks: [Task] = []
    var isLoading = false
    var errorMessage: String?

    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
    }

    var incompleteTasks: [Task] {
        tasks.filter { !$0.isComplete }
    }

    var completionRate: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter(\.isComplete).count) / Double(tasks.count)
    }

    func load() async {
        isLoading = true
        do {
            tasks = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleComplete(_ task: Task) async {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isComplete.toggle()
        try? await repository.update(tasks[index])
    }

    func delete(_ task: Task) async {
        tasks.removeAll { $0.id == task.id }
        try? await repository.delete(task.id)
    }
}

// View
struct TaskListView: View {
    var viewModel: TaskListViewModel

    var body: some View {
        List {
            ForEach(viewModel.tasks) { task in
                TaskRow(task: task) {
                    Task { await viewModel.toggleComplete(task) }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    Task { await viewModel.delete(viewModel.tasks[index]) }
                }
            }
        }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .task { await viewModel.load() }
    }
}
```

### MVVM Strengths
- Simple and familiar — low learning curve
- Works naturally with SwiftUI's `@Observable`
- Easy to test ViewModels in isolation

### MVVM Weaknesses
- ViewModels can grow large without discipline
- Navigation logic often leaks into views
- No enforced unidirectional data flow

## The Composable Architecture (TCA)

TCA (by Point-Free) enforces unidirectional data flow with reducers, actions, and a store:

```swift
import ComposableArchitecture

@Reducer
struct TaskListFeature {
    @ObservableState
    struct State: Equatable {
        var tasks: [Task] = []
        var isLoading = false
    }

    enum Action {
        case onAppear
        case tasksLoaded([Task])
        case toggleComplete(Task)
        case delete(Task)
    }

    @Dependency(\.taskRepository) var repository

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let tasks = try await repository.fetchAll()
                    await send(.tasksLoaded(tasks))
                }

            case .tasksLoaded(let tasks):
                state.isLoading = false
                state.tasks = tasks
                return .none

            case .toggleComplete(let task):
                guard let index = state.tasks.firstIndex(where: { $0.id == task.id }) else {
                    return .none
                }
                state.tasks[index].isComplete.toggle()
                let updated = state.tasks[index]
                return .run { _ in try await repository.update(updated) }

            case .delete(let task):
                state.tasks.removeAll { $0.id == task.id }
                return .run { _ in try await repository.delete(task.id) }
            }
        }
    }
}

// View
struct TaskListView: View {
    let store: StoreOf<TaskListFeature>

    var body: some View {
        List {
            ForEach(store.tasks) { task in
                TaskRow(task: task) {
                    store.send(.toggleComplete(task))
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    store.send(.delete(store.tasks[index]))
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}
```

### TCA Strengths
- Enforced unidirectional data flow — state changes are predictable
- Excellent testability — test reducers as pure functions
- Built-in dependency injection and side-effect management
- Features compose cleanly via scoping

### TCA Weaknesses
- Steep learning curve
- Verbose for simple screens
- Third-party dependency

## Coordinator Pattern

Coordinators extract navigation logic from views, keeping them focused on presentation:

```swift
@Observable
class AppCoordinator {
    var path = NavigationPath()

    func showTaskDetail(_ task: Task) {
        path.append(Route.taskDetail(task))
    }

    func showSettings() {
        path.append(Route.settings)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    enum Route: Hashable {
        case taskDetail(Task)
        case settings
    }
}

struct CoordinatedRootView: View {
    var coordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            TaskListView(onSelect: coordinator.showTaskDetail)
                .toolbar {
                    Button("Settings") { coordinator.showSettings() }
                }
                .navigationDestination(for: AppCoordinator.Route.self) { route in
                    switch route {
                    case .taskDetail(let task):
                        TaskDetailView(task: task)
                    case .settings:
                        SettingsView()
                    }
                }
        }
    }
}
```

### Coordinator Strengths
- Centralizes navigation logic — views don't know about other views
- Easy to change navigation flows without modifying views
- Works well with deep linking and state restoration

## Choosing an Architecture

| Factor              | MVVM           | TCA              | Coordinator     |
|---------------------|----------------|------------------|-----------------|
| Team size           | Any            | Medium+          | Any             |
| App complexity      | Small–Large    | Medium–Large     | Complements any |
| Learning curve      | Low            | High             | Low             |
| Testability         | Good           | Excellent        | Good            |
| SwiftUI fit         | Natural        | Good (w/ lib)    | Natural         |

## Best Practices

- **Start with MVVM** — it's the simplest architecture that works well with SwiftUI and `@Observable`.
- **Adopt TCA for complex state** — when you have features with many side effects, shared state, or need exhaustive testing.
- **Use Coordinators alongside MVVM or TCA** — they solve a different problem (navigation) and complement either architecture.
- **Keep ViewModels focused** — one ViewModel per screen. If it grows past 200 lines, split responsibilities.
- **Inject dependencies** — never hardcode services in ViewModels. Use protocols or TCA's `@Dependency` for testability.
- **Test the business logic layer** — whether that's a ViewModel or a Reducer, it should be testable without any UI.
- **Don't over-architect early** — start simple and refactor when complexity demands it.

## References

- [The Composable Architecture — GitHub](https://github.com/pointfreeco/swift-composable-architecture)
- [Managing model data in your app — Apple Developer](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [App Architecture — objc.io](https://www.objc.io/books/app-architecture/)
