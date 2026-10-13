# Spike notes: KSPlayer against the real DVR

Findings from tasks 2.1–2.6 of the `menu-bar-camera-viewer` change. DVR:
Intelbras MHDX 1108-C at 192.168.1.2:554. Mac: macOS 26.6, Xcode 27, KSPlayer
2.3.4 with FFmpegKit 6.1.4.

How to run the spike: `make build`, then `Scripts/spike-run.sh -spikeWindow YES`
(optionally `-spikeChannel N -spikeSubtype S`; `SPIKE_FFMPEG_LOG=1` prints
FFmpeg's log to stderr with the password removed). App logs:
`/usr/bin/log stream --info --predicate 'subsystem == "com.carloseduardo.IntelbrasViewer"'`.

## 2.1 Channel 1 substream through KSPlayer (2026-10-13)

Result: **works.**

- Substream (`subtype=1`): **H.264 Baseline/High, yuv420p, 352x240, 7 fps**
  (the SDP advertises `profile-level-id=64000B`; FFmpeg reports Baseline).
  Small and cheap: about 2% CPU and 85 MB RSS for the whole app with one stream.
- Time from `start` to the first frame: about 3.8 s. Most of it is FFmpeg
  probing the stream at 7 fps; worth trying to shorten later (smaller
  `probesize`/`max_analyze_duration`), but acceptable.
- VideoToolbox is used (`videotoolbox_vld`). It logs "hardware accelerator
  failed to decode picture" 3 times right at the start, before the first
  keyframe, then decodes without errors.
- Player setup that works: `KSMEPlayer` directly (not `KSPlayerLayer`, which
  adds Now Playing and remote-control handling), `rtsp_transport=tcp`,
  `timeout=5000000` (µs), `nobuffer`, `codecLowDelay`, hardware decode on.
- FFmpeg sends `OPTIONS` first and answers the DVR's Digest challenge
  (`realm="Login to <hash>"`, nonce, **no `qop`**) on its own.

Things learned on the way:

- **The DVR user name is case-sensitive** (`macApp`, not `macapp`): the name
  is part of the Digest hash, so a wrong case looks exactly like a wrong
  password (`401`). Setup must not change the case of what is typed.
- Wrong logins count towards the DVR's lockout (Dahua firmware usually locks
  a user for about 30 minutes after about 5 failures). The app must not retry
  a rejected login in a loop: after a `401` from the probe it should stop and
  ask, not keep retrying streams with the same password.
- **Keychain prompts with ad-hoc signing:** an item created by the `security`
  tool only trusts Apple tools (its partition list), so the app reading it
  shows a Keychain permission dialog, and `SecItemCopyMatching` blocks the main
  thread until it is answered. An item the app creates itself is trusted by
  that build only; because an ad-hoc signature changes on every rebuild, a
  rebuilt app may be asked again ("Always Allow"). Consequences for 3.4: never
  read the Keychain on the main thread at launch in a way that can freeze the
  panel, and expect this dialog during development. The spike passes the
  password through the environment instead (`Scripts/spike-run.sh`).

## 2.2 Channel 1 main stream stretched to 16:9 (2026-10-13)

Result: **works, and 16:9 is the right shape.**

- Main stream (`subtype=0`): **HEVC Main, yuv420p, 960x1080, 30 fps**, decoded
  by VideoToolbox. About 6% CPU and 120 MB RSS with this one stream.
- `contentMode = .scaleToFill` on the KSPlayer view sets the display layer's
  video gravity to `.resize`, so the picture fills the 16:9 frame exactly.
- Checked by saving a frame (`-spikeFrameDump`) as the stream's pixels and
  redrawn at 1920x1080: in the 16:9 image wheels are round and the DVR's
  on-screen text ("intelbras", "Canal1") has normal proportions; the raw
  960x1080 image is visibly squeezed. The DVR does not need any per-channel
  aspect setting. A side-by-side look against VLC by eye is left for the
  manual checklist (7.1), since the spike ran without access to the screen.
- VideoToolbox logs "hardware accelerator failed to decode picture" about 40
  times in the first seconds (before the first keyframe), then none.
- The DVR's on-screen clock was about 20 minutes ahead of the Mac. Snapshot
  file names use the Mac's clock, so they may not match the time burned into
  the picture.

## 2.3 All eight substreams at once (2026-10-13)

Result: **works.**

- The DVR accepted 8 simultaneous RTSP sessions from the restricted user
  (8 established TCP connections to port 554, all 8 players reached
  `playing`). No limit was hit, so the grid does not need to throttle.
- Every substream is H.264 352x240 at 7 fps (channel 8 too, although its main
  stream is 1280x720).
- Whole app with 8 substreams: about 8% CPU (`ps`, sampled every 2 s for 10 s,
  6.6–9.5%) and 125 MB RSS. Cheap enough to leave the grid running while the
  panel is open.
- First frame for all 8 within about 4 s of start.
- Channels 7 and 8 stream a black picture with only the DVR's text overlay
  (logo, clock, "Canal7"/"Canal8"). The DVR still serves the stream, so the
  player reports `playing`, not a failure: "Sem sinal" will not appear for a
  channel without a camera. Hiding the channel ("Mostrar" off) is the way to
  remove it.
- At 352x240 the substream is soft in a ~282x159 pt tile on a Retina screen
  (about 564x318 px). Acceptable for a preview; the enlarged view uses the
  main stream.

## 2.4 Percent-encoded credentials (2026-10-13)

Result: **FFmpeg decodes percent-encoded user and password correctly.**

Checked against a fake RTSP server instead of a temporary DVR user, so no
user had to be created on the DVR: `Scripts/fake-rtsp-digest.py` answers like
the DVR (Digest, no `qop`) and checks the response FFmpeg computes.

- User `tester`, password `a@b:c/d#e`, sent as
  `rtsp://tester:a%40b%3Ac%2Fd%23e@127.0.0.1:8554/...` (everything except
  RFC 3986 unreserved characters percent-encoded): the server reports
  **MATCH**, so FFmpeg used the decoded password in the Digest hash.
- Control: the same with `a@b:c/d#X` reports **MISMATCH**.
- On the real DVR, the `macApp` password itself contains characters outside
  the unreserved set and plays when sent percent-encoded the same way (2.1).

So the fallback in design.md (passing credentials as player options, or
forbidding `@ : / # ?` in passwords) is not needed.

Run it again with:

    Scripts/fake-rtsp-digest.py 8554 &
    SPIKE_DVR_HOST=127.0.0.1 SPIKE_DVR_PORT=8554 SPIKE_DVR_USER=tester \
      SPIKE_DVR_PASSWORD='a@b:c/d#e' \
      DerivedData/Build/Products/Debug/IntelbrasViewer.app/Contents/MacOS/IntelbrasViewer -spikeWindow YES

## 2.5 Starting and stopping streams from the panel's visibility (2026-10-13)

Result: **occlusion notifications work for the MenuBarExtra window.**

`PanelVisibilityObserver` (an `NSViewRepresentable` in the panel) observes
`NSWindow.didChangeOcclusionStateNotification` on the panel's window and
reports `occlusionState.contains(.visible)`; the spike starts all streams on
visible and stops them on hidden. The panel was opened and closed 4 times by
pressing the status item's button from code (`-spikeTogglePanel 4`, 8
substreams), sampling RTSP connections with `lsof` every 0.25 s:

| Event | Occlusion | Connections to :554 |
| --- | --- | --- |
| open 1 | visible after 65 ms | 8 (first frames ~4 s later) |
| close 1 | hidden after 31 ms | 0 at the next sample (< 0.25 s) |
| open 2 | visible after 40 ms | 8 |
| close 2 | hidden after 23 ms | 0 at the next sample (< 0.25 s) |

- Well within the spec's "all streams stop within 1 second".
- When the window is first created the observer reports `hidden` and then,
  30 ms later, `visible`: harmless (stopping nothing), but the model must
  treat repeated or early `hidden` reports as no-ops.
- `didBecomeKey` did not fire on the first open (the app had never been
  active), so key status is not a reliable open signal; the
  `didBecomeKey`/`didResignKey` fallback in design.md is not needed.
- Not covered here, for the manual checklist (7.1): a real mouse click on the
  icon, closing by clicking outside the panel, and Esc. Pressing the button
  from code goes through the same toggle, but focus behaves differently with
  a real click.
