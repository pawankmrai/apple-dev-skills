---
topic: NowPlaying Framework — Media Sessions for System Surfaces
date: 2026-06-12
platform: iOS 26, macOS 26, tvOS 26, watchOS 26, visionOS 26
swift: "6.2"
difficulty: intermediate
---

# NowPlaying Framework — Media Sessions for System Surfaces

Introduced at WWDC 2026, the `NowPlaying` framework is a modern Swift replacement for `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`. It lets your app connect media playback to system surfaces — the Lock Screen, Control Center, Dynamic Island, and CarPlay — using an observable, protocol-based API.

## Why NowPlaying?

Before iOS 26, surfacing media info required populating a `[String: Any]` dictionary and manually registering remote command handlers. The new `NowPlaying` framework brings:

- **Protocol conformance** — `MediaSessionRepresentable` describes exactly what the system needs
- **Observable model** — the system reacts automatically when your `@Observable` model changes
- **Typed content** — `MusicContent`, `PodcastContent`, and `GenericContent` replace stringly-typed dictionaries
- **Remote sessions** — represent playback happening on external devices (smart speakers, AirPlay targets)

## Adopting MediaSessionRepresentable

Conform your existing player model to `MediaSessionRepresentable`:

```swift
import NowPlaying
import Observation

@Observable
final class PlayerModel: MediaSessionRepresentable {
    let player: AudioPlayer
    var track: Track { player.currentTrack }

    // Stable identifier for this session
    var id: String { "my-app-playback-session" }

    // Describes what is currently playing
    var content: (any MediaContentRepresentable)? {
        MusicContent(
            id: track.id,
            title: track.title,
            artist: track.artist,
            albumTitle: track.album,
            duration: .finite(track.duration),
            artwork: Artwork(id: track.id) { size in
                let data = try await self.loadArtwork(size: size)
                return try ArtworkRepresentation(data: data)
            }
        )
    }

    // Current playback state
    var playbackSnapshot: MediaPlaybackSnapshot? {
        MediaPlaybackSnapshot(
            state: player.isPlaying ? .playing(position: player.currentTime) : .paused,
            playbackRate: player.rate
        )
    }

    // Commands the system can send back
    var commands: [MediaCommand] {[
        .play  { self.player.play() },
        .pause { self.player.pause() },
        .previous { self.player.skipToPrevious() },
        .next     { self.player.skipToNext() },
        .seek { time in self.player.seek(to: time) }
    ]}
}
```

## Starting a Media Session

Create a `MediaSession` once — it activates automatically when your model's `content` becomes non-nil:

```swift
import NowPlaying

struct AppEnvironment {
    let player: AudioPlayer
    let model: PlayerModel
    let session: MediaSession<PlayerModel>

    init() {
        self.player = AudioPlayer()
        self.model  = PlayerModel(player: player)
        self.session = MediaSession(model)   // retains the session
    }
}
```

The session observes your `@Observable` model and pushes updates to system surfaces automatically. No manual `MPNowPlayingInfoCenter.default().nowPlayingInfo = ...` calls needed.

## Podcast and Generic Content

Use the right content type for the media category:

```swift
// Podcast
var content: (any MediaContentRepresentable)? {
    PodcastContent(
        id: episode.id,
        title: episode.title,
        showTitle: episode.show,
        duration: .finite(episode.duration),
        artwork: Artwork(id: episode.showID) { _ in ... }
    )
}

// Anything else (ambient sound, audiobook, etc.)
var content: (any MediaContentRepresentable)? {
    GenericContent(
        id: sound.id,
        title: sound.name,
        subtitle: sound.category,
        type: .audio,
        duration: .live,          // stream with no fixed end
        artwork: Artwork(id: sound.id) { _ in ... }
    )
}
```

## Remote Media Sessions

When your app controls playback on an external device (e.g., a smart speaker via a proprietary SDK), create an **app extension** that conforms to `RemoteMediaSessionExtension`:

```swift
// In your app extension target
import ExtensionFoundation
import NowPlaying

@main
final class SpeakerExtension: @MainActor RemoteMediaSessionExtension {
    var configuration: some AppExtensionConfiguration {
        RemoteMediaSessionExtensionConfiguration(extension: self)
    }
    var extensionPoint: AppExtensionPoint {
        AppExtensionPoint.Identifier(host: "com.apple.nowplaying", name: "remote-media")
    }
    func session(_ state: RemotePlayerState) async throws -> RemotePlayerModel {
        RemotePlayerModel(state: state)
    }
}
```

Conform your remote model to `RemoteMediaSessionRepresentable`, adding `devices` to expose volume controls:

```swift
extension RemotePlayerModel: @MainActor RemoteMediaSessionRepresentable {
    var devices: [MediaDevice] {
        state.speakers.map { speaker in
            MediaDevice(
                id: speaker.id,
                name: speaker.name,
                type: .speaker,
                capabilities: [
                    .absoluteVolume(speaker.volume) { newVolume in
                        try await self.client.setVolume(newVolume, on: speaker.id)
                    }
                ]
            )
        }
    }
}
```

The system pushes `RemotePlayerState` updates via APNs whenever playback changes on the external device.

## Best Practices

- **Retain `MediaSession`** for the lifetime of your player; releasing it removes your app from Now Playing.
- **Use typed content** (`MusicContent`, `PodcastContent`) over `GenericContent` when possible — the system tailors UI (e.g., star ratings for music) to the content type.
- **Set `duration: .live`** for streams with no fixed end; don't fake a duration.
- **Keep commands minimal** — only add commands your player actually supports to avoid the system showing disabled buttons.
- **Test on a locked device** — the Lock Screen and Dynamic Island are invisible in the Simulator's default state; always verify on hardware.
- **Migrate gradually** — the framework coexists with `MPNowPlayingInfoCenter`, so you can adopt it per feature rather than all at once.

## References

- [WWDC 2026: Meet the Now Playing framework](https://developer.apple.com/videos/play/wwdc2026/312/)
- [Publishing media sessions](https://developer.apple.com/documentation/NowPlaying/publishing-media-sessions)
- [Publishing remote media sessions](https://developer.apple.com/documentation/NowPlaying/publishing-remote-media-sessions)
- [Routing media to third-party devices](https://developer.apple.com/documentation/AVSystemRouting/routing-media-to-third-party-devices)
