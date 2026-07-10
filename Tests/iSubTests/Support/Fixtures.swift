//
//  Fixtures.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

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
