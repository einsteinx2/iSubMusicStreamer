//
//  HLSVideoTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import AVKit
import Resolver
@testable import iSub_Beta

// E2E-06 video path, part 1: HLSReverseProxyServer URL/origin rewriting against a real
// stubbed HLS endpoint (the embedded mock Subsonic server's /rest/hls.m3u8 + .ts
// handlers) over loopback HTTP, exactly as AVPlayer would drive it for a self-signed
// HTTPS server.
final class HLSReverseProxyServerTests: SandboxedTestCase {
    private var originURL: URL!
    private var proxy: HLSReverseProxyServer!
    private let session = URLSession(configuration: .ephemeral)

    override func setUpWithError() throws {
        try super.setUpWithError()
        originURL = try XCTUnwrap(MockSubsonicHTTPServer.shared.start())
        proxy = HLSReverseProxyServer()
        XCTAssertTrue(proxy.start(), "reverse proxy did not start")
    }

    override func tearDownWithError() throws {
        proxy.stop()
        proxy = nil
        MockSubsonicHTTPServer.shared.stop()
        originURL = nil
        try super.tearDownWithError()
    }

    // The origin URL for a path on the mock server, e.g. "http://127.0.0.1:<port>/rest/seg0.ts"
    private func originURLString(path: String) -> String {
        originURL.appendingPathComponent(path).absoluteString
    }

    // The playlist URL AVPlayer is handed by VideoPlayer: the proxy's host/port with the
    // API query parameters plus __hls_origin_url pointing at the real (origin) server
    private func proxyPlaylistURL(query: String = "id=9101&bitRate=512") throws -> URL {
        let originPlaylist = originURLString(path: "rest/hls.m3u8")
        let encoded = try XCTUnwrap(originPlaylist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        return try XCTUnwrap(URL(string: "http://127.0.0.1:\(HLSReverseProxyServer.port)/rest/hls.m3u8?\(query)&__hls_origin_url=\(encoded)"))
    }

    private func get(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(from: url)
        return (data, try XCTUnwrap(response as? HTTPURLResponse))
    }

    func testPlaylistSegmentAndURILinesAreRewrittenToProxyURLs() async throws {
        let url = try proxyPlaylistURL()
        let (data, response) = try await get(url)
        XCTAssertEqual(response.statusCode, 200,
                       "request: \(url.absoluteString)\nbody: \(String(data: data, encoding: .utf8) ?? "<binary>")")
        let playlist = try XCTUnwrap(String(data: data, encoding: .utf8))

        // The origin received the Subsonic query parameters appended by the proxy
        // (the mock echoes them into a comment line)
        XCTAssertTrue(playlist.contains("# requested id=9101 bitRate=512"),
                      "origin did not receive the Subsonic query parameters:\n\(playlist)")

        // Every segment line is rewritten to the proxy with the origin URL preserved
        let segmentLines = playlist.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        XCTAssertEqual(segmentLines.count, 2, "expected the two fixture segments:\n\(playlist)")
        for (index, line) in segmentLines.enumerated() {
            let url = try XCTUnwrap(URL(string: line), "segment line is not a URL: \(line)")
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.host, "127.0.0.1")
            XCTAssertEqual(components.port, HLSReverseProxyServer.port, "segment not routed through the proxy: \(line)")
            XCTAssertEqual(components.path, "/rest/seg\(index).ts")
            let origin = components.queryItems?.first { $0.name == "__hls_origin_url" }?.value
            XCTAssertEqual(origin, originURLString(path: "rest/seg\(index).ts"),
                           "rewritten segment does not point back at the origin: \(line)")
        }

        // URI="..." attribute lines (e.g. EXT-X-MAP) are rewritten the same way
        let mapLine = try XCTUnwrap(playlist.components(separatedBy: .newlines).first { $0.hasPrefix("#EXT-X-MAP") })
        XCTAssertTrue(mapLine.contains("URI=\"http://127.0.0.1:\(HLSReverseProxyServer.port)/rest/init.ts?"),
                      "URI attribute was not rewritten to the proxy: \(mapLine)")
        XCTAssertTrue(mapLine.contains("__hls_origin_url="), "URI attribute lost the origin URL: \(mapLine)")
    }

    func testSegmentFetchThroughProxyReturnsOriginBytes() async throws {
        // Take a rewritten segment URL from the proxied playlist and fetch it
        let (playlistData, _) = try await get(try proxyPlaylistURL())
        let playlist = try XCTUnwrap(String(data: playlistData, encoding: .utf8))
        let segmentLine = try XCTUnwrap(playlist.components(separatedBy: .newlines)
            .first { !$0.isEmpty && !$0.hasPrefix("#") })

        let (data, response) = try await get(try XCTUnwrap(URL(string: segmentLine)))
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(data, MockSubsonicHTTPServer.hlsSegmentData,
                       "proxied segment bytes do not match the origin")
        XCTAssertEqual(response.mimeType, "video/mp2t")
    }

    func testMissingOriginURLIsRejected() async throws {
        let playlistURL = try XCTUnwrap(URL(string: "http://127.0.0.1:\(HLSReverseProxyServer.port)/rest/hls.m3u8?id=1"))
        let (_, playlistResponse) = try await get(playlistURL)
        XCTAssertEqual(playlistResponse.statusCode, 400, "playlist request without an origin URL must be rejected")

        let segmentURL = try XCTUnwrap(URL(string: "http://127.0.0.1:\(HLSReverseProxyServer.port)/rest/seg0.ts"))
        let (_, segmentResponse) = try await get(segmentURL)
        XCTAssertEqual(segmentResponse.statusCode, 400, "segment request without an origin URL must be rejected")
    }
}

// E2E-06 video path, part 2: VideoPlayer's guards, bitrate parameters, and
// audio-session/presentation setup. Runs hosted in the app, so presenting the
// AVPlayerViewController exercises the real flow.
final class VideoPlayerTests: StoreTestCase {
    private var settings: SavedSettings!
    private var fakePlayer: FakePlayer!
    private var videoPlayer: VideoPlayer!
    private var server: Server!

    override func setUpWithError() throws {
        try super.setUpWithError()

        server = TestData.server(id: 1, urlString: "http://video.example.com")
        XCTAssertTrue(store.add(server: server))

        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
        settings.currentServer = server

        let player = FakePlayer()
        TestContainer.register { player as PlayerControlling }
        fakePlayer = player

        videoPlayer = VideoPlayer()

        // Earlier tests in the shared host app can leave error alerts presented on the
        // window, which would block our AVPlayerViewController presentation
        dismissAnyPresentedController()
    }

    override func tearDownWithError() throws {
        // Dismiss any presented player so later tests get a clean window
        NotificationCenter.postOnMainThread(name: Notifications.removeVideoPlayer)
        spinRunLoop { UIApplication.keyWindow?.rootViewController?.presentedViewController == nil }
        videoPlayer = nil
        fakePlayer = nil
        settings = nil
        server = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func spinRunLoop(timeout: TimeInterval = 10, until condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    private var presentedController: UIViewController? {
        UIApplication.keyWindow?.rootViewController?.presentedViewController
    }

    private func dismissAnyPresentedController() {
        guard presentedController != nil else { return }
        UIApplication.keyWindow?.rootViewController?.dismiss(animated: false)
        XCTAssertTrue(spinRunLoop { self.presentedController == nil },
                      "could not clear a leftover presented controller")
    }

    func testHLSRequestUsesM3U8PathAndBitrateParameters() throws {
        // The .hls action builds rest/hls.m3u8 (not .view) and encodes each bitrate as
        // its own bitRate parameter
        let request = try XCTUnwrap(URLRequest(serverId: server.id, subsonicAction: .hls,
                                               parameters: ["id": "9101", "bitRate": ["512", "256"]]))
        let url = try XCTUnwrap(request.url)
        XCTAssertTrue(url.path.hasSuffix("/rest/hls.m3u8"), "hls action must request the .m3u8 path: \(url)")
        let queryItems = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(queryItems.first { $0.name == "id" }?.value, "9101")
        XCTAssertEqual(queryItems.filter { $0.name == "bitRate" }.map(\.value), ["512", "256"],
                       "each video bitrate must be sent as its own bitRate parameter")
    }

    func testDefaultVideoBitratesAreAvailable() {
        // The video path depends on a non-nil default so playback works out of the box
        XCTAssertNotNil(settings.currentVideoBitrates, "no default video bitrates")
    }

    func testPlayVideoIgnoresNonVideoSongsAndUnsupportedServers() {
        // A non-video song must not interrupt audio playback or present anything
        videoPlayer.playVideo(song: TestData.song(id: "1", isVideo: false), bitrates: ["512"])
        XCTAssertEqual(fakePlayer.stopCount, 0, "playVideo acted on a non-video song")

        // A video song on a server without video support must also be ignored
        server.isVideoSupported = false
        settings.currentServer = server
        videoPlayer.playVideo(song: TestData.song(id: "9101", isVideo: true), bitrates: ["512"])
        XCTAssertEqual(fakePlayer.stopCount, 0, "playVideo acted despite isVideoSupported == false")
        // Stray app alerts can be presented by unrelated async work in the shared host,
        // so only assert that no *video player* appeared
        XCTAssertFalse(presentedController is AVPlayerViewController,
                       "a video player was presented despite the guards")
    }

    func testPlayVideoStopsAudioPresentsPlayerAndConfiguresAudioSession() throws {
        let song = TestData.song(id: "9101", path: "Video/test_video.mp4", suffix: "mp4", isVideo: true)
        videoPlayer.playVideo(song: song, bitrates: ["512"])

        // The audio player is stopped before video playback starts
        XCTAssertEqual(fakePlayer.stopCount, 1, "playVideo did not stop the audio player")

        // The AVPlayerViewController is presented (plain HTTP goes direct, no proxy)
        XCTAssertTrue(spinRunLoop { self.presentedController is AVPlayerViewController },
                      "no AVPlayerViewController was presented")

        // The presentation completion configures the audio session for movie playback
        XCTAssertTrue(spinRunLoop {
            AVAudioSession.sharedInstance().category == .playback
                && AVAudioSession.sharedInstance().mode == .moviePlayback
        }, "audio session was not configured for video playback")

        // removeVideoPlayer dismisses it again (the path PlayQueue uses for non-video songs)
        NotificationCenter.postOnMainThread(name: Notifications.removeVideoPlayer)
        XCTAssertTrue(spinRunLoop { !(self.presentedController is AVPlayerViewController) },
                      "removeVideoPlayer did not dismiss the video player")
    }
}
