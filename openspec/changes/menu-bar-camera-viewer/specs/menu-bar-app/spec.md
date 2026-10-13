## ADDED Requirements

### Requirement: Menu bar only
The app SHALL appear only as an icon in the right side of the macOS menu bar, a video camera symbol. It SHALL NOT show an icon in the Dock, SHALL NOT appear in the Cmd+Tab app switcher, and SHALL NOT open any window on launch.

#### Scenario: Launching the app
- **WHEN** the person opens the app from Finder
- **THEN** a camera icon appears in the menu bar, no Dock icon appears, and no window or panel opens

### Requirement: Floating panel
Clicking the menu bar icon SHALL open a floating panel attached below the icon. The panel SHALL have a header with the title "Câmeras", a refresh button and a "…" menu button, a content area, and a footer with the connection status and a button that opens the snapshots folder. Clicking the icon again, clicking outside the panel, or pressing Esc SHALL close the panel.

#### Scenario: Opening the panel
- **WHEN** the DVR is configured and the person clicks the menu bar icon
- **THEN** the panel opens below the icon with the "Câmeras" header, the camera grid and the status footer

#### Scenario: Closing by clicking outside
- **WHEN** the panel is open and the person clicks on the desktop
- **THEN** the panel closes

#### Scenario: Closing with Esc
- **WHEN** the panel is open, is not showing a text field being edited, and the person presses Esc
- **THEN** the panel closes

### Requirement: Panel menu
The "…" button SHALL open a menu with, in order: "Renomear câmeras", "Configurações do DVR", an "Abrir ao iniciar o Mac" item with a checkmark when it is on, and "Sair". "Sair" SHALL stop every stream and quit the app.

#### Scenario: Quitting
- **WHEN** the person chooses "Sair" from the "…" menu
- **THEN** every stream stops, the camera icon disappears from the menu bar and the app process ends

### Requirement: Open at login
"Abrir ao iniciar o Mac" SHALL register or unregister the app as a login item with macOS. It SHALL be off on first launch. Its checkmark SHALL reflect the state macOS reports, including changes the person makes in System Settings.

#### Scenario: Turning it on
- **WHEN** the person chooses "Abrir ao iniciar o Mac" while it is off, then logs out and back in
- **THEN** the camera icon is in the menu bar after login, and the menu item shows a checkmark

#### Scenario: Turned off in System Settings
- **WHEN** the option is on, and the person removes the app under System Settings > General > Login Items, then opens the "…" menu
- **THEN** "Abrir ao iniciar o Mac" shows no checkmark
