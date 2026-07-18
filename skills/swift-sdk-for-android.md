---
topic: Swift SDK for Android — Sharing Swift Logic Across Platforms
date: 2026-07-18
platform: Swift 6.3, Android NDK r27d+
swift: "6.3"
difficulty: intermediate
---

# Swift SDK for Android — Sharing Swift Logic Across Platforms

Swift 6.3 shipped the first official Swift SDK for Android, turning a decade of grassroots community work (Readdle's Spark, flowkey, MediQuo) into a supported cross-compilation target. This doesn't make SwiftUI run on Android — the UI layer of an Android app is still Kotlin or Java — but it does let you write business logic, algorithms, and data models once in Swift and share that code between your iOS, macOS, and Android apps, calling into it from Kotlin/Java via JNI.

## How It Works

Swift compiles directly to native ARM64/x86_64 machine code on Android, the same way it does everywhere else, bundling a native runtime with its standard library, Dispatch, and Foundation. Because most Android platform APIs (camera, location, notifications) are only exposed through Java/Kotlin, Swift code calls into the Android Runtime through the Java Native Interface (JNI). The `swift-java` project's `jextract` and `wrap-java` tools generate those JNI bindings automatically in both directions — Swift calling Java, and Java/Kotlin calling into a Swift `.so` library.

## Installing the Toolchain

Cross-compiling for Android needs three pieces installed on your host (macOS or Linux): the open-source Swift toolchain, the Swift SDK bundle for Android, and the Android NDK (LTS r27d or later).

```bash
# 1. Install a matching open-source Swift toolchain with swiftly
swiftly install latest
swiftly use latest
swift --version   # Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)

# 2. Install the Swift SDK for Android
swift sdk install \
  https://download.swift.org/swift-6.3.3-release/android-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_android.artifactbundle.tar.gz \
  --checksum d160cc3206dd1886dae3fef2337af5e25ec034692cd0ec225721c56cc69da7f5

swift sdk list   # swift-6.3.3-RELEASE_android

# 3. Install and wire up the Android NDK (from the SDK's install directory)
cd ~/Library/org.swift.swiftpm/swift-sdks/swift-6.3.3-RELEASE_android.artifactbundle/swift-android/
curl -fSL -o ndk.zip "https://dl.google.com/android/repository/android-ndk-r27d-$(uname -s).zip"
unzip -qo ndk.zip
export ANDROID_NDK_HOME=$PWD/android-ndk-r27d
./scripts/setup-android-sdk.sh
```

## Building and Running "Hello, World"

A standard Swift package cross-compiles to an Android executable by passing `--swift-sdk`:

```bash
swift package init --type executable
swift build   # sanity check on the host

# Cross-compile for a 64-bit ARM device or emulator
swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib

file .build/aarch64-unknown-linux-android28/debug/hello
# ELF 64-bit LSB pie executable, ARM aarch64 ... dynamically linked
```

Push the binary and its C++ runtime dependency to a device with `adb`, then run it:

```bash
adb push .build/aarch64-unknown-linux-android28/debug/hello /data/local/tmp
adb push "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so /data/local/tmp/
adb shell /data/local/tmp/hello
# Hello, world!
```

## Targeting Multiple Android API Levels

Recent Swift 6.3 previews bring the familiar `@available`/`#available` attributes to Android, so a single build can branch on API level at runtime just like it does for iOS deployment targets:

```swift
#if canImport(Android)
import Android
import Dispatch
#endif

@available(Android 33, *)
func logBacktrace() {
    withUnsafeTemporaryAllocation(of: UnsafeMutableRawPointer.self, capacity: 1) { address in
        _ = backtrace(address.baseAddress!, 1)
    }
}

@main
struct ExecutableDemo {
    static func main() {
        #if os(Android)
        print("Hello from Android API 28 or later")
        if #available(Android 33, *) {
            logBacktrace()
            print("Hello from Android API 33+")
        }
        #endif
    }
}
```

## Calling Swift from Kotlin

Real Android apps aren't command-line executables — they're `.apk` archives with a Kotlin or Java UI layer. Build the shared Swift logic as a native `.so` per architecture, then use `swift-java`'s `jextract` in JNI mode to generate the Kotlin-side bindings automatically, rather than hand-writing JNI glue. The generated wrapper lets Kotlin call a Swift function as if it were a local method, with `jextract` handling the marshaling of primitives, strings, and structs across the boundary. See the `swift-java-weather-app` example in the Android Examples repository for a full working reference.

## Best Practices

Keep the split clean: put shared business logic, networking, parsing, and data models in a Swift package built for both platforms, and leave every screen, navigation flow, and platform-specific API call (camera, push notifications, permissions) in Kotlin or Jetpack Compose — the Swift Android workgroup deliberately isn't shipping a GUI toolkit. Pin the open-source toolchain version to match the installed Swift SDK bundle exactly; a mismatch is the most common source of cross-compilation failures. Use `--static-swift-stdlib` for standalone executables so you don't have to ship the Swift runtime separately, but for app-embedded `.so` libraries follow the swift-java packaging guidance instead. Wire the official Android GitHub Actions workflow into CI so every package build is validated against the Android SDK on every commit, not just on your own machine. Because Android debugger support is still an active work item for the workgroup, keep logic units small and well-tested on the host platform with Swift Testing before cross-compiling, rather than relying on on-device debugging.

## References

- [Getting Started with the Swift SDK for Android](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)
- [Exploring the Swift SDK for Android](https://www.swift.org/blog/exploring-the-swift-sdk-for-android/)
- [swift-java interoperability project](https://github.com/swiftlang/swift-java)
- [Swift Android Examples repository](https://github.com/swiftlang/swift-android-examples)
- [Swift Evolution: Android platform vision document](https://github.com/swiftlang/swift-evolution/blob/main/visions/android.md)
