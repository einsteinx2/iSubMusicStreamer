//
//  SavedSettings.swift
//  iSub
//
//  Created by Ben Baron on 2/26/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import UIKit
import CocoaLumberjackSwift
import Resolver

enum CachingType: Int {
    case minSpace = 0
    case maxSize = 1
}

final class SavedSettings {
    // The server-session state (current server, redirect, offline mode) lives in
    // ServerSession; SavedSettings owns it strongly and forwards the legacy property
    // names below so existing call sites and tests compile untouched. Deliberate,
    // acyclic shim — new code should inject ServerSession directly.
    let session: ServerSession

    init(session: ServerSession = ServerSession()) {
        self.session = session
    }

    // Network state for the bitrate branches: a weak back-reference attached at the
    // composition root (AppServices) or by tests. When never attached, the wifi
    // branch is used.
    private weak var networkStatus: NetworkStatus?

    func attach(networkStatus: NetworkStatus) {
        self.networkStatus = networkStatus
    }

    // The UserDefaults store backing all settings, including the @UserDefault property
    // wrappers. Tests point this at an isolated suite (see SandboxedTestCase); production
    // always uses .standard. Resolved at access time so a swap affects existing instances.
    static var defaults: UserDefaults = .standard

    private var defaults: UserDefaults { Self.defaults }

    func setup(store: Store) {
        // Disable screen sleep if necessary
        if !self.isScreenSleepEnabled {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        // Run settings migrations
        migrate()

        session.setup(store: store)
    }

    // MARK: Login Settings (forwarded to ServerSession)

    var currentServerId: Int {
        return session.currentServerId
    }

    var currentServer: Server? {
        get { session.currentServer }
        set { session.currentServer = newValue }
    }

    var activeContext: LibraryContext? {
        return session.activeContext
    }

    var activeContextId: Int {
        return session.activeContextId
    }

    var isCombinedContext: Bool {
        return session.isCombinedContext
    }

    // MARK: Other Settings

    var appCrashedOnLastRun: Bool = false

    var isOfflineMode: Bool {
        get { session.isOfflineMode }
        set { session.isOfflineMode = newValue }
    }

    var isInvalidSSLCert: Bool = false
    
    var showPlayerIcon: Bool { !UIDevice.isPad }
    
    // NOTE: Properties with a `ui:` argument automatically appear as rows in the
    // settings UI, grouped by their SettingUI.section and displayed in declaration
    // order within each section (SettingsRegistry enumerates this class via Mirror).
    // Properties without `ui:` are internal-only. Side effects belong in `onChange:`,
    // never in didSet (see the note on UserDefault below).

    // MARK: Internal settings (no UI row)

    @UserDefault(key: .appTerminatedCleanly, defaultValue: true)
    var appTerminatedCleanly: Bool

    @UserDefault(key: .checkUpdatesSetting, defaultValue: true)
    var isUpdateCheckEnabled: Bool

    @UserDefault(key: .isUpdateCheckQuestionAsked, defaultValue: false)
    var isUpdateCheckQuestionAsked: Bool

    @UserDefault(key: .hasSeenCombinedIntro, defaultValue: false)
    var hasSeenCombinedIntro: Bool

    @UserDefault(key: .hasSeenCombinedExitNote, defaultValue: false)
    var hasSeenCombinedExitNote: Bool

    @UserDefault(key: .recover, defaultValue: false)
    var isRecover: Bool

    @UserDefault(key: .seekTime, defaultValue: 0.0)
    var seekTime: Double

    @UserDefault(key: .byteOffset, defaultValue: 0)
    var byteOffset: Int

    @UserDefault(key: .gainMultiplier, defaultValue: 1.0)
    var gainMultiplier: Float

    @UserDefault(key: .isJukeboxEnabled, defaultValue: false)
    var isJukeboxEnabled: Bool

    @UserDefault(key: .isShouldShowEQViewInstructions, defaultValue: true)
    var isShouldShowEQViewInstructions: Bool

    @UserDefault(key: .isEqualizerOn, defaultValue: false)
    var isEqualizerOn: Bool

    @UserDefault(key: .migrateIncrementor, defaultValue: 0)
    var migrateIncrementor: Int

    @UserDefault(key: .isCacheSizeTableFinished, defaultValue: false)
    var isCacheSizeTableFinished: Bool

    // The cache space limits have UI, but through the custom cache-space row (slider +
    // editable size field) rather than a registry-generated row, so no `ui:` here
    @UserDefault(key: .maxCacheSize, defaultValue: 1073741824)
    var maxCacheSize: Int

    @UserDefault(key: .minFreeSpace, defaultValue: 268435456)
    var minFreeSpace: Int

    var currentVisualizerType: VisualizerType {
        get { VisualizerType(rawValue: defaults.integer(forKey: .currentVisualizerType)) ?? .none }
        set { defaults.set(newValue.rawValue, forKey: .currentVisualizerType) }
    }

    // MARK: Network & Streaming settings

    @UserDefault(key: .manualOfflineModeSetting, defaultValue: false,
                 ui: SettingUI(title: "Force Offline Mode",
                               section: .network,
                               kind: .toggle,
                               footer: "Use iSub in offline mode even when a network connection is available.",
                               accessibilityId: AccessibilityId.optionsManualOfflineMode),
                 onChange: { isOn in
                     NotificationCenter.postOnMainThread(name: isOn ? Notifications.goOffline : Notifications.goOnline)
                 })
    var isForceOfflineMode: Bool

    @UserDefault(key: .isDisableUsageOver3G, defaultValue: false,
                 ui: SettingUI(title: "Disable Usage Over Cellular",
                               section: .network,
                               kind: .toggle,
                               footer: "Automatically switch to offline mode when not connected to Wi-Fi.",
                               accessibilityId: AccessibilityId.optionsDisableCellUsage),
                 onChange: { isDisabled in
                     // When on cellular right now, entering/leaving this mode takes
                     // effect immediately
                     guard let settings = Resolver.optional(SavedSettings.self),
                           let networkStatus = Resolver.optional(NetworkStatus.self) else { return }
                     if !settings.isOfflineMode && isDisabled && !networkStatus.isWifi {
                         NotificationCenter.postOnMainThread(name: Notifications.goOffline)
                     } else if settings.isOfflineMode && !isDisabled && !networkStatus.isWifi {
                         NotificationCenter.postOnMainThread(name: Notifications.goOnline)
                     }
                 })
    var isDisableUsageOver3G: Bool

    // NOTE: Basic auth became a per-server flag (Server.isBasicAuthEnabled, edited on
    // the server form); Key.isBasicAuthEnabled remains only for the libraryContexts
    // migration to seed the column from the old global setting

    @UserDefault(key: .maxBitrateWifiSetting, defaultValue: 7,
                 ui: SettingUI(title: "Max Audio Bitrate (Wi-Fi)",
                               section: .network,
                               kind: .picker(labels: ["64", "96", "128", "160", "192", "256", "320", "Unlimited"])))
    var maxBitrateWifi: Int

    @UserDefault(key: .maxBitrate3GSetting, defaultValue: 7,
                 ui: SettingUI(title: "Max Audio Bitrate (Cellular)",
                               section: .network,
                               kind: .picker(labels: ["64", "96", "128", "160", "192", "256", "320", "Unlimited"])))
    var maxBitrate3G: Int

    var currentMaxBitrate: Int {
        BitratePolicy.maxKiloBitrate(isWifi: networkStatus?.isWifi ?? true,
                                     wifiSetting: maxBitrateWifi,
                                     cellSetting: maxBitrate3G)
    }

    @UserDefault(key: .maxVideoBitrateWifi, defaultValue: 5,
                 ui: SettingUI(title: "Max Video Bitrate (Wi-Fi)",
                               section: .network,
                               kind: .picker(labels: ["512", "1024", "1536", "2048", "4096", "8192"])))
    var maxVideoBitrateWifi: Int

    @UserDefault(key: .maxVideoBitrate3G, defaultValue: 5,
                 ui: SettingUI(title: "Max Video Bitrate (Cellular)",
                               section: .network,
                               kind: .picker(labels: ["192", "512", "1024", "1536", "2048", "4096"])))
    var maxVideoBitrate3G: Int

    var currentVideoBitrates: [String]? {
        BitratePolicy.videoBitrates(isWifi: networkStatus?.isWifi ?? true,
                                    wifiSetting: maxVideoBitrateWifi,
                                    cellSetting: maxVideoBitrate3G)
    }

    // MARK: Downloads & Cache settings

    @UserDefault(key: .enableSongCachingSetting, defaultValue: true,
                 ui: SettingUI(title: "Download Songs for Offline Use",
                               section: .downloads,
                               kind: .toggle,
                               footer: "Automatically save streamed songs so they can be played offline.",
                               accessibilityId: AccessibilityId.optionsEnableSongCaching))
    var isSongCachingEnabled: Bool

    @UserDefault(key: .enableNextSongCacheSetting, defaultValue: true,
                 ui: SettingUI(title: "Pre-Download Next Song",
                               section: .downloads,
                               kind: .toggle,
                               accessibilityId: AccessibilityId.optionsEnableNextSongCache,
                               dependsOn: .enableSongCachingSetting))
    var isNextSongCacheEnabled: Bool

    @UserDefault(key: .isManualCachingOnWWANEnabled, defaultValue: false,
                 ui: SettingUI(title: "Manual Downloads Over Cellular",
                               section: .downloads,
                               kind: .toggle,
                               confirmation: SettingUI.Confirmation(title: "Warning",
                                                                    message: "This feature can use a large amount of data. Please be sure to monitor your data plan usage to avoid overage charges from your wireless provider.")),
                 onChange: { _ in
                     // DownloadQueue observes and starts/stops itself when on cellular
                     NotificationCenter.postOnMainThread(name: Notifications.manualCachingOnWWANSettingChanged)
                 })
    var isManualCachingOnWWANEnabled: Bool

    @UserDefault(key: .isBackupCacheEnabled, defaultValue: false,
                 ui: SettingUI(title: "Back Up Downloaded Songs",
                               section: .downloads,
                               kind: .toggle,
                               accessibilityId: AccessibilityId.optionsEnableBackupCache,
                               confirmation: SettingUI.Confirmation(title: "Warning",
                                                                    message: "This setting can take up a large amount of space on your computer or iCloud storage. Are you sure you want to backup your cached songs?")),
                 onChange: { _ in
                     // DownloadsManager observes and applies the backup exclusion flag
                     // to all existing downloads
                     NotificationCenter.postOnMainThread(name: Notifications.backupCacheSettingChanged)
                 })
    var isBackupCacheEnabled: Bool

    @UserDefault(key: .cachingTypeSetting, defaultValue: 0,
                 ui: SettingUI(title: "Cache Limit Type",
                               section: .downloads,
                               kind: .picker(labels: ["Minimum Free Space", "Maximum Cache Size"]),
                               dependsOn: .enableSongCachingSetting))
    var cachingType: Int

    @UserDefault(key: .autoDeleteCacheSetting, defaultValue: false,
                 ui: SettingUI(title: "Auto-Delete Old Downloads",
                               section: .downloads,
                               kind: .toggle,
                               accessibilityId: AccessibilityId.optionsAutoDeleteCache))
    var isAutoDeleteCacheEnabled: Bool

    @UserDefault(key: .autoDeleteCacheTypeSetting, defaultValue: 0,
                 ui: SettingUI(title: "Auto-Delete By",
                               section: .downloads,
                               kind: .picker(labels: ["Oldest Played", "Oldest Downloaded"])))
    var autoDeleteCacheType: Int

    @UserDefault(key: .cacheSongCellColorSetting, defaultValue: 3,
                 ui: SettingUI(title: "Downloaded Song Highlight",
                               section: .downloads,
                               kind: .picker(labels: ["Red", "Yellow", "Green", "Blue", "None"])))
    var downloadedSongCellColorType: Int

    // MARK: Playback settings

    @UserDefault(key: .recoverSetting, defaultValue: 0,
                 ui: SettingUI(title: "Resume on Launch",
                               section: .playback,
                               kind: .picker(labels: ["Playing", "Paused"]),
                               footer: "Whether playback resumes playing or paused when iSub restarts mid-song."))
    var recoverSetting: Int

    @UserDefault(key: .quickSkipNumberOfSeconds, defaultValue: 30,
                 ui: SettingUI(title: "Quick Skip Length",
                               section: .playback,
                               kind: .pickerMapped(labels: ["5 seconds", "15 seconds", "30 seconds", "45 seconds", "1 minute", "2 minutes", "5 minutes", "10 minutes", "20 minutes"],
                                                   values: QuickSkipMapping.secondsOptions),
                               accessibilityId: AccessibilityId.optionsQuickSkipSegment),
                 onChange: { _ in
                     // The player updates its quick skip button labels
                     NotificationCenter.postOnMainThread(name: Notifications.quickSkipSecondsSettingChanged)
                 })
    var quickSkipNumberOfSeconds: Int

    @UserDefault(key: .isLockScreenArtEnabled, defaultValue: true,
                 ui: SettingUI(title: "Album Art on Lock Screen",
                               section: .playback,
                               kind: .toggle,
                               accessibilityId: AccessibilityId.optionsEnableLockScreenArt))
    var isLockScreenArtEnabled: Bool

    @UserDefault(key: .enableScrobblingSetting, defaultValue: false,
                 ui: SettingUI(title: "Last.fm Scrobbling",
                               section: .playback,
                               kind: .toggle,
                               footer: "Scrobbling requires Last.fm credentials configured on your server.",
                               accessibilityId: AccessibilityId.optionsEnableScrobbling))
    var isScrobbleEnabled: Bool

    @UserDefault(key: .scrobblePercentSetting, defaultValue: 0.5,
                 ui: SettingUI(title: "Scrobble At",
                               section: .playback,
                               kind: .percentSlider,
                               footer: "How much of a song must play before it's scrobbled.",
                               dependsOn: .enableScrobblingSetting))
    var scrobblePercent: Float

    // Distinct from isJukeboxEnabled above: this gates whether the jukebox feature is
    // available at all (shows the Player screen button); that one tracks whether the
    // mode is currently active
    @UserDefault(key: .enableJukeboxSetting, defaultValue: false,
                 ui: SettingUI(title: "Enable Jukebox Mode",
                               section: .playback,
                               kind: .toggle,
                               footer: "Show a jukebox button on the Player screen to play music through your server's speakers instead of this device.",
                               accessibilityId: AccessibilityId.optionsEnableJukebox),
                 onChange: { isEnabled in
                     // Disabling the feature must also exit jukebox mode, otherwise
                     // playback silently stays routed to the server with no UI to stop it
                     if !isEnabled, let coordinator = Resolver.optional(PlaybackCoordinator.self) {
                         coordinator.setJukeboxEnabled(false)
                     }
                     NotificationCenter.postOnMainThread(name: Notifications.jukeboxSettingChanged)
                 })
    var isJukeboxFeatureEnabled: Bool

    // MARK: Appearance & Behavior settings

    @UserDefault(key: .isPopupsEnabled, defaultValue: true,
                 ui: SettingUI(title: "Show Alert Popups",
                               section: .appearanceBehavior,
                               kind: .toggle,
                               accessibilityId: AccessibilityId.optionsShowPopups))
    var isPopupsEnabled: Bool

    @UserDefault(key: .isScreenSleepEnabled, defaultValue: true,
                 ui: SettingUI(title: "Allow Screen Sleep",
                               section: .appearanceBehavior,
                               kind: .toggle,
                               accessibilityId: AccessibilityId.optionsAllowScreenSleep),
                 onChange: { isEnabled in
                     UIApplication.shared.isIdleTimerDisabled = !isEnabled
                 })
    var isScreenSleepEnabled: Bool

    @UserDefault(key: .lockRotationSetting, defaultValue: false,
                 ui: SettingUI(title: "Lock Rotation",
                               section: .appearanceBehavior,
                               kind: .toggle,
                               accessibilityId: AccessibilityId.optionsDisableRotation))
    var isRotationLockEnabled: Bool

    @UserDefault(key: .autoReloadArtistsSetting, defaultValue: false,
                 ui: SettingUI(title: "Auto-Reload Library Tab",
                               section: .appearanceBehavior,
                               kind: .toggle,
                               footer: "Refresh the artist list from the server every time the Library tab appears.",
                               accessibilityId: AccessibilityId.optionsAutoReloadArtist))
    var isAutoReloadArtistsEnabled: Bool

    @UserDefault(key: .enableChatSetting, defaultValue: false,
                 ui: SettingUI(title: "Enable Server Chat",
                               section: .appearanceBehavior,
                               kind: .toggle,
                               footer: "Show a Server Chat item on the Library tab's Browse page. Not supported by all servers.",
                               accessibilityId: AccessibilityId.optionsEnableServerChat))
    var isChatEnabled: Bool
    
    func migrate() {
        // In the future, when settings migrations are required, check the migrateIncrementor number and perform the necessary migrations in order based on the incrementor number
    }
    
    // MARK: Document Folder Paths
    
    func createDirectoryIfNotExists(path: String) {
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch {
                DDLogError("[SavedSettings] Failed to create path \(path), \(error)")
            }
        }
    }
    
    var documentsPath: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    }
    
    var applicationSupportPath: String {
        let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        createDirectoryIfNotExists(path: path)
        return path
    }
    
    var databasePath: String {
        let path = (documentsPath as NSString).appendingPathComponent("database")
        createDirectoryIfNotExists(path: path)
        return path
    }
    
    var updatedDatabasePath: String {
        let path = (applicationSupportPath as NSString).appendingPathComponent("database")
        createDirectoryIfNotExists(path: path)
        return path
    }
    
    var cachesPath: String {
        return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
    }
    
    var songCachePath: String {
        let path = (cachesPath as NSString).appendingPathComponent("songCache")
        createDirectoryIfNotExists(path: path)
        return path
    }
    
    var tempCachePath: String {
        let path = (cachesPath as NSString).appendingPathComponent("tempCachePath")
        createDirectoryIfNotExists(path: path)
        return path
    }
    
    // MARK: Root Folders Settings

    // The media-folder selection is stored per server; the Combined Library honors
    // each server's own saved selection, so fan-out loads read by explicit server id
    // (the current-server properties would interpolate -1 while Combined is active)
    func rootFoldersSelectedFolderId(serverId: Int) -> Int {
        defaults.object(forKey: "rootFoldersSelectedFolder\(serverId)") as? Int ?? MediaFolder.allFoldersId
    }

    private var rootFoldersSelectedFolderIdKey: String { "rootFoldersSelectedFolder\(currentServerId)" }
    var rootFoldersSelectedFolderId: Int {
        get { defaults.object(forKey: rootFoldersSelectedFolderIdKey) as? Int ?? MediaFolder.allFoldersId }
        set { defaults.set(newValue, forKey: rootFoldersSelectedFolderIdKey) }
    }

    // MARK: Root Artists Settings

    func rootArtistsSelectedFolderId(serverId: Int) -> Int {
        defaults.object(forKey: "rootArtistsSelectedFolder\(serverId)") as? Int ?? MediaFolder.allFoldersId
    }

    private var rootArtistsSelectedFolderIdKey: String { "rootArtistsSelectedFolder\(currentServerId)" }
    var rootArtistsSelectedFolderId: Int {
        get { defaults.object(forKey: rootArtistsSelectedFolderIdKey) as? Int ?? MediaFolder.allFoldersId }
        set { defaults.set(newValue, forKey: rootArtistsSelectedFolderIdKey) }
    }
    
    // MARK: App Logs
    
    func logAppSettings() {
        let keysToSkip = ["handlerStack", "rootFolders", "password", "servers", "url", "username"]
        let settings = defaults.dictionaryRepresentation().filter { !keysToSkip.contains($0.key) }
        DDLogInfo("App Settings:\n\(settings)")
    }
    
    func zipAllLogFiles() -> String? {
        // Log the app settings, excluding sensitive info
        logAppSettings()
        
        // Flush all logs to disk
        DDLog.flushLog()
        
        let zipFileName = "iSub Logs.zip"
        let zipFilePath = "\(FileManager.default.temporaryDirectory.path)/\(zipFileName)"
        let logsFolder = "\(cachesPath)/\("Logs")"
        
        // Delete the old zip if exists
        if FileManager.default.fileExists(atPath: zipFilePath) {
            do {
                try FileManager.default.removeItem(atPath: zipFilePath)
            } catch {
                DDLogError("[SavedSettings] Failed to delete old zip file at path: \(zipFilePath), error: \(error)")
                return nil
            }
        }
        
        // Zip the logs and move to temp directory since the created zip file is only available inside the callback closure
        var error: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: URL(fileURLWithPath: logsFolder), options: [.forUploading], error: &error) { zipUrl in
            do {
                try FileManager.default.moveItem(atPath: zipUrl.path, toPath: zipFilePath)
            } catch {
                DDLogError("[SavedSettings] Failed to create zip file at path: \(zipFilePath), error: \(error)")
            }
        }
        
        if let _ = error {
            return nil
        }
        return zipFilePath
    }
    
    // MARK: Keys
    
    enum Key: String {
        case migrateIncrementor
        
        // State Saving
        case recover
        case isPlaying
        case isShuffle
        case normalPlaylistIndex
        case shufflePlaylistIndex
        case repeatMode
        case kiloBitrate
        case seekTime
        case byteOffset
        
        case currentServerId
        case activeContextId
        case hasSeenCombinedIntro
        case hasSeenCombinedExitNote
        case appTerminatedCleanly
        
        // Settings
        case areSettingsSetup
        case manualOfflineModeSetting
        case recoverSetting
        case maxBitrateWifiSetting
        case maxBitrate3GSetting
        case enableSongCachingSetting
        case enableNextSongCacheSetting
        case cachingTypeSetting
        case maxCacheSize
        case minFreeSpace
        case autoDeleteCacheSetting
        case autoDeleteCacheTypeSetting
        case cacheSongCellColorSetting
        case lyricsEnabledSetting
        case autoPlayerInfoSetting
        case autoReloadArtistsSetting
        case scrobblePercentSetting
        case enableScrobblingSetting
        case disablePopupsSetting
        case lockRotationSetting
        case isJukeboxEnabled
        case isScreenSleepEnabled
        case isPopupsEnabled
        case checkUpdatesSetting
        case isUpdateCheckQuestionAsked
        case isBasicAuthEnabled
        case gainMultiplier
        case isTapAndHoldEnabled
        case isSwipeEnabled
        case currentVisualizerType
        case quickSkipNumberOfSeconds
        case isShouldShowEQViewInstruction
        case isLockScreenArtEnabled
        case maxVideoBitrateWifi
        case maxVideoBitrate3G
        case isBackupCacheEnabled
        case isManualCachingOnWWANEnabled
        case isShouldShowEQViewInstructions
        case isEqualizerOn
        case isDisableUsageOver3G
        case isCacheSizeTableFinished
        case enableChatSetting
        case enableJukeboxSetting
    }
}

extension UserDefaults {
    func object(forKey defaultName: SavedSettings.Key) -> Any? {
        return object(forKey: defaultName.rawValue)
    }
    
    func bool(forKey defaultName: SavedSettings.Key) -> Bool {
        return bool(forKey: defaultName.rawValue)
    }
    
    func integer(forKey defaultName: SavedSettings.Key) -> Int {
        return integer(forKey: defaultName.rawValue)
    }
    
    func set(_ value: Any?, forKey defaultName: SavedSettings.Key) {
        set(value, forKey: defaultName.rawValue)
    }
}

@propertyWrapper
struct UserDefault<Value> {
    let key: SavedSettings.Key
    let defaultValue: Value
    // When nil (the default), the shared SavedSettings.defaults store is used, resolved
    // at access time so tests can swap in an isolated suite
    var container: UserDefaults?
    // Display metadata for the data-driven settings UI. nil (the default) means the
    // setting is internal-only and gets no row (see SettingsRegistry).
    var ui: SettingUI? = nil
    // Change side effects. IMPORTANT: never use didSet on a @UserDefault property —
    // the settings UI writes through a type-erased copy of this wrapper (via
    // SettingsRegistry), which bypasses the enclosing property's observers. onChange
    // fires on every write path. Closures here can't capture self; resolve any
    // services they need via Resolver at fire time.
    var onChange: ((Value) -> Void)? = nil

    private var resolvedContainer: UserDefaults { container ?? SavedSettings.defaults }

    var wrappedValue: Value {
        get {
            return resolvedContainer.object(forKey: key) as? Value ?? defaultValue
        }
        nonmutating set {
            resolvedContainer.set(newValue, forKey: key)
            resolvedContainer.synchronize()
            onChange?(newValue)
        }
    }
}

// Type-erased access to a UserDefault wrapper, used by SettingsRegistry to enumerate
// and bind settings without knowing their value types
protocol AnySettingProperty {
    var settingKey: SavedSettings.Key { get }
    var settingUI: SettingUI? { get }
    func anyValue() -> Any
    func setAnyValue(_ value: Any)
}

extension UserDefault: AnySettingProperty {
    var settingKey: SavedSettings.Key { key }
    var settingUI: SettingUI? { ui }

    func anyValue() -> Any { wrappedValue }

    func setAnyValue(_ value: Any) {
        guard let value = value as? Value else {
            DDLogError("[UserDefault] Ignoring write of \(type(of: value)) value to \(key) which expects \(Value.self)")
            return
        }
        wrappedValue = value
    }
}
