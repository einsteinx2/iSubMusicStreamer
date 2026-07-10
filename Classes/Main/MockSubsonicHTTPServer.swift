//
//  MockSubsonicHTTPServer.swift
//  iSub
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// An embedded mock Subsonic server backed by the vendored GCDWebServer, used for E2E
// tests (launched with -UITEST -MOCKSERVER, see UITestSupport). Unlike the URLProtocol
// stub, requests travel over real loopback HTTP, so streaming, byte ranges, partial
// downloads, and seek-past-cache-point flows behave exactly like production.
//
// Endpoints:
//   /rest/stream.view (GET/POST) — serves fixture audio bytes with Range support:
//       song id 9001 -> tone.flac (exercises BASS plugin loading), others -> test_song.mp3
//   /rest/<action>.view          — serves the fixture XML mapped by UITestFixtures
//                                  (honoring the -FIXTURES response set)
final class MockSubsonicHTTPServer {
    static let shared = MockSubsonicHTTPServer()

    private let webServer = GCDWebServer()
    private(set) var url: URL?

    private init() {
        webServer.addHandler(forMethod: "GET", pathRegex: "^/rest/.*", request: GCDWebServerRequest.self) { request, completion in
            completion(Self.respond(to: request))
        }
        webServer.addHandler(forMethod: "POST", pathRegex: "^/rest/.*", request: GCDWebServerURLEncodedFormRequest.self) { request, completion in
            completion(Self.respond(to: request))
        }
    }

    // Starts the server on an OS-assigned port and returns its base URL
    func start() -> URL? {
        if webServer.isRunning, let url = url {
            return url
        }
        let options: [String: Any] = [
            GCDWebServerOption_Port: 0,
            GCDWebServerOption_BindToLocalhost: true,
        ]
        do {
            try webServer.start(options: options)
        } catch {
            DDLogError("[MockSubsonicHTTPServer] failed to start: \(error)")
            return nil
        }
        let url = URL(string: "http://127.0.0.1:\(webServer.port)")!
        self.url = url
        DDLogInfo("[MockSubsonicHTTPServer] serving at \(url)")
        return url
    }

    func stop() {
        guard webServer.isRunning else { return }
        webServer.stop()
        url = nil
    }

    private static func respond(to request: GCDWebServerRequest) -> GCDWebServerResponse {
        let action = (request.url.lastPathComponent as NSString).deletingPathExtension
        let bodyData = (request as? GCDWebServerURLEncodedFormRequest)?.data
        let parameters = UITestFixtures.parameters(query: request.url.query, bodyData: bodyData)

        if action == "stream" || action == "download" {
            guard let audioURL = UITestFixtures.audioURL(songId: parameters["id"]),
                  FileManager.default.fileExists(atPath: audioURL.path) else {
                return GCDWebServerResponse(statusCode: 404)
            }
            // GCDWebServerFileResponse handles 206/Content-Range from the request's byte range
            guard let response = GCDWebServerFileResponse(file: audioURL.path, byteRange: request.byteRange) else {
                return GCDWebServerResponse(statusCode: 500)
            }
            return response
        }

        guard let xmlURL = UITestFixtures.xmlURL(action: action, parameters: parameters),
              let body = try? Data(contentsOf: xmlURL) else {
            return GCDWebServerResponse(statusCode: 404)
        }
        return GCDWebServerDataResponse(data: body, contentType: "text/xml; charset=utf-8")
    }
}
