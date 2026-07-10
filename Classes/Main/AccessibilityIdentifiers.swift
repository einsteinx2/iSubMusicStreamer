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
    static let equalizerSavePreset = "equalizer.savePreset"
    static let equalizerDeletePreset = "equalizer.deletePreset"
    static let equalizerClose = "equalizer.close"
}
