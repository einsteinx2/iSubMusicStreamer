//
//  Analytics.swift
//  iSub Release
//
//  Created by Benjamin Baron on 4/23/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class Analytics {
    enum EventType: String {
        case jukeboxDisabled    = "JukeboxDisabled"
        case jukeboxEnabled     = "JukeboxEnabled"
        case homeTab            = "HomeTab"
        case searchAll          = "SearchAll"
        case nowPlayingTab      = "NowPlayingTab"
        case chatTab            = "ChatTab"
        case libraryTab         = "LibraryTab"
        case foldersTab         = "FoldersTab"
        case bookmarksTab       = "BookmarksTab"
        case playlistsTab       = "PlaylistsTab"
        case playerPlayQueue    = "PlayerPlayQueue"
        case playQueueTab       = "PlayQueueTab"
        case localPlaylistsTab  = "LocalPlaylistsTab"
        case serverPlaylistsTab = "ServerPlaylistsTab"
        case downloadsTab       = "DownloadsTab"
        case quickSkip          = "QuickSkip"
        case equalizer          = "Equalizer"
    }
    
    func setup() {
        loadFlurryAnalytics()
    }
    
    func log(event: EventType) {
        logEvent(name: event.rawValue)
    }
    
    fileprivate func logEvent(name: String) {
        Flurry.logEvent(name)
    }
    
    private func loadFlurryAnalytics() {
        var apiKey: String? = nil
        #if DEBUG
            apiKey = nil
        #elseif RELEASE
            apiKey = "3KK4KKD2PSEU5APF7PNX"
        #elseif BETA
            apiKey = "KNN9DUXQEENZUG4Q12UA"
        #endif
        
        if let apiKey = apiKey {
            Flurry.startSession(apiKey)
            
            // Send basic device model and OS information
            let parameters = ["FirmwareVersion": UIDevice.completeOSVersion, "HardwareVersion": UIDevice.deviceModel]
            Flurry.logEvent("DeviceInfo", withParameters: parameters)
        }
    }
}

@objc final class Analytics_ObjCDeleteMe: NSObject {
    private static var analytics: Analytics { Resolver.resolve() }
    
    @objc static func logEvent(name: String) {
        analytics.logEvent(name: name)
    }
}
