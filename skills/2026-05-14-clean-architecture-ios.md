---
topic: Clean Architecture for iOS Apps
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: advanced
---

# Clean Architecture for iOS Apps

Clean Architecture, popularized by Robert C. Martin, organizes code into concentric layers where dependencies point inward — business logic never depends on UI or frameworks. Applied to iOS, it produces apps that are testable, maintainable, and resilient to change.

## The Layers

```
┌─────────────────────────────────────────┐
│            Presentation Layer           │  Views, ViewModels
├─────────────────────────────────────────┤
│              Domain Layer               │  Use Cases, Entities, Repository Protocols
├─────────────────────────────────────────┤
│               Data Layer                │  Repository Implementations, API, Database
└─────────────────────────────────────────┘

Dependency Rule: outer layers depend on inner layers, never the reverse.
```

- **Domain Layer** (innermost) — pure Swift, no imports of UIKit, SwiftUI, or frameworks. Contains entities, use cases, and repository protocols.
- **Data Layer** — implements repository protocols with concrete networking, persistence, or caching.
- **Presentation Layer** (outermost) — SwiftUI views and ViewModels that call use cases.

## Domain Layer — Entities

Entities are plain data types representing core business objects:

```swift
// Domain/Entities/Product.swift
struct Product: Identifiable, Equatable {
    let id: UUID
    let name: String
    let price: Decimal
    let category: Category
    let isAvailable: Bool

    enum Category: String, CaseIterable {
        case electronics, clothing, food, books
    }
}
```

No framework imports, no Codable (that's a data-layer concern), no SwiftUI dependencies.

## Domain Layer — Repository Protocols

Define interfaces the data layer must implement:

```swift
// Domain/Repositories/ProductRepository.swift
protocol ProductRepository {
    func fetchAll() async throws -> [Product]
    func fetch(id: UUID) async throws -> Product
    func search(query: String) async throws -> [Product]
    func save(_ product: Product) async throws
    func delete(id: UUID) async throws
}
```

The domain layer owns these protocols. The data layer provides the implementations.

## Domain Layer — Use Cases

Each use case encapsulates a single business operation:

```swift
// Domain/UseCases/GetProductsUseCase.swift
struct GetProductsUseCase {
    private let repository: ProductRepository

    init(repository: ProductRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Product] {
        let products = try await repository.fetchAll()
        return products.filter { $0.isAvailable }
    }
}

// Domain/UseCases/SearchProductsUseCase.swift
struct SearchProductsUseCase {
    private let repository: ProductRepository

    init(repository: ProductRepository) {
        self.repository = repository
    }

    func execute(query: String) async throws -> [Product] {
        guard query.count >= 2 else { return [] }
        return try await repository.search(query: query)
    }
}
```

Use cases contain business rules — like filtering unavailable products or enforcing minimum query length — that stay stable regardless of how data is fetched or displayed.

## Data Layer — DTOs and Mapping

Data Transfer Objects handle serialization; mappers convert to domain entities:

```swift
// Data/DTOs/ProductDTO.swift
struct ProductDTO: Codable {
    let id: String
    let name: String
    let price: Double
    let category: String
    let isAvailable: Bool

    func toDomain() -> Product? {
        guard let uuid = UUID(uuidString: id),
              let category = Product.Category(rawValue: category) else {
            return nil
        }
        return Product(
            id: uuid,
            name: name,
            price: Decimal(price),
            category: category,
            isAvailable: isAvailable
        )
    }
}
```

## Data Layer — Repository Implementation

```swift
// Data/Repositories/RemoteProductRepository.swift
final class RemoteProductRepository: ProductRepository {
    private let apiClient: APIClient
    private let cache: ProductCache

    init(apiClient: APIClient, cache: ProductCache) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func fetchAll() async throws -> [Product] {
        if let cached = cache.getAll(), !cached.isEmpty {
            return cached
        }

        let dtos: [ProductDTO] = try await apiClient.request(path: "/products")
        let products = dtos.compactMap { $0.toDomain() }
        cache.store(products)
        return products
    }

    func fetch(id: UUID) async throws -> Product {
        let dto: ProductDTO = try await apiClient.request(path: "/products/\(id.uuidString)")
        guard let product = dto.toDomain() else {
            throw DataError.mappingFailed
        }
        return product
    }

    func search(query: String) async throws -> [Product] {
        let dtos: [ProductDTO] = try await apiClient.request(
            path: "/products/search",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        return dtos.compactMap { $0.toDomain() }
    }

    func save(_ product: Product) async throws {
        try await apiClient.request(path: "/products", method: .post, body: product)
    }

    func delete(id: UUID) async throws {
        try await apiClient.request(path: "/products/\(id.uuidString)", method: .delete)
    }
}
```

## Presentation Layer — ViewModel

The ViewModel depends only on use cases, never on the data layer directly:

```swift
// Presentation/ViewModels/ProductListViewModel.swift
import Observation

@Observable
class ProductListViewModel {
    var products: [Product] = []
    var searchResults: [Product] = []
    var isLoading = false
    var errorMessage: String?

    private let getProducts: GetProductsUseCase
    private let searchProducts: SearchProductsUseCase

    init(getProducts: GetProductsUseCase, searchProducts: SearchProductsUseCase) {
        self.getProducts = getProducts
        self.searchProducts = searchProducts
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await getProducts.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func search(query: String) async {
        do {
            searchResults = try await searchProducts.execute(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Presentation Layer — View

```swift
// Presentation/Views/ProductListView.swift
import SwiftUI

struct ProductListView: View {
    var viewModel: ProductListViewModel
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    let items = searchText.isEmpty ? viewModel.products : viewModel.searchResults
                    List(items) { product in
                        ProductRow(product: product)
                    }
                }
            }
            .navigationTitle("Products")
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, query in
                Task { await viewModel.search(query: query) }
            }
            .task { await viewModel.load() }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
```

## Dependency Injection — Wiring It All Together

A composition root assembles all dependencies at app launch:

```swift
// App/DependencyContainer.swift
@Observable
class DependencyContainer {
    private let apiClient: APIClient
    private let cache: ProductCache

    init() {
        self.apiClient = APIClient(baseURL: URL(string: "https://api.example.com")!)
        self.cache = InMemoryProductCache()
    }

    // Repositories
    private var productRepository: ProductRepository {
        RemoteProductRepository(apiClient: apiClient, cache: cache)
    }

    // Use Cases
    private var getProductsUseCase: GetProductsUseCase {
        GetProductsUseCase(repository: productRepository)
    }

    private var searchProductsUseCase: SearchProductsUseCase {
        SearchProductsUseCase(repository: productRepository)
    }

    // ViewModels
    func makeProductListViewModel() -> ProductListViewModel {
        ProductListViewModel(
            getProducts: getProductsUseCase,
            searchProducts: searchProductsUseCase
        )
    }
}

// App/MyApp.swift
@main
struct MyApp: App {
    @State private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ProductListView(viewModel: container.makeProductListViewModel())
        }
    }
}
```

## Testing

Clean Architecture makes each layer independently testable:

```swift
// Tests/Domain/GetProductsUseCaseTests.swift
import Testing

struct GetProductsUseCaseTests {
    @Test func filtersUnavailableProducts() async throws {
        let mock = MockProductRepository(products: [
            Product(id: UUID(), name: "Available", price: 10, category: .books, isAvailable: true),
            Product(id: UUID(), name: "Sold Out", price: 20, category: .books, isAvailable: false)
        ])
        let useCase = GetProductsUseCase(repository: mock)

        let result = try await useCase.execute()

        #expect(result.count == 1)
        #expect(result.first?.name == "Available")
    }
}

class MockProductRepository: ProductRepository {
    let products: [Product]
    init(products: [Product]) { self.products = products }

    func fetchAll() async throws -> [Product] { products }
    func fetch(id: UUID) async throws -> Product { products.first! }
    func search(query: String) async throws -> [Product] {
        products.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    func save(_ product: Product) async throws {}
    func delete(id: UUID) async throws {}
}
```

## Project Structure

```
Sources/
├── Domain/
│   ├── Entities/
│   │   └── Product.swift
│   ├── UseCases/
│   │   ├── GetProductsUseCase.swift
│   │   └── SearchProductsUseCase.swift
│   └── Repositories/
│       └── ProductRepository.swift       (protocol)
├── Data/
│   ├── DTOs/
│   │   └── ProductDTO.swift
│   ├── Repositories/
│   │   └── RemoteProductRepository.swift (implementation)
│   ├── Network/
│   │   └── APIClient.swift
│   └── Cache/
│       └── InMemoryProductCache.swift
├── Presentation/
│   ├── ViewModels/
│   │   └── ProductListViewModel.swift
│   └── Views/
│       ├── ProductListView.swift
│       └── ProductRow.swift
└── App/
    ├── DependencyContainer.swift
    └── MyApp.swift
```

## Best Practices

- **The Domain layer should have zero framework imports** — no Foundation (where avoidable), no UIKit, no SwiftUI. This keeps business logic portable and testable.
- **Use cases should do one thing** — name them as verbs (GetProducts, SearchProducts, PlaceOrder). If a use case does multiple things, split it.
- **DTOs are not entities** — keep `Codable` in the data layer. Map DTOs to domain entities at the repository boundary.
- **Inject dependencies, don't create them** — every class receives its dependencies through `init`. The composition root is the only place that knows about concrete types.
- **Don't over-apply to small apps** — Clean Architecture shines in large codebases with multiple developers. For a simple app, MVVM is often sufficient.
- **Test use cases and repositories independently** — mock the repository to test use cases; mock the network to test repositories.
- **Keep ViewModels thin** — they should delegate to use cases, not contain business logic.

## References

- [Clean Architecture — Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Clean Architecture for SwiftUI — Alexey Naumov](https://nalexn.github.io/clean-architecture-swiftui/)
- [Separation of concerns using protocols — Swift by Sundell](https://www.swiftbysundell.com/articles/separation-of-concerns-using-protocols-in-swift/)
