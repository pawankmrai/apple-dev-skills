---
topic: UIKit and AppKit Interop with SwiftUI
date: 2026-05-14
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# UIKit and AppKit Interop with SwiftUI

Most production apps need to mix SwiftUI with UIKit (iOS) or AppKit (macOS). Apple provides bridging APIs in both directions — embedding UIKit views inside SwiftUI and hosting SwiftUI views inside UIKit view controllers.

## Wrapping UIKit Views with UIViewRepresentable

Use `UIViewRepresentable` to bring any `UIView` subclass into SwiftUI:

```swift
import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.region = mapView.region
        }
    }
}
```

The Coordinator pattern bridges UIKit's delegate model to SwiftUI's declarative data flow.

## Wrapping UIKit View Controllers

Use `UIViewControllerRepresentable` for full view controllers like `UIImagePickerController`:

```swift
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.dismiss()
        }
    }
}
```

## Hosting SwiftUI in UIKit

Use `UIHostingController` to embed SwiftUI views inside a UIKit-based app:

```swift
class SettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = SettingsView()
        let hostingController = UIHostingController(rootView: swiftUIView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}
```

## Inline UIHostingConfiguration for UIKit Cells

For table and collection view cells, use `UIHostingConfiguration` to avoid the overhead of a full hosting controller:

```swift
class RecipeCell: UICollectionViewCell {
    func configure(with recipe: Recipe) {
        contentConfiguration = UIHostingConfiguration {
            HStack {
                Image(systemName: recipe.icon)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text(recipe.name).font(.headline)
                    Text(recipe.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
```

## AppKit Interop (macOS)

The macOS equivalents are `NSViewRepresentable` and `NSViewControllerRepresentable`:

```swift
struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}
```

## Best Practices

- **Start new screens in SwiftUI** — only bridge UIKit when SwiftUI lacks the capability you need (e.g., advanced `UICollectionView` layouts, `MKMapView`).
- **Use Coordinators for delegates** — they're the bridge between UIKit's delegate pattern and SwiftUI's state model.
- **Avoid over-wrapping** — if you only need a simple UIKit view, check whether SwiftUI has an equivalent first (`Map`, `PhotosPicker`, etc.).
- **Use `UIHostingConfiguration`** for cells in UIKit collection/table views — it's lighter than `UIHostingController`.
- **Keep data flow unidirectional** — pass `@Binding` into representables; use coordinators to push UIKit events back up.
- **Manage lifecycle carefully** — `makeUIView` is called once; `updateUIView` is called on every state change. Don't recreate expensive objects in `updateUIView`.

## References

- [UIViewRepresentable | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)
- [UIHostingController | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/uihostingcontroller)
- [UIHostingConfiguration | Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/uihostingconfiguration)
