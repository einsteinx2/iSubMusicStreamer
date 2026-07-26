//
//  SubsonicLenientTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// Unit tests for the lenient DTO primitives (SubsonicID, LenientArray) and
// SubsonicDateParsing. These back the Codable DTO layer that decodes both the JSON
// and XML flavors of the Subsonic API, so their tolerance rules are load-bearing.
final class SubsonicLenientTests: XCTestCase {
    private let decoder = JSONDecoder()

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder.decode(T.self, from: Data(json.utf8))
    }

    // MARK: SubsonicID

    private struct IDContainer: Decodable, Equatable {
        let id: SubsonicID
        let parent: SubsonicID?
    }

    func testIDDecodesString() throws {
        let container = try decode(IDContainer.self, #"{"id": "al-123"}"#)
        XCTAssertEqual(container.id.value, "al-123")
        XCTAssertNil(container.parent)
    }

    func testIDDecodesNumber() throws {
        let container = try decode(IDContainer.self, #"{"id": 123, "parent": 45}"#)
        XCTAssertEqual(container.id.value, "123")
        XCTAssertEqual(container.parent?.value, "45")
    }

    func testIDRejectsOtherTypes() {
        XCTAssertThrowsError(try decode(IDContainer.self, #"{"id": true}"#)) { error in
            guard case DecodingError.typeMismatch = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
        }
        XCTAssertThrowsError(try decode(IDContainer.self, #"{"id": {"nested": 1}}"#))
        XCTAssertThrowsError(try decode(IDContainer.self, #"{"id": null}"#))
    }

    // MARK: LenientArray

    private struct Entry: Decodable, Equatable {
        let name: String
    }

    private struct ListContainer: Decodable, Equatable {
        let entry: LenientArray<Entry>?
    }

    func testLenientArrayDecodesArray() throws {
        let container = try decode(ListContainer.self, #"{"entry": [{"name": "a"}, {"name": "b"}]}"#)
        XCTAssertEqual(container.entry?.values, [Entry(name: "a"), Entry(name: "b")])
    }

    func testLenientArrayDecodesLoneObject() throws {
        let container = try decode(ListContainer.self, #"{"entry": {"name": "a"}}"#)
        XCTAssertEqual(container.entry?.values, [Entry(name: "a")])
    }

    func testLenientArrayDecodesEmptyArray() throws {
        let container = try decode(ListContainer.self, #"{"entry": []}"#)
        XCTAssertEqual(container.entry?.values, [])
    }

    func testLenientArrayMissingKeyDecodesNil() throws {
        let container = try decode(ListContainer.self, #"{}"#)
        XCTAssertNil(container.entry)
    }

    func testLenientArrayRejectsScalar() {
        XCTAssertThrowsError(try decode(ListContainer.self, #"{"entry": 5}"#))
    }

    // MARK: SubsonicDateParsing

    func testDateWithMillisecondsAndTimezone() {
        // The format Subsonic/Airsonic servers reply with
        let date = SubsonicDateParsing.date(from: "2021-01-06T05:03:04.123Z")
        XCTAssertNotNil(date)
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1609909384.123, accuracy: 0.001)
    }

    func testDateWithoutTimezone() {
        // The format shown in the API documentation
        let date = SubsonicDateParsing.date(from: "2021-01-06T05:03:04")
        XCTAssertNotNil(date)
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1609909384, accuracy: 0.001)
    }

    func testDateWithFractionalSecondsAndOffset() {
        // Navidrome emits colon-separated offsets and long fractional seconds
        let date = SubsonicDateParsing.date(from: "2021-01-06T05:03:04.123+02:00")
        XCTAssertNotNil(date)
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1609909384.123 - 7200, accuracy: 0.001)
    }

    func testDateWithOffsetWithoutFractionalSeconds() {
        let date = SubsonicDateParsing.date(from: "2021-01-06T05:03:04+02:00")
        XCTAssertNotNil(date)
        XCTAssertEqual(date?.timeIntervalSince1970 ?? 0, 1609909384 - 7200, accuracy: 0.001)
    }

    func testDateGarbageReturnsNil() {
        XCTAssertNil(SubsonicDateParsing.date(from: "not a date"))
        XCTAssertNil(SubsonicDateParsing.date(from: ""))
    }

    func testDateHelperParityWithStringCleanXML() {
        // String+Clean's dateXML helpers route through SubsonicDateParsing, so both
        // parse paths must agree for identical DB rows across formats.
        let raw: String? = "2021-01-06T05:03:04.123Z"
        XCTAssertEqual(raw.dateXMLOptional, SubsonicDateParsing.date(from: "2021-01-06T05:03:04.123Z"))
    }
}
