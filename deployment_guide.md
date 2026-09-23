# EXECUTION.md: Compiling, Signing, and Running on macOS

Because macOS enforces strict sandboxing rules, code generated in an IDE will not magically become a desktop widget. You must use Xcode to link the targets and authorize the App Group.

## Phase 1: Setup & Capabilities in Xcode

1. **Open Xcode:** Open the folder/project in Xcode by double-clicking the `.xcodeproj` file.
2. **Ensure Targets Exist:** If the IDE didn't generate the Xcode targets properly, go to `File > New > Target`, select **Widget Extension**, and name it `YTMWidget`.
3. **Configure App Groups (Critical Step):**
   - Click the top-level project file in the left sidebar.
   - Select the **YTMCompanion** target. Go to the **Signing & Capabilities** tab.
   - Click **+ Capability** and add **App Groups**.
   - Click the **+** button under App Groups and create a new identifier: `group.local.ytmcompanion`.
   - **Repeat this exact step** for the **YTMWidget** target. Check the box next to `group.local.ytmcompanion`.
     _(Without this, the widget cannot read the data the main app is saving)._

## Phase 2: Verify YTMDesktop Settings

1. Open your YTMDesktop application.
2. Go to **Settings > Integrations**.
3. Ensure **Companion Server** is enabled.
4. Note the port number (default is usually `9863`). Ensure your `YTMService.swift` URL matches this port.

## Phase 3: Build & Run

1. At the top middle of Xcode, select the **YTMCompanion** scheme and your Mac as the destination.
2. Press **Cmd + R** (Run).
3. The host app will launch. You can hide it, but it must remain open in the dock or menu bar to poll the local API.

## Phase 4: Place the Widget on the Desktop

1. Right-click anywhere on your empty macOS Desktop.
2. Select **Edit Widgets...**.
3. In the search bar on the left, type **YTMCompanion**.
4. Drag your new YouTube Music widget onto your desktop.
5. Play a song in YTMDesktop. Within 3 seconds, your desktop widget should update with the album art and track details.
