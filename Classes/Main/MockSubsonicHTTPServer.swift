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
//   /rest/hls.m3u8               — serves a two-segment HLS playlist (segments relative
//                                  to the request URL) echoing the requested id/bitRate
//                                  in a comment line so tests can assert them
//   /rest/*.ts                   — serves deterministic dummy segment bytes
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
            // Without this the socket doesn't bind until the app foregrounds (start() is
            // called before activation, when the app state is still background), so the
            // OS-assigned port would read as 0 when the seeded server URL is built
            GCDWebServerOption_AutomaticallySuspendInBackground: false,
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
        UITestSupport.logRequest(action: action, parameters: parameters)

        if action == "stream" || action == "download" {
            guard let audioURL = UITestFixtures.audioURL(songId: parameters["id"]),
                  FileManager.default.fileExists(atPath: audioURL.path) else {
                return GCDWebServerResponse(statusCode: 404)
            }
            // -SLOWDOWNLOAD trickles the audio bytes so tests can interact with an
            // in-flight transfer (e.g. deleting the active download from the queue)
            if ProcessInfo.processInfo.arguments.contains("-SLOWDOWNLOAD"),
               let data = try? Data(contentsOf: audioURL) {
                return slowResponse(data: data, byteRange: request.byteRange,
                                    contentType: action == "stream" ? "audio/mpeg" : "application/octet-stream")
            }
            // GCDWebServerFileResponse handles 206/Content-Range from the request's byte range
            guard let response = GCDWebServerFileResponse(file: audioURL.path, byteRange: request.byteRange) else {
                return GCDWebServerResponse(statusCode: 500)
            }
            return response
        }

        // HLS video path (E2E-06): the app requests /rest/hls.m3u8, AVPlayer (or the
        // HLSReverseProxyServer in integration tests) then fetches the segment lines
        if action == "hls" {
            return GCDWebServerDataResponse(data: Self.hlsPlaylist(parameters: parameters),
                                            contentType: "application/x-mpegurl")
        }
        if request.url.pathExtension == "ts" {
            return GCDWebServerDataResponse(data: Self.hlsSegmentData, contentType: "video/mp2t")
        }

        guard let xmlURL = UITestFixtures.xmlURL(action: action, parameters: parameters),
              let body = try? Data(contentsOf: xmlURL) else {
            return GCDWebServerResponse(statusCode: 404)
        }
        return GCDWebServerDataResponse(data: body, contentType: "text/xml; charset=utf-8")
    }

    // Two segments relative to the playlist URL plus a URI attribute line, covering
    // both rewrite paths in HLSReverseProxyServer. The comment line echoes the request
    // parameters so tests can assert the Subsonic query reached the origin.
    static func hlsPlaylist(parameters: [String: String]) -> Data {
        let playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        # requested id=\(parameters["id"] ?? "") bitRate=\(parameters["bitRate"] ?? "")
        #EXT-X-MAP:URI="init.ts"
        #EXTINF:10,
        seg0.ts
        #EXTINF:10,
        seg1.ts
        #EXT-X-ENDLIST
        """
        return Data(playlist.utf8)
    }

    // Deterministic filler with TS sync bytes every 188 bytes — not decodable video,
    // just stable bytes tests can compare against
    static let hlsSegmentData: Data = {
        var data = Data(count: 4096)
        for index in stride(from: 0, to: data.count, by: 188) {
            data[index] = 0x47
        }
        return data
    }()

    // Streams the data in small chunks with a delay between each, keeping the transfer
    // alive long enough for a test to act on it. Honors "bytes=N-" ranges so a
    // seek-past-cache-point stream restart behaves like production.
    private static func slowResponse(data fullData: Data, byteRange: NSRange, contentType: String) -> GCDWebServerResponse {
        var data = fullData
        var statusCode = 200
        var contentRange: String?
        let location = byteRange.location
        if location > 0 && location < fullData.count {
            data = fullData.subdata(in: location..<fullData.count)
            statusCode = 206
            contentRange = "bytes \(location)-\(fullData.count - 1)/\(fullData.count)"
        }

        let chunkSize = 16 * 1024
        let chunkDelay = 0.2
        var offset = 0
        let response = GCDWebServerStreamedResponse(contentType: contentType) { completion in
            DispatchQueue.global().asyncAfter(deadline: .now() + chunkDelay) {
                guard offset < data.count else {
                    completion(Data(), nil) // Empty data signals the end of the stream
                    return
                }
                let chunk = data.subdata(in: offset..<min(offset + chunkSize, data.count))
                offset += chunk.count
                completion(chunk, nil)
            }
        }
        response.statusCode = statusCode
        response.contentLength = UInt(data.count)
        if let contentRange {
            response.setValue(contentRange, forAdditionalHeader: "Content-Range")
        }
        return response
    }
}
