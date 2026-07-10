//
//  UITestSupport.swift
//  iSub
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// Support for XCUITest runs. UI tests launch the app with these arguments:
//   -UITEST            enable test mode: route all networking to the fixture-serving
//                      URLProtocol below, seed a pre-configured server (skipping
//                      first-run setup), and suppress system permission prompts
//   -RESET_STATE       wipe the database, downloads, and UserDefaults before setup
//   -MODE <mode>       online (default) | offline | jukebox
//   -FIXTURES <name>   named fixture response set served by the stub (default "default")
// See docs/UI_TESTING.md for the full contract.
enum UITestSupport {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-UITEST") }

    enum Mode: String { case online, offline, jukebox }

    // "-MODE offline" style arguments are exposed through the UserDefaults argument domain
    static var mode: Mode { Mode(rawValue: UserDefaults.standard.string(forKey: "MODE") ?? "") ?? .online }
    static var fixtureSet: String { UserDefaults.standard.string(forKey: "FIXTURES") ?? "default" }

    static let seededServerId = 1

    // Called first thing in AppDelegate, before anything touches disk or defaults
    static func resetStateIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-RESET_STATE") else { return }
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        for url in [FileSystem.databaseDirectory, FileSystem.downloadsDirectory, FileSystem.tempDownloadsDirectory] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // Called after store.setup() but before settings.setup(), so the seeded server is
    // picked up as the current server
    static func configureIfEnabled() {
        guard isEnabled else { return }

        // All networking (API loaders, stream handlers, jukebox) serves canned fixtures
        APIURLSession.stubProtocolClasses = [UITestURLProtocol.self]
        APIURLSession.shared = APIURLSession.createDefaultSession()

        // Seed a pre-configured server so tests skip first-run server setup
        let store: Store = Resolver.resolve()
        if store.server(id: seededServerId) == nil {
            let server = Server(id: seededServerId, type: .subsonic, url: URL(string: "http://uitest.local")!, username: "uitest", password: "uitest")
            _ = store.add(server: server)
        }
        UserDefaults.standard.set(seededServerId, forKey: SavedSettings.Key.currentServerId.rawValue)

        let settings: SavedSettings = Resolver.resolve()
        switch mode {
        case .online:
            break
        case .offline:
            settings.isForceOfflineMode = true
            settings.isOfflineMode = true
        case .jukebox:
            settings.isJukeboxEnabled = true
        }
    }
}

// Serves canned Subsonic responses from the Fixtures folder bundled with the app (beta
// builds only), keyed by the /rest/<action>.view path. The -FIXTURES launch argument
// selects a named override set; anything not overridden falls back to the default map.
final class UITestURLProtocol: URLProtocol {
    // Named response sets: overrides applied on top of the default action map
    private static let fixtureSets: [String: [String: String]] = [
        "default": [:],
        "badauth": ["ping": "ping_error_wrong_credentials.xml"],
    ]

    private static func defaultFixture(action: String, parameters: [String: String]) -> String? {
        switch action {
        case "ping": return "ping_success.xml"
        case "getMusicFolders": return "getMusicFolders.xml"
        case "getIndexes": return "getIndexes.xml"
        case "getMusicDirectory": return parameters["id"] == "225" ? "getMusicDirectory_album.xml" : "getMusicDirectory_artist.xml"
        case "getArtists": return "getArtists.xml"
        case "getArtist": return "getArtist.xml"
        case "getAlbum": return "getAlbum.xml"
        case "getPlaylists": return "getPlaylists.xml"
        case "getPlaylist": return "getPlaylist.xml"
        case "getNowPlaying": return "getNowPlaying.xml"
        case "getChatMessages": return "getChatMessages.xml"
        case "addChatMessage": return "ping_success.xml"
        case "getLyrics": return "getLyrics.xml"
        case "search2": return "search2.xml"
        case "search3": return "search3.xml"
        case "getAlbumList": return "getAlbumList_newest.xml"
        case "getRandomSongs": return "getRandomSongs.xml"
        case "jukeboxControl": return "jukeboxControl_get.xml"
        case "scrobble": return "ping_success.xml"
        default: return nil
        }
    }

    private static func fixture(action: String, parameters: [String: String]) -> String? {
        if let override = fixtureSets[UITestSupport.fixtureSet]?[action] {
            return override
        }
        return defaultFixture(action: action, parameters: parameters)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let action = (url.lastPathComponent as NSString).deletingPathExtension
        let fixtureName = Self.fixture(action: action, parameters: parameters(from: request))
        let fixtureURL = fixtureName.flatMap {
            Bundle.main.resourceURL?.appendingPathComponent("Fixtures/XML").appendingPathComponent($0)
        }

        guard let fixtureURL = fixtureURL, let body = try? Data(contentsOf: fixtureURL) else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let headers = ["Content-Type": "text/xml; charset=utf-8", "Content-Length": "\(body.count)"]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // Single-value parameters from the query string (GET) or form-encoded body (POST)
    private func parameters(from request: URLRequest) -> [String: String] {
        var raw = request.url?.query ?? ""
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                guard read > 0 else { break }
                data.append(buffer, count: read)
            }
            if let bodyString = String(data: data, encoding: .utf8), !bodyString.isEmpty {
                raw += raw.isEmpty ? bodyString : "&\(bodyString)"
            }
        }
        var parameters = [String: String]()
        for pair in raw.components(separatedBy: "&") where !pair.isEmpty {
            let parts = pair.components(separatedBy: "=")
            let name = parts[0].removingPercentEncoding ?? parts[0]
            if parameters[name] == nil {
                parameters[name] = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
            }
        }
        return parameters
    }
}
