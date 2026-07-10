//
//  AsyncStatusLoaderTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

final class AsyncStatusLoaderTests: SandboxedTestCase {
    private let serverURL = "https://example.com"

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()
    }

    override func tearDownWithError() throws {
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    private func makeLoader() -> AsyncStatusLoader {
        AsyncStatusLoader(urlString: serverURL, username: "bbaron", password: "correcthorsebatterystaple")
    }

    func testPingSuccessParsesVersionAndCapabilities() async throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")

        let status = try await makeLoader().load()

        // The fixture is a real Airsonic response reporting API version 1.15.0
        XCTAssertEqual(status.versionString, "1.15.0")
        XCTAssertEqual(status.majorAPIVersion, 1)
        XCTAssertEqual(status.minorAPIVersion, 15)
        XCTAssertTrue(status.isVideoSupported)
        XCTAssertTrue(status.isNewSearchSupported)
        XCTAssertTrue(status.isTagSerachSupported)
    }

    func testPingSuccessSubsonicParsesVersionAndCapabilities() async throws {
        // Real Subsonic response: API version 1.16.1 and no Airsonic "type" attribute
        // on the root element — both header styles must parse identically
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success_subsonic.xml")

        let status = try await makeLoader().load()

        XCTAssertEqual(status.versionString, "1.16.1")
        XCTAssertEqual(status.majorAPIVersion, 1)
        XCTAssertEqual(status.minorAPIVersion, 16)
        XCTAssertTrue(status.isVideoSupported)
        XCTAssertTrue(status.isNewSearchSupported)
        XCTAssertTrue(status.isTagSerachSupported)
    }

    func testIncompatibleProtocolVersionThrowsServerVersion() async throws {
        // Airsonic-Advanced (API 1.15.0) rejects clients announcing v=1.16.1 with
        // error code 30, where real Subsonic accepts them; the fixture is the real
        // Airsonic response and must surface as SubsonicError.serverVersion
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_error_incompatible_version.xml")

        do {
            _ = try await makeLoader().load()
            XCTFail("expected SubsonicError.serverVersion")
        } catch SubsonicError.serverVersion {
            // expected
        }
    }

    func testPingRequestIsWellFormed() async throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")

        _ = try await makeLoader().load()

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .ping).first)
        XCTAssertEqual(received.request.httpMethod, "GET")
        XCTAssertEqual(received.request.url?.path, "/rest/ping.view")
        XCTAssertEqual(received.parameter("u"), "bbaron")
        XCTAssertEqual(received.parameter("c"), "iSub")
        XCTAssertNotNil(received.parameter("v"))
        // Passwords are hex-encoded on the wire
        XCTAssertEqual(received.parameter("p")?.lowercased(), "enc:" + Data("correcthorsebatterystaple".utf8).map { String(format: "%02x", $0) }.joined())
    }

    func testSubsonicErrorResponseThrowsBadCredentials() async throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_error_wrong_credentials.xml")

        do {
            _ = try await makeLoader().load()
            XCTFail("expected SubsonicError.badCredentials")
        } catch SubsonicError.badCredentials {
            // expected
        }
    }

    func testPlainTextResponseThrowsResponseNotXML() async throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/not_xml.txt")

        do {
            _ = try await makeLoader().load()
            XCTFail("expected APIError.responseNotXML")
        } catch APIError.responseNotXML {
            // expected
        }
    }

    func testHTMLErrorPageThrowsServerUnsupported() async throws {
        // An HTML error page (e.g. from a reverse proxy) parses to a root tag of "html",
        // which the validator reports as an unsupported server
        try MockSubsonicServer.stub(.ping, fixture: "XML/not_xml.html")

        do {
            _ = try await makeLoader().load()
            XCTFail("expected APIError.serverUnsupported")
        } catch APIError.serverUnsupported {
            // expected
        }
    }

    func testTruncatedXMLStillParsesViaRecovery() async throws {
        // RXMLElement parses with XML_PARSE_RECOVER, so a truncated response whose
        // root element and attributes survived still loads successfully
        try MockSubsonicServer.stub(.ping, fixture: "XML/malformed.xml")

        let status = try await makeLoader().load()
        XCTAssertEqual(status.versionString, "1.15.0")
    }

    func testConnectionErrorPropagates() async throws {
        MockSubsonicServer.stubConnectionError(.ping, code: .cannotConnectToHost)

        do {
            _ = try await makeLoader().load()
            XCTFail("expected URLError")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cannotConnectToHost)
        }
    }

    func testCancelledTaskThrowsBeforeLoading() async throws {
        try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")

        let task = Task {
            try await makeLoader().load()
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch is CancellationError {
            // expected: cancelled at a checkCancellation() gate
        } catch let error as URLError where error.code == .cancelled {
            // expected: cancelled while awaiting the network call
        }
    }
}
