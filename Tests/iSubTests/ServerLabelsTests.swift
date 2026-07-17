//
//  ServerLabelsTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

final class ServerLabelsTests: StoreTestCase {
    private var session: ServerSession!
    private var settings: SavedSettings!
    private var labels: ServerLabels!

    override func setUpWithError() throws {
        try super.setUpWithError()
        session = ServerSession()
        settings = SavedSettings(session: session)
        TestContainer.register { [settings] in settings! }
    }

    override func tearDownWithError() throws {
        labels = nil
        settings = nil
        session = nil
        try super.tearDownWithError()
    }

    @MainActor private func makeLabels() -> ServerLabels {
        let labels = ServerLabels()
        self.labels = labels
        return labels
    }

    @MainActor func testLabelUsesNicknameFallingBackToHost() {
        _ = store.add(server: Server(id: 1, type: .subsonic, url: URL(string: "https://one.example.com")!,
                                     username: "u", password: "p", name: "Home NAS"))
        _ = store.add(server: TestData.server(id: 2, urlString: "https://two.example.com:8443/subsonic"))
        let labels = makeLabels()

        XCTAssertEqual(labels.label(serverId: 1), "Home NAS")
        XCTAssertEqual(labels.label(serverId: 2), "two.example.com", "no nickname falls back to the host")
        XCTAssertNil(labels.label(serverId: -1), "non-server ids have no label")
    }

    @MainActor func testBadgeTextOnlyWhileCombinedIsActive() {
        let server = TestData.server(id: 1)
        _ = store.add(server: server)
        let labels = makeLabels()

        session.setActiveContext(.server(server))
        XCTAssertNil(labels.badgeText(serverId: 1), "single-server mode shows no badges")

        session.setActiveContext(.combined)
        XCTAssertEqual(labels.badgeText(serverId: 1), "music.example.com")
    }

    @MainActor func testReloadServerListInvalidatesTheCache() {
        _ = store.add(server: TestData.server(id: 1))
        let labels = makeLabels()
        XCTAssertEqual(labels.label(serverId: 1), "music.example.com")

        // Renaming happens through the edit flow, which posts reloadServerList
        _ = store.add(server: Server(id: 1, type: .subsonic, url: URL(string: "https://music.example.com:8080/subsonic")!,
                                     username: "user", password: "password", name: "Renamed"))
        NotificationCenter.postOnMainThread(name: Notifications.reloadServerList)

        XCTAssertEqual(labels.label(serverId: 1), "Renamed")
    }
}

// The universal cell picks its badge up from ServerLabels centrally, so every list
// (queue, playlists, downloads, search…) shows badges in Combined with no per-screen
// wiring — and none anywhere else.
final class UniversalTableViewCellBadgeTests: StoreTestCase {
    @MainActor func testBadgeAppearsOnlyInCombinedContext() {
        let session = ServerSession()
        let settings = SavedSettings(session: session)
        TestContainer.register { settings }
        let server = Server(id: 1, type: .subsonic, url: URL(string: "https://one.example.com")!,
                            username: "u", password: "p", name: "NAS")
        _ = store.add(server: server)
        // The shared cache may hold another test's store contents
        ServerLabels.shared.invalidate()
        defer { ServerLabels.shared.invalidate() }

        let cell = UniversalTableViewCell(style: .default, reuseIdentifier: nil)

        session.setActiveContext(.server(server))
        cell.update(model: TestData.song(serverId: 1))
        XCTAssertNil(cell.serverBadgeText, "single-server mode shows no badge")

        session.setActiveContext(.combined)
        cell.update(model: TestData.song(serverId: 1))
        XCTAssertEqual(cell.serverBadgeText, "NAS")

        cell.update(model: LocalPlaylist(id: 10, name: "Mix", contextId: 0))
        XCTAssertNil(cell.serverBadgeText, "models without a server (serverId -1) get no badge")

        cell.update(primaryText: "Plain")
        XCTAssertNil(cell.serverBadgeText, "the plain-text overload clears the badge")
    }
}
