import Foundation

/// Shared data model for passing track metadata between
/// the companion app and the WidgetKit extension via App Group UserDefaults.
struct TrackData: Codable {
    let title: String
    let author: String
    let coverData: Data?
    let isPlaying: Bool

    /// Fallback data shown when no track is playing or YTMDesktop is unreachable.
    static let placeholder = TrackData(
        title: "Not Playing",
        author: "YTMusic Desktop",
        coverData: nil,
        isPlaying: false
    )
}
