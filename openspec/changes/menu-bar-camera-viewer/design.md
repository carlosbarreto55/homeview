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

The probe is used by "Conectar"/"Salvar"; before streams start from cold (the panel opens, or refresh with no streams running), so that a password changed on the DVR costs one failed login instead of one per tile (only "wrong credentials" keeps the streams from starting; an unreachable DVR still starts them so tiles show "Sem sinal" and retry); and again when every tile has failed, to choose the footer message. Switching between the grid and the enlarged view does not probe again. Digest computation and response classification are pure functions with unit tests.

### 6. Credentials in URLs
`StreamURL` builds `rtsp://user:password@HOST:PORT/cam/realmonitor?channel=N&subtype=S`, percent-encoding the user and password with only RFC 3986 unreserved characters left as-is. The URL lives only in memory and is never logged; logs show `rtsp://HOST:PORT/…channel=N&subtype=S` without credentials. The spike verifies that FFmpeg decodes percent-encoded credentials (see Risks).

### 7. State and modules
- `AppModel` (`@Observable`, main actor): the route (`setup`, `grid`, `enlarged(channel)`, `dvrSettings`, `renameCameras`), the remembered view for reopening, the panel's visibility, and the footer status.
- `DVRSettingsStore`: host and port in `UserDefaults`; user and password in a `KeychainStore` (generic password, service = bundle id, account = user, data = password).
- `CameraListStore`: 8 `Camera(channel, name, isVisible)` saved as JSON in `UserDefaults`; normalizes names (trim, empty → "Canal N", max 30 characters).
- `StreamSession` per visible tile: wraps a `CameraPlayer` and a `RetryPolicy` (5 s, doubling, max 30 s, reset on success). States: `connecting`, `playing`, `failed(nextRetry)`. Time is injected so the policy is testable. Retrying can be suspended: when the probe reports wrong credentials, every session stops retrying (to stay clear of the DVR's lockout) until the settings are saved again or the person presses refresh.
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

Spike results (tasks 2.1–2.6, 2026-10-13) are in `docs/spike-notes.md`. Risks the spike settled:

- ~~[KSPlayer cannot play the DVR's H.265 stream smoothly, or 8 at once is too heavy]~~ → **settled, KSPlayer stays.** Main stream HEVC 960x1080 at 30 fps plays on VideoToolbox at about 6% CPU; all 8 substreams (H.264 352x240, 7 fps) at about 8% CPU and 125 MB for the whole app. The player is `KSMEPlayer` used directly (not `KSPlayerLayer`, which adds Now Playing and remote-control handling). No VLCKit switch.
- ~~[FFmpeg does not decode percent-encoded credentials in RTSP URLs]~~ → **settled, it does.** `a@b:c/d#e` sent percent-encoded produces the right Digest response (checked against a fake RTSP server), and the real password, which has reserved characters, plays the same way. No password restrictions in setup.
- ~~[Occlusion notifications do not fire as expected for the MenuBarExtra window]~~ → **settled, they do.** Visible/hidden arrive within 25–65 ms of each open and close, and all RTSP connections are gone within 0.25 s of closing. `didBecomeKey` is unreliable (not sent on the first open), so there is no key-status fallback. The observer also reports `hidden` once when the window is first created; the model ignores repeated reports.
- ~~[The DVR limits concurrent RTSP sessions per user]~~ → **settled, no limit hit.** 8 simultaneous sessions accepted.

Risks still open, or found by the spike:

- [Wrong credentials lock the DVR user] Dahua-based firmware usually locks a user for about 30 minutes after about 5 failed logins, and 8 tiles retrying a rejected password every 5–30 s would reach that in seconds. → When every tile has failed, the probe runs once; if it reports wrong credentials, the sessions stop retrying (footer "Usuário ou senha incorretos" with "Corrigir") until the settings are saved again or the person presses refresh. Setup and "Salvar" make exactly one authenticated attempt per press.
- [User names are case-sensitive] The DVR user is `macApp`; `macapp` gets the same `401` as a wrong password, because the name is part of the Digest hash. → The "Usuário" field keeps exactly what is typed (no capitalization, autocorrection or lowercasing); the wrong-credentials message is the same for both cases.
- [Keychain prompts with ad-hoc signing] Each rebuild changes the ad-hoc signature, so a rebuilt app may get a Keychain "allow access" dialog for the item an earlier build created, and `SecItemCopyMatching` blocks the calling thread until it is answered. → `DVRSettingsStore` reads the Keychain once, when the panel first needs it, never inside a view's body; the dialog is expected during development and documented in the README. Items made by the `security` tool are worse (only Apple tools are trusted), so the app always creates its own item.
- [FFmpeg's log can contain the full stream URL, with credentials] At debug level FFmpeg prints the URL it opens. → The app leaves KSPlayer at its default log level (warning), whose messages go to `os_log` as private data; the spike's debug logging (`SPIKE_FFMPEG_LOG=1`) removes the password and is deleted with the spike code in 5.1.
- [A channel with no camera still streams] The DVR serves channels 7 and 8 as a black picture with its text overlay, so the player reports `playing` and the tile never shows "Sem sinal". → Expected; "Mostrar" off is how the person removes such channels.
- [Slow first frame] About 4 s from start to first frame, mostly FFmpeg probing a 7 fps stream. → Acceptable ("Conectando…" covers it); `probesize` and `max_analyze_duration` can be tuned later.
- [Building needs the Metal Toolchain] KSPlayer has a Metal shader, and Xcode 27 does not include the Metal Toolchain by default. → `xcodebuild -downloadComponent MetalToolchain`, documented in the README. FFmpegKit's macOS frameworks also need `SKIP_EMBEDDED_FRAMEWORKS_VALIDATION` (set in `project.yml`).
- [macOS Local Network permission is denied, and every request fails silently] → the probe detects `localNetworkDenied` and shows how to enable it.
- [KSPlayer is GPL-3.0] → acceptable while the app is personal; distributing it would require switching players or a commercial license.
- [Not sandboxed] → acceptable for a personal app; nothing in the code depends on being unsandboxed beyond file locations, so sandboxing can be added later.

## Migration Plan

New app, nothing to migrate. To remove it: choose "Sair", delete the app, and delete the "com.carloseduardo.IntelbrasViewer" entry in Keychain Access.

## Open Questions

- ~~The substream's codec and resolution~~ → resolved by the spike: H.264, 352x240, 7 fps on every channel. The grid tiles are larger than the substream on a Retina screen, so they look soft; acceptable for a preview.
- ~~Whether KSPlayer exposes the current frame as a `CGImage`~~ → resolved: `KSMEPlayer.thumbnailImageAtCurrentTime()` returns the last shown frame at the stream's pixel size (960x1080 for a main stream), or `nil` before the first frame. The snapshot redraws it at 16:9.
- The DVR's clock was about 20 minutes ahead of the Mac's. Snapshot names use the Mac's clock, so they may not match the time drawn in the picture; not something the app should change (it cannot write DVR settings).
