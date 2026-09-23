import SwiftUI

@main
struct YTMCompanionApp: App {
    @StateObject private var service = YTMService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
        }
        .defaultSize(width: 460, height: 520)
    }
}
