import Foundation
import AppIntents
import WidgetKit

@available(macOS 14.0, *)
struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var description = IntentDescription("Toggles playback in YouTube Music Desktop.")

    func perform() async throws -> some IntentResult {
        // Optimistic UI update for immediate widget response
        let current = TrackStore.shared.loadTrack()
        if current.title != "Not Playing" {
            let updated = TrackData(
                title: current.title,
                author: current.author,
                coverData: current.coverData,
                isPlaying: !current.isPlaying
            )
            TrackStore.shared.saveTrack(updated)
            WidgetCenter.shared.reloadAllTimelines()
        }

        await withCheckedContinuation { continuation in
            TrackStore.shared.sendPlaybackCommand("playPause") { _ in
                continuation.resume()
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(macOS 14.0, *)
struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skips to the next track in YouTube Music Desktop.")

    func perform() async throws -> some IntentResult {
        await withCheckedContinuation { continuation in
            TrackStore.shared.sendPlaybackCommand("next") { _ in
                continuation.resume()
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

@available(macOS 14.0, *)
struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Skips to the previous track in YouTube Music Desktop.")

    func perform() async throws -> some IntentResult {
        await withCheckedContinuation { continuation in
            TrackStore.shared.sendPlaybackCommand("previous") { _ in
                continuation.resume()
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
