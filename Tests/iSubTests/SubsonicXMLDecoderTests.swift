//
//  SubsonicXMLDecoderTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The parity gate for the XML-backed Decoder: every captured XML fixture must decode
// into DTOs that are EQUAL to the ones decoded from its JSON twin. Field-level
// correctness is asserted by SubsonicDTODecodingTests against the JSON corpus, so
// envelope equality here transfers all of those assertions to the XML decoder.
final class SubsonicXMLDecoderTests: XCTestCase {
    // Every converted fixture pair (XML original -> generated JSON twin), plus
    // getAlbum_navidrome where BOTH sides are real captures of the same response
    // from a live Navidrome server (f=xml and f=json), so equality also covers
    // real cross-format server output rather than only our conversion rules.
    private static let pairedFixtures = [
        "error_data_not_found",
        "getAlbum", "getAlbum_formats", "getAlbum_navidrome",
        "getAlbumList_newest", "getAlbumList_server2",
        "getArtist", "getArtist_formats",
        "getArtists", "getArtists_server2",
        "getChatMessages",
        "getIndexes", "getIndexes_server2",
        "getLyrics", "getLyrics_empty",
        "getMusicDirectory_album", "getMusicDirectory_artist", "getMusicDirectory_formats",
        "getMusicDirectory_server2", "getMusicDirectory_videos",
        "getMusicFolders",
        "getNowPlaying",
        "getPlaylist", "getPlaylists", "getPlaylists_server2",
        "getRandomSongs",
        "jukeboxControl_error_not_authorized", "jukeboxControl_get", "jukeboxControl_status",
        "ping_error_incompatible_version", "ping_error_wrong_credentials",
        "ping_navidrome", "ping_success", "ping_success_subsonic",
        "search2", "search2_server2",
        "search3", "search3_server2",
    ]

    private func decodeXML(_ fixture: String) throws -> SubsonicEnvelope {
        try SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: Fixtures.data("XML/\(fixture).xml"))
    }

    func testAllFixturesDecodeEqualToTheirJSONTwins() throws {
        for fixture in Self.pairedFixtures {
            let xmlEnvelope = try decodeXML(fixture)
            let jsonEnvelope = try SubsonicJSON.decode(SubsonicEnvelope.self, from: Fixtures.data("JSON/\(fixture).json"))
            XCTAssertEqual(xmlEnvelope, jsonEnvelope, "XML and JSON decodes disagree for fixture \(fixture)")
        }
    }

    // MARK: Spot checks on XML-specific mapping rules

    func testRootAttributesDecode() throws {
        let response = try decodeXML("ping_navidrome").response
        XCTAssertEqual(response.status, "ok")
        XCTAssertEqual(response.version, "1.16.1")
        XCTAssertEqual(response.type, "navidrome")
        XCTAssertEqual(response.serverVersion, "0.52.5 (734eb30a)")
        XCTAssertEqual(response.openSubsonic, true)
    }

    func testElementTextDecodesAsValue() throws {
        let lyrics = try XCTUnwrap(decodeXML("getLyrics").response.lyrics)
        XCTAssertEqual(lyrics.artist, "Beck")
        XCTAssertEqual(lyrics.value?.hasPrefix("In the time of chimpanzees"), true)
    }

    func testEmptyElementDecodesWithoutValue() throws {
        let lyrics = try XCTUnwrap(decodeXML("getLyrics_empty").response.lyrics)
        XCTAssertNil(lyrics.value)
    }

    func testRepeatedChildrenDecodeAsArrays() throws {
        let directory = try XCTUnwrap(decodeXML("getMusicDirectory_formats").response.directory)
        XCTAssertEqual(directory.child?.values.count, 2)
        XCTAssertEqual(directory.child?.values.first?.id.value, "9001")
    }

    func testSingleChildDecodesAsOneElementArray() throws {
        let artist = try XCTUnwrap(decodeXML("getArtist").response.artist)
        XCTAssertEqual(artist.album?.values.count, 1)
    }

    func testStringScalarsConvertToTypedFields() throws {
        let song = try XCTUnwrap(decodeXML("getAlbum").response.album?.song?.values.first)
        XCTAssertEqual(song.size, 8484888)          // Int from "8484888"
        XCTAssertEqual(song.isVideo, false)         // Bool from "false"
        XCTAssertEqual(song.created, SubsonicDateParsing.date(from: "2024-02-24T15:31:22.978Z"))
        let status = try XCTUnwrap(decodeXML("jukeboxControl_status").response.jukeboxStatus)
        XCTAssertEqual(status.gain, 0.75)           // Double from "0.75"
    }

    func testSubsonicErrorPayload() throws {
        let error = try XCTUnwrap(decodeXML("ping_error_wrong_credentials").response.error)
        XCTAssertEqual(error.code, 40)
        XCTAssertEqual(error.message, "Wrong username or password.")
    }

    // MARK: Bad input

    func testTruncatedXMLDecodesViaLibxmlRecovery() throws {
        // RXMLElement parses with XML_PARSE_RECOVER, so truncated XML whose root
        // element survived still decodes — identical to the legacy parser behavior
        // pinned by AsyncStatusLoaderTests.testTruncatedXMLStillParsesViaRecovery
        let envelope = try SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: Fixtures.data("XML/malformed.xml"))
        XCTAssertEqual(envelope.response.version, "1.15.0")
        XCTAssertNotNil(envelope.response.indexes)
    }

    func testNonXMLThrows() throws {
        let data = try Fixtures.data("XML/not_xml.txt")
        XCTAssertThrowsError(try SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: data))
        let html = try Fixtures.data("XML/not_xml.html")
        XCTAssertThrowsError(try SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: html))
        XCTAssertThrowsError(try SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: Data("{}".utf8)))
    }

    func testWrongRootElementThrowsKeyNotFound() {
        let data = Data("<?xml version=\"1.0\"?><wrong-root status=\"ok\"/>".utf8)
        XCTAssertThrowsError(try SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: data)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected keyNotFound, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "subsonic-response")
        }
    }

    // MARK: Performance sanity (largest fixtures in the corpus)

    func testDecodePerformance() throws {
        let xmlData = try Fixtures.data("XML/getAlbumList_newest.xml")
        let jsonData = try Fixtures.data("JSON/getAlbumList_newest.json")
        measure {
            for _ in 0..<50 {
                _ = try? SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: xmlData)
                _ = try? SubsonicJSON.decode(SubsonicEnvelope.self, from: jsonData)
            }
        }
    }
}
