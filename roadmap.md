# ROADMAP.md: YTMDesktop Widget Code Architecture

**Goal:** Build a native macOS companion app that acts as a bridge between the YTMDesktop local server and a WidgetKit desktop extension.

## 1. Project Directory Structure

Instruct the IDE to create the following file tree in the root folder:

/YTMCompanion
├── YTMCompanionApp.swift (Main App Entry Point)
├── ContentView.swift (Main App UI - simple status screen)
├── Services/
│ └── YTMService.swift (Network Poller & Data Bridge)
└── Models/
└── TrackData.swift (Shared struct for track metadata)
/YTMWidget
├── YTMWidgetBundle.swift (Widget Extension Entry Point)
├── YTMWidget.swift (TimelineProvider & Configuration)
└── Views/
└── WidgetEntryView.swift (SwiftUI UI for the Widget)

---

## 2. Shared Data Models (Models/TrackData.swift)

- Create a `TrackData` struct conforming to `Codable`.
- Properties: `title` (String), `author` (String), `coverData` (Data?), `isPlaying` (Bool).
- **Crucial:** This file must be targeted for BOTH the `YTMCompanion` app and the `YTMWidget` extension.

## 3. The Network Engine (Services/YTMService.swift)

- Create an `ObservableObject` class named `YTMService`.
- Implement a `Timer` that fires every 3 seconds.
- Fetch `http://localhost:9863/api/v1/state` (or `/query` depending on YTMDesktop version).
- **Data Processing:**
  1. Parse the JSON response for track title, artist, and cover URL.
  2. Download the cover URL image and convert it to raw `Data` (WidgetKit cannot load async images dynamically).
  3. Serialize the `TrackData` object.
  4. Save it to `UserDefaults(suiteName: "group.local.ytmcompanion")`.
  5. Call `WidgetCenter.shared.reloadAllTimelines()` (requires `import WidgetKit`).

## 4. The Widget Extension (YTMWidget/)

- **YTMWidget.swift:**
  - Create a `TimelineProvider`.
  - In `getTimeline()`, read from `UserDefaults(suiteName: "group.local.ytmcompanion")`.
  - Decode the `TrackData` and pass it to a `SimpleEntry`.
  - Set the timeline policy to `.never` (the main app triggers the reloads).
- **Views/WidgetEntryView.swift:**
  - Build the SwiftUI UI. If `coverData` exists, convert it to an `NSImage` and display it as the background. Layer the `title` and `author` text over it using a `VStack` with a `.ultraThinMaterial` background.
