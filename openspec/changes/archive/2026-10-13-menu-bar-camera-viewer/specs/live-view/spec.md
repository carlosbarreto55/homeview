## ADDED Requirements

### Requirement: Camera grid
When the DVR is configured, the panel content SHALL be a grid of the visible cameras in two columns, ordered by channel number. Each tile SHALL play the camera's substream live and show the camera's name and a badge with its channel number. When the tiles do not fit the panel's height, the grid SHALL scroll.

#### Scenario: All eight channels visible
- **WHEN** all 8 channels are visible and the person opens the panel
- **THEN** the grid shows 8 live tiles in 2 columns, from channel 1 at the top left to channel 8 at the bottom right, each with its name and channel badge

#### Scenario: Some channels hidden
- **WHEN** channels 7 and 8 are hidden and the person opens the panel
- **THEN** the grid shows 6 tiles, channels 1 to 6, and channels 7 and 8 are not streamed

### Requirement: 16:9 display
Every camera picture, in the grid and in the enlarged view, SHALL be drawn filling a 16:9 frame exactly, without letterboxing or cropping, whatever the stream's pixel size.

#### Scenario: A 960x1080 channel
- **WHEN** channel 1, whose stream is 960x1080, is shown
- **THEN** its picture fills a 16:9 frame, and a round object in front of the camera looks round, not squeezed

#### Scenario: The 1280x720 channel
- **WHEN** channel 8, whose stream is 1280x720, is shown
- **THEN** its picture fills the same 16:9 frame size as the other tiles

### Requirement: Enlarged camera
Clicking a tile SHALL replace the grid with that camera alone at the panel's full width, playing its main stream. The header SHALL show a back control with the camera's name ("‹ Garagem") and a snapshot button, in place of the "Câmeras" title. While a camera is enlarged, the grid's streams SHALL stop. The back control SHALL return to the grid and restart its streams.

#### Scenario: Opening a camera
- **WHEN** the person clicks the "Canal 6" tile
- **THEN** the panel shows only channel 6, from its main stream, with "‹ Canal 6" and the snapshot button in the header, and the other channels stop streaming

#### Scenario: Going back
- **WHEN** channel 6 is enlarged and the person clicks "‹ Canal 6"
- **THEN** the grid returns and its tiles start playing again

### Requirement: Streams follow the panel
Streams SHALL start when the panel opens and SHALL all stop within 1 second after it closes. Reopening the panel SHALL show the view the person left, the grid or the same enlarged camera, and start its streams again.

#### Scenario: Closing the panel
- **WHEN** the grid is playing and the person closes the panel
- **THEN** within 1 second the app has no open connection to the DVR's RTSP port

#### Scenario: Reopening on an enlarged camera
- **WHEN** the person closed the panel while channel 2 was enlarged, then opens it again
- **THEN** the panel shows channel 2 enlarged, playing its main stream

### Requirement: Per-camera loading and failure
While a camera is starting, its tile SHALL show its name and "Conectando…". When a camera fails or its stream stops, its tile SHALL show "Sem sinal" and retry automatically while the panel is open, after 5 seconds and then doubling the wait up to 30 seconds. A failing camera SHALL NOT affect the others. When a retry succeeds, the tile SHALL play again and the wait SHALL reset to 5 seconds.

#### Scenario: A camera unplugged
- **WHEN** the camera on channel 4 is unplugged from the DVR and the panel is open
- **THEN** tile 4 shows "Sem sinal" and the other tiles keep playing

#### Scenario: The camera comes back
- **WHEN** channel 4 shows "Sem sinal" and the camera is plugged back in
- **THEN** within 30 seconds tile 4 plays again without any action from the person

### Requirement: Refresh
The refresh button in the header SHALL stop and restart every stream in the current view immediately, resetting the retry waits.

#### Scenario: Refreshing a failed camera
- **WHEN** tile 4 shows "Sem sinal" and is waiting 30 seconds for its next retry, and the person presses refresh
- **THEN** every tile, tile 4 included, restarts right away
