# HomeView

A small macOS menu bar app for watching the cameras DVR on
the local network, without official apps or their cloud.

Click the camera icon in the menu bar and a panel opens with every camera
live. Click a camera to see it alone in full quality, take a snapshot, and
close the panel when you are done. Nothing streams while the panel is closed.

![The panel with six cameras playing (pictures blurred for privacy)](docs/images/panel.png)

*The camera pictures in this screenshot are blurred for privacy.*

The interface is in Brazilian Portuguese.

## Features

- **Lives in the menu bar only.** No Dock icon, no Cmd+Tab entry, no window at
  launch. The panel opens to the right of the menu bar icon and closes when
  you click the icon again, click outside it, or press Esc.
- **Live grid.** The visible cameras play side by side in two columns, using
  each channel's light substream, with the camera's name and channel number.
- **Enlarged view.** Clicking a camera shows it alone at the panel's full
  width from its main stream; the grid's streams stop meanwhile.
- **Always 16:9.** Channels recorded at 960x1080 ("1080N", non-square pixels)
  are stretched to their intended 16:9 shape, so people and wheels look
  right, not squeezed.
- **Snapshots.** Saves the frame on screen as a 16:9 JPEG (1920x1080 for a
  1080N main stream) in `~/Pictures/HomeView`, named after the camera
  and the time, e.g. `Garagem 2026-10-13 21.04.37.jpg`. The folder button in
  the footer opens it in Finder.
- **Names and hidden channels.** Rename each camera ("Canal 1"…"Canal 8" by
  default) and hide channels with no camera. Hidden channels are never streamed.
- **Clear status.** The footer says "Conectando…", "Conectado", "Sem conexão
  com o DVR" or "Usuário ou senha incorretos" (with a "Corrigir" button). A
  camera that drops shows "Sem sinal" and is retried automatically (after 5 s,
  doubling up to 30 s) while the others keep playing. The refresh button
  restarts everything at once.
- **Open at login**, from the panel's "…" menu.
- **Credentials in the Keychain.** The DVR user and password are stored only
  in the macOS Keychain and never written to preferences or logs.

Out of scope: recordings and playback, motion alerts, PTZ, audio, multiple
DVRs, and access from outside the home network.

## Requirements

- macOS 14 (Sonoma) or later. Developed and tested on an Apple silicon Mac with macOS 26.
- An Intelbras DVR that serves RTSP, on the same network as the Mac. Developed
  and tested with an **MHDX 1108-C** (8 channels, firmware 4.000). Other
  Intelbras or Dahua-based recorders that use the
  `rtsp://HOST:554/cam/realmonitor?channel=N&subtype=S` addresses should work.
- To build: **full Xcode** (tested with Xcode 27) at `/Applications/Xcode.app`,
  [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode's Metal
  Toolchain:

  ```sh
  brew install xcodegen
  xcodebuild -downloadComponent MetalToolchain   # about 840 MB, needed by KSPlayer's shader
  ```

  The active developer directory does not need to change (`xcode-select` can
  keep pointing at the Command Line Tools): the Makefile sets `DEVELOPER_DIR`
  itself.

## Build and run

```sh
make generate   # create HomeView.xcodeproj from project.yml
make build      # build the app into DerivedData/
make test       # run the unit tests
make run        # build and open the app
```

The built app is `DerivedData/Build/Products/Debug/HomeView.app`; copy
it to `/Applications` to keep it. The Xcode project is generated and not
committed; edit `project.yml` instead and run `make generate` again. You can
also open the generated project in Xcode and run the `HomeView` scheme.

The app is signed to run locally (ad-hoc) and is not sandboxed. It is meant
for personal use and is not notarized.

### First launch

1. Click the camera icon in the menu bar. The panel shows **Configurar DVR**.
2. Check the address (default `192.168.1.2`) and port (default `554`), enter
   the DVR user and password, and press **Conectar**.
3. macOS asks whether the app may find devices on the local network. Allow it,
   or the app cannot reach the DVR (you can change it later in System Settings
   › Privacy & Security › Local Network).
4. The app checks the login with the DVR once. If it is accepted, the settings
   are saved and the cameras appear. If not, the form says why (wrong user or
   password, DVR not found at that address, or local network access denied)
   and nothing is saved.

After a rebuild, macOS may ask whether the new build may use its Keychain
item ("HomeView wants to use your confidential information…").
Choose **Always Allow**. This happens because every ad-hoc build has a new
signature.

## Creating a restricted user on the DVR

The app only needs to watch live video, so give it its own DVR user with the
least access possible rather than the admin account. On the DVR's web page
(`http://192.168.1.2`) or on the recorder itself, signed in as admin:

1. Open the user management settings (Account / Users).
2. Add a user, for example `macApp`, in the ordinary user group (not admin).
3. Grant only **live view** and **playback** for the channels you want to
   see. Leave every configuration permission off.
4. Save, then test it in VLC with
   `rtsp://macApp:PASSWORD@192.168.1.2:554/cam/realmonitor?channel=1&subtype=1`.

Things to know:

- **User names are case-sensitive.** `macApp` and `macapp` are different
  users; a wrong case looks exactly like a wrong password.
- **The DVR locks a user after a few failed logins** (Dahua-based firmware
  usually locks it for about 30 minutes after about 5 failures). The app is
  careful about this: it checks the login once before starting any stream and
  stops retrying as soon as the DVR rejects the password, so a changed password costs one failed
  attempt, not one per camera. Avoid retrying a wrong password by hand.
- A restricted user cannot read the DVR's channel names or settings, which is
  why camera names are set inside the app ("…" › Renomear câmeras).
- Passwords with special characters (`@ : / # ?` and so on) work.

## Using it

| To | Do |
| --- | --- |
| See all cameras | Click the camera icon in the menu bar. |
| See one camera in full quality | Click its tile; click "‹ Name" in the header to go back. |
| Take a snapshot | In the enlarged view, press the camera button in the header (enabled once the picture appears). |
| Open the snapshots folder | Press the folder button in the footer. |
| Restart every stream now | Press the refresh button in the header. |
| Rename or hide cameras | "…" › **Renomear câmeras**, then **Concluído** (or **Cancelar**). |
| Change the DVR address or login | "…" › **Configurações do DVR**. Leave the password empty to keep the current one. **Esquecer DVR** removes everything. |
| Open the app when the Mac starts | "…" › **Abrir ao iniciar o Mac**. |
| Quit | "…" › **Sair**. |

The panel reopens on the view you left: the grid, or the same enlarged camera.

## How it works

- **Streams.** The DVR serves each channel over RTSP with Digest
  authentication: `cam/realmonitor?channel=N&subtype=1` (substream, H.264
  352x240 at 7 fps on the MHDX 1108-C) for the grid and `subtype=0` (main
  stream, H.265 960x1080 at 30 fps) for the enlarged view. AVPlayer cannot play
  RTSP, so the app uses [KSPlayer](https://github.com/kingslay/KSPlayer)
  (FFmpeg) with RTSP over TCP and hardware decoding through VideoToolbox. All
  eight substreams together use about 8% CPU on an Apple silicon Mac.
- **Player boundary.** The app talks to the player only through the small
  `CameraPlayer` protocol, so KSPlayer could be replaced (VLCKit was the
  fallback considered) without touching the rest of the app.
- **Panel lifecycle.** A `MenuBarExtra` keeps its view alive between
  openings, so the app watches the panel window's occlusion state to start
  streams when it opens and stop them all within a fraction of a second after
  it closes.
- **Login check.** Before streams start, a small RTSP client built on
  Network.framework (`RTSPProbe`) sends one authenticated `DESCRIBE` and tells
  apart "accepted", "wrong user or password", "DVR not found" and "local
  network denied", which the player's FFmpeg errors cannot.
- **Storage.** Address and port in the app's preferences; user and password
  in the Keychain (service `com.carloseduardo.HomeView`); camera names
  and visibility as JSON in the preferences. Stream addresses with credentials
  exist only in memory; logs show them without user and password.

## Project layout

```
HomeView/
  HomeViewApp.swift   MenuBarExtra scene
  AppModel.swift             routes, streams, status, settings, snapshots
  Connection/                StreamURL, Digest auth, RTSPProbe, Keychain and settings stores
  Cameras/                   camera names and visibility
  Streams/                   per-camera StreamSession, RetryPolicy, ConnectionStatus
  Player/                    CameraPlayer protocol and its KSPlayer implementation
  Panel/                     SwiftUI views: header, grid, enlarged view, forms
  Snapshots/                 file naming, 16:9 JPEG writer, snapshots folder
HomeViewTests/        unit tests (XCTest)
Scripts/fake-rtsp-digest.py  fake RTSP server for testing logins without a DVR
docs/                        spike notes and the manual verification checklist
openspec/                    the change proposal, design, specs and tasks
project.yml                  XcodeGen project spec
```

## Development

- `make test` runs the unit tests. They cover stream addresses, Digest
  authentication (RFC 2617 examples), the login probe over a fake connection,
  the Keychain and settings stores, camera names, the retry policy, the
  footer status, the app model's routes and stream lifecycle, panel placement
  and snapshot files. They never contact the DVR.
- `TEST_RUNNER_RENDER_PANEL_DIR=/tmp/panel make test` also renders the main
  panel screens to PNG files, to check layouts without opening the menu bar.
  Video and AppKit controls appear as placeholders in these renders.
- `Scripts/fake-rtsp-digest.py 8554` starts a local server that answers like
  the DVR. Point the setup form at `127.0.0.1:8554`, with user `tester` and
  password `a@b:c/d#e`, to exercise the login check.
- Logs: `/usr/bin/log stream --info --predicate 'subsystem == "com.carloseduardo.HomeView"'`.
- Things that need the real DVR or the menu bar are covered by the manual
  checklist in [`docs/verificacao-manual.md`](docs/verificacao-manual.md).
  The results of the initial validation of KSPlayer against the DVR are in
  [`docs/spike-notes.md`](docs/spike-notes.md).
- The work is planned with [OpenSpec](https://github.com/Fission-AI/OpenSpec):
  the current specs are in `openspec/specs/`, and the first change (proposal,
  design, tasks) is archived in
  `openspec/changes/archive/2026-10-13-menu-bar-camera-viewer/`. Commits follow Conventional
  Commits.

## Privacy and security

- The app only talks to the DVR on your local network. It has no account, no
  cloud service, no analytics.
- The password is kept in the Keychain and is never written to files,
  preferences or logs.
- Use a DVR user restricted to live view and playback.
- Do not expose the DVR to the internet to watch it from outside. For remote
  access, use a private network such as a VPN instead.

## Uninstalling

1. Choose "…" › **Sair** (and turn off **Abrir ao iniciar o Mac** first if it is on).
2. Delete the app.
3. Remove the saved login and preferences:

   ```sh
   security delete-generic-password -s com.carloseduardo.HomeView
   defaults delete com.carloseduardo.HomeView
   ```

Snapshots stay in `~/Pictures/HomeView` until you delete them.

## License note

KSPlayer's open-source edition is licensed under GPL-3.0. This app is built
for personal use; distributing it would require complying with the GPL or
switching to another player (the `CameraPlayer` protocol keeps that change
contained). Intelbras is a trademark of its owner; this project is not
affiliated with or endorsed by Intelbras.
