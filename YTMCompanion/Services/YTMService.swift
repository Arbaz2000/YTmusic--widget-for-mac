import Foundation
import AppKit
import WidgetKit
import Combine

/// Polls the YTMDesktop Companion Server every 3 seconds,
/// handles authentication/pairing with YTMDesktop,
/// parses track state, and pushes data to the shared App Group.
final class YTMService: ObservableObject {

    // MARK: – Published state

    @Published var currentTrack: TrackData = .placeholder
    @Published var isConnected: Bool = false
    @Published var needsAuthorization: Bool = false
    @Published var isAuthorizing: Bool = false
    @Published var authStatusMessage: String? = nil
    @Published var pairingCode: String? = nil

    // MARK: – Private

    private var timer: Timer?
    private let apiURL = URL(string: "http://localhost:9863/api/v1/state")!
    private let authRequestCodeURL = URL(string: "http://localhost:9863/api/v1/auth/requestcode")!
    private let authRequestURL = URL(string: "http://localhost:9863/api/v1/auth/request")!
    private let session: URLSession
    private let authSession: URLSession

    private let tokenKey = "ytm_companion_auth_token"
    private var authToken: String?

    /// Cache the last cover URL so we don't re-download the same image every cycle.
    private var lastCoverURL: String?
    private var cachedCoverData: Data?

    // MARK: – Lifecycle

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)

        // Longer timeout for auth since user has up to 30s to approve the prompt
        let authConfig = URLSessionConfiguration.default
        authConfig.timeoutIntervalForRequest = 40
        authConfig.timeoutIntervalForResource = 45
        self.authSession = URLSession(configuration: authConfig)

        self.authToken = TrackStore.shared.loadAuthToken() ?? UserDefaults.standard.string(forKey: tokenKey)
        if let token = self.authToken, !token.isEmpty {
            TrackStore.shared.saveAuthToken(token)
        } else {
            self.needsAuthorization = true
        }

        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: – Polling

    func startPolling() {
        timer?.invalidate()
        fetchState()
        // Poll every 5.2 seconds to stay safely within YTMDesktop's 5.0-second rate limit
        timer = Timer.scheduledTimer(withTimeInterval: 5.2, repeats: true) { [weak self] _ in
            self?.fetchState()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: – Fetch State

    func fetchState() {
        var request = URLRequest(url: apiURL)
        if let token = authToken, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 4.0

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.needsAuthorization = true
                        if self.authStatusMessage == nil {
                            self.authStatusMessage = "Authorization required to connect."
                        }
                    }
                    return
                }

                // If rate limited (HTTP 429), silently skip this cycle without wiping state
                if httpResponse.statusCode == 429 {
                    return
                }

                // Require HTTP 200 OK
                guard httpResponse.statusCode == 200 else {
                    return
                }
            }

            if error != nil {
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                return
            }

            // Ensure JSON contains track/player/video data before parsing
            guard json["player"] != nil || json["video"] != nil || json["track"] != nil else {
                return
            }

            DispatchQueue.main.async {
                self.isConnected = true
                self.needsAuthorization = false
            }
            self.parseAndSave(json: json)
        }.resume()
    }

    // MARK: – Authorization Flow

    func requestAuthorization() {
        guard !isAuthorizing else { return }

        DispatchQueue.main.async {
            self.isAuthorizing = true
            self.pairingCode = nil
            self.authStatusMessage = "Requesting pairing code from YouTube Music Desktop App..."
        }

        var reqCodeRequest = URLRequest(url: authRequestCodeURL)
        reqCodeRequest.httpMethod = "POST"
        reqCodeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let codeBody: [String: String] = [
            "appId": "ytmcompanion",
            "appName": "YTMCompanion",
            "appVersion": "1.0.0"
        ]
        reqCodeRequest.httpBody = try? JSONSerialization.data(withJSONObject: codeBody)

        authSession.dataTask(with: reqCodeRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
                DispatchQueue.main.async {
                    self.isAuthorizing = false
                    self.authStatusMessage = "Pairing is disabled in YTMDesktop. Please turn ON 'Enable companion authorization' in YTMDesktop Settings > Integrations first."
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawCode = json["code"] else {
                DispatchQueue.main.async {
                    self.isAuthorizing = false
                    self.authStatusMessage = "Failed to obtain pairing code. Make sure YTMDesktop is running with Companion Server enabled."
                }
                return
            }

            let codeString = "\(rawCode)"
            DispatchQueue.main.async {
                self.pairingCode = codeString
                self.authStatusMessage = "Popup opened in YTMDesktop. Please click 'Authorize' to approve (Code: \(codeString))."
            }

            self.exchangeCodeForToken(code: codeString)
        }.resume()
    }

    private func exchangeCodeForToken(code: String) {
        var tokenRequest = URLRequest(url: authRequestURL)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let tokenBody: [String: String] = [
            "appId": "ytmcompanion",
            "code": code
        ]
        tokenRequest.httpBody = try? JSONSerialization.data(withJSONObject: tokenBody)

        authSession.dataTask(with: tokenRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["token"] as? String else {
                DispatchQueue.main.async {
                    self.isAuthorizing = false
                    self.authStatusMessage = "Authorization was denied or timed out. Please try again."
                }
                return
            }

            DispatchQueue.main.async {
                self.authToken = token
                UserDefaults.standard.set(token, forKey: self.tokenKey)
                TrackStore.shared.saveAuthToken(token)
                self.isAuthorizing = false
                self.needsAuthorization = false
                self.pairingCode = nil
                self.authStatusMessage = "Connected successfully!"
                self.fetchState()
            }
        }.resume()
    }

    // MARK: – Playback Controls

    func togglePlayPause() {
        // Optimistic UI update
        let updated = TrackData(
            title: currentTrack.title,
            author: currentTrack.author,
            coverData: currentTrack.coverData,
            isPlaying: !currentTrack.isPlaying
        )
        currentTrack = updated
        TrackStore.shared.saveTrack(updated)
        WidgetCenter.shared.reloadAllTimelines()

        TrackStore.shared.sendPlaybackCommand("playPause", explicitToken: authToken) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.fetchState()
            }
        }
    }

    func nextTrack() {
        TrackStore.shared.sendPlaybackCommand("next", explicitToken: authToken) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self?.fetchState()
            }
        }
    }

    func previousTrack() {
        TrackStore.shared.sendPlaybackCommand("previous", explicitToken: authToken) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self?.fetchState()
            }
        }
    }

    // MARK: – Parse & Commit

    private func parseAndSave(json: [String: Any]) {
        let player = json["player"] as? [String: Any]
        let trackState = player?["trackState"] as? Int ?? 0
        let isPlaying = trackState == 1

        // 1. Check root "video" object
        let video = json["video"] as? [String: Any]
        let videoTitle = (video?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let videoAuthor = ((video?["author"] as? String) ?? (video?["artist"] as? String) ?? (video?["uploader"] as? String))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let videoThumbnails = video?["thumbnails"] as? [[String: Any]]

        // 2. Check "player" -> "queue" -> "items" (selected track)
        let queue = player?["queue"] as? [String: Any]
        let queueItems = (queue?["items"] as? [[String: Any]]) ?? []
        var queueSelectedTrack: [String: Any]? = queueItems.first(where: { ($0["selected"] as? Bool) == true })
        if queueSelectedTrack == nil, let selectedIndex = queue?["selectedItemIndex"] as? Int, selectedIndex >= 0, selectedIndex < queueItems.count {
            queueSelectedTrack = queueItems[selectedIndex]
        }
        let queueTitle = (queueSelectedTrack?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let queueAuthor = ((queueSelectedTrack?["author"] as? String) ?? (queueSelectedTrack?["artist"] as? String))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let queueThumbnails = queueSelectedTrack?["thumbnails"] as? [[String: Any]]

        // 3. Check alternate root or player "track"
        let altTrack = (json["track"] as? [String: Any]) ?? (player?["track"] as? [String: Any])
        let altTitle = (altTrack?["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let altAuthor = ((altTrack?["author"] as? String) ?? (altTrack?["artist"] as? String))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let altThumbnails = altTrack?["thumbnails"] as? [[String: Any]]

        // Combine with fallback priority
        let rawTitle = [videoTitle, queueTitle, altTitle].compactMap { $0 }.first(where: { !$0.isEmpty })
        let rawAuthor = [videoAuthor, queueAuthor, altAuthor].compactMap { $0 }.first(where: { !$0.isEmpty })
        let thumbnails = videoThumbnails ?? queueThumbnails ?? altThumbnails

        var resolvedTitle: String
        var resolvedAuthor: String

        if let t = rawTitle, !t.isEmpty {
            resolvedTitle = t
            resolvedAuthor = (rawAuthor != nil && !rawAuthor!.isEmpty) ? rawAuthor! : "YouTube Music"
        } else if self.currentTrack.title != "Not Playing" && self.currentTrack.title != "Unknown Title" {
            // Retain previous known good track during song transitions, pauses, or transient nulls
            resolvedTitle = self.currentTrack.title
            resolvedAuthor = self.currentTrack.author
        } else if isPlaying {
            resolvedTitle = "Unknown Title"
            resolvedAuthor = "Unknown Artist"
        } else {
            resolvedTitle = "Not Playing"
            resolvedAuthor = "YTMusic Desktop"
        }

        // Resolve highest-resolution thumbnail URL
        var coverURL: String?
        if let thumbs = thumbnails, !thumbs.isEmpty {
            let sortedThumbs = thumbs.sorted {
                let w1 = $0["width"] as? Int ?? 0
                let w2 = $1["width"] as? Int ?? 0
                return w1 < w2
            }
            if let best = sortedThumbs.last, let url = best["url"] as? String {
                coverURL = url
            }
        }

        // If no thumbnail available in JSON but retaining active track, reuse cached cover
        if coverURL == nil && resolvedTitle == self.currentTrack.title && self.cachedCoverData != nil {
            let trackData = TrackData(title: resolvedTitle, author: resolvedAuthor,
                                     coverData: self.cachedCoverData, isPlaying: isPlaying)
            commit(trackData)
            return
        }

        // Re-use cached cover data if the URL hasn't changed
        if let coverURL = coverURL, coverURL == lastCoverURL, let cached = cachedCoverData {
            let trackData = TrackData(title: resolvedTitle, author: resolvedAuthor,
                                     coverData: cached, isPlaying: isPlaying)
            commit(trackData)
            return
        }

        // Download new cover image if URL changed
        if let coverURL = coverURL, let url = URL(string: coverURL) {
            session.dataTask(with: url) { [weak self] imageData, _, _ in
                guard let self = self else { return }
                self.lastCoverURL = coverURL
                self.cachedCoverData = imageData
                let trackData = TrackData(title: resolvedTitle, author: resolvedAuthor,
                                         coverData: imageData, isPlaying: isPlaying)
                self.commit(trackData)
            }.resume()
        } else {
            let trackData = TrackData(title: resolvedTitle, author: resolvedAuthor,
                                     coverData: nil, isPlaying: isPlaying)
            commit(trackData)
        }
    }

    // MARK: – Commit to UserDefaults & Reload Widget

    private func commit(_ trackData: TrackData) {
        DispatchQueue.main.async {
            let titleChanged = trackData.title != self.currentTrack.title
            let authorChanged = trackData.author != self.currentTrack.author
            let playStateChanged = trackData.isPlaying != self.currentTrack.isPlaying
            let coverPresenceChanged = (trackData.coverData == nil) != (self.currentTrack.coverData == nil)

            guard titleChanged || authorChanged || playStateChanged || coverPresenceChanged else { return }

            self.currentTrack = trackData
            TrackStore.shared.saveTrack(trackData)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
