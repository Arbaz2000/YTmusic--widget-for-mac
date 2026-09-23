import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: YTMService

    var body: some View {
        ZStack {
            // ── Background gradient ──
            LinearGradient(
                colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f3460")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                headerBar
                Spacer()
                albumArt
                trackInfo
                playingIndicator
                Spacer()
                footerNote
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 460, minHeight: 400, idealHeight: 520)
    }

    // MARK: – Sub-views

    private var headerBar: some View {
        HStack {
            Image(systemName: "music.note.tv")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.red)

            Text("YTM Companion")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            connectionBadge
        }
        .padding(.horizontal)
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(service.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: service.isConnected ? .green.opacity(0.6) : .red.opacity(0.6),
                        radius: 4)

            Text(service.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(Capsule())
    }

    private var albumArt: some View {
        Group {
            if let coverData = service.currentTrack.coverData,
               let nsImage = NSImage(data: coverData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .red.opacity(0.3), radius: 20, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
    }

    private var trackInfo: some View {
        VStack(spacing: 8) {
            Text(service.currentTrack.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(service.currentTrack.author)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var playingIndicator: some View {
        if service.currentTrack.isPlaying {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    EqualizerBar(index: index)
                }
            }
            .frame(height: 24)
        }
    }

    private var footerNote: some View {
        Text("Widget updates every 3 seconds")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.4))
            .padding(.bottom, 8)
    }
}

// MARK: – Animated equaliser bar

private struct EqualizerBar: View {
    let index: Int
    @State private var animating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.red)
            .frame(width: 4, height: animating ? CGFloat(12 + index * 4) : 6)
            .animation(
                .easeInOut(duration: 0.4 + Double(index) * 0.1)
                    .repeatForever(autoreverses: true),
                value: animating
            )
            .onAppear { animating = true }
    }
}

// MARK: – Hex colour helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
