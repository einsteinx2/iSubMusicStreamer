//
//  Notifications.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc class NotificationKeys: NSObject {
    @objc static let serverId = "serverId"
}

@objc class Notifications: NSObject {
    @objc static let songPlaybackStarted = Notification.Name("iSub.songPlaybackStarted")
    @objc static let songPlaybackPaused = Notification.Name("iSub.songPlaybackPaused")
    @objc static let songPlaybackEnded = Notification.Name("iSub.songPlaybackEnded")
    @objc static let songPlaybackFailed = Notification.Name("iSub.songPlaybackFailed")
    
    @objc static let albumArtLargeDownloaded = Notification.Name("iSub.albumArtLargeDownloaded")
    
    @objc static let switchServer = Notification.Name("iSub.switchServer")
    @objc static let reloadServerList = Notification.Name("iSub.reloadServerList")
    @objc static let showSaveButton = Notification.Name("iSub.showSaveButton")
    
    @objc static let serverSwitched = Notification.Name("iSub.serverSwitched")
    @objc static let checkServer = Notification.Name("iSub.checkServer")
    @objc static let serverCheckPassed = Notification.Name("iSub.serverCheckPassed")
    @objc static let serverCheckFailed = Notification.Name("iSub.serverCheckFailed")
    
    @objc static let lyricsDownloaded = Notification.Name("iSub.lyricsDownloaded")
    @objc static let lyricsFailed = Notification.Name("iSub.lyricsFailed")
    
    @objc static let repeatModeChanged = Notification.Name("iSub.repeatModeChanged")
    
    @objc static let bassEffectPresetLoaded = Notification.Name("iSub.bassEffectPresetLoaded")
    
    @objc static let currentPlaylistOrderChanged = Notification.Name("iSub.currentPlaylistOrderChanged")
    @objc static let currentPlaylistShuffleToggled = Notification.Name("iSub.currentPlaylistShuffleToggled")
    @objc static let currentPlaylistIndexChanged = Notification.Name("iSub.currentPlaylistIndexChanged")
    @objc static let currentPlaylistSongsQueued = Notification.Name("iSub.currentPlaylistSongsQueued")

    @objc static let songCachingEnabled = Notification.Name("iSub.songCachingEnabled")
    @objc static let songCachingDisabled = Notification.Name("iSub.songCachingDisabled")

    @objc static let showPlayer = Notification.Name("iSub.showPlayer")

    @objc static let cacheQueueStarted = Notification.Name("iSub.cacheQueueStarted")
    @objc static let cacheQueueStopped = Notification.Name("iSub.cacheQueueStopped")
    @objc static let cacheQueueSongDownloaded = Notification.Name("iSub.cacheQueueSongDownloaded")
    @objc static let cacheQueueSongFailed = Notification.Name("iSub.cacheQueueSongFailed")
    @objc static let streamHandlerSongDownloaded = Notification.Name("iSub.streamHandlerSongDownloaded")
    @objc static let streamHandlerSongFailed = Notification.Name("iSub.streamHandlerSongFailed")

    @objc static let cacheSizeChecked = Notification.Name("iSub.cacheSizeChecked")

    @objc static let willEnterOfflineMode = Notification.Name("iSub.willEnterOfflineMode")
    @objc static let willEnterOnlineMode = Notification.Name("iSub.willEnterOnlineMode")

    @objc static let bassInitialized = Notification.Name("iSub.bassInitialized")
    @objc static let bassFreed = Notification.Name("iSub.bassFreed")

    @objc static let jukeboxEnabled = Notification.Name("iSub.jukeboxEnabled")
    @objc static let jukeboxDisabled = Notification.Name("iSub.jukeboxDisabled")

    @objc static let jukeboxSongInfo = Notification.Name("iSub.jukeboxSongInfo")

    @objc static let playVideo = Notification.Name("iSub.playVideo")
    @objc static let removeVideoPlayer = Notification.Name("iSub.removeVideoPlayer")

    @objc static let showDeleteButton = Notification.Name("iSub.showDeleteButton")
    @objc static let hideDeleteButton = Notification.Name("iSub.hideDeleteButton")

    @objc static let cachedSongDeleted = Notification.Name("iSub.cachedSongDeleted")

    @objc static let quickSkipSecondsSettingChanged = Notification.Name("iSub.quickSkipSecondsSettingChanged")
}
