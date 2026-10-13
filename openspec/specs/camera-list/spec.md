# camera-list Specification

## Purpose
TBD - created by archiving change menu-bar-camera-viewer. Update Purpose after archive.
## Requirements
### Requirement: Default cameras
The app SHALL know 8 cameras, channels 1 to 8, named "Canal 1" to "Canal 8", all visible, until the person changes them.

#### Scenario: First use
- **WHEN** the person finishes first-run setup
- **THEN** the grid shows 8 tiles named "Canal 1" to "Canal 8"

### Requirement: Renaming cameras
"Renomear câmeras" SHALL show the 8 channels in order, each with its channel number, a text field with its name, and a "Mostrar" switch. Changes SHALL apply when the person presses "Concluído", which returns to the grid; "Cancelar" SHALL discard them. A name left empty or made only of spaces SHALL go back to the default "Canal N". Names SHALL be limited to 30 characters. Names and visibility SHALL persist across app restarts. A camera's name SHALL be used in its tile, in the enlarged view's header, and in its snapshot file names.

#### Scenario: Naming a camera
- **WHEN** the person renames channel 3 to "Garagem" and presses "Concluído"
- **THEN** tile 3 shows "Garagem", and after quitting and reopening the app it still shows "Garagem"

#### Scenario: Clearing a name
- **WHEN** the person erases the name of channel 3 and presses "Concluído"
- **THEN** tile 3 shows "Canal 3"

#### Scenario: Cancelling
- **WHEN** the person renames channel 5 and presses "Cancelar"
- **THEN** tile 5 keeps its previous name

### Requirement: Hiding cameras
A channel with "Mostrar" off SHALL NOT appear in the grid and SHALL NOT be streamed. When every channel is hidden, the grid SHALL show "Nenhuma câmera visível" with a "Escolher câmeras" button that opens "Renomear câmeras".

#### Scenario: Hiding unused channels
- **WHEN** the DVR has cameras only on channels 1 to 4 and the person turns "Mostrar" off for channels 5 to 8
- **THEN** the grid shows only 4 tiles, and the app opens no stream for channels 5 to 8

#### Scenario: Everything hidden
- **WHEN** the person turns "Mostrar" off for all 8 channels and presses "Concluído"
- **THEN** the grid shows "Nenhuma câmera visível" and an "Escolher câmeras" button

