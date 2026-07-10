//
//  MockSubsonicHTTPServerTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// Exercises the embedded GCDWebServer-backed mock Subsonic server over real loopback
// HTTP — the same server E2E UI tests get with -UITEST -MOCKSERVER
final class MockSubsonicHTTPServerTests: SandboxedTestCase {
    private var serverURL: URL!
    private let session = URLSession(configuration: .ephemeral)

    override func setUpWithError() throws {
        try super.setUpWithError()
        serverURL = try XCTUnwrap(MockSubsonicHTTPServer.shared.start())
    }

    override func tearDownWithError() throws {
        MockSubsonicHTTPServer.shared.stop()
        try super.tearDownWithError()
    }

    private func get(_ path: String, range: String? = nil) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: try XCTUnwrap(URL(string: path, relativeTo: serverURL)))
        if let range = range {
            request.setValue(range, forHTTPHeaderField: "Range")
        }
        let (data, response) = try await session.data(for: request)
        return (data, try XCTUnwrap(response as? HTTPURLResponse))
    }

    func testPingServesFixtureXMLOverHTTP() async throws {
        let (data, response) = try await get("rest/ping.view")
        XCTAssertEqual(response.statusCode, 200)
        let body = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(body.contains("<subsonic-response"))
        XCTAssertTrue(body.contains(#"status="ok""#))
    }

    func testStreamServesFullMP3() async throws {
        let (data, response) = try await get("rest/stream.view?id=376")
        XCTAssertEqual(response.statusCode, 200)
        let expected = try Fixtures.data("Audio/test_song.mp3")
        XCTAssertEqual(data, expected)
    }

    func testStreamHonorsByteRange() async throws {
        let expected = try Fixtures.data("Audio/test_song.mp3")
        let offset = 100_000
        let (data, response) = try await get("rest/stream.view?id=376", range: "bytes=\(offset)-")
        XCTAssertEqual(response.statusCode, 206)
        XCTAssertEqual(data.count, expected.count - offset)
        XCTAssertEqual(data, expected.subdata(in: offset..<expected.count))
    }

    func testStreamServesFLACForDesignatedSong() async throws {
        let (data, response) = try await get("rest/stream.view?id=9001")
        XCTAssertEqual(response.statusCode, 200)
        // FLAC stream marker
        XCTAssertEqual(data.prefix(4), Data("fLaC".utf8))
        let expected = try Fixtures.data("Audio/tone.flac")
        XCTAssertEqual(data, expected)
    }

    func testFormatsDirectoryListsTheFLACSong() async throws {
        let (data, response) = try await get("rest/getMusicDirectory.view?id=900")
        XCTAssertEqual(response.statusCode, 200)
        let body = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(body.contains(#"suffix="flac""#))
        XCTAssertTrue(body.contains(#"id="9001""#))
    }

    func testUnknownActionReturns404() async throws {
        let (_, response) = try await get("rest/definitelyNotAnAction.view")
        XCTAssertEqual(response.statusCode, 404)
    }
}
