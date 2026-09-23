import SwiftUI
import WidgetKit

struct WidgetEntryView: View {
    var entry: TrackEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: – Small Widget (album art full-bleed + text overlay)

    private var smallWidget: some View {
        ZStack {
            coverBackground

            VStack(alignment: .leading) {
                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    if entry.trackData.isPlaying {
                        nowPlayingBadge(fontSize: 8)
                    }

                    Text(entry.trackData.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(2)

                    Text(entry.trackData.author)
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.8)
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    // MARK: – Medium Widget (art left + info right)

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Album art
            if let coverData = entry.trackData.coverData,
               let nsImage = NSImage(data: coverData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            } else {
                placeholderArt(size: 120)
            }

            // Track info
            VStack(alignment: .leading, spacing: 6) {
                if entry.trackData.isPlaying {
                    nowPlayingBadge(fontSize: 9)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text(entry.trackData.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(entry.trackData.author)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "music.note.tv")
                        .font(.system(size: 10))
                    Text("YTMusic Desktop")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.06, green: 0.13, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: – Shared helpers

    @ViewBuilder
    private var coverBackground: some View {
        if let coverData = entry.trackData.coverData,
           let nsImage = NSImage(data: coverData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.06, green: 0.13, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func placeholderArt(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(.white.opacity(0.3))
            )
    }

    private func nowPlayingBadge(fontSize: CGFloat) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "play.fill")
                .font(.system(size: fontSize))
            Text("NOW PLAYING")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
        }
        .foregroundColor(.red)
    }
}
