//
//  ServersViewModelTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The server list view model's deletion rules, ported from the old
// ServersViewController: deleting the current server auto-switches to the first
// remaining server (with a notice when popups are enabled); deleting the last server
// clears the current server and presents the add sheet.
//
// XCTest runs these on the main thread; the @MainActor test methods (rather than a
// @MainActor class) keep the nonisolated setUp/tearDown overrides compiling.
final class ServersViewModelTests: StoreTestCase {
    private final class FakeServerSwitcher: ServerSwitcher {
        var switchCount = 0
        var lastContext: LibraryContext?
        var switchedToNoContext = false
        var lastResetTabs: Bool?
        var reloadCount = 0
        override func switchContext(to newContext: LibraryContext?, resetTabs: Bool) {
            switchCount += 1
            lastContext = newContext
            switchedToNoContext = newContext == nil
            lastResetTabs = resetTabs
        }
        override func reloadContext() {
            reloadCount += 1
        }
    }

    private var session: ServerSession!
    private var settings: SavedSettings!
    private var switcher: FakeServerSwitcher!
    private var downloadQueue: FakeDownloadQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let session = ServerSession()
        self.session = session
        let settings = SavedSettings(session: session)
        settings.setup(store: store)
        TestContainer.register { settings }
        self.settings = settings
        let downloadQueue = FakeDownloadQueue()
        TestContainer.register { downloadQueue as DownloadQueueing }
        self.downloadQueue = downloadQueue
        let playQueue = makeTestPlayQueue()
        TestContainer.register { playQueue }
        let switcher = FakeServerSwitcher(streamManager: FakeStreamManager(),
                                          player: FakePlayer(),
                                          settings: settings,
                                          session: session,
                                          store: store,
                                          stateRestorer: StateRestorer(settings: settings, player: FakePlayer(), playQueue: playQueue))
        self.switcher = switcher
        let injectedSwitcher: ServerSwitcher = switcher
        TestContainer.register { injectedSwitcher }
    }

    override func tearDownWithError() throws {
        switcher = nil
        downloadQueue = nil
        settings = nil
        session = nil
        try super.tearDownWithError()
    }

    private func addServer(id: Int, host: String) -> Server {
        let server = Server(id: id, type: .subsonic, url: URL(string: "http://\(host)")!, username: "user\(id)", password: "pass")
        XCTAssertTrue(store.add(server: server))
        return server
    }

    @MainActor func testReloadListsServersAndCurrentFlag() {
        let first = addServer(id: 1, host: "one.example.com")
        _ = addServer(id: 2, host: "two.example.com")
        settings.currentServer = first

        let viewModel = ServersViewModel()
        XCTAssertEqual(viewModel.servers.map(\.id), [1, 2])
        XCTAssertTrue(viewModel.isCurrent(viewModel.servers[0]))
        XCTAssertFalse(viewModel.isCurrent(viewModel.servers[1]))
    }

    @MainActor func testDeletingCurrentServerSwitchesToFirstRemaining() {
        let first = addServer(id: 1, host: "one.example.com")
        _ = addServer(id: 2, host: "two.example.com")
        settings.currentServer = first
        settings.isPopupsEnabled = true

        let viewModel = ServersViewModel()
        viewModel.delete(at: IndexSet(integer: 0))

        XCTAssertEqual(viewModel.servers.map(\.id), [2])
        XCTAssertEqual(switcher.lastContext?.server?.id, 2, "the first remaining server becomes the requested context")
        XCTAssertEqual(switcher.switchCount, 1, "the switch teardown runs for the replacement server")
        XCTAssertEqual(viewModel.alert?.title, "Notice")
        XCTAssertNil(viewModel.sheet)
    }

    @MainActor func testDeletingCurrentServerWithPopupsDisabledSkipsNotice() {
        let first = addServer(id: 1, host: "one.example.com")
        _ = addServer(id: 2, host: "two.example.com")
        settings.currentServer = first
        settings.isPopupsEnabled = false

        let viewModel = ServersViewModel()
        viewModel.delete(at: IndexSet(integer: 0))

        XCTAssertEqual(switcher.lastContext?.server?.id, 2)
        XCTAssertNil(viewModel.alert)
    }

    @MainActor func testDeletingNonCurrentServerChangesNothingElse() {
        let first = addServer(id: 1, host: "one.example.com")
        _ = addServer(id: 2, host: "two.example.com")
        settings.currentServer = first

        let viewModel = ServersViewModel()
        viewModel.delete(at: IndexSet(integer: 1))

        XCTAssertEqual(viewModel.servers.map(\.id), [1])
        XCTAssertEqual(settings.currentServer?.id, 1)
        XCTAssertEqual(switcher.switchCount, 0)
        XCTAssertNil(viewModel.alert)
    }

    @MainActor func testDeletingLastServerClearsCurrentAndPresentsAddSheet() {
        let only = addServer(id: 1, host: "one.example.com")
        settings.currentServer = only

        let viewModel = ServersViewModel()
        viewModel.delete(at: IndexSet(integer: 0))

        XCTAssertTrue(viewModel.servers.isEmpty)
        XCTAssertTrue(switcher.switchedToNoContext, "no servers remain, so the requested context is none")
        XCTAssertEqual(switcher.switchCount, 1, "playback teardown must run even with no replacement server")
        XCTAssertEqual(switcher.lastResetTabs, false, "the servers screen must stay in place to present the add sheet")
        if case .add = viewModel.sheet {
            // expected: no servers left, so the add-server sheet presents
        } else {
            XCTFail("no servers left, so the add-server sheet must present (got \(String(describing: viewModel.sheet)))")
        }
    }

    @MainActor func testDeletingServerWithInFlightDownloadRestartsQueue() {
        _ = addServer(id: 1, host: "one.example.com")
        let second = addServer(id: 2, host: "two.example.com")
        settings.currentServer = second
        downloadQueue.currentQueuedSong = TestData.song(serverId: 1, id: "55")

        let viewModel = ServersViewModel()
        viewModel.delete(at: IndexSet(integer: 0))

        XCTAssertEqual(downloadQueue.stopCount, 1, "the in-flight download for the doomed server stops first")
        XCTAssertEqual(downloadQueue.startCount, 1, "the queue restarts to advance past the deleted server's song")
        XCTAssertEqual(switcher.switchCount, 0, "deleting a non-current server does not switch contexts")
    }

    @MainActor func testDeletingServerWithoutInFlightDownloadLeavesQueueAlone() {
        _ = addServer(id: 1, host: "one.example.com")
        let second = addServer(id: 2, host: "two.example.com")
        settings.currentServer = second
        downloadQueue.currentQueuedSong = TestData.song(serverId: 2, id: "55")

        let viewModel = ServersViewModel()
        viewModel.delete(at: IndexSet(integer: 0))

        XCTAssertEqual(downloadQueue.stopCount, 0)
        XCTAssertEqual(downloadQueue.startCount, 0)
    }

    @MainActor func testReloadServerListNotificationRefreshes() {
        let viewModel = ServersViewModel()
        XCTAssertTrue(viewModel.servers.isEmpty)

        _ = addServer(id: 1, host: "one.example.com")
        NotificationCenter.postOnMainThread(name: Notifications.reloadServerList)
        XCTAssertEqual(viewModel.servers.map(\.id), [1])
    }
}
