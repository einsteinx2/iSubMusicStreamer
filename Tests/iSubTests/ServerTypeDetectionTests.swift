//
//  ServerTypeDetectionTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// Mapping the ping response's OpenSubsonic self-identification attributes to a
// ServerType, including the legacy fallback (no type attribute → generic Subsonic)
final class ServerTypeDetectionTests: XCTestCase {
    func testKnownTypesAreDetectedCaseInsensitively() {
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "navidrome", isOpenSubsonic: true), .navidrome)
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "Navidrome", isOpenSubsonic: true), .navidrome)
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "gonic", isOpenSubsonic: true), .gonic)
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "lms", isOpenSubsonic: true), .lms)
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "ampache", isOpenSubsonic: true), .ampache)
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "subsonic", isOpenSubsonic: false), .subsonic)
    }

    func testAirsonicVariantsAllMapToAirsonic() {
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "Airsonic-Advanced", isOpenSubsonic: false), .airsonic)
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "airsonic", isOpenSubsonic: false), .airsonic)
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "AirsonicAdvanced", isOpenSubsonic: true), .airsonic)
    }

    func testUnknownSelfIdentifyingServerUsesOpenSubsonicBadge() {
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "somefutureserver", isOpenSubsonic: true), .openSubsonic)
        // Self-identifies but doesn't claim OpenSubsonic: fall back to the generic badge
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "somefutureserver", isOpenSubsonic: false), .subsonic)
    }

    func testLegacyServersWithoutTypeAttributeFallBackToSubsonic() {
        // Original Subsonic and original Airsonic pings are indistinguishable (no type
        // attribute), so both get the generic Subsonic badge
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: nil, isOpenSubsonic: false), .subsonic)
        XCTAssertEqual(ServerTypeDetection.serverType(typeAttribute: "", isOpenSubsonic: false), .subsonic)
    }
}
