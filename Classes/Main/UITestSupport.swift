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
//   -FIRSTRUN          skip the server seeding (keeping the network stub) so tests can
//                      drive the real first-run server setup flow
// See docs/UI_TESTING.md for the full contract.
enum UITestSupport {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-UITEST") }

    // First-run flow: networking is still stubbed, but no server is seeded, so the app
    // routes to server setup exactly like a fresh install
    static var isFirstRun: Bool { ProcessInfo.processInfo.arguments.contains("-FIRSTRUN") }

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

    // With -MOCKSERVER, an embedded GCDWebServer-backed mock Subsonic server serves
    // fixture XML and real audio bytes over loopback HTTP (real byte-serving with Range
    // support for streaming/download E2E flows) instead of the URLProtocol stub
    static var usesMockServer: Bool { ProcessInfo.processInfo.arguments.contains("-MOCKSERVER") }

    // "-REQUESTLOG <path>": append one "action?key=value&..." line per stubbed request
    // to this file so the UI test process can assert on the app's network traffic
    // (e.g. jukebox mode issuing jukeboxControl instead of stream requests)
    static var requestLogPath: String? { UserDefaults.standard.string(forKey: "REQUESTLOG") }

    private static let requestLogLock = NSLock()

    static func logRequest(action: String, parameters: [String: String]) {
        guard isEnabled, let path = requestLogPath else { return }
        requestLogLock.lock(); defer { requestLogLock.unlock() }
        let params = parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let line = "\(action)?\(params)\n"
        if let handle = FileHandle(forWritingAtPath: path) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    // Called after store.setup() but before settings.setup(), so the seeded server is
    // picked up as the current server
    static func configureIfEnabled() {
        guard isEnabled else { return }

        let serverURL: URL?
        if usesMockServer, let mockServerURL = MockSubsonicHTTPServer.shared.start() {
            // Real HTTP over loopback: streaming, ranges, and downloads all behave like production
            serverURL = mockServerURL
        } else {
            // All networking (API loaders, stream handlers, jukebox) serves canned fixtures
            // in-process. The URLProtocol intercepts every URL, so a previously seeded
            // server URL keeps working and is preferred below — downloaded file paths are
            // keyed by Server.path (derived from the URL), so relaunches without
            // -RESET_STATE must not change the URL or seeded downloads become unplayable
            // (e.g. the offline suite downloads via -MOCKSERVER, then relaunches offline).
            APIURLSession.stubProtocolClasses = [UITestURLProtocol.self]
            APIURLSession.shared = APIURLSession.createDefaultSession()
            serverURL = nil
        }

        // Seed a pre-configured server so tests skip first-run server setup (unless the
        // test is exercising the first-run flow itself). Always (re)written because the
        // mock server binds a different port on every launch.
        if !isFirstRun {
            let store: Store = Resolver.resolve()
            let existing = store.server(id: seededServerId)
            let url = serverURL ?? existing?.url ?? URL(string: "http://uitest.local")!
            let server = Server(id: seededServerId, type: .subsonic, url: url,
                                username: existing?.username ?? "uitest", password: existing?.password ?? "uitest")
            _ = store.add(server: server)
            UserDefaults.standard.set(seededServerId, forKey: SavedSettings.Key.currentServerId.rawValue)
        }

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

// Maps Subsonic actions to the fixture XML bundled with the app (beta builds only).
// The -FIXTURES launch argument selects a named override set; anything not overridden
// falls back to the default map. Shared by UITestURLProtocol and MockSubsonicHTTPServer.
enum UITestFixtures {
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
        case "getMusicDirectory":
            switch parameters["id"] {
            case "225": return "getMusicDirectory_album.xml"
            // The album's disc folders (242/232) resolve to a songs-only directory so
            // recursive loaders (play all/shuffle/download folder) terminate
            case "900", "242", "232": return "getMusicDirectory_formats.xml"
            // The "Video" folder artist (210 in getIndexes) contains an isVideo entry
            // for the video-path E2E flows
            case "210": return "getMusicDirectory_videos.xml"
            default: return "getMusicDirectory_artist.xml"
            }
        case "getArtists": return "getArtists.xml"
        // 900A/900B are the tag artist/album of the downloadable fixture songs, so the
        // Downloads tab's tag browsing has metadata to join against
        case "getArtist": return parameters["id"] == "900A" ? "getArtist_formats.xml" : "getArtist.xml"
        case "getAlbum": return parameters["id"] == "900B" ? "getAlbum_formats.xml" : "getAlbum.xml"
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

    static func xmlURL(action: String, parameters: [String: String]) -> URL? {
        let name = fixtureSets[UITestSupport.fixtureSet]?[action] ?? defaultFixture(action: action, parameters: parameters)
        return name.flatMap { Bundle.main.resourceURL?.appendingPathComponent("Fixtures/XML").appendingPathComponent($0) }
    }

    // Audio served for stream requests: song id 9001 is the FLAC tone (exercises BASS
    // plugin loading); everything else gets the small MP3
    static func audioURL(songId: String?) -> URL? {
        let name = songId == "9001" ? "tone.flac" : "test_song.mp3"
        return Bundle.main.resourceURL?.appendingPathComponent("Fixtures/Audio").appendingPathComponent(name)
    }

    // Single-value parameters from a query string and/or form-encoded body
    static func parameters(query: String?, bodyData: Data?) -> [String: String] {
        var raw = query ?? ""
        if let bodyData = bodyData, let bodyString = String(data: bodyData, encoding: .utf8), !bodyString.isEmpty {
            raw += raw.isEmpty ? bodyString : "&\(bodyString)"
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

// Serves canned Subsonic responses in-process, keyed by the /rest/<action>.view path
final class UITestURLProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let action = (url.lastPathComponent as NSString).deletingPathExtension
        let requestParameters = parameters(from: request)
        UITestSupport.logRequest(action: action, parameters: requestParameters)
        let fixtureURL = UITestFixtures.xmlURL(action: action, parameters: requestParameters)

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
        var bodyData: Data?
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
            bodyData = data
        }
        return UITestFixtures.parameters(query: request.url?.query, bodyData: bodyData)
    }
}
