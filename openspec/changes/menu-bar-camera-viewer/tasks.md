Each subtask is exactly one commit, using Conventional Commits with the message shown after it. The commit holds the subtask's code, its tests, and this file with the subtask's box ticked. Commits must build and pass the unit tests (from 1.3 on). A problem found later is fixed in its own `fix(...)` commit, not by amending an earlier one.

## 1. Project setup

- [x] 1.1 Write `project.yml` (XcodeGen): app target `IntelbrasViewer` (macOS 14, bundle id `com.carloseduardo.IntelbrasViewer`, display name "Intelbras Viewer", `LSUIElement = YES`, `NSLocalNetworkUsageDescription` in pt-BR, no sandbox, sign to run locally), test target `IntelbrasViewerTests`, KSPlayer as a SwiftPM dependency — commit: `build: add XcodeGen project spec with KSPlayer dependency`
- [x] 1.2 Add `.gitignore` (generated `.xcodeproj`, `DerivedData`, `.build`, `xcuserdata`) and a `Makefile` with `generate`, `build`, `test` and `run` using `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` — commit: `build: add Makefile and gitignore for command-line builds`
- [x] 1.3 Minimal `MenuBarExtra` app (camera SF Symbol, `.window` style, placeholder panel) that builds, launches with no Dock icon, and an empty test that passes — commit: `feat(app): add menu bar app shell with placeholder panel`

## 2. Spike against the real DVR

Findings from each spike subtask are written to `docs/spike-notes.md` in the same commit.

- [x] 2.1 Behind a `CameraPlayer` protocol, play channel 1 substream with KSPlayer in the panel (RTSP over TCP, hardware decoding, low-latency options); log the substream's codec and resolution — commit: `feat(spike): play channel 1 substream through KSPlayer`
- [x] 2.2 Play channel 1 main stream (H.265 960x1080) stretched to 16:9 and check that it looks right compared to VLC — commit: `feat(spike): play main stream stretched to 16:9`
- [x] 2.3 Play all 8 substreams at once; note CPU use and whether the DVR accepts 8 concurrent sessions — commit: `feat(spike): play all eight substreams at once`
- [x] 2.4 Test a percent-encoded password containing `@ : /` (temporary password on a test DVR user) and record whether FFmpeg accepts it — commit: `test(spike): check percent-encoded RTSP credentials`
- [x] 2.5 Log the panel window's occlusion-state changes on open and close, and confirm streams can be started and stopped from them — commit: `feat(spike): start and stop streams from panel visibility`
- [x] 2.6 Find how to grab the current frame as a `CGImage` from KSPlayer — commit: `feat(spike): grab current frame from the player`
- [x] 2.7 Write the spike's findings into design.md (update Risks and Open Questions); if KSPlayer fails 2.1–2.3, the switch to VLCKit behind the same protocol is its own `refactor(player): replace KSPlayer with VLCKit` commit before this one — commit: `docs(openspec): record spike findings in design`

## 3. Connection core (unit tested)

- [x] 3.1 `StreamURL`: builds substream/main stream URLs with percent-encoded credentials, plus a credential-free description for logs; tests for channel 3 and the `a@b:c/d#e` password — commit: `feat(connection): build RTSP stream URLs`
- [x] 3.2 Digest auth: parse `WWW-Authenticate`, compute the response (no `qop` and `qop=auth`); tests with the RFC 2617 example — commit: `feat(connection): compute RTSP digest authentication`
- [x] 3.3 `RTSPProbe` on Network.framework with an injectable transport: DESCRIBE, challenge, authenticated retry, 5 s timeout, classification (ok / wrong credentials / not found / local network denied); tests for each outcome over a fake transport — commit: `feat(connection): probe DVR credentials over RTSP`
- [x] 3.4 `KeychainStore` (save, read, delete user + password) with tests on a test-only service name — commit: `feat(connection): store DVR credentials in the Keychain`
- [x] 3.5 `DVRSettingsStore` combining `UserDefaults` (host, port) and the Keychain; tests with an isolated defaults suite — commit: `feat(connection): persist DVR settings`

## 4. Cameras and streams (unit tested)

- [x] 4.1 `CameraListStore`: 8 default cameras "Canal 1"…"Canal 8", rename with normalization (trim, empty → default, 30-character limit), visibility, JSON persistence; tests — commit: `feat(cameras): add camera list with names and visibility`
- [x] 4.2 `RetryPolicy` (5 s, doubling, max 30 s, reset on success) with an injected clock; tests — commit: `feat(streams): add stream retry policy`
- [x] 4.3 `StreamSession`: owns a `CameraPlayer` and a `RetryPolicy`, states `connecting` / `playing` / `failed(nextRetry)`, restart for refresh; tests with a fake player — commit: `feat(streams): add per-camera stream session`
- [x] 4.4 `ConnectionStatus.derive(sessions, lastProbe)`; tests for "Conectando…", "Conectado", "Sem conexão com o DVR", "Usuário ou senha incorretos" — commit: `feat(streams): derive overall connection status`

## 5. Panel UI

- [x] 5.1 `AppModel` with routes (setup, grid, enlarged, DVR settings, rename), remembered view on reopen, and stream start/stop driven by the panel's visibility observer (from 2.5); Esc closes the panel unless a text field is being edited; remove the spike UI it replaces — commit: `feat(ui): add app model with routes and panel lifecycle`
- [ ] 5.2 Panel chrome: "Câmeras" header with refresh and "…" menu, footer with status text, "Corrigir" button when credentials are rejected, and the folder button — commit: `feat(ui): add panel header, menu and status footer`
- [ ] 5.3 First-run "Configurar DVR" form: prefilled address and port, hidden password, "Conectar" runs the probe and shows each error message from the dvr-connection spec — commit: `feat(ui): add first-run DVR setup`
- [ ] 5.4 "Configurações do DVR": same form, empty password keeps the saved one, "Salvar", "Cancelar", "Esquecer DVR" — commit: `feat(ui): add DVR settings with forget option`
- [ ] 5.5 Camera grid: two columns, 16:9 tiles with name and channel badge, scrolling past 540 pt, "Conectando…" and "Sem sinal" states, "Nenhuma câmera visível" with "Escolher câmeras" — commit: `feat(ui): add live camera grid`
- [ ] 5.6 Enlarged view: main stream at 16:9, "‹ Name" back control, grid streams stopped while enlarged and restarted on back — commit: `feat(ui): add enlarged camera view`
- [ ] 5.7 "Renomear câmeras": 8 rows with number, name field and "Mostrar" switch; "Concluído" applies, "Cancelar" discards — commit: `feat(ui): add rename and hide cameras screen`
- [ ] 5.8 "Abrir ao iniciar o Mac" with `SMAppService.mainApp`, checkmark read from macOS each time the menu opens; "Sair" stops streams and quits — commit: `feat(ui): add open at login and quit`

## 6. Snapshots

- [ ] 6.1 `SnapshotFileName` (sanitized camera name + `yyyy-MM-dd HH.mm.ss` + `.jpg`) and 16:9 output sizing at the stream's height; tests including "Sala/Cozinha" and 960x1080 → 1920x1080 — commit: `feat(snapshots): name and size snapshot files`
- [ ] 6.2 `SnapshotWriter`: frame from the player, redraw at 16:9, JPEG 0.9 via ImageIO into `~/Pictures/Intelbras Viewer` (created if missing); error path returns a failure — commit: `feat(snapshots): write snapshots as JPEG`
- [ ] 6.3 Snapshot button in the enlarged header (disabled until the first frame), "Foto salva" and "Não foi possível salvar a foto" messages, folder button opens Finder — commit: `feat(ui): add snapshot button and folder shortcut`

## 7. Verification on the real DVR

- [ ] 7.1 Write `docs/verificacao-manual.md`: a checklist with each scenario from the five specs that needs the DVR or the menu bar (setup with right/wrong password and wrong address, grid of 8, hide channels, rename and restart, enlarge and back, unplug a camera and plug it back, refresh, close the panel and confirm no RTSP connections remain with `lsof -i :554`, reopen on an enlarged camera, snapshot of a renamed camera, open at login, quit) — commit: `docs: add manual verification checklist`
- [ ] 7.2 Run `make test` and the checklist against the DVR, and record the date and result of each item in the checklist; each problem found gets its own `fix(<scope>): …` commit before this one — commit: `docs: record manual verification results`
- [ ] 7.3 Write a README (pt-BR) with what the app does, how to build and run it, how to create the restricted DVR user, and a screenshot — commit: `docs: add README in Portuguese`
