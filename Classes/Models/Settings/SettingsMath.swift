//
//  SettingsMath.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// MARK: Extracted settings logic (unit tested)

// Maps the quick-skip seconds setting to/from its position in the options list
enum QuickSkipMapping {
    static let secondsOptions = [5, 15, 30, 45, 60, 120, 300, 600, 1200]

    static func segmentIndex(seconds: Int) -> Int? {
        return secondsOptions.firstIndex(of: seconds)
    }

    static func seconds(segmentIndex: Int) -> Int? {
        guard segmentIndex >= 0 && segmentIndex < secondsOptions.count else { return nil }
        return secondsOptions[segmentIndex]
    }
}

// The min-free-space / max-cache-size slider math: clamps the chosen size between
// 50MB and the available space minus 50MB
enum CacheSpaceSliderMath {
    static let reservedBytes = 52428800 // 50MB

    // Returns the byte value for the slider position, plus the corrected slider
    // position when the value had to be clamped (nil when unclamped)
    static func spaceSetting(sliderValue: Float, totalSpace: Int, freeSpace: Int) -> (bytes: Int, clampedSliderValue: Float?) {
        if sliderValue * Float(totalSpace) > Float(freeSpace) - Float(reservedBytes) {
            let bytes = freeSpace - reservedBytes
            return (bytes, Float(bytes) / Float(totalSpace))
        } else if sliderValue * Float(totalSpace) < Float(reservedBytes) {
            return (reservedBytes, Float(reservedBytes) / Float(totalSpace))
        } else {
            return (Int(sliderValue * Float(totalSpace)), nil)
        }
    }
}
