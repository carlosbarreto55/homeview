## ADDED Requirements

### Requirement: First-run setup
When no DVR credentials are saved, the panel SHALL show a "Configurar DVR" form instead of the grid, with the fields "Endereço" (prefilled with 192.168.1.2), "Porta" (prefilled with 554), "Usuário" and "Senha", and a "Conectar" button. The password field SHALL hide what is typed. "Conectar" SHALL check the credentials with an authenticated request to the DVR's RTSP service before saving anything. Only when the DVR accepts them SHALL the app save the settings and show the camera grid.

#### Scenario: Valid credentials
- **WHEN** the person enters the `macapp` user and its correct password and presses "Conectar"
- **THEN** the settings are saved and the panel shows the camera grid

#### Scenario: Wrong password
- **WHEN** the person enters a wrong password and presses "Conectar"
- **THEN** the form stays open with the message "Usuário ou senha incorretos", and nothing is saved

#### Scenario: DVR not reachable
- **WHEN** the person enters the address 192.168.1.250, where no device answers, and presses "Conectar"
- **THEN** within 5 seconds the form shows "Não foi possível encontrar o DVR em 192.168.1.250:554", and nothing is saved

#### Scenario: Local network access denied
- **WHEN** macOS has denied the app access to the local network and the person presses "Conectar"
- **THEN** the form shows "Permita o acesso à rede local em Ajustes do Sistema > Privacidade e Segurança > Rede Local"

### Requirement: Credential storage
The user and password SHALL be stored only in the macOS Keychain. The address and port SHALL be stored in the app's preferences. The password SHALL NOT be written to any file, preference, or log, and stream addresses containing credentials SHALL NOT be shown in the interface or logged.

#### Scenario: Restarting the app
- **WHEN** the person configured the DVR, quits the app and opens it again
- **THEN** opening the panel shows the camera grid without asking for the credentials

#### Scenario: Password stays out of preferences
- **WHEN** the DVR is configured
- **THEN** the password appears in the Keychain under the app's entry, and does not appear in the app's preferences file or in the system log

### Requirement: Changing or forgetting the DVR
"Configurações do DVR" SHALL show the same form with the saved address, port and user, and an empty password field with the hint "Deixe em branco para manter a atual". "Salvar" SHALL check the credentials the same way as first-run setup before replacing the saved ones. The form SHALL offer "Esquecer DVR", which removes the Keychain entry and the saved address, stops every stream, and returns to first-run setup. A "Cancelar" button SHALL return to the previous view without changes.

#### Scenario: Keeping the current password
- **WHEN** the person opens "Configurações do DVR", changes only the port, leaves the password empty and presses "Salvar"
- **THEN** the app checks the new port with the saved password and, if the DVR accepts it, saves the new port

#### Scenario: Forgetting the DVR
- **WHEN** the person presses "Esquecer DVR"
- **THEN** the Keychain entry is removed, every stream stops, and the panel shows "Configurar DVR"

### Requirement: Stream addresses
For channel N (1 to 8), the app SHALL use `rtsp://HOST:PORT/cam/realmonitor?channel=N&subtype=1` for the grid (substream) and `rtsp://HOST:PORT/cam/realmonitor?channel=N&subtype=0` for the enlarged view (main stream), with the saved credentials. Credentials with characters that are special in URLs SHALL work.

#### Scenario: Grid address for channel 3
- **WHEN** the grid starts channel 3 on a DVR at 192.168.1.2 port 554
- **THEN** the stream requested is `/cam/realmonitor?channel=3&subtype=1` on 192.168.1.2:554

#### Scenario: Password with special characters
- **WHEN** the saved password is `a@b:c/d#e`
- **THEN** the DVR receives exactly that password and the camera plays

### Requirement: Connection status
The panel footer SHALL show one status: "Conectando…" while no camera has started and at least one is still trying; "Conectado" while at least one camera is playing; "Sem conexão com o DVR" when every attempt has failed because the DVR could not be reached; "Usuário ou senha incorretos" with a "Corrigir" button that opens "Configurações do DVR" when the DVR rejects the saved credentials.

#### Scenario: Normal use
- **WHEN** the panel is open and the grid's cameras are playing
- **THEN** the footer shows "Conectado"

#### Scenario: Password changed on the DVR
- **WHEN** someone changed the `macapp` password on the DVR and the person opens the panel
- **THEN** the footer shows "Usuário ou senha incorretos" with a "Corrigir" button

#### Scenario: Away from home
- **WHEN** the Mac is on a different network where 192.168.1.2 does not answer and the person opens the panel
- **THEN** the footer shows "Sem conexão com o DVR"
