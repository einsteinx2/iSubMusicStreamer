//
//  Notifications.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct Notifications {
    static let songPlaybackStarted = Notification.Name("iSub.songPlaybackStarted")
    static let songPlaybackPaused = Notification.Name("iSub.songPlaybackPaused")
    static let songPlaybackEnded = Notification.Name("iSub.songPlaybackEnded")
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
    
    static let bassEffectPresetLoaded = Notification.Name("iSub.bassEffectPresetLoaded")
    
    static let currentPlaylistOrderChanged = Notification.Name("iSub.currentPlaylistOrderChanged")
    static let currentPlaylistShuffleToggled = Notification.Name("iSub.currentPlaylistShuffleToggled")
    static let currentPlaylistIndexChanged = Notification.Name("iSub.currentPlaylistIndexChanged")
    static let currentPlaylistSongsQueued = Notification.Name("iSub.currentPlaylistSongsQueued")

    static let songCachingEnabled = Notification.Name("iSub.songCachingEnabled")
    static let songCachingDisabled = Notification.Name("iSub.songCachingDisabled")

    static let showPlayer = Notification.Name("iSub.showPlayer")

    static let downloadQueueStarted = Notification.Name("iSub.downloadQueueStarted")
    static let downloadQueueStopped = Notification.Name("iSub.downloadQueueStopped")
    static let downloadQueueSongDownloaded = Notification.Name("iSub.downloadQueueSongDownloaded")
    static let downloadQueueSongFailed = Notification.Name("iSub.downloadQueueSongFailed")
    static let downloadQueueSongAdded = Notification.Name("iSub.downloadQueueSongAdded")
    static let downloadQueueSongRemoved = Notification.Name("iSub.downloadQueueSongRemoved")
    static let streamHandlerSongDownloaded = Notification.Name("iSub.streamHandlerSongDownloaded")
    static let streamHandlerSongFailed = Notification.Name("iSub.streamHandlerSongFailed")

    static let downloadsSizeChecked = Notification.Name("iSub.downloadsSizeChecked")

    static let goOffline = Notification.Name("iSub.goOffline")
    static let goOnline = Notification.Name("iSub.goOnline")
    static let didEnterOfflineMode = Notification.Name("iSub.didEnterOfflineMode")
    static let didEnterOnlineMode = Notification.Name("iSub.didEnterOnlineMode")

    static let bassInitialized = Notification.Name("iSub.bassInitialized")
    static let bassFreed = Notification.Name("iSub.bassFreed")

    static let jukeboxEnabled = Notification.Name("iSub.jukeboxEnabled")
    static let jukeboxDisabled = Notification.Name("iSub.jukeboxDisabled")

    static let jukeboxSongInfo = Notification.Name("iSub.jukeboxSongInfo")

    static let playVideo = Notification.Name("iSub.playVideo")
    static let removeVideoPlayer = Notification.Name("iSub.removeVideoPlayer")

    static let showDeleteButton = Notification.Name("iSub.showDeleteButton")
    static let hideDeleteButton = Notification.Name("iSub.hideDeleteButton")

    static let downloadedSongDeleted = Notification.Name("iSub.downloadedSongDeleted")
    
    static let quickSkipSecondsSettingChanged = Notification.Name("iSub.quickSkipSecondsSettingChanged")
}

final class Notifications_ObjcDeleteMe: NSObject {
    static let bassEffectPresetLoaded = Notifications.bassEffectPresetLoaded
    static let quickSkipSecondsSettingChanged = Notifications.quickSkipSecondsSettingChanged
    static let enterOfflineMode = Notifications.goOffline
    static let enterOnlineMode = Notifications.goOnline
}
