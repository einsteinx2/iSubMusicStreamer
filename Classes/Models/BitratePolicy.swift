//
//  BitratePolicy.swift
//  iSub
//
//  Created by Ben Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Pure bitrate decision logic, extracted from SavedSettings and Song so nothing here
// touches services or state: callers pass the current network branch and settings
enum BitratePolicy {
    // Maps the max-bitrate slider positions to a Kbps cap (0 means no cap)
    static func maxKiloBitrate(isWifi: Bool, wifiSetting: Int, cellSetting: Int) -> Int {
        switch isWifi ? wifiSetting : cellSetting {
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

    // Maps the max-video-bitrate slider positions to the HLS bitrate list, highest
    // first (nil means no restriction parameter is sent)
    static func videoBitrates(isWifi: Bool, wifiSetting: Int, cellSetting: Int) -> [String]? {
        if isWifi {
            switch wifiSetting {
            case 0: return ["512"]
            case 1: return ["1024", "512"]
            case 2: return ["1536", "1024", "512"]
            case 3: return ["2048", "1536", "1024", "512"]
            case 4: return ["4096", "2048", "1536", "1024", "512"]
            case 5: return ["8192@1920x1080", "4096", "2048", "1536", "1024", "512"]
            default: return nil
            }
        } else {
            switch cellSetting {
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

    // Best guess at the bitrate a song will actually stream at, given its tagged
    // bitrate, whether the server is (probably) transcoding it, and the user's cap
    static func estimatedKiloBitrate(songKiloBitrate: Int, isTranscoded: Bool, currentMaxBitrate: Int) -> Int {
        // Default to 128 if there is no bitrate for this song object (should never happen)
        var rate = songKiloBitrate == 0 ? 128 : songKiloBitrate

        if isTranscoded {
            // This is probably being transcoded, so attempt to determine the bitrate
            if (rate > 128 && currentMaxBitrate == 0) {
                rate = 128 // Subsonic default transcoding bitrate
            } else if rate > currentMaxBitrate && currentMaxBitrate != 0 {
                rate = currentMaxBitrate
            }
        } else {
            // This is not being transcoded between formats, however bitrate limiting may be active
            if rate > currentMaxBitrate && currentMaxBitrate != 0 {
                rate = currentMaxBitrate
            }
        }

        return rate
    }
}
