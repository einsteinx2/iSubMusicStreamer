//
//  ServerStoreTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-03: CRUD tests for the server table
final class ServerStoreTests: StoreTestCase {
    func testNextServerIdOnEmptyTableIsOne() {
        XCTAssertEqual(store.nextServerId(), 1)
    }

    func testNextServerIdIsMaxPlusOne() {
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))
        XCTAssertTrue(store.add(server: TestData.server(id: 7)))
        XCTAssertEqual(store.nextServerId(), 8)
    }

    func testAddAndFetchServerRoundTrip() throws {
        let server = TestData.server(id: 1, urlString: "https://music.example.com:8080/subsonic", username: "bbaron")
        XCTAssertTrue(store.add(server: server))

        let fetched = try XCTUnwrap(store.server(id: 1))
        XCTAssertEqual(fetched.id, 1)
        XCTAssertEqual(fetched.type, .subsonic)
        XCTAssertEqual(fetched.url.absoluteString, "https://music.example.com:8080/subsonic")
        XCTAssertEqual(fetched.username, "bbaron")
        XCTAssertEqual(fetched.password, "password")
        XCTAssertEqual(fetched.path, "https_music.example.com_8080_subsonic")
        XCTAssertTrue(fetched.isVideoSupported)
        XCTAssertTrue(fetched.isNewSearchSupported)
        XCTAssertTrue(fetched.isTagSearchSupported)
    }

    func testAddUpdatesExistingServer() throws {
        let server = TestData.server(id: 1)
        XCTAssertTrue(store.add(server: server))

        let updated = Server(id: 1, type: .subsonic, url: server.url, username: "other", password: "newpass",
                             path: server.path, isVideoSupported: false, isNewSearchSupported: false, isTagSearchSupported: false)
        XCTAssertTrue(store.add(server: updated))

        XCTAssertEqual(store.servers().count, 1)
        let fetched = try XCTUnwrap(store.server(id: 1))
        XCTAssertEqual(fetched.username, "other")
        XCTAssertFalse(fetched.isVideoSupported)
    }

    func testServersReturnsAllRows() {
        XCTAssertEqual(store.servers().count, 0)
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))
        XCTAssertTrue(store.add(server: TestData.server(id: 2, urlString: "http://other.example.com")))
        XCTAssertEqual(store.servers().map(\.id).sorted(), [1, 2])
    }

    func testFetchMissingServerReturnsNil() {
        XCTAssertNil(store.server(id: 99))
    }

    func testDeleteServerOnlyRemovesThatRow() {
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))
        XCTAssertTrue(store.add(server: TestData.server(id: 2, urlString: "http://other.example.com")))

        XCTAssertTrue(store.deleteServer(id: 1))
        XCTAssertNil(store.server(id: 1))
        XCTAssertNotNil(store.server(id: 2))
    }
}
