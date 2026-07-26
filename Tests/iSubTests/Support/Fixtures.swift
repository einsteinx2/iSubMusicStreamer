//
//  Fixtures.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
@testable import iSub_Beta

private final class FixturesBundleToken {}

// Loads canned test resources from the Fixtures folder bundled with the test target.
// The Fixtures folder is added to the project as a folder reference, so files dropped
// into it are automatically available here with no project file changes.
enum Fixtures {
    static let bundle = Bundle(for: FixturesBundleToken.self)

    enum FixturesError: Error {
        case missing(String)
    }

    static func url(_ relativePath: String) throws -> URL {
        guard let resourceURL = bundle.resourceURL else { throw FixturesError.missing(relativePath) }
        let url = resourceURL.appendingPathComponent("Fixtures").appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { throw FixturesError.missing(relativePath) }
        return url
    }

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: url(relativePath))
    }

    static func string(_ relativePath: String) throws -> String {
        try String(contentsOf: url(relativePath), encoding: .utf8)
    }
}

// Builds DTO values for tests by decoding inline literals (or fixtures) through the
// app's real wire decoders, so test models take the same construction path as
// production responses.
enum TestDTO {
    /// Decodes a single DTO from an inline JSON literal via the Subsonic JSON decoder.
    static func json<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try SubsonicJSON.decode(T.self, from: Data(json.utf8))
    }

    /// Wraps an inline XML payload in a subsonic-response envelope, decodes it with
    /// the XML decoder, and returns the response payload.
    static func xmlResponse(_ payloadXML: String, status: String = "ok") throws -> SubsonicResponse {
        let document = """
            <?xml version="1.0" encoding="UTF-8"?>
            <subsonic-response xmlns="http://subsonic.org/restapi" status="\(status)" version="1.15.0">\(payloadXML)</subsonic-response>
            """
        return try SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: Data(document.utf8)).response
    }

    /// Decodes a fixture file (either wire format) and returns the response payload.
    static func response(fixture relativePath: String) throws -> SubsonicResponse {
        try SubsonicEnvelope.decode(from: Fixtures.data(relativePath)).response
    }
}
