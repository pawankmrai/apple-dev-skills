---
topic: Trust Insights — Detecting Coerced Actions in Sensitive Flows
date: 2026-07-29
platform: iOS 27
swift: "6.4"
difficulty: advanced
---

# Trust Insights — Detecting Coerced Actions in Sensitive Flows

Announced at WWDC26, `TrustInsights` is a new framework that helps apps recognize when a legitimate, authenticated user may be actively coached through a sensitive action — the classic "stay on the phone while you send this transfer" scam. It is not an authentication system or a fraud engine. It is a privacy-preserving behavioral signal you request at the moment a person is about to do something risky, so your app can slow things down instead of quietly trusting a valid tap from an unsafe context.

The API is beta in the iOS 27 SDK, so treat exact type names as the current shape rather than a forever contract.

## What it detects

The first available insight is `IsLikelyBeingCoachedInsight`. It looks for signs someone may be coached in real time during flows like:

- sending money to a new recipient
- changing a recovery email, phone number, or passkey
- authorizing a new device or granting remote access
- exporting personal data or sending sensitive documents
- consuming costly resources, like paid AI inference

Apple's design intent: notice a risk pattern and create space, not shame the user or block on the app's authority alone.

## Enable the capability

Trust Insights requires the `com.apple.developer.trustinsights.base` entitlement. In Xcode, enable the **Trust Insights** capability on the app target that requests evaluations. Users control the feature in Settings, and a cooldown may apply after they disable it — treat denial as an ordinary product state, not an error to nag about.

## Map your flows to an operation category

The category isn't just logging metadata — it changes the model logic used for evaluation. Five categories exist today: `payment`, `account`, `resourceUse`, `communication`, and `other`.

```swift
import TrustInsights

@available(iOS 27.0, *)
enum SensitiveOperation {
    case newRecipientTransfer
    case changeRecoveryEmail
    case runExpensiveInferenceJob

    var trustCategory: InsightEvaluator.OperationCategory {
        switch self {
        case .newRecipientTransfer: return .payment
        case .changeRecoveryEmail: return .account
        case .runExpensiveInferenceJob: return .resourceUse
        }
    }
}
```

## Request authorization, then evaluate

Check authorization, build the request and context, then evaluate — asynchronously, since it can take a few seconds and needs network reachability. Call it from a review or confirmation screen, not the final commit step.

```swift
import TrustInsights

@available(iOS 27.0, *)
struct CoachingRiskEvaluator {
    enum Result {
        case unavailable, noAdditionalSignal, addLightFriction, addStrongFriction
    }

    private let evaluator = InsightEvaluator()

    func evaluate(operation: SensitiveOperation) async -> Result {
        let request = IsLikelyBeingCoachedInsight.request(schema: .version1, modelVersion: .current)
        let context = InsightEvaluator.InsightContext(
            operationCategory: operation.trustCategory,
            requestedEvaluations: request
        )

        do {
            guard try await evaluator.requestAuthorization(for: context) == .authorized else {
                return .unavailable
            }
            let assessment = try await evaluator.requestEvaluation(context: context)
            switch try assessment.insight.outcome.get() {
            case .unknown:
                assessment.reportConsumption(.usedUnchangedFriction)
                return .noAdditionalSignal
            case .medium:
                assessment.reportConsumption(.usedIncreasedFriction)
                return .addLightFriction
            case .high:
                assessment.reportConsumption(.usedIncreasedFriction)
                return .addStrongFriction
            @unknown default:
                assessment.reportConsumption(.notUsedError)
                return .unavailable
            }
        } catch {
            return .unavailable
        }
    }
}
```

## `unknown` is not `safe`

The outcome has three values: `unknown` (no evidence found), `medium`, and `high`. `unknown` means the system found no coaching evidence in *this* evaluation — it does not vouch for the recipient or the transaction. Name your app-level result `noAdditionalSignal`, not `lowRisk`, so nobody later writes `if trustInsight == .unknown { approveTransfer() }`. Trust Insights is one input alongside your existing fraud and risk checks, never the sole gate.

## Always report consumption

Call `reportConsumption` on every returned evaluation, even when it didn't change the flow — omitting feedback can lead to rate limiting. Use `.usedIncreasedFriction`, `.usedUnchangedFriction`, `.usedReducedFriction`, `.notUsedNotNeeded` (user canceled), or `.notUsedError` (timeout or technical failure) to describe what actually happened.

## Design friction, not fear

For `medium`, add a short delay, a plain-language scam warning, or an out-of-band recipient check. For `high`, require verification, hold for manual review, or offer a direct support path. Keep copy calm:

```
Take a moment before continuing.
Scammers sometimes stay on a call or chat and guide people through transfers.
If someone is telling you to keep this secret, pause and contact support or
the recipient through a trusted channel.
```

## Best Practices

Only request evaluation in flows where the signal can genuinely change the outcome — don't sprinkle it across the whole app. Call `authorizationStatus(for:)` before prompting so you can show your own short explanation ahead of the system dialog. Test every path in Xcode's sandbox override, including authorization-denied, network timeout, `unknown`, `medium`, `high`, and result-arrives-after-cancel. If you submit offline fraud labels through Apple Business Register, store only an opaque `insightID` and your own `operationID` — never recipient names, emails, or memo text — and keep that audit trail separate from general analytics.

## References

- [Meet Trust Insights — WWDC26](https://developer.apple.com/videos/play/wwdc2026/379/)
- [TrustInsights documentation](https://developer.apple.com/documentation/TrustInsights)
- [Trust Insights: Detect Coerced Actions In Sensitive iOS Flows — The Swift Dev](https://www.theswift.dev/posts/trust-insights-sensitive-ios-flows)
