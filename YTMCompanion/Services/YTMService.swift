import Foundation
import AppKit
import WidgetKit
import Combine

/// Polls the YTMDesktop Companion Server every 3 seconds,
/// parses the current track state, downloads cover art,
/// and pushes the data to the shared App Group UserDefaults
/// so the WidgetKit extension can read it.
final class YTMService: ObservableObject {

    // MARK: – Published state

    @Published var currentTrack: TrackData = .placeholder
    @Published var isConnected: Bool = false

    // MARK: – Private

    private var timer: Timer?
    private let apiURL = URL(string: "http://localhost:9863/api/v1/state")!
    private let session: URLSession

    /// Cache the last cover URL so we don't re-download the same image every cycle.
    private var lastCoverURL: String?
    private var cachedCoverData: Data?

    // MARK: – Lifecycle

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: – Polling

    func startPolling() {
        timer?.invalidate()
        fetchState()  // fire immediately
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchState()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: – Fetch

    private func fetchState() {
        let request = URLRequest(url: apiURL)

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if error != nil {
                DispatchQueue.main.async { self.isConnected = false }
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { self.isConnected = false }
                return
            }

            DispatchQueue.main.async { self.isConnected = true }
            self.parseAndSave(json: json)
        }.resume()
    }

    // MARK: – Parse

    private func parseAndSave(json: [String: Any]) {
        let player = json["player"] as? [String: Any]
        let video  = json["video"]  as? [String: Any]

        let title      = video?["title"]  as? String ?? "Unknown Title"
        let author     = video?["author"] as? String ?? "Unknown Artist"
        let trackState = player?["trackState"] as? Int ?? 0
        let isPlaying  = trackState == 1

        // Resolve the highest-resolution thumbnail URL.
        var coverURL: String?
        if let thumbnails = video?["thumbnails"] as? [[String: Any]],
           let best = thumbnails.last,
           let url = best["url"] as? String {
            coverURL = url
        }

        // Re-use cached cover data if the URL hasn't changed.
        if let coverURL, coverURL == lastCoverURL, let cached = cachedCoverData {
            let trackData = TrackData(title: title, author: author,
                                     coverData: cached, isPlaying: isPlaying)
            commit(trackData)
            return
        }

        // Download new cover image.
        if let coverURL, let url = URL(string: coverURL) {
            session.dataTask(with: url) { [weak self] imageData, _, _ in
                guard let self else { return }
                self.lastCoverURL = coverURL
                self.cachedCoverData = imageData
                let trackData = TrackData(title: title, author: author,
                                         coverData: imageData, isPlaying: isPlaying)
                self.commit(trackData)
            }.resume()
        } else {
            let trackData = TrackData(title: title, author: author,
                                     coverData: nil, isPlaying: isPlaying)
            commit(trackData)
        }
    }

    // MARK: – Commit to UserDefaults & Reload Widget

    private func commit(_ trackData: TrackData) {
        DispatchQueue.main.async {
            self.currentTrack = trackData
        }

        TrackStore.shared.saveTrack(trackData)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
