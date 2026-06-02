---
topic: Swift Package Plugins — Build Tools and Custom Commands
date: 2026-06-02
platform: iOS 26, macOS 26
swift: "6.2"
difficulty: intermediate
---

# Swift Package Plugins — Build Tools and Custom Commands

Swift Package Manager plugins let you run custom scripts and tools as part of your build process or on demand from the command line. Instead of fragile Run Script phases in Xcode, you define plugins in Swift that integrate cleanly with SPM and Xcode. There are two flavors: **build tool plugins** that run automatically during compilation, and **command plugins** that you invoke manually.

## Build Tool Plugins

Build tool plugins generate source files or resources before compilation. A common use case is code generation — turning `.proto` files, asset catalogs, or JSON schemas into Swift code.

### Package Layout

```
MyPackage/
├── Package.swift
├── Plugins/
│   └── GenerateConstants/
│       └── GenerateConstants.swift
├── Sources/
│   └── MyApp/
│       ├── constants.json
│       └── main.swift
```

### Defining the Plugin in Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyPackage",
    targets: [
        .executableTarget(
            name: "MyApp",
            plugins: [.plugin(name: "GenerateConstants")]
        ),
        .plugin(
            name: "GenerateConstants",
            capability: .buildTool()
        ),
    ]
)
```

### Implementing the Build Tool Plugin

```swift
import PackagePlugin

@main
struct GenerateConstants: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        let jsonFiles = sourceTarget.sourceFiles.filter {
            $0.path.extension == "json"
        }

        return jsonFiles.map { file in
            let outputName = file.path.stem + "Generated.swift"
            let outputPath = context.pluginWorkDirectory
                .appending(outputName)

            return .buildCommand(
                displayName: "Generate \(outputName)",
                executable: .init("/usr/bin/swift"),
                arguments: [
                    "script.swift", // your generator logic
                    "\(file.path)",
                    "\(outputPath)"
                ],
                inputFiles: [file.path],
                outputFiles: [outputPath]
            )
        }
    }
}
```

The build system tracks `inputFiles` and `outputFiles` for incremental builds — the command only reruns when inputs change.

## Command Plugins

Command plugins are manually triggered via `swift package <command>` or Xcode's right-click menu. They're ideal for linting, formatting, documentation generation, or project maintenance tasks.

### Defining a Command Plugin

```swift
// In Package.swift
.plugin(
    name: "FormatCode",
    capability: .command(
        intent: .sourceCodeFormatting(),
        permissions: [
            .writeToPackageDirectory(
                reason: "Format Swift source files in place"
            )
        ]
    )
)
```

### Implementing the Command

```swift
import PackagePlugin
import Foundation

@main
struct FormatCode: CommandPlugin {
    func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        let swiftFormat = try context.tool(named: "swift-format")

        let sourceFiles = context.package.targets
            .compactMap { $0 as? SourceModuleTarget }
            .flatMap { $0.sourceFiles }
            .filter { $0.path.extension == "swift" }
            .map { $0.path.string }

        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: swiftFormat.path.string
        )
        process.arguments = ["--in-place"] + sourceFiles
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            Diagnostics.error("swift-format failed")
            return
        }
        print("Formatted \(sourceFiles.count) files.")
    }
}
```

Run it with:

```bash
swift package format-code
```

## Xcode Integration

Build tool plugins run automatically in Xcode — just add the plugin dependency to your target. Command plugins appear under **File → Packages** in Xcode's menu bar, or via right-clicking a package in the navigator.

## Pre-Build and Post-Build Actions

SPM also supports `prebuildCommand` for tasks that must discover outputs at build time (when you can't predict output filenames ahead of time):

```swift
return [.prebuildCommand(
    displayName: "Generate Localizations",
    executable: try context.tool(named: "gen-strings").path,
    arguments: ["--output-dir", "\(context.pluginWorkDirectory)"],
    outputFilesDirectory: context.pluginWorkDirectory
)]
```

## Best Practices

- **Prefer build tool plugins over Run Script phases**: They're portable, cacheable, and work with `swift build` outside Xcode.
- **Declare inputs and outputs precisely**: This enables incremental builds and avoids unnecessary re-execution.
- **Use `prebuildCommand` sparingly**: Only when output filenames aren't known at plugin evaluation time — it bypasses the build system's incremental logic.
- **Request only needed permissions**: Command plugins must explicitly declare `writeToPackageDirectory`; the user confirms at runtime.
- **Bundle executables as dependencies**: Reference code generation tools as binary targets or package dependencies rather than hardcoding paths.
- **Test plugins in isolation**: Create a minimal fixture package that exercises your plugin to catch regressions early.

## References

- [Swift.org: Writing a Build Tool Plugin](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/writingbuildtoolplugin/)
- [Swift.org: Writing a Command Plugin](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/writingcommandplugin/)
- [Swift.org: Plugins Overview](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/plugins/)
- [WWDC 2022: Meet Swift Package plugins](https://developer.apple.com/videos/play/wwdc2022/110359/)
