---
topic: UIKit Scene Lifecycle Migration — Adopting UISceneDelegate for iOS 27
date: 2026-10-09
platform: iOS 27, iPadOS 27, Mac Catalyst 27
swift: "6.2"
difficulty: intermediate
---

# UIKit Scene Lifecycle Migration — Adopting UISceneDelegate for iOS 27

Apps built with the iOS 27 SDK must use the scene-based life cycle. What was a console warning in iOS 26 is now a launch-time assertion (pointing at TN3187) for UIKit apps that still own their `UIWindow` in `AppDelegate`. `UIApplicationDelegate` is **not** deprecated — it keeps process-level work (push registration, SDK setup). Everything UI-related moves to `UIWindowSceneDelegate`: window ownership, foreground/background transitions, URL and universal link handling, shortcuts, and state restoration.

The trigger is the SDK you build with, not the OS your users run — so migrate before switching to Xcode 27.

## 1. Declare the Scene Manifest

Add `UIApplicationSceneManifest` to Info.plist. Set `UIApplicationSupportsMultipleScenes` to `false` if you aren't ready for multi-window on iPad.

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

Alternatively, return a `UISceneConfiguration` (with `delegateClass = SceneDelegate.self`) from `application(_:configurationForConnecting:options:)`.

## 2. Move Window Setup into the Scene Delegate

Delete `var window: UIWindow?` from `AppDelegate`. The scene delegate creates the window from the `UIWindowScene`.

```swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let router = DeepLinkRouter()

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: HomeViewController())
        self.window = window
        window.makeKeyAndVisible()

        // Cold-launch entry points arrive here — NOT in AppDelegate.
        if let url = connectionOptions.urlContexts.first?.url { router.open(url) }
        if let activity = connectionOptions.userActivities.first { router.handle(activity) }
        if let item = connectionOptions.shortcutItem { router.handle(item) }
    }
}
```

The most common migration bug: forgetting that launch-time URLs, user activities, and shortcut items are delivered in `connectionOptions`, while warm-launch ones arrive via the methods below.

## 3. Map AppDelegate Callbacks to Scene Equivalents

| AppDelegate (legacy) | UIWindowSceneDelegate |
|---|---|
| `applicationDidBecomeActive` | `sceneDidBecomeActive(_:)` |
| `applicationWillResignActive` | `sceneWillResignActive(_:)` |
| `applicationDidEnterBackground` | `sceneDidEnterBackground(_:)` |
| `applicationWillEnterForeground` | `sceneWillEnterForeground(_:)` |
| `application(_:open:options:)` | `scene(_:openURLContexts:)` |
| `application(_:continue:restorationHandler:)` | `scene(_:continue:)` |
| `application(_:performActionFor:completionHandler:)` | `windowScene(_:performActionFor:completionHandler:)` |

```swift
extension SceneDelegate {
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach { router.open($0.url) }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        router.handle(userActivity)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AppStore.shared.saveDraftsIfNeeded()
    }
}
```

Push notification registration (`didRegisterForRemoteNotificationsWithDeviceToken`) and `UNUserNotificationCenterDelegate` stay app-level — keep them in `AppDelegate`.

## 4. Replace Global Window Lookups

`UIApplication.shared.keyWindow` and `UIApplication.shared.windows` are deprecated and ambiguous with multiple scenes. Derive the window from context instead:

```swift
extension UIViewController {
    var hostWindowScene: UIWindowScene? { view.window?.windowScene }
}

// When there's no view context (e.g. a service presenting an alert):
@MainActor
func activeWindowScene() -> UIWindowScene? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
}
```

Prefer listening to `UIScene.didEnterBackgroundNotification` over `UIApplication.didEnterBackgroundNotification` in view controllers so each window reacts independently.

## 5. State Restoration per Scene

Return an `NSUserActivity` describing the scene so the system can restore it:

```swift
func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    let activity = NSUserActivity(activityType: "com.example.app.viewDocument")
    activity.userInfo = ["documentID": router.currentDocumentID?.uuidString ?? ""]
    return activity
}
```

Read it back in `willConnectTo` via `session.stateRestorationActivity`.

## Best Practices

- **Audit first:** if Info.plist lacks `UIApplicationSceneManifest` and you don't implement `configurationForConnecting`, you must migrate.
- **Test every entry point on cold and warm launch:** URL schemes, universal links, Home Screen quick actions, Handoff, and notification taps.
- **Keep `AppDelegate` lean:** SDK initialization, push token handling, background URLSession events.
- **Opt out of multi-window initially** (`UIApplicationSupportsMultipleScenes = false`), ship the migration, then enable multiple scenes later.
- **SwiftUI-hybrid apps** using `UIHostingController` need the same migration; pure `App`-protocol SwiftUI apps already use scenes.
- **Third-party SDKs** that read `AppDelegate.window` must be updated — check vendor release notes.

## References

- [TN3187: Migrating to the UIKit scene-based life cycle](https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle)
- [Apple Developer Forums — Migrating to the UIKit scene-based life cycle](https://developer.apple.com/forums/thread/820807)
- [UIWindowSceneDelegate documentation](https://developer.apple.com/documentation/uikit/uiwindowscenedelegate)
- [Specifying the scenes your app supports](https://developer.apple.com/documentation/uikit/specifying-the-scenes-your-app-supports)
