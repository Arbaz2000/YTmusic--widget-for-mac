import Foundation

final class TrackStore {
    static let shared = TrackStore()

    let suiteName: String
    private let userDefaults: UserDefaults?

    private init() {
        // Read the expanded team-prefixed identifier from Info.plist
        if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           !id.isEmpty, !id.contains("$") {
            self.suiteName = id
        } else {
            self.suiteName = "33Z2BF7995.group.local.ytmcompanion"
        }
        self.userDefaults = UserDefaults(suiteName: self.suiteName)
    }

    func saveTrack(_ track: TrackData) {
        guard let encoded = try? JSONEncoder().encode(track) else { return }

        // 1. Write to App Group UserDefaults
        userDefaults?.set(encoded, forKey: "currentTrack")

        // 2. Also write to App Group container file as backup
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let fileURL = containerURL.appendingPathComponent("currentTrack.json")
            try? encoded.write(to: fileURL)
        }
    }

    func loadTrack() -> TrackData {
        // 1. Try App Group UserDefaults
        if let data = userDefaults?.data(forKey: "currentTrack"),
           let track = try? JSONDecoder().decode(TrackData.self, from: data) {
            return track
        }

        // 2. Try App Group container file
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let fileURL = containerURL.appendingPathComponent("currentTrack.json")
            if let data = try? Data(contentsOf: fileURL),
               let track = try? JSONDecoder().decode(TrackData.self, from: data) {
                return track
            }
        }

        return .placeholder
    }
}
