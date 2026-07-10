//
//  URLRequestSubsonicTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-06: request-construction tests for URLRequest+Subsonic — API version
// selection, URL shape, auth, GET/POST, ranges, timeouts, and query encoding.
// These directly affect compatibility with every Subsonic-family server.
final class URLRequestSubsonicTests: SandboxedTestCase {
    private var settings: SavedSettings!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
    }

    override func tearDownWithError() throws {
        settings = nil
        try super.tearDownWithError()
    }

    private func makeRequest(action: SubsonicAction, urlString: String = "https://music.example.com", username: String = "user", password: String = "pass", parameters: [String: Any]? = nil, byteOffset: Int = 0, file: StaticString = #filePath, line: UInt = #line) throws -> URLRequest {
        try XCTUnwrap(URLRequest(subsonicAction: action, urlString: urlString, username: username, password: password, parameters: parameters, byteOffset: byteOffset), "request creation failed", file: file, line: line)
    }

    // Decodes "a=1&b=2&b=3" into ["a": ["1"], "b": ["2", "3"]]
    private func decode(_ raw: String) -> [String: [String]] {
        var parameters = [String: [String]]()
        for pair in raw.components(separatedBy: "&") where !pair.isEmpty {
            let parts = pair.components(separatedBy: "=")
            let name = parts[0].removingPercentEncoding ?? parts[0]
            let value = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
            parameters[name, default: []].append(value)
        }
        return parameters
    }

    // Extracts the sent parameters from the query string (GET) or body (POST)
    private func sentParameters(_ request: URLRequest) throws -> [String: [String]] {
        if request.httpMethod == "GET" {
            return decode(try XCTUnwrap(request.url?.query))
        }
        let body = try XCTUnwrap(request.httpBody)
        return decode(try XCTUnwrap(String(data: body, encoding: .utf8)))
    }

    // MARK: API version selection

    func testAPIVersionPerAction() throws {
        let expectedVersions: [(SubsonicAction, String)] = [
            (.ping, "1.0.0"),
            (.getMusicFolders, "1.0.0"),
            (.getIndexes, "1.0.0"),
            (.getMusicDirectory, "1.0.0"),
            (.stream, "1.0.0"),
            (.getPlaylists, "1.0.0"),
            (.getChatMessages, "1.2.0"),
            (.getRandomSongs, "1.2.0"),
            (.getLyrics, "1.2.0"),
            (.jukeboxControl, "1.2.0"),
            (.getAlbumList, "1.2.0"),
            (.search2, "1.4.0"),
            (.scrobble, "1.5.0"),
            (.hls, "1.8.0"),
            (.getArtists, "1.8.0"),
            (.getArtist, "1.8.0"),
            (.getAlbum, "1.8.0"),
            (.getSong, "1.8.0"),
            (.search3, "1.8.0"),
        ]
        for (action, expectedVersion) in expectedVersions {
            let request = try makeRequest(action: action)
            let params = try sentParameters(request)
            XCTAssertEqual(params["v"], [expectedVersion], "\(action.rawValue) should send v=\(expectedVersion)")
        }
    }

    func testBaseParametersAlwaysIncluded() throws {
        let request = try makeRequest(action: .getIndexes)
        let params = try sentParameters(request)
        XCTAssertEqual(params["c"], ["iSub"])
        XCTAssertEqual(params["u"], ["user"])
        XCTAssertNotNil(params["v"])
        XCTAssertNotNil(params["p"])
    }

    // MARK: URL construction

    func testHlsUsesM3U8PathAndGet() throws {
        let request = try makeRequest(action: .hls)
        XCTAssertEqual(request.url?.path, "/rest/hls.m3u8")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertNotNil(request.url?.query, "GET requests carry the query string in the URL")
    }

    func testOtherActionsUseViewPath() throws {
        XCTAssertEqual(try makeRequest(action: .ping).url?.path, "/rest/ping.view")
        XCTAssertEqual(try makeRequest(action: .getArtists).url?.path, "/rest/getArtists.view")
        XCTAssertEqual(try makeRequest(action: .stream).url?.path, "/rest/stream.view")
    }

    func testPingIsGetSoRedirectsWorkOnStatusChecks() throws {
        let request = try makeRequest(action: .ping)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
    }

    func testNonStatusActionsArePostWithFormBody() throws {
        let request = try makeRequest(action: .getArtists)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.url?.query, "POST requests keep credentials out of the URL")
        XCTAssertNotNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
    }

    // MARK: Password encoding

    func testPasswordIsHexEncodedWithEncPrefix() throws {
        let request = try makeRequest(action: .getIndexes, password: "abc")
        let params = try sentParameters(request)
        XCTAssertEqual(params["p"], ["enc:616263"])
    }

    func testUnicodePasswordIsHexEncoded() throws {
        // é is C3A9 in UTF-8
        let request = try makeRequest(action: .getIndexes, password: "é")
        let params = try sentParameters(request)
        XCTAssertEqual(params["p"], ["enc:C3A9"])
    }

    // MARK: Basic Auth header

    func testBasicAuthHeaderOnlyWhenEnabled() throws {
        let plain = try makeRequest(action: .getIndexes)
        XCTAssertNil(plain.value(forHTTPHeaderField: "Authorization"))

        settings.isBasicAuthEnabled = true
        let authed = try makeRequest(action: .getIndexes, username: "user", password: "pass")
        let header = try XCTUnwrap(authed.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(header.hasPrefix("Basic "))
        let encoded = String(header.dropFirst("Basic ".count))
        let decoded = try XCTUnwrap(String(data: XCTUnwrap(Data(base64Encoded: encoded)), encoding: .utf8))
        XCTAssertEqual(decoded, "user:pass")
    }

    // MARK: Range header

    func testRangeHeaderOnlyForPositiveByteOffset() throws {
        let noOffset = try makeRequest(action: .stream, byteOffset: 0)
        XCTAssertNil(noOffset.value(forHTTPHeaderField: "Range"))

        let withOffset = try makeRequest(action: .stream, byteOffset: 12345)
        XCTAssertEqual(withOffset.value(forHTTPHeaderField: "Range"), "bytes=12345-")
    }

    // MARK: Caching

    func testCachingDisabled() throws {
        let request = try makeRequest(action: .getIndexes)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-cache")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
    }

    // MARK: Timeouts

    func testPerActionTimeouts() throws {
        XCTAssertEqual(try makeRequest(action: .getPlaylist).timeoutInterval, 3600.0, accuracy: 0.001)
        XCTAssertEqual(try makeRequest(action: .ping).timeoutInterval, 15.0, accuracy: 0.001)
        XCTAssertEqual(try makeRequest(action: .getIndexes).timeoutInterval, 240.0, accuracy: 0.001)
        XCTAssertEqual(try makeRequest(action: .stream).timeoutInterval, 240.0, accuracy: 0.001)
    }

    // MARK: Query string encoding

    func testParameterValuesAreURLEncoded() throws {
        let request = try makeRequest(action: .search2, parameters: ["query": "Sigur Rós"])
        let params = try sentParameters(request)
        XCTAssertEqual(params["query"], ["Sigur Rós"])
        // The raw body must contain the percent-encoded form
        let body = try XCTUnwrap(String(data: XCTUnwrap(request.httpBody), encoding: .utf8))
        XCTAssertTrue(body.contains("query=Sigur%20R%C3%B3s"), "unicode and spaces must be percent-encoded")
    }

    func testAmpersandInParameterValueIsNotEscaped() throws {
        // Documents a limitation of URLQueryEncoded: it uses .urlQueryAllowed, which
        // permits & and = inside values, so such values are sent unescaped and a
        // server will parse them as separate parameters
        let request = try makeRequest(action: .search2, parameters: ["query": "a&b"])
        let body = try XCTUnwrap(String(data: XCTUnwrap(request.httpBody), encoding: .utf8))
        XCTAssertTrue(body.contains("query=a&b"))
    }

    func testUsernameIsURLEncoded() throws {
        let request = try makeRequest(action: .getIndexes, username: "user name")
        let params = try sentParameters(request)
        XCTAssertEqual(params["u"], ["user name"])
        let body = try XCTUnwrap(String(data: XCTUnwrap(request.httpBody), encoding: .utf8))
        XCTAssertTrue(body.contains("u=user%20name"))
    }

    func testMultiValueArrayParameters() throws {
        let request = try makeRequest(action: .jukeboxControl, parameters: ["id": ["1", "2", "3"], "action": "add"])
        let params = try sentParameters(request)
        XCTAssertEqual(params["id"], ["1", "2", "3"], "array parameters must repeat the key")
        XCTAssertEqual(params["action"], ["add"])
    }

    func testNumericParameters() throws {
        let request = try makeRequest(action: .getRandomSongs, parameters: ["size": NSNumber(value: 50), "offsets": [NSNumber(value: 1), NSNumber(value: 2)]])
        let params = try sentParameters(request)
        XCTAssertEqual(params["size"], ["50"])
        XCTAssertEqual(params["offsets"], ["1", "2"])
    }

    // MARK: serverId-based initializer

    func testServerIdInitializerUsesStoredServer() throws {
        let store = Store()
        store.setup(location: .memory)
        let injectedStore: Store = store
        TestContainer.register { injectedStore }
        XCTAssertTrue(store.add(server: TestData.server(id: 1, urlString: "https://stored.example.com", username: "stored")))

        let request = try XCTUnwrap(URLRequest(serverId: 1, subsonicAction: .ping))
        XCTAssertEqual(request.url?.host, "stored.example.com")
        let params = try sentParameters(request)
        XCTAssertEqual(params["u"], ["stored"])

        XCTAssertNil(URLRequest(serverId: 42, subsonicAction: .ping), "missing server must fail request creation")
    }

    func testServerIdInitializerHonorsRedirectUrl() throws {
        let store = Store()
        store.setup(location: .memory)
        let injectedStore: Store = store
        TestContainer.register { injectedStore }
        XCTAssertTrue(store.add(server: TestData.server(id: 1, urlString: "https://original.example.com")))
        settings.currentServerRedirectUrlString = "https://redirected.example.com"

        let request = try XCTUnwrap(URLRequest(serverId: 1, subsonicAction: .ping))
        XCTAssertEqual(request.url?.host, "redirected.example.com")
    }
}
