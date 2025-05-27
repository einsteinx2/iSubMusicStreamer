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

// TODO: implement this
// TODO: Refactor this and make sure it works correctly
// TODO: Refactor this so everything happens in a background thread
final class DownloadsManager {
    @LazyInjected private var settings: SavedSettings
    @LazyInjected private var store: Store
    @LazyInjected private var downloadQueue: DownloadQueue

    private var cacheCheckInterval = 60.0
    private var cacheCheckWorkItem: DispatchWorkItem?
    private(set) var cacheSize: Int = 0
    
    var totalSpace: Int { FileSystem.downloadsDirectory.systemTotalSpace ?? 0 }
    var freeSpace: Int { FileSystem.downloadsDirectory.systemAvailableSpace ?? 0 }
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
        checkCache()
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
                    let alert = UIAlertController(title: "IMPORTANT", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
                } else {
                    // Remove the oldest cached songs until freeSpace > minFreeSpace or pop the free space low alert
                    if settings.isAutoDeleteCacheEnabled {
                        removeOldestCachedSongs()
                    } else {
                        let message = "Free space is running low. Delete some cached songs or lower the minimum free space setting."
                        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
                        alert.addOKAction()
                        UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
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
                    let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
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
        DispatchQueue.main.async(after: delay, execute: cacheCheckWorkItem)
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
    private func removeOldestCachedSongs() {
        if settings.cachingType == CachingType.minSpace.rawValue {
            // Remove the oldest songs based on either oldest played or oldest cached until free space is more than minFreeSpace
            while freeSpace < settings.minFreeSpace {
                if let downloadedSong = settings.autoDeleteCacheType == 0 ? store.oldestDownloadedSongByPlayedDate() : store.oldestDownloadedSongByDownloadedDate() {
                    DDLogInfo("[DownloadsManager] removeOldestCachedSongs: min space removing \(downloadedSong)")
                    if !store.delete(downloadedSong: downloadedSong) {
                        DDLogError("[DownloadsManager] removeOldestCachedSongs: Failed to delete \(downloadedSong), so bailing")
                        break
                    }
                }
            }
        } else if settings.cachingType == CachingType.maxSize.rawValue {
            // Remove the oldest songs based on either oldest played or oldest cached until cache size is less than maxCacheSize
            var size = cacheSize
            while size > settings.maxCacheSize {
                if let downloadedSong = settings.autoDeleteCacheType == 0 ? store.oldestDownloadedSongByPlayedDate() : store.oldestDownloadedSongByDownloadedDate(), let song = store.song(downloadedSong: downloadedSong) {
                    if let songSize = URL(fileURLWithPath: song.localPath).fileSize {
                        if store.delete(downloadedSong: downloadedSong) {
                            size -= songSize
                        } else {
                            DDLogError("[DownloadsManager] removeOldestCachedSongs: Failed to delete \(downloadedSong), so bailing")
                            break
                        }
                    } else {
                        DDLogError("[DownloadsManager] removeOldestCachedSongs: Failed to get file size of \(downloadedSong), so bailing")
                        break
                    }
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
        
        guard let enumerator = directoryEnumerator else {
            DDLogError("[DownloadsManager] findCacheSize: Failed to initialize directory enumerator")
            return
        }
        
        var size = 0
        while let url = enumerator.nextObject() as? URL {
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
    
    // TODO: implement this
    // NOTE: The docs say that you can just set it on a single directory and it will apply to all subfolders/files, however various people have tested and found this to be incorrect. So what needs to be done is to use the directory enumerator to enumerate all files and subdirectories in the downloads directory and mark them all. Then any time a new file is created, like in the stream handler, the flag needs to be set according to the user's setting because apparently it won't apply to newly created files, especially in the documents directory. See discussion here: https://stackoverflow.com/a/26683417/299262
    func setAllCachedSongsToBackup() {
        // Set the flag on the downloads directory, no need to set it on all individual files
//        (FileSystem.downloadsDirectory as NSURL).removeSkipBackupAttribute()
    }
    
    func setAllCachedSongsToNotBackup() {
        // Set the flag on the downloads directory, no need to set it on all individual files
//        (FileSystem.downloadsDirectory as NSURL).addSkipBackupAttribute()
    }
}
