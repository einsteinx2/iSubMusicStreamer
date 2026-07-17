//
//  SettingsRegistryTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The reflection-driven settings registry: every @UserDefault property on SavedSettings
// carrying SettingUI metadata becomes a UI row. These tests pin the reflection behavior
// (count, order, uniqueness) so a toolchain change or accidental metadata removal fails
// loudly, and prove that reads/writes through the type-erased registry path hit the
// swapped test defaults and fire onChange side effects.
final class SettingsRegistryTests: SandboxedTestCase {
    private var settings: SavedSettings!
    private var registry: SettingsRegistry!

    override func setUpWithError() throws {
        try super.setUpWithError()
        settings = SavedSettings()
        TestContainer.register { self.settings! }
        registry = SettingsRegistry(settings: settings)
    }

    override func tearDownWithError() throws {
        registry = nil
        settings = nil
        try super.tearDownWithError()
    }

    private func item(_ key: SavedSettings.Key) throws -> SettingsRegistry.Item {
        try XCTUnwrap(registry.items.first { $0.id == key.rawValue }, "no registry item for \(key)")
    }

    // MARK: Reflection shape

    func testEveryVisibleSettingHasValidMetadata() {
        XCTAssertEqual(registry.items.count, 25, "expected exactly the 25 visible settings; add the new setting to the section order test too if this grew intentionally")
        XCTAssertEqual(Set(registry.items.map(\.id)).count, registry.items.count, "setting ids must be unique")
        for item in registry.items {
            XCTAssertFalse(item.ui.title.isEmpty, "\(item.id) has an empty title")
        }
    }

    func testSectionMembershipAndDeclarationOrder() {
        let expected: [SettingsSection: [SavedSettings.Key]] = [
            .network: [.manualOfflineModeSetting, .isDisableUsageOver3G,
                       .maxBitrateWifiSetting, .maxBitrate3GSetting, .maxVideoBitrateWifi, .maxVideoBitrate3G],
            .downloads: [.enableSongCachingSetting, .enableNextSongCacheSetting, .isManualCachingOnWWANEnabled,
                         .isBackupCacheEnabled, .cachingTypeSetting, .autoDeleteCacheSetting,
                         .autoDeleteCacheTypeSetting, .cacheSongCellColorSetting],
            .playback: [.recoverSetting, .quickSkipNumberOfSeconds, .isLockScreenArtEnabled,
                        .enableScrobblingSetting, .scrobblePercentSetting, .enableJukeboxSetting],
            .appearanceBehavior: [.isPopupsEnabled, .isScreenSleepEnabled, .lockRotationSetting,
                                  .autoReloadArtistsSetting, .enableChatSetting],
            .about: [],
        ]
        for (section, keys) in expected {
            XCTAssertEqual(registry.items(in: section).map(\.id), keys.map(\.rawValue),
                           "\(section) rows should match SavedSettings declaration order")
        }
    }

    func testFeatureGatesDefaultOff() {
        // Server chat and jukebox mode are opt-in features; their UI entry points
        // (Browse chat row, Player jukebox button) must be hidden on a fresh install
        XCTAssertFalse(settings.isChatEnabled)
        XCTAssertFalse(settings.isJukeboxFeatureEnabled)
    }

    func testQuickSkipMappedValuesMatchLabels() throws {
        let quickSkip = try item(.quickSkipNumberOfSeconds)
        guard case let .pickerMapped(labels, values) = quickSkip.ui.kind else {
            return XCTFail("quick skip should be a mapped picker")
        }
        XCTAssertEqual(labels.count, values.count)
        XCTAssertEqual(values, QuickSkipMapping.secondsOptions)
    }

    func testPickerLabelCountsCoverStoredIndexRanges() throws {
        // The audio bitrate pickers must cover BitratePolicy's 0...7 mapping
        for key in [SavedSettings.Key.maxBitrateWifiSetting, .maxBitrate3GSetting] {
            guard case let .picker(labels) = try item(key).ui.kind else {
                return XCTFail("\(key) should be a picker")
            }
            XCTAssertEqual(labels.count, 8)
        }
    }

    // MARK: Type-erased reads and writes

    func testRegistryReadAndWriteUseSwappedTestDefaults() throws {
        let bitrate = try item(.maxBitrateWifiSetting)
        XCTAssertEqual(bitrate.property.anyValue() as? Int, 7, "default value before any write")

        bitrate.property.setAnyValue(3)
        XCTAssertEqual(settings.maxBitrateWifi, 3, "type-erased write must be visible through the typed property")
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.maxBitrateWifiSetting.rawValue), 3,
                       "write must land in the swapped test suite, not .standard")
        XCTAssertNil(UserDefaults.standard.object(forKey: SavedSettings.Key.maxBitrateWifiSetting.rawValue),
                     "nothing may leak into the standard defaults")
    }

    func testMismatchedTypeWriteIsIgnored() throws {
        let bitrate = try item(.maxBitrateWifiSetting)
        bitrate.property.setAnyValue("not an int")
        XCTAssertEqual(settings.maxBitrateWifi, 7, "a wrongly-typed write must be dropped, not crash or corrupt")
    }

    // MARK: onChange side effects

    func testTypeErasedWriteFiresOnChange() throws {
        let forceOffline = try item(.manualOfflineModeSetting)

        var received = [Notification.Name]()
        let names: [Notification.Name] = [Notifications.goOffline, Notifications.goOnline]
        let observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in
                received.append(name)
            }
        }
        defer { observers.forEach { NotificationCenter.default.removeObserver($0) } }

        forceOffline.property.setAnyValue(true)
        XCTAssertEqual(received, [Notifications.goOffline],
                       "onChange must fire on the type-erased registry write path")

        forceOffline.property.setAnyValue(false)
        XCTAssertEqual(received, [Notifications.goOffline, Notifications.goOnline])
    }

    func testTypedWriteFiresOnChange() {
        // Replaces the old didSet coverage: assignment through the typed property posts
        // the observer notification exactly once
        var count = 0
        let observer = NotificationCenter.default.addObserver(forName: Notifications.backupCacheSettingChanged,
                                                              object: nil, queue: nil) { _ in count += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        settings.isBackupCacheEnabled = true
        XCTAssertEqual(count, 1, "typed assignment must post exactly once (no didSet double-post)")
        XCTAssertTrue(settings.isBackupCacheEnabled)
    }
}
