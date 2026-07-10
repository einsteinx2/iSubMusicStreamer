//
//  SingletonLifecycleTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-12: singleton/lifecycle integration tests — Jukebox command construction and
// response parsing, ServerChecker online/offline transitions and capability
// persistence, and the add/select/delete server lifecycle.
final class JukeboxTests: StoreTestCase {
    private var jukebox: Jukebox!
    private var playQueue: PlayQueue!
    private var settings: SavedSettings!
    private var server: Server!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()

        server = TestData.server(id: 1, urlString: "https://mock.example.com")
        XCTAssertTrue(store.add(server: server))

        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
        settings.currentServer = server
        settings.isJukeboxEnabled = true

        TestContainer.register { FakeStreamManager() as StreamManaging }
        TestContainer.register { FakeDownloadQueue() as DownloadQueueing }
        TestContainer.register { FakePlayer() as PlayerControlling }
        let freshPlayQueue = PlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue

        jukebox = Jukebox()
    }

    override func tearDownWithError() throws {
        // Push any pending periodic getInfo far past the process lifetime
        jukebox?.getInfo(delay: 999_999)
        jukebox = nil
        playQueue = nil
        settings = nil
        server = nil
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    private func lastJukeboxRequest() -> MockSubsonicServer.ReceivedRequest? {
        MockSubsonicServer.receivedRequests(action: .jukeboxControl).last
    }

    // MARK: Command construction

    func testPlaySongSendsSkipAndUpdatesIndex() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")

        jukebox.playSong(index: 3)

        // Assert the synchronous index update before waiting on the request: once the
        // stubbed status response is parsed it overwrites currentIndex with the
        // fixture's value, so checking after the wait races the response
        XCTAssertEqual(playQueue.currentIndex, 3, "the local index tracks the jukebox immediately")

        XCTAssertTrue(waitUntil { self.lastJukeboxRequest() != nil })
        XCTAssertEqual(lastJukeboxRequest()?.parameter("action"), "skip")
        XCTAssertEqual(lastJukeboxRequest()?.parameter("index"), "3")
    }

    func testTransportActionsSendExpectedCommands() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")

        jukebox.play()
        XCTAssertTrue(jukebox.isPlaying)
        XCTAssertTrue(waitUntil { self.lastJukeboxRequest()?.parameter("action") == "start" })

        jukebox.stop()
        XCTAssertFalse(jukebox.isPlaying)
        XCTAssertTrue(waitUntil { self.lastJukeboxRequest()?.parameter("action") == "stop" })

        jukebox.setVolume(level: 0.5)
        XCTAssertTrue(waitUntil {
            let request = self.lastJukeboxRequest()
            return request?.parameter("action") == "setGain" && request?.parameter("gain") == "0.5"
        })

        jukebox.seek(seconds: 42)
        XCTAssertTrue(waitUntil {
            let request = self.lastJukeboxRequest()
            return request?.parameter("action") == "skip" && request?.parameter("offset") == "42"
        })
    }

    func testAddSongIdsSendsRepeatedIdParameters() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")

        jukebox.add(songIds: ["10", "20", "30"])

        XCTAssertTrue(waitUntil { self.lastJukeboxRequest()?.parameter("action") == "add" })
        XCTAssertEqual(lastJukeboxRequest()?.parameters["id"], ["10", "20", "30"])
    }

    func testAddEmptySongIdsSendsNothing() {
        jukebox.add(songIds: [])
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .jukeboxControl).count, 0)
    }

    // MARK: Response parsing

    func testStatusResponseUpdatesPlaybackState() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")
        jukebox.play()

        // The fixture reports currentIndex=1, playing=false, gain=0.75, position=42
        XCTAssertTrue(waitUntil { self.jukebox.gain == 0.75 })
        XCTAssertFalse(jukebox.isPlaying, "the server-reported state wins")
        XCTAssertEqual(jukebox.position, 42)
        XCTAssertEqual(playQueue.currentIndex, 1)
    }

    func testGetResponseReplacesLocalJukeboxQueue() {
        // The jukebox playlist references songs the client already knows (Song.queue()
        // only writes play-queue rows), so seed the shared song records first
        _ = store.add(song: TestData.song(serverId: 1, id: "376", title: "Going Crazy", path: "One Gud Cide/13.mp3"))
        _ = store.add(song: TestData.song(serverId: 1, id: "229", title: "Devils Haircut", path: "Beck/01.mp3"))
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_get.xml")

        jukebox.getInfo(delay: 0)

        let infoExpectation = expectation(forNotification: Notifications.jukeboxSongInfo, object: nil, handler: nil)
        wait(for: [infoExpectation], timeout: 10)

        XCTAssertTrue(jukebox.isPlaying)
        XCTAssertEqual(jukebox.gain, 0.75)
        XCTAssertEqual(jukebox.position, 42)
        XCTAssertEqual(playQueue.currentIndex, 1)

        // The playlist entries land in the jukebox play queue (jukebox mode is on)
        let queued = store.songs(localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId)
        XCTAssertEqual(Set(queued.map(\.id)), ["376", "229"])
        XCTAssertEqual(playQueue.count, 2)
    }

    func testNotAuthorizedErrorDisablesJukebox() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_error_not_authorized.xml")
        XCTAssertTrue(settings.isJukeboxEnabled)

        let disabledExpectation = expectation(forNotification: Notifications.jukeboxDisabled, object: nil, handler: nil)
        jukebox.play()
        wait(for: [disabledExpectation], timeout: 10)

        XCTAssertFalse(settings.isJukeboxEnabled, "a code-50 error turns jukebox mode off")
    }

    func testSkipNextPastEndStops() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")
        // Empty play queue: nextIndex (0) is not < count (0), so playback ends
        let endedExpectation = expectation(forNotification: Notifications.songPlaybackEnded, object: nil, handler: nil)

        jukebox.skipNext()

        wait(for: [endedExpectation], timeout: 10)
        XCTAssertFalse(jukebox.isPlaying)
        XCTAssertTrue(waitUntil { self.lastJukeboxRequest()?.parameter("action") == "stop" })
    }
}

// MARK: - ServerChecker

final class ServerCheckerTests: StoreTestCase {
    private var serverChecker: ServerChecker!
    private var settings: SavedSettings!
    private var downloadQueue: FakeDownloadQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()

        downloadQueue = FakeDownloadQueue()
        let fakeDownloadQueue = downloadQueue!
        TestContainer.register { fakeDownloadQueue as DownloadQueueing }
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
    }

    override func tearDownWithError() throws {
        serverChecker?.cancelNextServerCheck()
        serverChecker = nil
        settings = nil
        downloadQueue = nil
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    private func makeCurrentServer(isVideoSupported: Bool = true, isNewSearchSupported: Bool = true) -> Server {
        let server = TestData.server(id: 1, urlString: "https://mock.example.com")
        server.isVideoSupported = isVideoSupported
        server.isNewSearchSupported = isNewSearchSupported
        XCTAssertTrue(store.add(server: server))
        settings.currentServer = server
        return server
    }

    func testSuccessfulCheckStartsDownloadQueue() throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")
        _ = makeCurrentServer()

        serverChecker = ServerChecker()
        serverChecker.checkServer()

        XCTAssertTrue(waitUntil { self.downloadQueue.startCount > 0 }, "a passing check resumes the download queue")
    }

    func testSuccessfulCheckSkipsDownloadQueueAfterCrash() throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")
        _ = makeCurrentServer()
        settings.appCrashedOnLastRun = true

        let passedExpectation = expectation(forNotification: Notifications.serverCheckPassed, object: nil, handler: nil)
        serverChecker = ServerChecker()
        serverChecker.checkServer()
        wait(for: [passedExpectation], timeout: 10)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(downloadQueue.startCount, 0, "the download queue must not auto-start after a crash")
    }

    func testSuccessfulCheckUpdatesServerCapabilities() throws {
        // The ping fixture reports API 1.15.0, so both capabilities should flip to true
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")
        _ = makeCurrentServer(isVideoSupported: false, isNewSearchSupported: false)

        serverChecker = ServerChecker()
        serverChecker.checkServer()

        XCTAssertTrue(waitUntil { self.store.server(id: 1)?.isVideoSupported == true }, "capability flags are persisted after a successful check")
        XCTAssertEqual(store.server(id: 1)?.isNewSearchSupported, true)
        XCTAssertEqual(settings.currentServer?.isVideoSupported, true)
    }

    func testSuccessfulCheckPostsGoOnlineWhenOffline() throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")
        _ = makeCurrentServer()
        settings.isOfflineMode = true

        let onlineExpectation = expectation(forNotification: Notifications.goOnline, object: nil, handler: nil)
        serverChecker = ServerChecker()
        serverChecker.checkServer()
        wait(for: [onlineExpectation], timeout: 10)
    }

    func testFailedCheckPostsGoOffline() {
        MockSubsonicServer.stubConnectionError(.ping, code: .cannotConnectToHost)
        _ = makeCurrentServer()
        XCTAssertFalse(settings.isOfflineMode)

        let offlineExpectation = expectation(forNotification: Notifications.goOffline, object: nil, handler: nil)
        serverChecker = ServerChecker()
        serverChecker.checkServer()
        wait(for: [offlineExpectation], timeout: 10)
    }

    func testCheckServerRespondsToNotification() throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")
        _ = makeCurrentServer()
        serverChecker = ServerChecker()

        let passedExpectation = expectation(forNotification: Notifications.serverCheckPassed, object: nil, handler: nil)
        NotificationCenter.postOnMainThread(name: Notifications.checkServer)
        wait(for: [passedExpectation], timeout: 10)
    }

    func testCheckWithoutCurrentServerDoesNothing() {
        serverChecker = ServerChecker()
        serverChecker.checkServer()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertEqual(MockSubsonicServer.receivedRequests.count, 0, "no ping without a configured server")
        XCTAssertEqual(downloadQueue.startCount, 0)
    }
}

// MARK: - Server lifecycle

final class ServerLifecycleTests: StoreTestCase {
    private var settings: SavedSettings!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
    }

    override func tearDownWithError() throws {
        settings = nil
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    // The add-server flow: verify credentials with the status loader, then persist
    // the server with the reported capabilities and select it
    func testAddServerFlowAllocatesIdPersistsCapabilitiesAndSelects() async throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")

        // An existing server occupies id 1
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))

        let status = try await AsyncStatusLoader(urlString: "https://new.example.com", username: "u", password: "p").load()
        let newId = store.nextServerId()
        XCTAssertEqual(newId, 2, "new servers get MAX(id)+1")

        let server = Server(id: newId, type: .subsonic, url: URL(string: "https://new.example.com")!, username: "u", password: "p")
        server.isVideoSupported = status.isVideoSupported
        server.isNewSearchSupported = status.isNewSearchSupported
        XCTAssertTrue(store.add(server: server))
        settings.currentServer = server

        let persisted = try XCTUnwrap(store.server(id: 2))
        XCTAssertTrue(persisted.isVideoSupported, "capabilities from the ping response are persisted")
        XCTAssertTrue(persisted.isNewSearchSupported)
        XCTAssertEqual(settings.currentServerId, 2)
        XCTAssertEqual(testDefaults.object(forKey: SavedSettings.Key.currentServerId.rawValue) as? Int, 2)
    }

    func testFailedVerificationDoesNotPersistServer() async throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_error_wrong_credentials.xml")

        do {
            _ = try await AsyncStatusLoader(urlString: "https://new.example.com", username: "u", password: "wrong").load()
            XCTFail("expected badCredentials")
        } catch SubsonicError.badCredentials {
            // The add flow only persists after a successful check (see BUG-17 for the
            // phantom-entry investigation on the real ServerEditViewController path)
            XCTAssertEqual(store.servers().count, 0)
            XCTAssertNil(settings.currentServer)
        }
    }

    func testDeleteServerRemovesRow() {
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))
        XCTAssertTrue(store.add(server: TestData.server(id: 2, urlString: "http://two.example.com")))

        XCTAssertTrue(store.deleteServer(id: 1))

        XCTAssertNil(store.server(id: 1))
        XCTAssertNotNil(store.server(id: 2))
        // NOTE: cascade deletion of the server's browse/download data is STUB-08;
        // extend this test when that lands
    }
}
