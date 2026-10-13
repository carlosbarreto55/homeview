import XCTest
@testable import HomeView

final class ConnectionStatusTests: XCTestCase {
    private let failed = StreamSession.State.failed(nextRetry: Date())

    private func derive(_ sessions: [StreamSession.State], probe: RTSPProbe.Result? = nil) -> ConnectionStatus {
        ConnectionStatus.derive(sessions: sessions, lastProbe: probe)
    }

    func testConnectingWhileNothingHasStarted() {
        XCTAssertEqual(derive([.connecting, .connecting]), .connecting)
        XCTAssertEqual(derive([.connecting, failed]), .connecting)
        XCTAssertEqual(ConnectionStatus.connecting.text, "Conectando…")
    }

    func testConnectedWhenAnyCameraPlays() {
        XCTAssertEqual(derive([.playing, failed, .connecting]), .connected)
        XCTAssertEqual(ConnectionStatus.connected.text, "Conectado")
    }

    func testPlayingWinsOverAnOldProbe() {
        XCTAssertEqual(derive([.playing], probe: .wrongCredentials), .connected)
    }

    func testUnreachableWhenEveryStreamFailedAndTheDVRIsNotFound() {
        XCTAssertEqual(derive([failed, failed], probe: .notFound), .unreachable)
        XCTAssertEqual(derive([failed], probe: .localNetworkDenied), .unreachable)
        XCTAssertEqual(ConnectionStatus.unreachable.text, "Sem conexão com o DVR")
        XCTAssertFalse(ConnectionStatus.unreachable.offersFix)
    }

    func testStillConnectingWhileTheProbeRuns() {
        XCTAssertEqual(derive([failed, failed], probe: nil), .connecting)
    }

    func testWrongCredentials() {
        let suspended = StreamSession.State.failed(nextRetry: nil)
        XCTAssertEqual(derive([suspended, suspended], probe: .wrongCredentials), .wrongCredentials)
        XCTAssertEqual(ConnectionStatus.wrongCredentials.text, "Usuário ou senha incorretos")
        XCTAssertTrue(ConnectionStatus.wrongCredentials.offersFix)
    }

    func testIdleWithoutStreams() {
        XCTAssertEqual(derive([]), .idle)
        XCTAssertEqual(derive([.stopped, .stopped]), .idle)
        XCTAssertEqual(ConnectionStatus.idle.text, "")
    }

    func testStoppedSessionsDoNotCount() {
        XCTAssertEqual(derive([.stopped, .playing]), .connected)
        XCTAssertEqual(derive([.stopped, failed], probe: .notFound), .unreachable)
    }
}
