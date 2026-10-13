## Context

The project folder has only OpenSpec scaffolding; this change creates the app. What is known about the DVR comes from probing the real device (see `openspec/config.yaml`): an Intelbras MHDX 1108-C at 192.168.1.2 serving 8 channels over RTSP on port 554 with Digest auth, main streams in H.265 at 960x1080 (channel 8: 1280x720). Playback of `cam/realmonitor?channel=1&subtype=1` was confirmed in VLC with the restricted `macapp` user. That user cannot call the configuration CGI endpoints ("Invalid Authority!"), so the app must only rely on RTSP.

The Mac runs macOS 26 with Xcode installed at `/Applications/Xcode.app`, but the active developer directory is the Command Line Tools. XcodeGen is installed through Homebrew.

The app is personal: it is built and run locally, not distributed through the App Store.

## Goals / Non-Goals

**Goals:**
- A menu bar app whose panel shows the cameras live within a couple of seconds of being clicked.
- Low resource use: nothing streams while the panel is closed; the grid uses substreams; decoding uses the GPU (VideoToolbox).
- Credentials handled safely (Keychain only, never logged).
- The logic that does not need a real DVR or a screen covered by unit tests.

**Non-Goals:**
- Recordings, timeline, events, PTZ, audio, multiple DVRs, access outside the LAN.
- Discovering the DVR automatically (ONVIF/broadcast); the address is typed once.
- App Store distribution, sandboxing, notarization.

## Decisions

### 1. Project: XcodeGen spec, SwiftUI, macOS 14+
`project.yml` describes an app target `IntelbrasViewer` and a unit test target `IntelbrasViewerTests`. The `.xcodeproj` is generated and git-ignored. Deployment target macOS 14, so the app can use `@Observable` and `SMAppService`. Bundle id `com.carloseduardo.IntelbrasViewer`, display name "Intelbras Viewer". The Info.plist sets `LSUIElement = YES` (no Dock icon, no Cmd+Tab) and `NSLocalNetworkUsageDescription` (macOS asks before the app reaches 192.168.1.2). Command-line builds use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, so nobody has to run `sudo xcode-select`.

*Alternatives:* a hand-made `.xcodeproj` (large opaque diffs, hard for Claude/Codex to edit safely); a Swift package executable (cannot produce a proper `.app` with an Info.plist without extra scripting).

### 2. No App Sandbox, local signing
The app is signed "to run locally" and not sandboxed. The Keychain, the network and `~/Pictures` work without entitlements. *Alternative:* sandboxing with the network-client and Pictures entitlements; it adds friction and protects little for a personal app that only talks to one LAN device.

### 3. Player: KSPlayer behind a `CameraPlayer` protocol
AVPlayer cannot play RTSP. KSPlayer (Swift, SwiftPM) wraps FFmpeg for RTSP and decodes H.265 through VideoToolbox, and renders into an `NSView` that SwiftUI can host. Each tile owns one player. The app talks to it only through a small `CameraPlayer` protocol (start(url), stop(), state stream, current-frame image), so the library can be swapped. Options: RTSP over TCP (no UDP packet loss on Wi-Fi), low-latency buffering, hardware decoding on.

*Alternatives:* VLCKit (LGPL, proven, but a large Objective-C binary with awkward SwiftPM support and its own view lifecycle); libmpv (needs manual bundling); a go2rtc process translating RTSP to HLS/WebRTC for AVPlayer/WKWebView (an extra server to run and keep alive). KSPlayer's open-source edition is GPL-3.0, which is fine for an app that is never distributed; if that changes, the protocol boundary keeps VLCKit as the fallback.

The first task is a spike that validates KSPlayer against the real DVR before anything else is built on it.

### 4. 16:9 by construction
Every picture is placed in a container with `.aspectRatio(16/9, contentMode: .fit)`, and the player's video gravity is set to *resize* (stretch to fill), not aspect-fit. A 960x1080 frame is stretched to 16:9, which is its intended display shape (1080N), and a 1280x720 frame is unchanged. No per-channel configuration is needed.

### 5. Our own RTSP credential probe
Setup must tell "wrong password" from "DVR not found" from "local network denied". Player errors are opaque FFmpeg strings, so a small `RTSPProbe` built on Network.framework does it: open TCP to HOST:PORT (5 s timeout), send `DESCRIBE` for channel 1 substream, read the `401` with `WWW-Authenticate: Digest realm=…, nonce=…`, compute the Digest response (MD5, as the DVR advertises no `qop`; support `qop=auth` too), resend, and classify:
- any status other than 401 after authenticating → credentials OK (a channel with no camera still proves the login);
- 401 after authenticating → wrong credentials;
- timeout / refused / host unreachable → not found;
- path unsatisfied with reason `localNetworkDenied` → local network denied.

The probe is used by "Conectar"/"Salvar", and again when every tile has failed, to choose the footer message. Digest computation and response classification are pure functions with unit tests.

### 6. Credentials in URLs
`StreamURL` builds `rtsp://user:password@HOST:PORT/cam/realmonitor?channel=N&subtype=S`, percent-encoding the user and password with only RFC 3986 unreserved characters left as-is. The URL lives only in memory and is never logged; logs show `rtsp://HOST:PORT/…channel=N&subtype=S` without credentials. The spike verifies that FFmpeg decodes percent-encoded credentials (see Risks).

### 7. State and modules
- `AppModel` (`@Observable`, main actor): the route (`setup`, `grid`, `enlarged(channel)`, `dvrSettings`, `renameCameras`), the remembered view for reopening, the panel's visibility, and the footer status.
- `DVRSettingsStore`: host and port in `UserDefaults`; user and password in a `KeychainStore` (generic password, service = bundle id, account = user, data = password).
- `CameraListStore`: 8 `Camera(channel, name, isVisible)` saved as JSON in `UserDefaults`; normalizes names (trim, empty → "Canal N", max 30 characters).
- `StreamSession` per visible tile: wraps a `CameraPlayer` and a `RetryPolicy` (5 s, doubling, max 30 s, reset on success). States: `connecting`, `playing`, `failed(nextRetry)`. Time is injected so the policy is testable.
- `ConnectionStatus.derive(sessions, lastProbe)`: pure function that yields "Conectando…", "Conectado", "Sem conexão com o DVR" or "Usuário ou senha incorretos".
- `SnapshotWriter`: takes the player's current `CGImage`, redraws it at 16:9 with the stream's height, writes JPEG (quality 0.9) through ImageIO into `~/Pictures/Intelbras Viewer`; `SnapshotFileName` sanitizes names (`/`, `:` and control characters → `-`).
- `LoginItem`: wraps `SMAppService.mainApp` and re-reads its status each time the "…" menu opens.

### 8. Knowing when the panel is open
`MenuBarExtra` with `.menuBarExtraStyle(.window)` keeps its SwiftUI view alive, so `onAppear`/`onDisappear` do not reliably mark each open and close. A small `NSViewRepresentable` captures the panel's `NSWindow` and observes `NSWindow.didChangeOcclusionStateNotification`; the window being visible starts the current view's streams, hidden stops them all. Esc is handled with `onExitCommand`, which closes the panel window unless a text field is being edited.

### 9. Panel size
Fixed width of 600 pt. Grid tiles are about 282x159 pt in two columns. The grid area scrolls past 540 pt of height, so the panel stays within a 13" screen. The enlarged view shows the camera at 576x324 pt.

### 10. Testing
Unit tests (XCTest) for `StreamURL`, Digest computation (RFC 2617 example), probe classification over a fake transport, `RetryPolicy`, `ConnectionStatus.derive`, `CameraListStore` (normalization and persistence with an isolated `UserDefaults` suite), `KeychainStore` (with a test-only service name, cleaned up after each test), `SnapshotFileName` and snapshot sizing. Scenarios that need the DVR or the menu bar are checked by hand with a checklist in `tasks.md`.

## Risks / Trade-offs

- [KSPlayer cannot play the DVR's H.265 stream smoothly, or 8 at once is too heavy] → the spike checks both on the real DVR before the UI is built; fallback is VLCKit behind the same `CameraPlayer` protocol.
- [FFmpeg does not decode percent-encoded credentials in RTSP URLs, so a password with `@` or `:` fails] → the spike tests a password with special characters; if it fails, pass credentials through the player's options when it allows, otherwise setup warns that the password must not contain `@ : / # ?` and asks the person to change it on the DVR.
- [Occlusion notifications do not fire as expected for the MenuBarExtra window] → the spike logs open/close events; fallback is observing `didBecomeKey`/`didResignKey` on the same window.
- [The DVR limits concurrent RTSP sessions per user] → the spike opens all 8 substreams at once; if the DVR refuses some, the grid limits concurrent streams and the design is revisited.
- [macOS Local Network permission is denied, and every request fails silently] → the probe detects `localNetworkDenied` and shows how to enable it.
- [KSPlayer is GPL-3.0] → acceptable while the app is personal; distributing it would require switching players or a commercial license.
- [Not sandboxed] → acceptable for a personal app; nothing in the code depends on being unsandboxed beyond file locations, so sandboxing can be added later.

## Migration Plan

New app, nothing to migrate. To remove it: choose "Sair", delete the app, and delete the "com.carloseduardo.IntelbrasViewer" entry in Keychain Access.

## Open Questions

- The substream's codec and resolution were not read from the DVR (only the main stream's); the spike will log them. This does not change the design.
- Whether KSPlayer exposes the current frame as a `CGImage` directly or the snapshot needs to read the rendered layer; resolved in the spike.
