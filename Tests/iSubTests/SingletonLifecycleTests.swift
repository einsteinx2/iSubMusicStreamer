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

        // The play queue captures its jukebox at construction, so the test jukebox
        // must be registered first (mirrors the composition root's ordering)
        jukebox = Jukebox(settings: settings, store: store)
        let registeredJukebox = jukebox!
        TestContainer.register { registeredJukebox }

        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue
        jukebox.attach(playQueue: freshPlayQueue)

        // LocalPlaylist.syncJukebox reads these ambiently (restored by
        // TestContainer.deactivate in tearDown)
        ModelServices.settings = settings
        ModelServices.jukebox = jukebox
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

    // The jukebox schedules a follow-up "get" 0.5s after every command, and after a
    // get it goes quiet for 30s — so a command is only briefly the LAST received
    // request, and asserting on .last races the follow-up (one main-thread stall at
    // the wrong moment misses the window forever). Always scan all received requests.
    @discardableResult
    private func waitForJukeboxRequest(timeout: TimeInterval = 5, matching predicate: (MockSubsonicServer.ReceivedRequest) -> Bool) -> MockSubsonicServer.ReceivedRequest? {
        var match: MockSubsonicServer.ReceivedRequest?
        waitUntil(timeout: timeout) {
            match = MockSubsonicServer.receivedRequests(action: .jukeboxControl).first(where: predicate)
            return match != nil
        }
        return match
    }

    // MARK: Command construction

    func testPlaySongSendsSkipAndUpdatesIndex() {
        // Stub a status whose currentIndex matches the skip target: the stub responds
        // instantly on a background thread and the parsed status overwrites
        // playQueue.currentIndex, so any other value races the assertion below
        let statusXML = #"<subsonic-response xmlns="http://subsonic.org/restapi" status="ok" version="1.15.0"><jukeboxStatus currentIndex="3" playing="false" gain="0.75" position="42"/></subsonic-response>"#
        MockSubsonicServer.stub(.jukeboxControl, data: Data(statusXML.utf8))

        jukebox.playSong(index: 3)

        XCTAssertEqual(playQueue.currentIndex, 3, "the local index tracks the jukebox immediately")

        let skipRequest = waitForJukeboxRequest { $0.parameter("action") == "skip" }
        XCTAssertNotNil(skipRequest, "no jukebox skip request was sent")
        XCTAssertEqual(skipRequest?.parameter("index"), "3")
        // The synthetic status carries a nonzero position (a real server that can't
        // open an audio device always reports 0, so this is only testable inline)
        XCTAssertTrue(waitUntil { self.jukebox.position == 42 })
    }

    func testTransportActionsSendExpectedCommands() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")

        jukebox.play()
        XCTAssertTrue(jukebox.isPlaying)
        XCTAssertNotNil(waitForJukeboxRequest { $0.parameter("action") == "start" })

        jukebox.stop()
        XCTAssertFalse(jukebox.isPlaying)
        XCTAssertNotNil(waitForJukeboxRequest { $0.parameter("action") == "stop" })

        jukebox.setVolume(level: 0.5)
        XCTAssertNotNil(waitForJukeboxRequest {
            $0.parameter("action") == "setGain" && $0.parameter("gain") == "0.5"
        })

        jukebox.seek(seconds: 42)
        XCTAssertNotNil(waitForJukeboxRequest {
            $0.parameter("action") == "skip" && $0.parameter("offset") == "42"
        })
    }

    func testAddSongIdsSendsRepeatedIdParameters() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")

        jukebox.add(songIds: ["10", "20", "30"])

        let addRequest = waitForJukeboxRequest { $0.parameter("action") == "add" }
        XCTAssertNotNil(addRequest, "no jukebox add request was sent")
        XCTAssertEqual(addRequest?.parameters["id"], ["10", "20", "30"])
    }

    func testAddEmptySongIdsSendsNothing() {
        jukebox.add(songIds: [])
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(MockSubsonicServer.receivedRequests(action: .jukeboxControl).count, 0)
    }

    // MARK: Playing from local playlists / queues (STUB-09)

    private func seedLocalPlaylist(id: Int, songIds: [String]) {
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: id, name: "Saved \(id)")))
        for songId in songIds {
            let song = TestData.song(serverId: 1, id: songId, title: "Song \(songId)", path: "A/\(songId).mp3")
            _ = store.add(song: song)
            XCTAssertTrue(store.add(song: song, localPlaylistId: id))
        }
    }

    func testPlaySongFromLocalPlaylistSyncsJukeboxAndSkips_STUB09() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")
        // The store resolves the Jukebox singleton for the remote sync
        let registeredJukebox = jukebox!
        TestContainer.register { registeredJukebox }
        seedLocalPlaylist(id: 5, songIds: ["1", "2"])

        let played = store.playSong(position: 1, localPlaylistId: 5)

        XCTAssertEqual(played?.id, "2")
        // The jukebox play queue (not the normal one) is filled, with its count updated
        XCTAssertEqual(playQueue.currentPlaylistId, LocalPlaylist.Default.jukeboxPlayQueueId)
        XCTAssertEqual(playQueue.songs().map(\.id), ["1", "2"])
        XCTAssertEqual(playQueue.count, 2, "the play queue's songCount must be updated")

        // The remote playlist is synced (clear + add) and the song started via skip
        XCTAssertTrue(waitUntil {
            let actions = MockSubsonicServer.receivedRequests(action: .jukeboxControl).compactMap { $0.parameter("action") }
            return actions.contains("clear") && actions.contains("add") && actions.contains("skip")
        }, "expected clear/add/skip jukebox commands")
        let requests = MockSubsonicServer.receivedRequests(action: .jukeboxControl)
        XCTAssertEqual(requests.first { $0.parameter("action") == "add" }?.parameters["id"], ["1", "2"])
        XCTAssertEqual(requests.first { $0.parameter("action") == "skip" }?.parameter("index"), "1")
    }

    func testPlaySongsListSyncsJukeboxAndSkips_STUB09() {
        // The playSong(position:songs:) path backs server shuffle and play-from-search
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")
        let registeredJukebox = jukebox!
        TestContainer.register { registeredJukebox }
        let songs = ["1", "2", "3"].map { TestData.song(serverId: 1, id: $0, title: "Song \($0)", path: "A/\($0).mp3") }
        songs.forEach { _ = store.add(song: $0) }

        let played = store.playSong(position: 0, songs: songs)

        XCTAssertEqual(played?.id, "1")
        XCTAssertTrue(waitUntil {
            let actions = MockSubsonicServer.receivedRequests(action: .jukeboxControl).compactMap { $0.parameter("action") }
            return actions.contains("clear") && actions.contains("add") && actions.contains("skip")
        }, "expected clear/add/skip jukebox commands")
        let addRequest = MockSubsonicServer.receivedRequests(action: .jukeboxControl).first { $0.parameter("action") == "add" }
        XCTAssertEqual(addRequest?.parameters["id"], ["1", "2", "3"])
    }

    func testLocalPlaylistQueueSyncsJukebox_STUB09() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")
        let registeredJukebox = jukebox!
        TestContainer.register { registeredJukebox }
        seedLocalPlaylist(id: 5, songIds: ["1", "2"])

        store.localPlaylist(id: 5)?.queue()

        // Songs land in the local jukebox queue and the remote playlist is synced
        XCTAssertEqual(store.songs(localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId).map(\.id), ["1", "2"])
        XCTAssertTrue(waitUntil {
            let actions = MockSubsonicServer.receivedRequests(action: .jukeboxControl).compactMap { $0.parameter("action") }
            return actions.contains("add")
        }, "queueing a local playlist must add its songs to the remote jukebox playlist")
    }

    // MARK: Response parsing

    func testStatusResponseUpdatesPlaybackState() {
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")
        jukebox.play()

        // The fixture reports currentIndex=1, playing=false, gain=0.75, position=0
        XCTAssertTrue(waitUntil { self.jukebox.gain == 0.75 })
        XCTAssertFalse(jukebox.isPlaying, "the server-reported state wins")
        XCTAssertEqual(jukebox.position, 0)
        XCTAssertEqual(playQueue.currentIndex, 1)
    }

    func testGetResponsePersistsSongsAndReplacesLocalJukeboxQueue_BUG31() {
        // The playlist references songs never browsed locally: the response must
        // persist their metadata so the JOIN-based queue reads can resolve them
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_get.xml")

        jukebox.getInfo(delay: 0)

        let infoExpectation = expectation(forNotification: Notifications.jukeboxSongInfo, object: nil, handler: nil)
        wait(for: [infoExpectation], timeout: 10)

        XCTAssertTrue(jukebox.isPlaying)
        XCTAssertEqual(jukebox.gain, 0.75)
        XCTAssertEqual(jukebox.position, 0)
        XCTAssertEqual(playQueue.currentIndex, 1)

        // The playlist entries land in the jukebox play queue (jukebox mode is on)
        // with their metadata persisted from the response
        let queued = store.songs(localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId)
        XCTAssertEqual(queued.map(\.id), ["189", "203"])
        XCTAssertEqual(queued.map(\.title), ["So Many Tears", "Seven Years"], "song metadata comes from the response")
        XCTAssertEqual(playQueue.count, 2)
        XCTAssertEqual(playQueue.currentSong?.id, "203", "currentSong must resolve so playback skips can be issued")
    }

    func testGetResponseKeepsMatchingLocalQueueIntact_BUG31() {
        // A local queue that already matches the server's list (e.g. freshly built by
        // play-all) must not be cleared and rebuilt by the periodic refresh
        let localA = TestData.song(serverId: 1, id: "189", title: "Local Title A", path: "a/1.mp3")
        let localB = TestData.song(serverId: 1, id: "203", title: "Local Title B", path: "a/2.mp3")
        _ = store.add(song: localA)
        _ = store.add(song: localB)
        _ = store.queue(song: localA)
        _ = store.queue(song: localB)
        try? MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_get.xml")

        jukebox.getInfo(delay: 0)
        let infoExpectation = expectation(forNotification: Notifications.jukeboxSongInfo, object: nil, handler: nil)
        wait(for: [infoExpectation], timeout: 10)

        let queued = store.songs(localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId)
        XCTAssertEqual(queued.map(\.id), ["189", "203"])
        XCTAssertEqual(queued.map(\.title), ["Local Title A", "Local Title B"],
                       "a queue matching the server's list is left untouched")
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
        XCTAssertNotNil(waitForJukeboxRequest { $0.parameter("action") == "stop" })
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
        // Cascade deletion of the server's browse/download data is covered by
        // ServerStoreTests.testDeleteServerCascadesAllScopedDataAndFiles
    }
}

// MARK: - Launch offline-mode decision (BUG-24)

final class LaunchOfflineCheckTests: XCTestCase {
    func testForceOfflineModeWinsRegardlessOfNetwork() {
        let message = SceneDelegate.launchOfflineAlertMessage(isForceOfflineMode: true, isNetworkReachable: true,
                                                              isWifi: true, isDisableUsageOver3G: false)
        XCTAssertEqual(message, "Offline mode switch on, entering offline mode.")
    }

    func testNoNetworkEntersOfflineMode() {
        let message = SceneDelegate.launchOfflineAlertMessage(isForceOfflineMode: false, isNetworkReachable: false,
                                                              isWifi: false, isDisableUsageOver3G: false)
        XCTAssertEqual(message, "No network detected, entering offline mode.")
    }

    func testCellularWithUsageDisabledEntersOfflineMode() {
        let message = SceneDelegate.launchOfflineAlertMessage(isForceOfflineMode: false, isNetworkReachable: true,
                                                              isWifi: false, isDisableUsageOver3G: true)
        XCTAssertEqual(message, "You are not on Wifi, and have chosen to disable use over cellular. Entering offline mode.")
    }

    func testOnlineConditionsStayOnline() {
        // Wifi
        XCTAssertNil(SceneDelegate.launchOfflineAlertMessage(isForceOfflineMode: false, isNetworkReachable: true,
                                                             isWifi: true, isDisableUsageOver3G: true))
        // Cellular with usage allowed
        XCTAssertNil(SceneDelegate.launchOfflineAlertMessage(isForceOfflineMode: false, isNetworkReachable: true,
                                                             isWifi: false, isDisableUsageOver3G: false))
    }
}
