//
//  Notifications.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct NotificationKeys {
    static let serverId = "serverId"
}

class Notifications: NSObject {
    @objc static let songPlaybackStarted = Notification.Name("iSub.songPlaybackStarted")
    @objc static let songPlaybackPaused = Notification.Name("iSub.songPlaybackPaused")
    @objc static let songPlaybackEnded = Notification.Name("iSub.songPlaybackEnded")
    static let songPlaybackFailed = Notification.Name("iSub.songPlaybackFailed")
    
    static let albumArtLargeDownloaded = Notification.Name("iSub.albumArtLargeDownloaded")
    
    static let switchServer = Notification.Name("iSub.switchServer")
    static let reloadServerList = Notification.Name("iSub.reloadServerList")
    static let showBackButton = Notification.Name("iSub.showBackButton")
    
    static let serverSwitched = Notification.Name("iSub.serverSwitched")
    static let checkServer = Notification.Name("iSub.checkServer")
    static let serverCheckPassed = Notification.Name("iSub.serverCheckPassed")
    static let serverCheckFailed = Notification.Name("iSub.serverCheckFailed")
    
    static let lyricsDownloaded = Notification.Name("iSub.lyricsDownloaded")
    static let lyricsFailed = Notification.Name("iSub.lyricsFailed")
    
    static let repeatModeChanged = Notification.Name("iSub.repeatModeChanged")
    
    @objc static let bassEffectPresetLoaded = Notification.Name("iSub.bassEffectPresetLoaded")
    
    @objc static let currentPlaylistOrderChanged = Notification.Name("iSub.currentPlaylistOrderChanged")
    @objc static let currentPlaylistShuffleToggled = Notification.Name("iSub.currentPlaylistShuffleToggled")
    @objc static let currentPlaylistIndexChanged = Notification.Name("iSub.currentPlaylistIndexChanged")
    static let currentPlaylistSongsQueued = Notification.Name("iSub.currentPlaylistSongsQueued")

    static let songCachingEnabled = Notification.Name("iSub.songCachingEnabled")
    static let songCachingDisabled = Notification.Name("iSub.songCachingDisabled")

    static let showPlayer = Notification.Name("iSub.showPlayer")

    static let cacheQueueStarted = Notification.Name("iSub.cacheQueueStarted")
    static let cacheQueueStopped = Notification.Name("iSub.cacheQueueStopped")
    static let cacheQueueSongDownloaded = Notification.Name("iSub.cacheQueueSongDownloaded")
    static let cacheQueueSongFailed = Notification.Name("iSub.cacheQueueSongFailed")
    static let streamHandlerSongDownloaded = Notification.Name("iSub.streamHandlerSongDownloaded")
    static let streamHandlerSongFailed = Notification.Name("iSub.streamHandlerSongFailed")

    static let cacheSizeChecked = Notification.Name("iSub.cacheSizeChecked")

    static let willEnterOfflineMode = Notification.Name("iSub.willEnterOfflineMode")
    static let willEnterOnlineMode = Notification.Name("iSub.willEnterOnlineMode")

    static let bassInitialized = Notification.Name("iSub.bassInitialized")
    @objc static let bassFreed = Notification.Name("iSub.bassFreed")

    static let jukeboxEnabled = Notification.Name("iSub.jukeboxEnabled")
    static let jukeboxDisabled = Notification.Name("iSub.jukeboxDisabled")

    static let jukeboxSongInfo = Notification.Name("iSub.jukeboxSongInfo")

    static let playVideo = Notification.Name("iSub.playVideo")
    static let removeVideoPlayer = Notification.Name("iSub.removeVideoPlayer")

    static let showDeleteButton = Notification.Name("iSub.showDeleteButton")
    static let hideDeleteButton = Notification.Name("iSub.hideDeleteButton")

    static let cachedSongDeleted = Notification.Name("iSub.cachedSongDeleted")

    @objc static let quickSkipSecondsSettingChanged = Notification.Name("iSub.quickSkipSecondsSettingChanged")
}
