//
//  SavedSettingsTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

final class SavedSettingsTests: SandboxedTestCase {
    func testWrapperReturnsDefaultValueWhenNothingPersisted() {
        let settings = SavedSettings()
        // Declared defaults in SavedSettings
        XCTAssertEqual(settings.maxBitrateWifi, 7)
        XCTAssertEqual(settings.maxBitrate3G, 7)
        XCTAssertTrue(settings.appTerminatedCleanly)
        XCTAssertFalse(settings.isForceOfflineMode)
    }

    func testWrapperPersistRoundTrip() {
        let settings = SavedSettings()
        settings.maxBitrateWifi = 3
        settings.isForceOfflineMode = true

        // The values landed in the injected suite...
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.maxBitrateWifiSetting.rawValue), 3)

        // ...and a separate instance backed by the same suite reads them back
        let reloaded = SavedSettings()
        XCTAssertEqual(reloaded.maxBitrateWifi, 3)
        XCTAssertTrue(reloaded.isForceOfflineMode)
    }

    func testInjectedSuiteDoesNotLeakIntoStandardDefaults() {
        let settings = SavedSettings()
        settings.maxBitrateWifi = 2

        let standardValue = UserDefaults.standard.object(forKey: SavedSettings.Key.maxBitrateWifiSetting.rawValue) as? Int
        XCTAssertNotEqual(standardValue, 2, "test writes must not reach UserDefaults.standard")
    }

    func testSuiteIsEmptyAtTestStart() {
        // Each test gets a fresh suite, so writes from other tests are never visible
        XCTAssertNil(testDefaults.object(forKey: SavedSettings.Key.maxBitrateWifiSetting.rawValue))
        XCTAssertNil(testDefaults.object(forKey: SavedSettings.Key.manualOfflineModeSetting.rawValue))
    }
}
