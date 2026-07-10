//
//  UtilityAndMathTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-02: Unit tests for the pure logic layer — Foundation extensions, the byte/time
// formatters in Defines.swift, the Bass buffering math, StreamHandler's threshold and
// throttle helpers, Song local path construction, and API error mapping.
final class UtilityAndMathTests: XCTestCase {
    // MARK: String+Hex

    func testHexValueEncodesASCII() {
        XCTAssertEqual("abc".hexValue, "616263")
        XCTAssertEqual("A".hexValue, "41")
    }

    func testHexValueEncodesMultibyteUTF8() {
        XCTAssertEqual("é".hexValue, "C3A9")
        XCTAssertEqual("🎵".hexValue, "F09F8EB5")
    }

    func testHexValueEmptyStringAndUnpaddedBytes() {
        XCTAssertEqual("".hexValue, "")
        // %X does not zero-pad, so bytes under 0x10 produce a single hex digit
        XCTAssertEqual("\n".hexValue, "A")
    }

    // MARK: String+URLEncode

    func testURLQueryEncodedEscapesSpacesAndUnicode() {
        XCTAssertEqual("a b".URLQueryEncoded, "a%20b")
        XCTAssertEqual("Björk".URLQueryEncoded, "Bj%C3%B6rk")
    }

    func testURLQueryEncodedLeavesQueryLegalCharacters() {
        // & and = are legal inside a query string, so urlQueryAllowed keeps them
        XCTAssertEqual("a&b=c".URLQueryEncoded, "a&b=c")
        XCTAssertEqual("path/to/file.mp3".URLQueryEncoded, "path/to/file.mp3")
    }

    // MARK: URL+QueryParameters

    func testQueryParameterSubscript() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/rest/ping.view?u=bbaron&v=1.15.0&empty="))
        XCTAssertEqual(url["u"], "bbaron")
        XCTAssertEqual(url["v"], "1.15.0")
        XCTAssertEqual(url["empty"], "")
        XCTAssertNil(url["missing"])
    }

    func testQueryParameterSubscriptWithoutQuery() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/rest/ping.view"))
        XCTAssertNil(url["u"])
    }

    // MARK: Error+IsCanceled

    func testIsCanceledForCancellationError() {
        XCTAssertTrue(CancellationError().isCanceled)
    }

    func testIsCanceledForURLErrorCancelled() {
        XCTAssertTrue(URLError(.cancelled).isCanceled)
        XCTAssertTrue(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled).isCanceled)
    }

    func testIsCanceledFalseForOtherErrors() {
        XCTAssertFalse(URLError(.timedOut).isCanceled)
        XCTAssertFalse(APIError.dataNotFound.isCanceled)
        XCTAssertFalse(NSError(domain: NSCocoaErrorDomain, code: -999).isCanceled)
    }

    // MARK: bytesForSeconds (Defines.swift)

    func testBytesForSeconds() {
        // (kiloBitrate / 8) * 1024 * seconds
        XCTAssertEqual(bytesForSeconds(seconds: 10, kiloBitrate: 128), 163840)
        XCTAssertEqual(bytesForSeconds(seconds: 1, kiloBitrate: 320), 40960)
        XCTAssertEqual(bytesForSeconds(seconds: 0, kiloBitrate: 128), 0)
        XCTAssertEqual(bytesForSeconds(seconds: 10, kiloBitrate: 0), 0)
        // Fractional seconds work because the math is done in Double
        XCTAssertEqual(bytesForSeconds(seconds: 0.1, kiloBitrate: 500), 6400)
    }

    // MARK: formatTime

    func testFormatTimeFormatsMinutesAndSeconds() {
        XCTAssertEqual(formatTime(seconds: 0), "0:00")
        XCTAssertEqual(formatTime(seconds: 59), "0:59")
        XCTAssertEqual(formatTime(seconds: 60), "1:00")
        XCTAssertEqual(formatTime(seconds: 61), "1:01")
        XCTAssertEqual(formatTime(seconds: 3599), "59:59")
        // No hours segment: minutes just keep counting up
        XCTAssertEqual(formatTime(seconds: 3661), "61:01")
    }

    func testFormatTimeFloatingPointTruncates() {
        XCTAssertEqual(formatTime(seconds: 59.9), "0:59")
        XCTAssertEqual(formatTime(seconds: 60.5), "1:00")
    }

    func testFormatTimeNegativeClampsToZero() {
        XCTAssertEqual(formatTime(seconds: -5), "0:00")
        XCTAssertEqual(formatTime(seconds: -0.5), "0:00")
    }

    // MARK: formatFileSize

    func testFormatFileSizeBuckets() {
        XCTAssertEqual(formatFileSize(bytes: 0), "0 bytes")
        XCTAssertEqual(formatFileSize(bytes: 1023), "1023 bytes")
        XCTAssertEqual(formatFileSize(bytes: 1024), "1.00 KB")
        XCTAssertEqual(formatFileSize(bytes: 1536), "1.50 KB")
        XCTAssertEqual(formatFileSize(bytes: 1024 * 1024), "1.00 MB")
        XCTAssertEqual(formatFileSize(bytes: Int(2.5 * 1024 * 1024)), "2.50 MB")
        XCTAssertEqual(formatFileSize(bytes: 1024 * 1024 * 1024), "1.00 GB")
        XCTAssertEqual(formatFileSize(bytes: 5 * 1024 * 1024 * 1024), "5.00 GB")
    }

    func testFormatFileSizeFloatingPointVariant() {
        XCTAssertEqual(formatFileSize(bytes: 1536.7), "1.50 KB")
    }

    // MARK: fileSize(formatted:)

    func testFileSizeFromFormattedString() {
        XCTAssertEqual(fileSize(formatted: "1.00 KB"), 1024)
        XCTAssertEqual(fileSize(formatted: "1.50 MB"), 1572864)
        XCTAssertEqual(fileSize(formatted: "2 GB"), 2147483648)
        XCTAssertEqual(fileSize(formatted: "512"), 512)
    }

    func testFileSizeFromFormattedStringWithoutNumberIsNil() {
        XCTAssertNil(fileSize(formatted: "no numbers here"))
        XCTAssertNil(fileSize(formatted: ""))
    }

    // MARK: Bass math

    func testBassBytesForSecondsAtBitRate() {
        XCTAssertEqual(Bass.bytesForSecondsAtBitRate(seconds: 10, bitRate: 128), 163840)
        XCTAssertEqual(Bass.bytesForSecondsAtBitRate(seconds: 0, bitRate: 128), 0)
        XCTAssertEqual(Bass.bytesForSecondsAtBitRate(seconds: 1, bitRate: 320), 40960)
    }

    func testBassBytesToBufferGuardFallsBackToTenSeconds() {
        // Zero bitrate or zero download speed falls back to 10 seconds of audio
        XCTAssertEqual(Bass.bytesToBuffer(kiloBitrate: 128, bytesPerSec: 0), bytesForSeconds(seconds: 10, kiloBitrate: 128))
        XCTAssertEqual(Bass.bytesToBuffer(kiloBitrate: 0, bytesPerSec: 100000), 0)
    }

    func testBassBytesToBufferSlowDownloadBuffersTwentySeconds() {
        // At any realistic download speed the seconds-per-second factor computes as
        // far below 0.5, so the slowest tier (20 seconds of audio) applies
        let expected = 20 * bytesForSeconds(seconds: 1, kiloBitrate: 128)
        XCTAssertEqual(Bass.bytesToBuffer(kiloBitrate: 128, bytesPerSec: 100_000), expected)
    }

    func testBassBytesToBufferVeryFastDownloadBuffersTwoSeconds() {
        // Push the factor above 1.0 to reach the fastest tier (2 seconds of audio)
        let expected = 2 * bytesForSeconds(seconds: 1, kiloBitrate: 128)
        XCTAssertEqual(Bass.bytesToBuffer(kiloBitrate: 128, bytesPerSec: 40_000_000_000_000), expected)
    }

    // MARK: StreamHandler thresholds

    func testMinimumBytesToStartPlaybackIsTenSecondsOfAudio() {
        XCTAssertEqual(minimumBytesToStartPlayback(kiloBitrate: 128), bytesForSeconds(seconds: 10, kiloBitrate: 128))
        XCTAssertEqual(minimumBytesToStartPlayback(kiloBitrate: 320), 409600)
        XCTAssertEqual(minimumBytesToStartPlayback(kiloBitrate: 0), 0)
    }

    func testMinBytesToStartLimitingIsSixtySecondsOfAudio() {
        XCTAssertEqual(minBytesToStartLimiting(kiloBitrate: 128), bytesForSeconds(seconds: 60, kiloBitrate: 128))
        XCTAssertEqual(minBytesToStartLimiting(kiloBitrate: 128), 983040)
    }

    func testMaxBytesPerIntervalConstants() {
        // 500 Kbps cap on cell, 8000 Kbps cap on wifi, over 0.1 second intervals
        XCTAssertEqual(maxBytesPerIntervalCell(), 6400)
        XCTAssertEqual(maxBytesPerIntervalWifi(), 102400)
        XCTAssertEqual(throttleTimeInterval, 0.1, accuracy: 0.0001)
    }

    func testMaxBytesPerIntervalScalesWithBitrate() {
        // The base rate is scaled by kiloBitrate/160
        XCTAssertEqual(maxBytesPerInterval(kiloBitrate: 160, isCell: true), 6400)
        XCTAssertEqual(maxBytesPerInterval(kiloBitrate: 320, isCell: true), 12800)
        XCTAssertEqual(maxBytesPerInterval(kiloBitrate: 160, isCell: false), 102400)
    }

    func testMaxBytesPerIntervalClampsToDefaultFloor() {
        // A low bitrate would scale below the default, so it clamps up to the default
        XCTAssertEqual(maxBytesPerInterval(kiloBitrate: 80, isCell: true), 6400)
        XCTAssertEqual(maxBytesPerInterval(kiloBitrate: 80, isCell: false), 102400)
    }

    func testMaxBytesPerIntervalClampsToTwiceWifiCeiling() {
        // A huge bitrate clamps at twice the wifi limit to protect disk bandwidth
        XCTAssertEqual(maxBytesPerInterval(kiloBitrate: 100_000, isCell: false), 2 * maxBytesPerIntervalWifi())
        XCTAssertEqual(maxBytesPerInterval(kiloBitrate: 100_000, isCell: true), 2 * maxBytesPerIntervalWifi())
    }

    func testMinBytesToStartPlaybackGuardFallsBackToMinimum() {
        XCTAssertEqual(minBytesToStartPlayback(kiloBitrate: 128, bytesPerSec: 0), minimumBytesToStartPlayback(kiloBitrate: 128))
        XCTAssertEqual(minBytesToStartPlayback(kiloBitrate: 0, bytesPerSec: 50000), minimumBytesToStartPlayback(kiloBitrate: 0))
    }

    func testMinBytesToStartPlaybackAdaptiveTiers() {
        // Realistic speeds compute a factor below 1.0 → 16-second buffer tier
        XCTAssertEqual(minBytesToStartPlayback(kiloBitrate: 128, bytesPerSec: 100_000), 16 * bytesForSeconds(seconds: 1, kiloBitrate: 128))
        // An extreme speed pushes the factor past 2.0 → 2-second tier
        XCTAssertEqual(minBytesToStartPlayback(kiloBitrate: 128, bytesPerSec: 40_000_000_000_000), 2 * bytesForSeconds(seconds: 1, kiloBitrate: 128))
    }

    // MARK: Throttle delay math (BUG-04)

    func testThrottleDelayZeroWhenUnderCap() {
        // 160 Kbps on cell caps at 6400 bytes per 0.1s interval
        XCTAssertEqual(throttleDelay(bytesTransferred: 6400, intervalSinceLastThrottle: 0.1, kiloBitrate: 160, isCell: true), 0)
        XCTAssertEqual(throttleDelay(bytesTransferred: 3200, intervalSinceLastThrottle: 0.1, kiloBitrate: 160, isCell: true), 0)
        XCTAssertEqual(throttleDelay(bytesTransferred: 0, intervalSinceLastThrottle: 1.0, kiloBitrate: 160, isCell: true), 0)
    }

    func testThrottleDelayForOverage() {
        // Twice the cap in one interval: the bytes should have taken 2 intervals,
        // so sleep for the extra interval
        XCTAssertEqual(throttleDelay(bytesTransferred: 12800, intervalSinceLastThrottle: 0.1, kiloBitrate: 160, isCell: true), 0.1, accuracy: 0.0001)
        // Four times the cap: sleep the 3 missing intervals
        XCTAssertEqual(throttleDelay(bytesTransferred: 25600, intervalSinceLastThrottle: 0.1, kiloBitrate: 160, isCell: true), 0.3, accuracy: 0.0001)
    }

    func testThrottleDelayScalesWithElapsedInterval() {
        // A longer elapsed interval allows proportionally more bytes before throttling:
        // 12,800 bytes over 0.2s is exactly at the 160 Kbps cell cap
        XCTAssertEqual(throttleDelay(bytesTransferred: 12800, intervalSinceLastThrottle: 0.2, kiloBitrate: 160, isCell: true), 0)
        // ...and twice that sleeps for the one missing 0.2s period
        XCTAssertEqual(throttleDelay(bytesTransferred: 25600, intervalSinceLastThrottle: 0.2, kiloBitrate: 160, isCell: true), 0.2, accuracy: 0.0001)
    }

    func testThrottleDelayUsesNetworkTypeCap() {
        // The same overage that throttles on cell is under the wifi cap
        XCTAssertGreaterThan(throttleDelay(bytesTransferred: 51200, intervalSinceLastThrottle: 0.1, kiloBitrate: 160, isCell: true), 0)
        XCTAssertEqual(throttleDelay(bytesTransferred: 51200, intervalSinceLastThrottle: 0.1, kiloBitrate: 160, isCell: false), 0)
    }

    // MARK: SubsonicError mapping

    func testSubsonicErrorCodeMapping() {
        func assertCase(_ code: Int, _ name: String, line: UInt = #line) {
            let error = SubsonicError(code: code, message: "msg")
            XCTAssertEqual(error.name, name, line: line)
            XCTAssertEqual(error.code, code, line: line)
            XCTAssertEqual(error.message, "msg", line: line)
        }
        assertCase(0, "SubsonicError.generic")
        assertCase(10, "SubsonicError.missingParameter")
        assertCase(20, "SubsonicError.clientVersion")
        assertCase(30, "SubsonicError.serverVersion")
        assertCase(40, "SubsonicError.badCredentials")
        assertCase(41, "SubsonicError.tokenAuthNotSupported")
        assertCase(50, "SubsonicError.notAuthorized")
        assertCase(60, "SubsonicError.trialExpired")
        assertCase(70, "SubsonicError.dataNotFound")
        assertCase(99, "SubsonicError.unknown")
    }

    func testSubsonicErrorFromXMLElement() throws {
        let element = try XMLTestHelpers.element(tag: "error", xml: #"<error code="60" message="Trial period is over."/>"#)
        let error = SubsonicError(element: element)
        guard case .trialExpired(let message) = error else {
            return XCTFail("expected .trialExpired, got \(error)")
        }
        XCTAssertEqual(message, "Trial period is over.")
    }

    func testSubsonicErrorFromXMLElementWithMissingAttributes() throws {
        // Missing code parses as 0 → .generic; missing message becomes the "nil" placeholder
        let element = try XMLTestHelpers.element(tag: "error", xml: #"<error/>"#)
        let error = SubsonicError(element: element)
        guard case .generic(let message) = error else {
            return XCTFail("expected .generic, got \(error)")
        }
        XCTAssertEqual(message, "nil")
    }

    func testSubsonicErrorFromRealErrorFixture() throws {
        let element = try XMLTestHelpers.element(tag: "error", fixture: "XML/ping_error_wrong_credentials.xml")
        let error = SubsonicError(element: element)
        guard case .badCredentials = error else {
            return XCTFail("expected .badCredentials, got \(error)")
        }
    }

    func testSubsonicErrorUnknownPreservesCodeAndMessage() {
        let error = SubsonicError(code: 123, message: "strange")
        guard case .unknown(let code, let message) = error else {
            return XCTFail("expected .unknown, got \(error)")
        }
        XCTAssertEqual(code, 123)
        XCTAssertEqual(message, "strange")
        XCTAssertTrue(error.localizedDescription.contains("123"))
        XCTAssertTrue(error.localizedDescription.contains("strange"))
    }

    // MARK: APIError

    func testAPIErrorNamesAndDescriptions() {
        XCTAssertEqual(APIError.dataNotFound.name, "APIError.dataNotFound")
        XCTAssertEqual(APIError.responseMissingElement(parent: "root", tag: "child").name, "APIError.responseMissingElement")
        XCTAssertTrue(APIError.responseMissingElement(parent: "root", tag: "child").localizedDescription.contains("child"))
        XCTAssertTrue(APIError.responseMissingAttribute(tag: "song", attribute: "id").localizedDescription.contains("id"))
        XCTAssertTrue(APIError.serverUnreachable.description.contains("APIError.serverUnreachable"))
    }
}

// Song.localPath/localTempPath need a Store (for the server path prefix) and the
// sandboxed FileSystem, so they get a SandboxedTestCase of their own
final class SongLocalPathTests: SandboxedTestCase {
    private var store: Store!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = Store()
        store.setup(location: .memory)
        let injectedStore: Store = store
        TestContainer.register { injectedStore }
    }

    override func tearDownWithError() throws {
        store = nil
        try super.tearDownWithError()
    }

    private func makeSong(serverId: Int, path: String, suffix: String = "mp3", transcodedSuffix: String? = nil) throws -> Song {
        let xml = "<song id=\"1\" title=\"t\" path=\"\(path)\" suffix=\"\(suffix)\"\(transcodedSuffix.map { " transcodedSuffix=\"\($0)\"" } ?? "")/>"
        return Song(serverId: serverId, element: try XMLTestHelpers.element(tag: "song", xml: xml))
    }

    func testLocalPathUsesServerPathPrefixAndSongPath() throws {
        let url = try XCTUnwrap(URL(string: "https://music.example.com:8080/subsonic"))
        let server = Server(id: 1, type: .subsonic, url: url, username: "u", password: "p")
        XCTAssertTrue(store.add(server: server))

        let song = try makeSong(serverId: 1, path: "Beck/Odelay/01 Devils Haircut.mp3")
        let expected = FileSystem.downloadsDirectory
            .appendingPathComponent("https_music.example.com_8080_subsonic")
            .appendingPathComponent("Beck/Odelay/01 Devils Haircut.mp3").path
        XCTAssertEqual(song.localPath, expected)
    }

    func testLocalTempPathUsesTempDownloadsDirectory() throws {
        let url = try XCTUnwrap(URL(string: "http://home.local"))
        let server = Server(id: 1, type: .subsonic, url: url, username: "u", password: "p")
        XCTAssertTrue(store.add(server: server))

        let song = try makeSong(serverId: 1, path: "a/b.mp3")
        let expected = FileSystem.tempDownloadsDirectory
            .appendingPathComponent("http_home.local_port")
            .appendingPathComponent("a/b.mp3").path
        XCTAssertEqual(song.localTempPath, expected)
    }

    func testLocalPathFallsBackToUnknownForMissingServer() throws {
        let song = try makeSong(serverId: 42, path: "x/y.mp3")
        let expected = FileSystem.downloadsDirectory
            .appendingPathComponent("Unknown")
            .appendingPathComponent("x/y.mp3").path
        XCTAssertEqual(song.localPath, expected)
    }

    func testLocalSuffixPrefersTranscodedSuffix() throws {
        let plain = try makeSong(serverId: 1, path: "p.mp3", suffix: "mp3")
        XCTAssertEqual(plain.localSuffix, "mp3")
        let transcoded = try makeSong(serverId: 1, path: "p.flac", suffix: "flac", transcodedSuffix: "opus")
        XCTAssertEqual(transcoded.localSuffix, "opus")
    }
}
