---
topic: Xcode 27 Device Hub — Unified Simulator and Device Management
date: 2026-07-16
platform: Xcode 27, iOS 26
swift: "6.2"
difficulty: intermediate
---

# Xcode 27 Device Hub — Unified Simulator and Device Management

Xcode 27 replaces `Simulator.app` with **Device Hub**, a standalone app (also bundled with Xcode) that manages physical devices and simulators from one interface. The bigger change is under the hood: `devicectl`, previously limited to physical devices, now drives simulators too. That means the same script and the same JSON output shape work whether you're pointed at a paired iPhone or a booted simulator — a real win for anyone maintaining CI scripts that previously had to branch between `devicectl` and `simctl`.

## The Device Hub interface

Device Hub has three panes: a sidebar listing every simulator and paired physical device, a canvas showing a live interactive screen, and an inspector with five panels — settings (appearance, text size, simulated location), diagnostics (crash logs, hangs, spins), device info, app management (including data containers), and profiles. Settings changes in the inspector apply instantly, without opening the device's own Settings app, which makes reproducing bugs that depend on a specific combination (landscape + large text + a spoofed location, say) a matter of seconds instead of minutes.

## devicectl now speaks simulator

Most of what `devicectl` can do with simulators, `simctl` already did. The value is a single, consistent syntax — and `--json-output` — across both device kinds:

```bash
#!/bin/bash
# pre-test-setup.sh — works against a physical device or a booted simulator
set -e

TMPFILE=$(mktemp)
devicectl list devices --json-output "$TMPFILE"
UDID=$(jq -r '.result.devices[]
    | select(.deviceProperties.name == "iPhone 16")
    | .hardwareProperties.udid' "$TMPFILE")
rm "$TMPFILE"

devicectl device settings appearance --device "$UDID" --mode dark

devicectl device simulate location coordinate --device "$UDID" \
  --latitude 51.5074 --longitude -0.1278

# New for simulators — no simctl equivalent
devicectl device orientation set --device "$UDID" landscapeLeft
devicectl device settings biometrics --device "$UDID" --enable
```

Resolving the UDID by device name up front means the same script targets a lab iPhone locally and a CI simulator without edits — swap the `select()` predicate or pass the name as a parameter.

## Capabilities simctl never had

A handful of `devicectl` subcommands have no `simctl` equivalent, because they were built for physical-device debugging. In Xcode 27 they're being extended to simulators, though several are still beta-limited:

```bash
# Query display characteristics (bounds, scale, native size)
devicectl device info displays --device "$UDID"

# Simulate a biometric match or failure for Face ID / Touch ID flows
devicectl device simulate biometrics --device "$UDID" --success

# Trigger a memory-pressure event on a running process
devicectl device process sendMemoryWarning --device "$UDID" --pid 1234

# Resizable-app sessions on an iPad simulator (Stage Manager-style resizing)
devicectl device appResize start --device "$UDID" --bundle-id com.example.App
```

As of the Xcode 27 betas, a few `devicectl` simulator paths still error out and fall back to `simctl` or the Finder: `device copy to/from`, `device info files`, `device info lockState`, and `device profile install/list/remove/validate`. Apple's direction is clearly toward full parity, but don't assume every subcommand works on simulators yet — test the specific command in your CI image before relying on it.

## Using Device Hub in a CI script

A typical pre-test step now looks the same regardless of runner target:

```bash
#!/bin/bash
set -euo pipefail

DEVICE_NAME="${TEST_DEVICE_NAME:-iPhone 16}"
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

devicectl list devices --json-output "$TMPFILE"
UDID=$(jq -r --arg name "$DEVICE_NAME" \
  '.result.devices[] | select(.deviceProperties.name == $name) | .hardwareProperties.udid' \
  "$TMPFILE")

if [ -z "$UDID" ]; then
  echo "No device matching '$DEVICE_NAME' found" >&2
  exit 1
fi

devicectl device settings appearance --device "$UDID" --mode light
devicectl device settings biometrics --device "$UDID" --enable
```

Locking in appearance, text size, and locale before every run removes an entire class of flaky failures caused by whatever state a simulator happened to boot into.

## Best Practices

Prefer `devicectl` over `simctl` for new automation so scripts work unchanged against physical devices in a device lab and simulators in CI. Always resolve UDIDs by name with `--json-output` rather than hardcoding them, since simulator UDIDs regenerate when a runtime is reinstalled. Keep a `simctl` fallback path for the small set of subcommands still marked beta-only for simulators, and re-test that list against each new Xcode 27 beta since Apple is actively closing the gap. Use Device Hub's inspector locally first to build a mental model of a setting before scripting it — the panel you'd click maps almost one-to-one to the `devicectl` subcommand you'd call.

## References

- [Device Hub — Apple Developer Documentation](https://developer.apple.com/documentation/xcode/device-hub)
- [Get the most out of Device Hub — WWDC26](https://developer.apple.com/videos/play/wwdc2026/260/)
- [Xcode 27 Extends Agent Integration, Revamps UI, and Introduces DeviceHub — InfoQ](https://www.infoq.com/news/2026/06/xcode-27-agents-device-hub/)
- [WWDC 2026: Device Hub and what it means for CI/CD — Bitrise Blog](https://bitrise.io/blog/post/wwdc-2026-device-hub-and-what-it-means-for-ci-cd)
