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
        var lastResetTabs: Bool?
        override func switchServer(resetTabs: Bool) {
            switchCount += 1
            lastResetTabs = resetTabs
        }
    }

    private var settings: SavedSettings!
    private var switcher: FakeServerSwitcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let settings = SavedSettings()
        settings.setup(store: store)
        TestContainer.register { settings }
        self.settings = settings
        let switcher = FakeServerSwitcher(streamManager: FakeStreamManager(),
                                          player: FakePlayer(),
                                          playQueue: makeTestPlayQueue(),
                                          downloadQueue: FakeDownloadQueue(),
                                          settings: settings)
        self.switcher = switcher
        let injectedSwitcher: ServerSwitcher = switcher
        TestContainer.register { injectedSwitcher }
    }

    override func tearDownWithError() throws {
        switcher = nil
        settings = nil
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
        XCTAssertEqual(settings.currentServer?.id, 2, "the first remaining server becomes current")
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

        XCTAssertEqual(settings.currentServer?.id, 2)
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
        XCTAssertNil(settings.currentServer)
        XCTAssertEqual(switcher.switchCount, 1, "playback teardown must run even with no replacement server")
        XCTAssertEqual(switcher.lastResetTabs, false, "the servers screen must stay in place to present the add sheet")
        if case .add = viewModel.sheet {
            // expected: no servers left, so the add-server sheet presents
        } else {
            XCTFail("no servers left, so the add-server sheet must present (got \(String(describing: viewModel.sheet)))")
        }
    }

    @MainActor func testReloadServerListNotificationRefreshes() {
        let viewModel = ServersViewModel()
        XCTAssertTrue(viewModel.servers.isEmpty)

        _ = addServer(id: 1, host: "one.example.com")
        NotificationCenter.postOnMainThread(name: Notifications.reloadServerList)
        XCTAssertEqual(viewModel.servers.map(\.id), [1])
    }
}
