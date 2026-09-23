import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: YTMService

    @State private var focusedInfoTab: Int = 0 // 0: All, 1: Title, 2: Artist

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

            VStack(spacing: 16) {
                headerBar

                if service.needsAuthorization || !service.isConnected {
                    authorizationCard
                } else {
                    Spacer()
                    albumArt
                    viewModePicker
                    trackInfo
                    playbackControls
                    playingIndicator
                    Spacer()
                }

                footerNote
            }
            .padding()
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 460, idealHeight: 540)
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

    // MARK: – Authorization Card

    private var authorizationCard: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Authorization Required")
                .font(.title2.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text("1.")
                        .bold()
                        .foregroundColor(.red)
                    Text("Open **YouTube Music Desktop App**, go to **Settings > Integrations**, and turn ON **Enable companion authorization**.")
                        .foregroundColor(.white.opacity(0.85))
                        .font(.callout)
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("2.")
                        .bold()
                        .foregroundColor(.red)
                    Text("Click the **Pair with YTMDesktop** button below.")
                        .foregroundColor(.white.opacity(0.85))
                        .font(.callout)
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("3.")
                        .bold()
                        .foregroundColor(.red)
                    Text("Click **Authorize** on the popup that appears in YouTube Music Desktop App.")
                        .foregroundColor(.white.opacity(0.85))
                        .font(.callout)
                }
            }
            .padding()
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)

            if let message = service.authStatusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(service.isConnected ? .green : .orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                service.requestAuthorization()
            }) {
                HStack(spacing: 8) {
                    if service.isAuthorizing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "link.badge.plus")
                    }
                    Text(service.isAuthorizing ? "Waiting for Approval..." : "Pair with YTMDesktop")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(service.isAuthorizing)

            Spacer()
        }
        .padding(.horizontal, 20)
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

    private var viewModePicker: some View {
        HStack(spacing: 6) {
            ForEach([("All", 0), ("Title Focus", 1), ("Artist Focus", 2)], id: \.1) { label, index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        focusedInfoTab = index
                    }
                }) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(focusedInfoTab == index ? Color.red.opacity(0.85) : Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var trackInfo: some View {
        VStack(spacing: 6) {
            if focusedInfoTab == 0 || focusedInfoTab == 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(service.currentTrack.title)
                        .font(.system(size: focusedInfoTab == 1 ? 22 : 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: 380)
            }

            if focusedInfoTab == 0 || focusedInfoTab == 2 {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(service.currentTrack.author)
                        .font(.system(size: focusedInfoTab == 2 ? 18 : 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: 380)
            }
        }
        .frame(minHeight: 52)
    }

    private var playbackControls: some View {
        HStack(spacing: 24) {
            // Previous Track
            Button(action: {
                service.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("Previous Track")

            // Play / Pause Toggle
            Button(action: {
                service.togglePlayPause()
            }) {
                Image(systemName: service.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color(hex: "b80000")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .help(service.currentTrack.isPlaying ? "Pause" : "Play")

            // Next Track / Move Forward
            Button(action: {
                service.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("Next Track")
        }
        .padding(.vertical, 4)
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
        Text("Widget updates automatically when track changes")
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
