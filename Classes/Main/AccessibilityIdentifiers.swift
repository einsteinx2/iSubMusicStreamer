//
//  AccessibilityIdentifiers.swift
//  iSub
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Stable accessibility identifiers for UI (XCUI) tests. This file is compiled into both
// the app targets and the iSubUITests bundle, so tests reference elements through these
// constants instead of display strings.
enum AccessibilityId {
    // Tab bar
    static let tabHome = "tab.home"
    static let tabLibrary = "tab.library"
    static let tabPlayer = "tab.player"
    static let tabPlaylists = "tab.playlists"
    static let tabDownloads = "tab.downloads"

    // Tables and cells
    static let universalTableViewCell = "cell.universal"

    // Server edit
    static let serverEditURL = "serverEdit.url"
    static let serverEditUsername = "serverEdit.username"
    static let serverEditPassword = "serverEdit.password"
    static let serverEditSave = "serverEdit.save"
    static let serverEditClose = "serverEdit.close"

    // Player transport
    static let playerPlayPause = "player.playPause"
    static let playerPrevious = "player.previous"
    static let playerNext = "player.next"
    static let playerQuickSkipBack = "player.quickSkipBack"
    static let playerQuickSkipForward = "player.quickSkipForward"
    static let playerSeekSlider = "player.seekSlider"
    static let playerRepeat = "player.repeat"
    static let playerShuffle = "player.shuffle"
    static let playerEqualizer = "player.equalizer"
    static let playerJukeboxVolume = "player.jukeboxVolume"

    // Equalizer
    static let equalizerToggle = "equalizer.toggle"
    static let equalizerPresetPicker = "equalizer.presetPicker"
    static let equalizerPresetLabel = "equalizer.presetLabel"
    static let equalizerSavePreset = "equalizer.savePreset"
    static let equalizerDeletePreset = "equalizer.deletePreset"
    static let equalizerClose = "equalizer.close"
    static let equalizerVisualizer = "equalizer.visualizer"

    // Home
    static let homeQuickAlbums = "home.quickAlbums"
    static let homeServerShuffle = "home.serverShuffle"
    static let homeJukebox = "home.jukebox"
    static let homeSettings = "home.settings"
    static let homeNowPlaying = "home.nowPlaying"
    static let homeChat = "home.chat"
    static let homeSongInfo = "home.songInfo"
    static let homeSearchBar = "home.searchBar"

    // Chat
    static let chatTextInput = "chat.textInput"
    static let chatSend = "chat.send"

    // Library
    static let libraryFolderDropdown = "library.folderDropdown"

    // Save/edit table headers (play queue, playlists, bookmarks, downloads)
    static let saveEditHeaderSaveDelete = "saveEditHeader.saveDelete"
    static let saveEditHeaderEdit = "saveEditHeader.edit"

    // Player extras
    static let playerBookmarks = "player.bookmarks"
    static let playerPageControl = "player.pageControl"

    // iPad menu (PadMenuViewController rows)
    static let padMenuSettings = "padMenu.settings"
    static let padMenuHome = "padMenu.home"
    static let padMenuLibrary = "padMenu.library"
    static let padMenuPlaylists = "padMenu.playlists"
    static let padMenuDownloads = "padMenu.downloads"
    static let padMenuBack = "padMenu.back"

    // Options (settings)
    static let optionsManualOfflineMode = "options.manualOfflineMode"
    static let optionsEnableScrobbling = "options.enableScrobbling"
    static let optionsAutoReloadArtist = "options.autoReloadArtist"
    static let optionsDisablePopups = "options.disablePopups"
    static let optionsDisableRotation = "options.disableRotation"
    static let optionsDisableScreenSleep = "options.disableScreenSleep"
    static let optionsEnableBasicAuth = "options.enableBasicAuth"
    static let optionsDisableCellUsage = "options.disableCellUsage"
    static let optionsEnableSongCaching = "options.enableSongCaching"
    static let optionsEnableNextSongCache = "options.enableNextSongCache"
    static let optionsEnableBackupCache = "options.enableBackupCache"
    static let optionsAutoDeleteCache = "options.autoDeleteCache"
    static let optionsEnableLockScreenArt = "options.enableLockScreenArt"
    static let optionsQuickSkipSegment = "options.quickSkipSegment"
    // Positive-phrasing replacements for the retired optionsDisablePopups /
    // optionsDisableScreenSleep toggles in the SwiftUI settings
    static let optionsShowPopups = "options.showPopups"
    static let optionsAllowScreenSleep = "options.allowScreenSleep"

    // SwiftUI settings root rows (the per-section ids live on SettingsSection)
    static let settingsSectionServers = "settings.section.servers"

    // SwiftUI server list
    static let serversList = "servers.list"
    static let serversAdd = "servers.add"
    static let serversEdit = "servers.edit"
}
