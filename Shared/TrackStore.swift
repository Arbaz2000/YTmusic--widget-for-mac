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

    // MARK: – Auth Token Persistence

    func saveAuthToken(_ token: String) {
        userDefaults?.set(token, forKey: "ytm_companion_auth_token")
        userDefaults?.synchronize()

        // Also write to App Group container file as backup for widget extension
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let fileURL = containerURL.appendingPathComponent("authToken.txt")
            try? token.data(using: .utf8)?.write(to: fileURL)
        }
    }

    func loadAuthToken() -> String? {
        if let token = userDefaults?.string(forKey: "ytm_companion_auth_token"), !token.isEmpty {
            return token
        }

        // Try App Group container file backup
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            let fileURL = containerURL.appendingPathComponent("authToken.txt")
            if let data = try? Data(contentsOf: fileURL),
               let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !token.isEmpty {
                return token
            }
        }

        return nil
    }

    // MARK: – Playback Commands (usable by main app and widget extension)

    func sendPlaybackCommand(_ command: String, explicitToken: String? = nil, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "http://localhost:9863/api/v1/command") else {
            completion?(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3.0

        let token = explicitToken ?? loadAuthToken()
        if let token = token, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["command": command]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                completion?(true)
            } else {
                completion?(false)
            }
        }
        task.resume()
    }
}
