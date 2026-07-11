//
//  DownloadsManager.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

// TODO: Refactor this and make sure it works correctly
// NOTE: not final so tests can subclass to stub freeSpace and observe alerts
class DownloadsManager {
    private let settings: SavedSettings
    private let store: Store
    @LazyInjected private var downloadQueue: DownloadQueueing

    private var cacheCheckInterval = 60.0
    private var cacheCheckWorkItem: DispatchWorkItem?
    private(set) var cacheSize: Int = 0

    // The periodic cache check walks the entire downloads directory and deletes files,
    // so it runs on this background queue and only hops to the main thread for alerts
    private let cacheCheckQueue = DispatchQueue(label: "com.isubapp.DownloadsManagerCacheCheckQueue", qos: .utility)
    
    var totalSpace: Int { FileSystem.downloadsDirectory.systemTotalSpace ?? 0 }
    var freeSpace: Int { FileSystem.downloadsDirectory.systemAvailableSpace ?? 0 }

    // Only read by downloadProgress(song:), which needs the live playback bitrate;
    // attached weakly at the composition root
    private weak var player: PlayerControlling?
    private weak var playQueue: PlayQueue?

    init(settings: SavedSettings, store: Store) {
        self.settings = settings
        self.store = store
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(backupCacheSettingChanged), name: Notifications.backupCacheSettingChanged)
    }

    func attach(player: PlayerControlling, playQueue: PlayQueue) {
        self.player = player
        self.playQueue = playQueue
    }

    // Moved from Song so a value model can't reach into the audio engine
    func downloadProgress(song: Song) -> Float {
        var downloadProgress: Float = 0

        if song.isFullyCached {
            downloadProgress = 1
        } else {
            var bitrate = song.estimatedKiloBitrate
            if let player, player.isPlaying, let currentStream = player.currentStream {
                bitrate = Bass.estimateKiloBitrate(bassStream: currentStream)
            }

            if song.transcodedSuffix != nil {
                // This is a transcode, so we'll want to use the actual bitrate if possible
                if let player, let currentSong = playQueue?.currentSong, currentSong == song {
                    // This is the current playing song, so see if BASS has an actual bitrate for it
                    if player.kiloBitrate > 0 {
                        // Bass has a non-zero bitrate, so use that for the calculation
                        bitrate = player.kiloBitrate
                    }
                }
            }
            let totalSize = bytesForSeconds(seconds: Double(song.duration), kiloBitrate: bitrate)
            downloadProgress = Float(song.localFileSize) / Float(totalSize)
        }

        // Keep within bounds
        downloadProgress = downloadProgress < 0 ? 0 : downloadProgress
        downloadProgress = downloadProgress > 1 ? 1 : downloadProgress

        // The song hasn't started downloading yet
        return downloadProgress
    }

    @objc private func backupCacheSettingChanged() {
        if settings.isBackupCacheEnabled {
            setAllCachedSongsToBackup()
        } else {
            setAllCachedSongsToNotBackup()
        }
    }

    // Shown when the download queue halts because the device is out of space
    func showNoFreeSpaceMessage() {
        guard settings.isPopupsEnabled else { return }
        let message = "Your device has run out of space and cannot download any more music. Please free some space and try again."
        presentAlert(title: "Notice", message: message)
    }
    var numberOfCachedSongs: Int { store.downloadedSongsCount() ?? 0 }
    
    func setup() {
        // TODO: implement this
        // TODO: Move old cached songs to new location
        
        // Clear the temp cache
        clearTempCache()
        
        // Start checking the cache size after 2 seconds to allow the app to load quicker
        checkCache(after: 2)
    }
    
    func clearTempCache() {
        // Clear the temp cache directory
        do {
            try FileManager.default.removeItem(at: FileSystem.tempDownloadsDirectory)
            try FileManager.default.createDirectory(at: FileSystem.tempDownloadsDirectory, withIntermediateDirectories: true, attributes: .none)
        } catch {
            DDLogError("[DownloadsManager] Failed to recreate temp downloads directory, \(error)")
        }
    }
    
    func startCacheCheckTimer(interval: Double) {
        cacheCheckInterval = interval
        stopCacheCheckTimer()
        checkCache(after: 0)
    }
    
    func stopCacheCheckTimer() {
        cacheCheckWorkItem?.cancel()
        cacheCheckWorkItem = nil
    }
    
    private func checkCache() {
        stopCacheCheckTimer()
        
        findCacheSize()
        
        // Adjust the cache size if needed
        adjustCacheSize()
        
        if settings.cachingType == CachingType.minSpace.rawValue && settings.isSongCachingEnabled {
            // Check to see if the free space left is lower than the setting
            if freeSpace < settings.minFreeSpace {
                // Check to see if the cache size + free space is still less than minFreeSpace
                if cacheSize + freeSpace < settings.minFreeSpace {
                    // Looks like even removing all of the cache will not be enough so turn off caching
                    settings.isSongCachingEnabled = false

                    let message = "Free space is running low, but even deleting the entire cache will not bring the free space up higher than your minimum setting. Automatic song caching has been turned off.\n\nYou can re-enable it in the Settings menu (tap the gear, tap Settings at the top)"
                    presentAlert(title: "IMPORTANT", message: message)
                } else {
                    // Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
                    if settings.isAutoDeleteCacheEnabled {
                        removeOldestCachedSongs()
                    } else {
                        let message = "Free space is running low. Delete some cached songs or lower the minimum free space setting."
                        presentAlert(title: "Notice", message: message)
                    }
                }
            }
        } else if settings.cachingType == CachingType.maxSize.rawValue && settings.isSongCachingEnabled {
            // Check to see if the cache size is higher than the max
            if cacheSize > settings.maxCacheSize {
                if settings.isAutoDeleteCacheEnabled {
                    removeOldestCachedSongs()
                } else {
                    settings.isSongCachingEnabled = false
                    let message = "The song cache is full. Automatic song caching has been disabled.\n\nYou can re-enable it in the Settings menu (tap the gear on the Home tab, tap Settings at the top)"
                    presentAlert(title: "Notice", message: message)
                }
            }
        }

        checkCache(after: cacheCheckInterval)
    }

    private func checkCache(after delay: Double) {
        let cacheCheckWorkItem = DispatchWorkItem { [weak self] in
            self?.checkCache()
        }
        self.cacheCheckWorkItem = cacheCheckWorkItem
        cacheCheckQueue.async(after: delay, execute: cacheCheckWorkItem)
    }

    private func presentAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addOKAction()
            UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func adjustCacheSize() {
        // Only adjust if the user is using max cache size as option
        if settings.cachingType == CachingType.maxSize.rawValue {
            let possibleSize = freeSpace + cacheSize
            let maxCacheSize = settings.maxCacheSize
            DDLogInfo("[DownloadsManager] adjustCacheSize:  possibleSize = \(possibleSize)  maxCacheSize = \(maxCacheSize)")
            if possibleSize < maxCacheSize {
                // Set the max cache size to 25MB less than the free space
                settings.maxCacheSize = possibleSize - (25 * 1024 * 1024)
            }
        }
    }
    
    // TODO: Refactor this to improve the logic
    func removeOldestCachedSongs() {
        if settings.cachingType == CachingType.minSpace.rawValue {
            // Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
            while freeSpace < settings.minFreeSpace {
                guard let downloadedSong = settings.autoDeleteCacheType == 0 ? store.oldestDownloadedSongByPlayedDate() : store.oldestDownloadedSongByDownloadedDate() else {
                    DDLogWarn("[DownloadsManager] removeOldestCachedSongs: No more songs can be deleted, so bailing")
                    break
                }
                DDLogInfo("[DownloadsManager] removeOldestCachedSongs: min space removing \(downloadedSong)")
                if !store.delete(downloadedSong: downloadedSong) {
                    DDLogError("[DownloadsManager] removeOldestCachedSongs: Failed to delete \(downloadedSong), so bailing")
                    break
                }
            }
        } else if settings.cachingType == CachingType.maxSize.rawValue {
            // Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
            var size = cacheSize
            while size > settings.maxCacheSize {
                guard let downloadedSong = settings.autoDeleteCacheType == 0 ? store.oldestDownloadedSongByPlayedDate() : store.oldestDownloadedSongByDownloadedDate() else {
                    DDLogWarn("[DownloadsManager] removeOldestCachedSongs: No more songs can be deleted, so bailing")
                    break
                }
                guard let song = store.song(downloadedSong: downloadedSong) else {
                    DDLogError("[DownloadsManager] removeOldestCachedSongs: Failed to find the song for \(downloadedSong), so bailing")
                    break
                }
                guard let songSize = URL(fileURLWithPath: song.localPath).fileSize else {
                    DDLogError("[DownloadsManager] removeOldestCachedSongs: Failed to get file size of \(downloadedSong), so bailing")
                    break
                }
                if store.delete(downloadedSong: downloadedSong) {
                    size -= songSize
                } else {
                    DDLogError("[DownloadsManager] removeOldestCachedSongs: Failed to delete \(downloadedSong), so bailing")
                    break
                }
            }

            findCacheSize()

            if !downloadQueue.isDownloading {
                downloadQueue.start()
            }
        }
    }
    
    func findCacheSize() {
        let directoryEnumerator = FileManager.default.enumerator(at: FileSystem.downloadsDirectory,
                                                                 includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey],
                                                                 options: .skipsHiddenFiles) { (url, error) -> Bool in
            DDLogError("[DownloadsManager] findCacheSize: Error enumerating file at url \(url), \(error)")
            return true
        }
        
        guard let directoryEnumerator else {
            DDLogError("[DownloadsManager] findCacheSize: Failed to initialize directory enumerator")
            return
        }
        
        var size = 0
        while let url = directoryEnumerator.nextObject() as? URL {
            do {
                if let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, !isDirectory {
                    if let songSize = try url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize {
                        size += songSize
                    }
                }
            } catch {
                DDLogError("[DownloadsManager] findCacheSize: failed to read resource value of \(url), \(error)")
            }
        }
        
        DDLogVerbose("[DownloadsManager] Total cache size was found to be \(size)")
        cacheSize = size
        
        NotificationCenter.postOnMainThread(name: Notifications.downloadsSizeChecked)
    }
    
    // NOTE: The isExcludedFromBackup flag must be set on every file individually: despite
    // the docs, it does not reliably propagate from a directory to its contents, and it
    // never applies to files created later (see https://stackoverflow.com/a/26683417/299262).
    // StreamHandler applies the current setting to each newly created download file; these
    // walk the existing downloads when the setting changes.
    func setAllCachedSongsToBackup() {
        cacheCheckQueue.async {
            self.applyBackupExclusionToAllDownloads(isExcludedFromBackup: false)
        }
    }

    func setAllCachedSongsToNotBackup() {
        cacheCheckQueue.async {
            self.applyBackupExclusionToAllDownloads(isExcludedFromBackup: true)
        }
    }

    // Synchronous worker (internal so tests can call it deterministically)
    func applyBackupExclusionToAllDownloads(isExcludedFromBackup: Bool) {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = isExcludedFromBackup

        // Mark the directory itself too so newly created intermediate state is covered
        var directoryURL = FileSystem.downloadsDirectory
        do {
            try directoryURL.setResourceValues(resourceValues)
        } catch {
            DDLogError("[DownloadsManager] Failed to set isExcludedFromBackup=\(isExcludedFromBackup) on \(directoryURL), \(error)")
        }

        guard let directoryEnumerator = FileManager.default.enumerator(at: FileSystem.downloadsDirectory, includingPropertiesForKeys: nil) else {
            DDLogError("[DownloadsManager] applyBackupExclusionToAllDownloads: Failed to initialize directory enumerator")
            return
        }
        while var url = directoryEnumerator.nextObject() as? URL {
            do {
                try url.setResourceValues(resourceValues)
            } catch {
                DDLogError("[DownloadsManager] Failed to set isExcludedFromBackup=\(isExcludedFromBackup) on \(url), \(error)")
            }
        }
    }
}
