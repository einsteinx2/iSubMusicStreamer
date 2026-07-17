//
//  ServerCheckerCombinedTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The Combined Library health check: every server pinged, capabilities persisted per
// server, and offline mode only when NO server answers.
final class ServerCheckerCombinedTests: StoreTestCase {
    private var session: ServerSession!
    private var settings: SavedSettings!
    private var downloadQueue: FakeDownloadQueue!
    private var checker: ServerChecker!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()
        session = ServerSession()
        settings = SavedSettings(session: session)
        TestContainer.register { [settings] in settings! }
        downloadQueue = FakeDownloadQueue()
        TestContainer.register { [downloadQueue] in downloadQueue! as DownloadQueueing }
        XCTAssertTrue(store.add(server: TestData.server(id: 1, urlString: "https://one.example.com")))
        XCTAssertTrue(store.add(server: TestData.server(id: 2, urlString: "https://two.example.com")))
        session.setActiveContext(.combined)
    }

    override func tearDownWithError() throws {
        checker?.cancelNextServerCheck()
        checker = nil
        downloadQueue = nil
        settings = nil
        session = nil
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    private func stubPing(okHosts: Set<String>) {
        let okXML = #"<subsonic-response xmlns="http://subsonic.org/restapi" status="ok" version="1.15.0"/>"#
        let errorXML = #"<subsonic-response status="failed" version="1.15.0"><error code="40" message="Wrong username or password"/></subsonic-response>"#
        MockSubsonicServer.stub(.ping) { request in
            let host = request.request.url?.host ?? ""
            return MockSubsonicServer.xmlResponse(okHosts.contains(host) ? okXML : errorXML)
        }
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    func testOneReachableServerKeepsTheAppOnlineAndStartsDownloads() throws {
        stubPing(okHosts: ["one.example.com"])
        var wentOffline = false
        let observer = NotificationCenter.default.addObserver(forName: Notifications.goOffline, object: nil, queue: nil) { _ in
            wentOffline = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        checker = ServerChecker()
        checker.checkServer()

        XCTAssertTrue(waitUntil { downloadQueue.startCount >= 1 }, "a reachable server starts the download queue")
        XCTAssertFalse(wentOffline, "one dead server must not knock the merged library offline")
    }

    func testAllServersUnreachableGoesOffline() throws {
        stubPing(okHosts: [])
        var wentOffline = false
        let observer = NotificationCenter.default.addObserver(forName: Notifications.goOffline, object: nil, queue: nil) { _ in
            wentOffline = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        checker = ServerChecker()
        checker.checkServer()

        XCTAssertTrue(waitUntil { wentOffline }, "no reachable server means offline mode")
        XCTAssertEqual(downloadQueue.startCount, 0)
    }
}
