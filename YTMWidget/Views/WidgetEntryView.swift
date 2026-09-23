import SwiftUI
import WidgetKit
import AppIntents

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

    // MARK: – Small Widget (album art full-bleed + text overlay + controls)

    private var smallWidget: some View {
        ZStack {
            coverBackground

            VStack(alignment: .leading) {
                Spacer()

                VStack(alignment: .leading, spacing: 3) {
                    if entry.trackData.isPlaying {
                        nowPlayingBadge(fontSize: 8)
                    }

                    Text(entry.trackData.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text(entry.trackData.author)
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.8)
                        .lineLimit(1)

                    // Interactive controls
                    HStack(spacing: 10) {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)

                        Button(intent: PlayPauseIntent()) {
                            Image(systemName: entry.trackData.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.red))
                        }
                        .buttonStyle(.plain)

                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .foregroundColor(.white)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    // MARK: – Medium Widget (art left + info right + interactive controls)

    private var mediumWidget: some View {
        HStack(spacing: 14) {
            // Album art
            if let coverData = entry.trackData.coverData,
               let nsImage = NSImage(data: coverData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 115, height: 115)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
            } else {
                placeholderArt(size: 115)
            }

            // Track info and controls
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if entry.trackData.isPlaying {
                        nowPlayingBadge(fontSize: 9)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Text("PAUSED")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "music.note.tv")
                            .font(.system(size: 9))
                        Text("YTM")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.4))
                }

                Text(entry.trackData.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(entry.trackData.author)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                Spacer(minLength: 2)

                // Interactive Playback Controls
                HStack(spacing: 16) {
                    Button(intent: PreviousTrackIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: entry.trackData.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.red))
                            .shadow(color: .red.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    Button(intent: NextTrackIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
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
