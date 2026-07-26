//
//  StringCleanXMLTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-01: Unit tests for the XML attribute conversion helpers in String+Clean.swift.
// These helpers back every API model's init(serverId:element:), so their nil/empty/
// malformed behavior is load-bearing for all XML parsing.
final class StringCleanXMLTests: XCTestCase {
    // MARK: stringXML

    func testStringXMLReturnsValue() {
        let value: String? = "The Beach Boys"
        XCTAssertEqual(value.stringXML, "The Beach Boys")
        XCTAssertEqual(value.stringXMLOptional, "The Beach Boys")
    }

    func testStringXMLNilDefaultsToLiteralNilString() {
        // Intentional (if surprising) behavior: the non-optional accessor substitutes
        // the literal string "nil" for a missing attribute
        let value: String? = nil
        XCTAssertEqual(value.stringXML, "nil")
        XCTAssertNil(value.stringXMLOptional)
    }

    func testStringXMLEmptyStaysEmptyRatherThanNil() {
        let value: String? = ""
        XCTAssertEqual(value.stringXML, "")
        XCTAssertEqual(value.stringXMLOptional, "")
    }

    func testStringXMLDoesNotTrimWhitespace() {
        let value: String? = "  padded  "
        XCTAssertEqual(value.stringXML, "  padded  ")
    }

    func testStringXMLPreservesSpecialCharacters() {
        let value: String? = "Sigur Rós — «Ágætis byrjun» & \"more\" <tags> 日本語 🎵"
        XCTAssertEqual(value.stringXML, "Sigur Rós — «Ágætis byrjun» & \"more\" <tags> 日本語 🎵")
    }

    // MARK: intXML

    func testIntXMLParsesIntegers() {
        XCTAssertEqual(("42" as String?).intXML, 42)
        XCTAssertEqual(("-7" as String?).intXML, -7)
        XCTAssertEqual(("0" as String?).intXML, 0)
        XCTAssertEqual(("42" as String?).intXMLOptional, 42)
    }

    func testIntXMLNilDefaultsToZero() {
        let value: String? = nil
        XCTAssertEqual(value.intXML, 0)
        XCTAssertNil(value.intXMLOptional)
    }

    func testIntXMLMalformedDefaultsToZero() {
        XCTAssertEqual(("abc" as String?).intXML, 0)
        XCTAssertEqual(("" as String?).intXML, 0)
        XCTAssertEqual(("1.5" as String?).intXML, 0)
        // No trimming happens before conversion, so padded numbers fail to parse
        XCTAssertEqual((" 42" as String?).intXML, 0)
        XCTAssertNil(("abc" as String?).intXMLOptional)
        XCTAssertNil(("" as String?).intXMLOptional)
    }

    // MARK: floatXML / doubleXML

    func testFloatXMLParsesValues() {
        XCTAssertEqual(("1.5" as String?).floatXML, 1.5)
        XCTAssertEqual(("-2.25" as String?).floatXML, -2.25)
        XCTAssertEqual(("3" as String?).floatXML, 3)
        XCTAssertEqual(("1.5" as String?).floatXMLOptional, 1.5)
    }

    func testFloatXMLNilAndMalformedDefaultToZero() {
        let missing: String? = nil
        XCTAssertEqual(missing.floatXML, 0)
        XCTAssertNil(missing.floatXMLOptional)
        XCTAssertEqual(("abc" as String?).floatXML, 0)
        XCTAssertNil(("abc" as String?).floatXMLOptional)
    }

    func testDoubleXMLParsesValues() {
        XCTAssertEqual(("4.75" as String?).doubleXML, 4.75)
        XCTAssertEqual(("4.75" as String?).doubleXMLOptional, 4.75)
    }

    func testDoubleXMLNilAndMalformedDefaultToZero() {
        let missing: String? = nil
        XCTAssertEqual(missing.doubleXML, 0)
        XCTAssertNil(missing.doubleXMLOptional)
        XCTAssertEqual(("12,5" as String?).doubleXML, 0)
        XCTAssertNil(("" as String?).doubleXMLOptional)
    }

    // MARK: boolXML

    func testBoolXMLParsesTrueAndFalse() {
        XCTAssertTrue(("true" as String?).boolXML)
        XCTAssertFalse(("false" as String?).boolXML)
        XCTAssertEqual(("true" as String?).boolXMLOptional, true)
        XCTAssertEqual(("false" as String?).boolXMLOptional, false)
    }

    func testBoolXMLOnlyAcceptsLowercaseTrueFalse() {
        // Bool(String) only recognizes exactly "true"/"false", so numeric or cased
        // variants fall back to the false default
        XCTAssertFalse(("1" as String?).boolXML)
        XCTAssertFalse(("TRUE" as String?).boolXML)
        XCTAssertFalse(("True" as String?).boolXML)
        XCTAssertFalse(("yes" as String?).boolXML)
        XCTAssertNil(("1" as String?).boolXMLOptional)
    }

    func testBoolXMLNilDefaultsToFalse() {
        let value: String? = nil
        XCTAssertFalse(value.boolXML)
        XCTAssertNil(value.boolXMLOptional)
    }

    // MARK: dateXML

    func testDateXMLParsesMillisecondsWithZuluSuffix() throws {
        // The format Airsonic/Subsonic actually sends
        let value: String? = "2024-02-24T15:31:22.978Z"
        let date = try XCTUnwrap(value.dateXMLOptional)
        XCTAssertEqual(date.timeIntervalSince1970, 1708788682.978, accuracy: 0.001)
        XCTAssertEqual(value.dateXML.timeIntervalSince1970, 1708788682.978, accuracy: 0.001)
    }

    func testDateXMLParsesMillisecondsWithNumericTimezone() throws {
        let value: String? = "2024-02-24T15:31:22.978+0100"
        let date = try XCTUnwrap(value.dateXMLOptional)
        XCTAssertEqual(date.timeIntervalSince1970, 1708785082.978, accuracy: 0.001)
    }

    func testDateXMLParsesSecondsWithoutTimezoneAsGMT() throws {
        // The documentation format, interpreted as GMT
        let value: String? = "2024-02-24T15:31:22"
        let date = try XCTUnwrap(value.dateXMLOptional)
        XCTAssertEqual(date.timeIntervalSince1970, 1708788682.0, accuracy: 0.001)
    }

    func testDateXMLSecondsWithZuluSuffixParses() throws {
        // Formerly a parser gap; the ISO8601 fallback in SubsonicDateParsing (added
        // for JSON support, since Navidrome emits this shape) now accepts it
        let value: String? = "2024-02-24T15:31:22Z"
        let date = try XCTUnwrap(value.dateXMLOptional)
        XCTAssertEqual(date.timeIntervalSince1970, 1708788682.0, accuracy: 0.001)
    }

    func testDateXMLNilAndMalformedDefaultToDistantPast() {
        let missing: String? = nil
        XCTAssertNil(missing.dateXMLOptional)
        XCTAssertEqual(missing.dateXML, .distantPast)
        XCTAssertNil(("not a date" as String?).dateXMLOptional)
        XCTAssertEqual(("not a date" as String?).dateXML, .distantPast)
        XCTAssertNil(("" as String?).dateXMLOptional)
    }
}
