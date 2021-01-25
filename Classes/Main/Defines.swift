//
//  Defines.swift
//  iSub
//
//  Created by Benjamin Baron on 11/24/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// Set up this way to be accessible in both Swift and Obj-C
@objc final class Defines: NSObject {
    @objc static var rowHeight: CGFloat { return UIDevice.isSmall() ? 50 : 65 }
    @objc static var tallRowHeight: CGFloat { return UIDevice.isSmall() ? 70 : 85 }
    @objc static var headerRowHeight: CGFloat { return UIDevice.isSmall() ? 45 : 60 }
    
    // Use same levels for Swift as used in Defines.h for Obj-C
    // TODO: Find a good way to share values between Obj-C and Swift so they don't need to be redefined
    @objc static func setupDefaultLogLevel() {
        #if BETA
            #if SILENT
                dynamicLogLevel = DDLogLevel.off
            #else
                dynamicLogLevel = DDLogLevel.info//all
            #endif
        #else
            dynamicLogLevel = DDLogLevel.info
        #endif
    }
}

func bytesForSeconds(seconds: Float, kiloBitrate: Float) -> Float {
    return (kiloBitrate / 8) * 1024 * seconds
}
