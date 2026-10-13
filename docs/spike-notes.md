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
