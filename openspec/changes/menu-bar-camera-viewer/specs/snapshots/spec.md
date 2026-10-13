## ADDED Requirements

### Requirement: Taking a snapshot
In the enlarged view, the snapshot button SHALL save the frame currently shown as a JPEG in the folder `~/Pictures/Intelbras Viewer`, creating the folder if needed. The image SHALL have the 16:9 proportions the person sees, at the main stream's height (1920x1080 for a 960x1080 stream). The file SHALL be named after the camera and the moment, as `<camera name> 2026-10-13 21.04.37.jpg`, with characters not allowed in file names replaced by "-". After saving, the panel SHALL show "Foto salva" for about 2 seconds. The button SHALL be disabled until the camera shows its first frame.

#### Scenario: Snapshot of a renamed camera
- **WHEN** "Garagem" is enlarged and playing, and the person presses the snapshot button on 13 October 2026 at 21:04:37
- **THEN** the file `~/Pictures/Intelbras Viewer/Garagem 2026-10-13 21.04.37.jpg` exists, is 1920x1080, matches what was on screen, and the panel shows "Foto salva"

#### Scenario: Name with a slash
- **WHEN** the camera is named "Sala/Cozinha" and the person takes a snapshot
- **THEN** the file name starts with "Sala-Cozinha "

#### Scenario: No picture yet
- **WHEN** the enlarged camera still shows "Conectando…"
- **THEN** the snapshot button is disabled

### Requirement: Snapshot failure
When the image cannot be written, the panel SHALL show "Não foi possível salvar a foto" and keep the stream playing.

#### Scenario: Folder not writable
- **WHEN** `~/Pictures/Intelbras Viewer` is read-only and the person takes a snapshot
- **THEN** the panel shows "Não foi possível salvar a foto" and the camera keeps playing

### Requirement: Opening the snapshots folder
The folder button in the panel footer SHALL open `~/Pictures/Intelbras Viewer` in Finder, creating it first if it does not exist.

#### Scenario: Opening the folder
- **WHEN** the person presses the folder button
- **THEN** a Finder window shows `~/Pictures/Intelbras Viewer`
