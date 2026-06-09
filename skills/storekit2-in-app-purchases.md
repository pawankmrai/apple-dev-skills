---
topic: StoreKit 2 — In-App Purchases and Subscriptions
date: 2026-06-09
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# StoreKit 2 — In-App Purchases and Subscriptions

StoreKit 2, introduced in iOS 15, is the modern Swift-native API for in-app purchases and subscriptions. It replaces the callback-heavy `SKPaymentQueue` model with a clean `async/await` interface, `Sendable` product types, and declarative SwiftUI paywall views. With iOS 26, Apple extended StoreKit 2 with `SubscriptionOfferView`, group subscriptions, and volume purchasing via Apple Business Manager.

## Setting Up Products in App Store Connect

Before writing code, create your products in App Store Connect under **Monetization → In-App Purchases** and **Subscriptions**. StoreKit 2 supports four product types:

- **Consumable** — single use (e.g., coins)
- **Non-consumable** — permanent unlock (e.g., remove ads)
- **Auto-renewable subscription** — recurring billing in a group
- **Non-renewing subscription** — fixed-duration, manual renewal

For local testing, create a `StoreKit Configuration File` in Xcode (**File → New → File → StoreKit Configuration File**) and enable it under the scheme's **Run → Options** tab.

## Loading Products

```swift
import StoreKit

@Observable
final class StoreManager {
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []

    let productIDs = [
        "com.example.app.premium",
        "com.example.app.coins_100",
        "com.example.app.subscription_monthly"
    ]

    func loadProducts() async throws {
        products = try await Product.products(for: productIDs)
    }

    var subscriptions: [Product] {
        products.filter { $0.type == .autoRenewable }
            .sorted { $0.price < $1.price }
    }

    var nonConsumables: [Product] {
        products.filter { $0.type == .nonConsumable }
    }
}
```

## Purchasing a Product

```swift
extension StoreManager {
    @discardableResult
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction

        case .userCancelled, .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
```

Always call `transaction.finish()` after handling a successful purchase — StoreKit keeps the transaction in the queue until you do.

## Listening for Transaction Updates

Observe the `Transaction.updates` sequence on app launch to catch purchases made outside your UI (e.g., family sharing, subscription renewals, refunds):

```swift
extension StoreManager {
    func observeTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            do {
                let transaction = try checkVerified(verificationResult)
                await updatePurchasedProducts()
                await transaction.finish()
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
    }

    func updatePurchasedProducts() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    ids.insert(transaction.productID)
                }
            }
        }
        purchasedProductIDs = ids
    }
}
```

Call both `loadProducts()` and `observeTransactionUpdates()` from your `App` entry point:

```swift
@main
struct MyApp: App {
    @State private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task {
                    try? await store.loadProducts()
                    await store.observeTransactionUpdates()
                }
        }
    }
}
```

## Displaying a Subscription Paywall with SubscriptionStoreView

StoreKit 2 ships a built-in paywall that matches the App Store visual style:

```swift
import StoreKit
import SwiftUI

struct PaywallView: View {
    @State private var showPaywall = false
    let groupID = "21234567-ABCD-1234-EFGH-123456789012"

    var body: some View {
        Button("Upgrade to Premium") {
            showPaywall = true
        }
        .subscriptionStoreSheet(groupID: groupID, isPresented: $showPaywall) {
            // Custom marketing content shown above the subscription options
            VStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                Text("Unlock Everything")
                    .font(.title.bold())
                Text("Unlimited access to all features.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
        }
    }
}
```

For manual layouts, iterate over products directly:

```swift
struct CustomPaywallView: View {
    @Environment(StoreManager.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            ForEach(store.subscriptions) { product in
                ProductRowView(product: product)
            }
        }
    }
}

struct ProductRowView: View {
    let product: Product
    @Environment(StoreManager.self) private var store
    @State private var isPurchasing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.displayName).font(.headline)
                Text(product.description).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button(product.displayPrice) {
                isPurchasing = true
                Task {
                    try? await store.purchase(product)
                    isPurchasing = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

## Restore Purchases

```swift
Button("Restore Purchases") {
    Task {
        try? await AppStore.sync()
        await store.updatePurchasedProducts()
    }
}
```

`AppStore.sync()` re-validates all server-side purchases and refreshes local entitlements. Required by App Store Review guidelines for non-consumable and subscription apps.

## Subscription Status and Expiration

```swift
extension StoreManager {
    func subscriptionStatus(for product: Product) async -> Product.SubscriptionInfo.Status? {
        guard let subscription = product.subscription else { return nil }
        let statuses = try? await subscription.status
        return statuses?.max { a, b in
            guard
                let aDate = try? a.transaction.payloadValue.expirationDate,
                let bDate = try? b.transaction.payloadValue.expirationDate
            else { return false }
            return aDate < bDate
        }
    }
}
```

## Best Practices

**Always verify transactions server-side for high-value items.** Use the `signedDate` and JWS payload from `VerificationResult.verified` to call your backend if needed.

**Gate features on `Transaction.currentEntitlements`, not local state.** This is the source of truth — local booleans can go out of sync after refunds or family sharing changes.

**Use `StoreKit Testing in Xcode`** to simulate renewals, cancellations, billing retries, and refunds without an App Store account. In the `Debug → StoreKit` menu, you can force-expire subscriptions and trigger billing retry scenarios.

**Handle `.pending` purchases gracefully.** Purchases from parental-approval flows enter `.pending` state and complete asynchronously via `Transaction.updates`.

**Test `AppStore.sync()` carefully in production.** On iOS it presents a sign-in sheet — only call it on explicit user interaction, not silently on launch.

## References

- [StoreKit 2 — Apple Developer](https://developer.apple.com/storekit/)
- [Implementing In-App Purchase with StoreKit 2 (WWDC)](https://developer.apple.com/videos/play/wwdc2021/10175/)
- [What's New in StoreKit and In-App Purchase (WWDC 2025)](https://developer.apple.com/videos/play/wwdc2025/241/)
- [Testing In-App Purchases with StoreKit in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)
