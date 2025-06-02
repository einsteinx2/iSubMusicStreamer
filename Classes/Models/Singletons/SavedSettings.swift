//
//  SavedSettings.swift
//  iSub
//
//  Created by Ben Baron on 2/26/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

enum CachingType: Int {
    case minSpace = 0
    case maxSize = 1
}

final class SavedSettings {
    @LazyInjected private var player: BassPlayer
    @LazyInjected private var playQueue: PlayQueue
    @LazyInjected private var downloadsManager: DownloadsManager
    @LazyInjected private var downloadQueue: DownloadQueue
    @LazyInjected private var store: Store
    
    private let defaults = UserDefaults.standard
    
    func setup() {
        // Disable screen sleep if necessary
        if !self.isScreenSleepEnabled {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        // Run settings migrations
        migrate()
        
        
        if let id = defaults.object(forKey: .currentServerId) as? Int {
            // Load the new server object
            currentServer = store.server(id: id)
        }
        
        // Start saving state
        setupSaveState()
    }
    
    // MARK: Login Settings
    
    var currentServerId: Int {
        return currentServer?.id ?? -1
    }
    
    var currentServer: Server? {
        didSet {
            currentServerRedirectUrlString = nil
            defaults.set(currentServer?.id, forKey: .currentServerId)
            defaults.synchronize()
        }
    }
    
    var currentServerRedirectUrlString: String?
    
    // MARK: Other Settings
    
    var appCrashedOnLastRun: Bool = false
    
    var isOfflineMode: Bool = false
    
    var isInvalidSSLCert: Bool = false
    
    var showPlayerIcon: Bool { !UIDevice.isPad }
    
    @UserDefault(key: .appTerminatedCleanly, defaultValue: true)
    var appTerminatedCleanly: Bool
    
    @UserDefault(key: .manualOfflineModeSetting, defaultValue: false)
    var isForceOfflineMode: Bool
    
    @UserDefault(key: .recoverSetting, defaultValue: 0)
    var recoverSetting: Int
    
    @UserDefault(key: .maxBitrateWifiSetting, defaultValue: 7)
    var maxBitrateWifi: Int
    
    @UserDefault(key: .maxBitrate3GSetting, defaultValue: 7)
    var maxBitrate3G: Int
    
    var currentMaxBitrate: Int {
        switch SceneDelegate.shared.isWifi ? maxBitrateWifi : maxBitrate3G {
            case 0: return 64
            case 1: return 96
            case 2: return 128
            case 3: return 160
            case 4: return 192
            case 5: return 256
            case 6: return 320
            default: return 0
        }
    }
    
    @UserDefault(key: .maxVideoBitrateWifi, defaultValue: 5)
    var maxVideoBitrateWifi: Int
    
    @UserDefault(key: .maxVideoBitrate3G, defaultValue: 5)
    var maxVideoBitrate3G: Int
    
    var currentVideoBitrates: [String]? {
        if SceneDelegate.shared.isWifi {
            switch maxVideoBitrateWifi {
            case 0: return ["512"]
            case 1: return ["1024", "512"]
            case 2: return ["1536", "1024", "512"]
            case 3: return ["2048", "1536", "1024", "512"]
            case 4: return ["4096", "2048", "1536", "1024", "512"]
            case 5: return ["8192@1920x1080", "4096", "2048", "1536", "1024", "512"]
            default: return nil
            }
        } else {
            switch (maxVideoBitrate3G) {
            case 0: return ["192"]
            case 1: return ["512", "192"]
            case 2: return ["1024", "512", "192"]
            case 3: return ["1536", "1024", "512", "192"]
            case 4: return ["2048", "1536", "1024", "512", "192"]
            case 5: return ["4096", "2048", "1536", "1024", "512", "192"]
            default: return nil
            }
        }
    }
    
    @UserDefault(key: .enableSongCachingSetting, defaultValue: true)
    var isSongCachingEnabled: Bool
    
    @UserDefault(key: .enableNextSongCacheSetting, defaultValue: true)
    var isNextSongCacheEnabled: Bool
    
    @UserDefault(key: .isBackupCacheEnabled, defaultValue: false)
    var isBackupCacheEnabled: Bool {
        didSet {
            if (isBackupCacheEnabled) {
                //Set all cached songs to removeSkipBackup
                downloadsManager.setAllCachedSongsToBackup()
            } else {
                // Set all cached songs to removeSkipBackup
                downloadsManager.setAllCachedSongsToNotBackup()
            }
        }
    }
    
    @UserDefault(key: .isManualCachingOnWWANEnabled, defaultValue: false)
    var isManualCachingOnWWANEnabled: Bool {
        didSet {
            if !SceneDelegate.shared.isWifi {
                isManualCachingOnWWANEnabled ? downloadQueue.start() : downloadQueue.stop()
            }
        }
    }
    
    @UserDefault(key: .cachingTypeSetting, defaultValue: 0)
    var cachingType: Int
    
    @UserDefault(key: .maxCacheSize, defaultValue: 1073741824)
    var maxCacheSize: Int
    
    @UserDefault(key: .minFreeSpace, defaultValue: 268435456)
    var minFreeSpace: Int
    
    @UserDefault(key: .autoDeleteCacheSetting, defaultValue: false)
    var isAutoDeleteCacheEnabled: Bool
    
    @UserDefault(key: .autoDeleteCacheTypeSetting, defaultValue: 0)
    var autoDeleteCacheType: Int
    
    @UserDefault(key: .cacheSongCellColorSetting, defaultValue: 3)
    var downloadedSongCellColorType: Int
    
    @UserDefault(key: .autoReloadArtistsSetting, defaultValue: false)
    var isAutoReloadArtistsEnabled: Bool
    
    @UserDefault(key: .scrobblePercentSetting, defaultValue: 0.5)
    var scrobblePercent: Float
    
    @UserDefault(key: .enableScrobblingSetting, defaultValue: false)
    var isScrobbleEnabled: Bool
    
    @UserDefault(key: .lockRotationSetting, defaultValue: false)
    var isRotationLockEnabled: Bool
    
    @UserDefault(key: .isJukeboxEnabled, defaultValue: false)
    var isJukeboxEnabled: Bool
    
    @UserDefault(key: .isScreenSleepEnabled, defaultValue: true)
    var isScreenSleepEnabled: Bool
    
    @UserDefault(key: .isPopupsEnabled, defaultValue: true)
    var isPopupsEnabled: Bool
    
    @UserDefault(key: .checkUpdatesSetting, defaultValue: true)
    var isUpdateCheckEnabled: Bool
    
    @UserDefault(key: .isUpdateCheckQuestionAsked, defaultValue: false)
    var isUpdateCheckQuestionAsked: Bool
    
    @UserDefault(key: .recover, defaultValue: false)
    var isRecover: Bool
    
    @UserDefault(key: .seekTime, defaultValue: 0.0)
    var seekTime: Double
    
    @UserDefault(key: .byteOffset, defaultValue: 0)
    var byteOffset: Int
    
    @UserDefault(key: .isBasicAuthEnabled, defaultValue: false)
    var isBasicAuthEnabled: Bool
    
    @UserDefault(key: .gainMultiplier, defaultValue: 1.0)
    var gainMultiplier: Float
    
    var currentVisualizerType: VisualizerType {
        get { VisualizerType(rawValue: defaults.integer(forKey: .currentVisualizerType)) ?? .none }
        set { defaults.set(newValue.rawValue, forKey: .currentVisualizerType) }
    }
    
    @UserDefault(key: .quickSkipNumberOfSeconds, defaultValue: 30)
    var quickSkipNumberOfSeconds: Int
    
    @UserDefault(key: .isShouldShowEQViewInstructions, defaultValue: true)
    var isShouldShowEQViewInstructions: Bool
    
    @UserDefault(key: .isLockScreenArtEnabled, defaultValue: true)
    var isLockScreenArtEnabled: Bool
    
    @UserDefault(key: .isEqualizerOn, defaultValue: false)
    var isEqualizerOn: Bool
    
    @UserDefault(key: .isDisableUsageOver3G, defaultValue: false)
    var isDisableUsageOver3G: Bool
    
    @UserDefault(key: .migrateIncrementor, defaultValue: 0)
    var migrateIncrementor: Int
    
    @UserDefault(key: .isCacheSizeTableFinished, defaultValue: false)
    var isCacheSizeTableFinished: Bool
    
    func migrate() {
        // In the future, when settings migrations are required, check the migrateIncrementor number and perform the necessary migrations in order based on the incrementor number
    }
    
    // MARK: State Saving
    
    // TODO: Refactor all this state saving stuff into another class using Codable etc
    private struct State {
        var isPlaying: Bool = false
        var isShuffle: Bool = false
        var normalPlaylistIndex: Int = 0
        var shufflePlaylistIndex: Int = 0
        var repeatMode: RepeatMode = .none
        var kiloBitrate: Int = 0
        var byteOffset: Int = 0
        var secondsOffset: Double = 0
        var isRecover: Bool = false
        var recoverSetting: Int = 0
        var currentServer: Server?
    }
    
    private var state = State()
    
    func setupSaveState() {
        // Load saved state first
        loadState()
        
        // Start the timer
        Timer.scheduledTimer(withTimeInterval: 3.3, repeats: true) { _ in
            self.saveState()
        }
    }
    
    func loadState() {
        state.isPlaying = isJukeboxEnabled ? false : defaults.bool(forKey: .isPlaying)
        
        state.isShuffle = defaults.bool(forKey: .isShuffle)
        playQueue.isShuffle = state.isShuffle
        
        state.normalPlaylistIndex = defaults.integer(forKey: .normalPlaylistIndex)
        playQueue.normalIndex = state.normalPlaylistIndex;
        
        state.shufflePlaylistIndex = defaults.integer(forKey: .shufflePlaylistIndex)
        playQueue.shuffleIndex = state.shufflePlaylistIndex
        
        state.repeatMode = RepeatMode(rawValue: defaults.integer(forKey: .repeatMode)) ?? .none
        playQueue.repeatMode = state.repeatMode;
        
        state.kiloBitrate = defaults.integer(forKey: .kiloBitrate)
        state.byteOffset = byteOffset
        state.secondsOffset = seekTime
        state.isRecover = isRecover
        state.recoverSetting = recoverSetting
        
        player.startByteOffset = state.byteOffset
        player.startSecondsOffset = state.secondsOffset
    }
    
    func saveState() {
        var isDefaultsDirty = false
        
        if player.isPlaying != state.isPlaying {
            if isJukeboxEnabled {
                state.isPlaying = false
            } else {
                state.isPlaying = player.isPlaying
            }
            
            defaults.set(state.isPlaying, forKey: .isPlaying)
            isDefaultsDirty = true
        }
        
        if playQueue.isShuffle != state.isShuffle {
            state.isShuffle = playQueue.isShuffle
            defaults.set(state.isShuffle, forKey: .isShuffle)
            isDefaultsDirty = true
        }
        
        if playQueue.normalIndex != state.normalPlaylistIndex {
            state.normalPlaylistIndex = playQueue.normalIndex
            defaults.set(state.normalPlaylistIndex, forKey: .normalPlaylistIndex)
            isDefaultsDirty = true
        }
        
        if playQueue.shuffleIndex != state.shufflePlaylistIndex {
            state.shufflePlaylistIndex = playQueue.shuffleIndex
            defaults.set(state.shufflePlaylistIndex, forKey: .shufflePlaylistIndex)
            isDefaultsDirty = true
        }
        
        if playQueue.repeatMode != state.repeatMode {
            state.repeatMode = playQueue.repeatMode
            defaults.set(state.repeatMode, forKey: .repeatMode)
            isDefaultsDirty = true
        }
        
        if player.kiloBitrate != state.kiloBitrate && player.kiloBitrate >= 0 {
            state.kiloBitrate = player.kiloBitrate;
            defaults.set(state.kiloBitrate, forKey: .kiloBitrate)
            isDefaultsDirty = true
        }
        
        if state.secondsOffset != player.progress {
            state.secondsOffset = player.progress
            defaults.set(state.secondsOffset, forKey: .seekTime)
            isDefaultsDirty = true
        }
        
        if state.byteOffset != player.currentByteOffset {
            state.byteOffset = player.currentByteOffset
            defaults.set(state.byteOffset, forKey: .byteOffset)
            isDefaultsDirty = true
        }
                
        var newIsRecover = false
        if state.isPlaying {
            newIsRecover = (state.recoverSetting == 0)
        } else {
            newIsRecover = false
        }
        
        if state.isRecover != newIsRecover {
            state.isRecover = newIsRecover
            defaults.set(state.isRecover, forKey: .recover)
            isDefaultsDirty = true
        }
        
        // Only synchronize to disk if necessary
        if isDefaultsDirty {
            defaults.synchronize()
        }
    }
    
    // MARK: Document Folder Paths
    
    func createDirectoryIfNotExists(path: String) {
        if FileManager.default.fileExists(atPath:path) {
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
    
    private var rootFoldersSelectedFolderIdKey: String { "rootFoldersSelectedFolder\(currentServerId)" }
    var rootFoldersSelectedFolderId: Int {
        get { defaults.object(forKey: rootFoldersSelectedFolderIdKey) as? Int ?? MediaFolder.allFoldersId }
        set { defaults.set(newValue, forKey: rootFoldersSelectedFolderIdKey) }
    }
   
    // MARK: Root Artists Settings
    
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
    var container: UserDefaults = .standard

    var wrappedValue: Value {
        get {
            return container.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
            container.synchronize()
        }
    }
}
