## Why

The only way to see the home cameras today is through Intelbras's own apps (ISIC Lite on the phone), which are slow to open, depend on the Intelbras cloud and do not exist for the Mac. The DVR on the LAN (MHDX 1108-C, 8 channels) already serves every camera over RTSP, and that was verified working in VLC, so a small native Mac app can show the cameras directly, one click away from the menu bar.

## What Changes

- New macOS app, built with SwiftUI, that lives only in the menu bar (camera icon at the top right, no Dock icon) and opens a floating panel when clicked.
- The panel shows a grid of the DVR's 8 cameras live, using the light substream, with each camera's name and a connection status at the bottom.
- Clicking a camera enlarges it inside the panel using the main stream, with a back control and a snapshot button.
- Snapshots of the current frame are saved as images in a folder under Pictures, and the panel can open that folder.
- Every camera is shown at 16:9, including channels whose stream is 960x1080 ("1080N"), so people do not look squeezed.
- Streams run only while the panel is open, and stop when it closes.
- An option to open the app automatically when the Mac starts.
- First-run setup inside the panel: DVR address, port, user and password. The user and password are stored in the macOS Keychain.
- The person can rename each camera (defaults "Canal 1"…"Canal 8") and hide channels that have no camera; this is stored by the app, since the restricted DVR user cannot read channel settings from the DVR.
- The app shows a clear message for a camera that fails, retries it, and offers a refresh-all button.
- New Xcode project (generated from a XcodeGen spec) with unit tests.

Out of scope for this change: recordings and timeline, motion notifications, PTZ, audio, remote access outside the home network, multiple DVRs.

## Capabilities

### New Capabilities
- `menu-bar-app`: the app's presence in the menu bar, the floating panel, how it opens and closes, opening at login, and quitting.
- `dvr-connection`: DVR settings (address, port, credentials in the Keychain), first-run setup, how stream addresses are formed, and the overall connection status.
- `live-view`: the camera grid, the enlarged single-camera view, 16:9 display, stream lifecycle tied to the panel, per-camera failure and retry.
- `camera-list`: which channels are shown, their default names, renaming and hiding them.
- `snapshots`: capturing the current frame of a camera to an image file and opening the snapshots folder.

### Modified Capabilities
<!-- None: this is the first change in the project. -->

## Impact

- New code: a SwiftUI macOS app target and a unit test target in `intelbras-viewer/`, plus `project.yml` for XcodeGen.
- New dependency: an RTSP-capable player library (KSPlayer, FFmpeg based, chosen in design.md), since AVPlayer cannot play RTSP.
- System integration: the macOS Keychain, the Local Network privacy prompt (the app talks to 192.168.1.2), and a folder under `~/Pictures`.
- DVR: read-only use through a restricted user (live view and playback permissions only). No DVR settings are changed.
- Build: requires full Xcode selected as the active developer directory.
