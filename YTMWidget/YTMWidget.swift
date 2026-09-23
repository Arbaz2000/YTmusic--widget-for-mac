import WidgetKit
import SwiftUI

// MARK: – Timeline Entry

struct TrackEntry: TimelineEntry {
    let date: Date
    let trackData: TrackData
}

// MARK: – Timeline Provider

struct YTMWidgetProvider: TimelineProvider {

    private let userDefaults = UserDefaults(suiteName: "group.local.ytmcompanion")

    func placeholder(in context: Context) -> TrackEntry {
        TrackEntry(date: .now, trackData: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackEntry) -> Void) {
        completion(TrackEntry(date: .now, trackData: loadTrackData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackEntry>) -> Void) {
        let entry = TrackEntry(date: .now, trackData: loadTrackData())
        // .never — the companion app calls WidgetCenter.shared.reloadAllTimelines()
        // every 3 seconds, so the widget never needs to self-refresh.
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    private func loadTrackData() -> TrackData {
        guard let data = userDefaults?.data(forKey: "currentTrack"),
              let track = try? JSONDecoder().decode(TrackData.self, from: data) else {
            return .placeholder
        }
        return track
    }
}

// MARK: – Widget Configuration

struct YTMWidget: Widget {
    let kind = "YTMWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YTMWidgetProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("YTMusic Now Playing")
        .description("Shows the currently playing track from YTMusic Desktop.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
