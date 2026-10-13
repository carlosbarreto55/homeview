import AppKit
import Observation
import os

/// What the panel shows, which streams run, and the footer status.
@MainActor
@Observable
final class AppModel {
    enum Route: Equatable {
        /// Reading the saved settings (the Keychain can be slow to answer).
        case loading
        case setup
        case grid
        case enlarged(channel: Int)
        case dvrSettings
        case renameCameras

        var hasStreams: Bool {
            switch self {
            case .grid, .enlarged: true
            default: false
            }
        }
    }

    typealias Probe = (DVRSettings) async -> RTSPProbe.Result

    private(set) var route: Route = .loading
    private(set) var settings: DVRSettings?
    let cameras: CameraListStore
    /// The streams of the current view, one per tile.
    private(set) var sessions: [StreamSession] = []
    /// The last probe's answer since streams last played; `nil` when none.
    private(set) var lastProbe: RTSPProbe.Result?
    /// Checking the login before starting streams.
    private(set) var isVerifying = false
    private(set) var isPanelVisible = false
    /// "Abrir ao iniciar o Mac", as macOS last reported it.
    private(set) var opensAtLogin = false

    @ObservationIgnored private let settingsStore: DVRSettingsStore
    @ObservationIgnored private let probe: Probe
    @ObservationIgnored private let makePlayer: @MainActor () -> CameraPlayer
    @ObservationIgnored private let loginItem: LoginItem
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var probeTask: Task<Void, Never>?
    /// Where "Cancelar" in a form goes back to.
    @ObservationIgnored private var routeBeforeForm: Route = .grid

    init(
        settingsStore: DVRSettingsStore = DVRSettingsStore(),
        cameras: CameraListStore = CameraListStore(),
        probe: @escaping Probe = { settings in
            await RTSPProbe().check(host: settings.host, port: settings.port,
                                    user: settings.credentials.user, password: settings.credentials.password)
        },
        loginItem: LoginItem? = nil,
        makePlayer: @escaping @MainActor () -> CameraPlayer
    ) {
        self.settingsStore = settingsStore
        self.cameras = cameras
        self.probe = probe
        self.loginItem = loginItem ?? MainAppLoginItem()
        self.makePlayer = makePlayer
    }

    var status: ConnectionStatus {
        guard isPanelVisible, route.hasStreams else { return .idle }
        if isVerifying { return .connecting }
        if sessions.isEmpty, lastProbe == .wrongCredentials { return .wrongCredentials }
        return ConnectionStatus.derive(sessions: sessions.map(\.state), lastProbe: lastProbe)
    }

    func session(channel: Int) -> StreamSession? {
        sessions.first { $0.channel == channel }
    }

    // MARK: Panel

    func panelVisibilityChanged(_ visible: Bool) {
        guard visible != isPanelVisible else { return }
        isPanelVisible = visible
        Logger.panel.info("panel \(visible ? "visible" : "hidden", privacy: .public)")
        if visible {
            refreshLoginItem()
            if route == .loading {
                loadSettings()
            } else {
                startStreams(verify: true)
            }
        } else {
            stopStreams()
        }
    }

    // MARK: DVR settings

    enum SettingsError: Error, Equatable {
        case wrongCredentials
        case notFound(host: String, port: Int)
        case localNetworkDenied
        case saveFailed

        var message: String {
            switch self {
            case .wrongCredentials:
                "Usuário ou senha incorretos"
            case .notFound(let host, let port):
                "Não foi possível encontrar o DVR em \(host):\(port)"
            case .localNetworkDenied:
                "Permita o acesso à rede local em Ajustes do Sistema > Privacidade e Segurança > Rede Local"
            case .saveFailed:
                "Não foi possível guardar o usuário e a senha no Keychain"
            }
        }
    }

    /// The address shown in the setup form: the saved one, or the defaults.
    var formAddress: (host: String, port: Int) {
        settings.map { ($0.host, $0.port) } ?? settingsStore.savedAddress
    }

    /// "Conectar": checks the login with the DVR (one attempt), and only if
    /// it is accepted saves it and shows the cameras.
    func connect(host: String, port: Int, credentials: Credentials) async -> SettingsError? {
        let candidate = DVRSettings(host: host.trimmingCharacters(in: .whitespaces), port: port,
                                    credentials: credentials)
        if let error = await verifyAndSave(candidate) { return error }
        route = .grid
        startStreams(verify: false)
        return nil
    }

    /// "Salvar" in "Configurações do DVR": like "Conectar", but an empty
    /// password keeps the saved one, and it returns to the previous view.
    func saveSettings(host: String, port: Int, user: String, password: String) async -> SettingsError? {
        let password = password.isEmpty ? settings?.credentials.password ?? "" : password
        let candidate = DVRSettings(host: host.trimmingCharacters(in: .whitespaces), port: port,
                                    credentials: Credentials(user: user, password: password))
        if let error = await verifyAndSave(candidate) { return error }
        closeForm()
        return nil
    }

    /// "Esquecer DVR": removes the login and address and goes back to setup.
    func forgetDVR() {
        stopStreams()
        try? settingsStore.forget()
        settings = nil
        lastProbe = nil
        route = .setup
    }

    private func verifyAndSave(_ candidate: DVRSettings) async -> SettingsError? {
        switch await probe(candidate) {
        case .ok:
            break
        case .wrongCredentials:
            return .wrongCredentials
        case .notFound:
            return .notFound(host: candidate.host, port: candidate.port)
        case .localNetworkDenied:
            return .localNetworkDenied
        }
        let store = settingsStore
        let saved = await Task.detached { (try? store.save(candidate)) != nil }.value
        guard saved else { return .saveFailed }
        settings = candidate
        return nil
    }

    // MARK: Navigation

    func openCamera(channel: Int) {
        route = .enlarged(channel: channel)
        startStreams(verify: false)
    }

    func backToGrid() {
        route = .grid
        startStreams(verify: false)
    }

    func openDVRSettings() {
        openForm(.dvrSettings)
    }

    func openRenameCameras() {
        openForm(.renameCameras)
    }

    /// "Cancelar" (or "Concluído") in a form: back to the view it was opened from.
    func closeForm() {
        var previous = routeBeforeForm
        if case .enlarged(let channel) = previous, cameras.camera(channel: channel)?.isVisible != true {
            previous = .grid
        }
        route = settings == nil ? .setup : previous
        startStreams(verify: false)
    }

    /// "Concluído" in "Renomear câmeras": saves the names and visibility and
    /// shows the grid.
    func finishRenaming(_ edited: [Camera]) {
        cameras.apply(edited)
        route = .grid
        startStreams(verify: false)
    }

    /// The header's refresh button: every stream restarts now, with the shortest wait.
    func refresh() {
        guard route.hasStreams else { return }
        if sessions.isEmpty {
            startStreams(verify: true)
        } else {
            lastProbe = nil
            sessions.forEach { $0.restart() }
        }
    }

    /// "Sair": stops every stream, then quits.
    func quit() {
        stopStreams()
        NSApplication.shared.terminate(nil)
    }

    // MARK: Open at login

    /// Reads the login item state from macOS again.
    func refreshLoginItem() {
        opensAtLogin = loginItem.isEnabled
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            try loginItem.setEnabled(enabled)
        } catch {
            Logger.panel.error("login item: \(error.localizedDescription, privacy: .public)")
        }
        refreshLoginItem()
    }

    // MARK: Streams

    private func openForm(_ form: Route) {
        if route.hasStreams { routeBeforeForm = route }
        stopStreams()
        route = form
    }

    private func loadSettings() {
        let store = settingsStore
        loadTask = Task {
            let loaded = await Task.detached { try? store.load() }.value
            settings = loaded
            route = loaded == nil ? .setup : .grid
            startStreams(verify: true)
        }
    }

    private func startStreams(verify: Bool) {
        stopStreams()
        guard isPanelVisible, route.hasStreams, let settings, !streams(settings: settings).isEmpty else { return }
        lastProbe = nil
        guard verify else {
            play(streams(settings: settings))
            return
        }
        // One login check first: 8 streams with a rejected password would be
        // 8 failed logins, enough for the DVR to lock the user.
        isVerifying = true
        probeTask = Task {
            let result = await probe(settings)
            probeTask = nil
            guard !Task.isCancelled else { return }
            isVerifying = false
            if result == .wrongCredentials {
                lastProbe = .wrongCredentials
                Logger.panel.error("login rejected; streams not started")
            } else {
                play(streams(settings: settings))
            }
        }
    }

    private func play(_ streams: [StreamURL]) {
        sessions = streams.map { stream in
            let session = StreamSession(stream: stream, player: makePlayer())
            session.onStateChange = { [weak self] _ in self?.sessionsChanged() }
            return session
        }
        sessions.forEach { $0.start() }
    }

    private func stopStreams() {
        probeTask?.cancel()
        probeTask = nil
        isVerifying = false
        sessions.forEach { $0.stop() }
        sessions = []
    }

    /// The streams the current view shows.
    private func streams(settings: DVRSettings) -> [StreamURL] {
        switch route {
        case .grid:
            cameras.visibleCameras.map { settings.streamURL(channel: $0.channel, quality: .substream) }
        case .enlarged(let channel):
            [settings.streamURL(channel: channel, quality: .main)]
        default:
            []
        }
    }

    /// When every stream has failed, asks the probe why, once.
    private func sessionsChanged() {
        let states = sessions.map(\.state)
        if states.contains(.playing) {
            lastProbe = nil
            return
        }
        let allFailed = !states.isEmpty && states.allSatisfy { if case .failed = $0 { true } else { false } }
        guard allFailed, lastProbe == nil, probeTask == nil, let settings else { return }
        probeTask = Task {
            let result = await probe(settings)
            probeTask = nil
            guard !Task.isCancelled, !sessions.isEmpty else { return }
            lastProbe = result
            if result == .wrongCredentials {
                Logger.panel.error("login rejected; streams stop retrying")
                sessions.forEach { $0.suspendRetries() }
            }
        }
    }

    // MARK: Testing

    /// Waits for loading and probing started so far (for tests).
    func settle() async {
        await loadTask?.value
        await probeTask?.value
    }
}
