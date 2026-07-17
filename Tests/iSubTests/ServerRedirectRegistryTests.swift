//
//  ServerRedirectRegistryTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// Per-server redirect isolation: a redirect negotiated for one server must never be
// applied to another server's requests (the old single-string design did exactly that
// once more than one server was in play).
final class ServerRedirectRegistryTests: XCTestCase {
    private var registry: ServerRedirectRegistry!
    private var serverA: Server!
    private var serverB: Server!

    override func setUp() {
        super.setUp()
        registry = ServerRedirectRegistry()
        serverA = TestData.server(id: 1, urlString: "https://a.example.com:4040")
        serverB = TestData.server(id: 2, urlString: "https://b.example.com")
    }

    override func tearDown() {
        registry = nil
        serverA = nil
        serverB = nil
        super.tearDown()
    }

    private func record(original: String, redirected: String) {
        registry.recordRedirect(originalRequestUrl: URL(string: original),
                                redirectedRequestUrl: URL(string: redirected),
                                knownServers: [serverA, serverB])
    }

    func testRecordMatchesServerByConfiguredUrl() {
        record(original: "https://a.example.com:4040/rest/ping.view", redirected: "https://new.example.com/rest/ping.view")

        XCTAssertEqual(registry.redirectUrlString(serverId: 1), "https://new.example.com")
        XCTAssertNil(registry.redirectUrlString(serverId: 2), "the redirect must not leak to other servers")
    }

    func testRedirectChainRematchesThroughRecordedRedirect() {
        record(original: "https://a.example.com:4040/rest/ping.view", redirected: "https://hop.example.com/rest/ping.view")
        // A later request was built against the recorded redirect and redirected again
        record(original: "https://hop.example.com/rest/stream.view", redirected: "https://final.example.com:8443/rest/stream.view")

        XCTAssertEqual(registry.redirectUrlString(serverId: 1), "https://final.example.com:8443")
    }

    func testUnmatchedOriginalIsDropped() {
        record(original: "https://unknown.example.com/rest/ping.view", redirected: "https://new.example.com/rest/ping.view")

        XCTAssertNil(registry.redirectUrlString(serverId: 1))
        XCTAssertNil(registry.redirectUrlString(serverId: 2))
    }

    func testPathPrefixIsPreserved() {
        let server = TestData.server(id: 3, urlString: "https://c.example.com/subsonic")
        registry.recordRedirect(originalRequestUrl: URL(string: "https://c.example.com/subsonic/rest/ping.view"),
                                redirectedRequestUrl: URL(string: "https://d.example.com/music/rest/ping.view"),
                                knownServers: [server])

        XCTAssertEqual(registry.redirectUrlString(serverId: 3), "https://d.example.com/music")
    }

    func testRedirectTargetWithoutRestPathFallsBackToHost() {
        record(original: "https://a.example.com:4040/rest/ping.view", redirected: "https://cdn.example.com/elsewhere")
        XCTAssertEqual(registry.redirectUrlString(serverId: 1), "https://cdn.example.com")

        record(original: "https://b.example.com/rest/ping.view", redirected: "http://cdn2.example.com:8080/elsewhere")
        XCTAssertEqual(registry.redirectUrlString(serverId: 2), "http://cdn2.example.com:8080")
    }

    func testClearRedirectAndRemoveAll() {
        record(original: "https://a.example.com:4040/rest/ping.view", redirected: "https://new.example.com/rest/ping.view")
        record(original: "https://b.example.com/rest/ping.view", redirected: "https://newb.example.com/rest/ping.view")

        registry.clearRedirect(serverId: 1)
        XCTAssertNil(registry.redirectUrlString(serverId: 1))
        XCTAssertEqual(registry.redirectUrlString(serverId: 2), "https://newb.example.com")

        registry.removeAll()
        XCTAssertNil(registry.redirectUrlString(serverId: 2))
    }

    func testMissingUrlsAreIgnored() {
        registry.recordRedirect(originalRequestUrl: nil,
                                redirectedRequestUrl: URL(string: "https://new.example.com/rest/ping.view"),
                                knownServers: [serverA])
        registry.recordRedirect(originalRequestUrl: URL(string: "https://a.example.com:4040/rest/ping.view"),
                                redirectedRequestUrl: nil,
                                knownServers: [serverA])

        XCTAssertNil(registry.redirectUrlString(serverId: 1))
    }
}
