//
//  Defines.swift
//  iSub
//
//  Created by Benjamin Baron on 11/24/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

struct Defines {
    static var rowHeight: CGFloat { UIDevice.isSmall ? 50 : 65 }
    static var tallRowHeight: CGFloat { UIDevice.isSmall ? 70 : 85 }
    static var headerRowHeight: CGFloat { UIDevice.isSmall ? 45 : 60 }
    
    // Use same levels for Swift as used in Defines.h for Obj-C
    // TODO: Find a good way to share values between Obj-C and Swift so they don't need to be redefined
    static func setupDefaultLogLevel() {
        #if BETA
            #if SILENT
                dynamicLogLevel = DDLogLevel.off
            #else
                dynamicLogLevel = DDLogLevel.all
            #endif
        #else
            dynamicLogLevel = DDLogLevel.info
        #endif
    }
}

// Generic callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typealias SuccessErrorCallback = (_ success: Bool, _ error: Error?) -> Void

func bytesForSeconds(seconds: Double, kiloBitrate: Int) -> Int {
    return Int((Double(kiloBitrate) / 8.0) * 1024.0 * seconds)
}

func formatTime<T: BinaryFloatingPoint>(seconds: T) -> String {
    guard seconds >= 0 else { return "0:00" }
    let mins = seconds / 60
    let secs = seconds.truncatingRemainder(dividingBy: 60)
    return String(format: "%d:%02d", Int(mins), Int(secs))
}

func formatTime<T: BinaryInteger>(seconds: T) -> String {
    formatTime(seconds: Double(seconds))
}

func formatFileSize<T: BinaryInteger>(bytes: T) -> String {
    let x = Int(bytes)
    switch x {
    case 0..<1024:
        return "\(x) bytes"
    case 1024..<(1024 * 1024):
        return String(format: "%.02f KB", Double(x) / 1024.0)
    case (1024 * 1024)..<(1024 * 1024 * 1024):
        return String(format: "%.02f MB", Double(x) / 1024.0 / 1024.0)
    case (1024 * 1024 * 1024)...:
        return String(format: "%.02f GB", Double(x) / 1024.0 / 1024.0 / 1024.0)
    default:
        // TODO: Handle negative values (not currently needed)
        return "\(x) bytes"
    }
}

func formatFileSize<T: BinaryFloatingPoint>(bytes: T) -> String {
    formatFileSize(bytes: Int(bytes))
}

func fileSize(formatted: String) -> Int? {
    // Extract the number value from the string
    let charSet = CharacterSet(charactersIn: "0123456789.").inverted
    let numbersArray = formatted.components(separatedBy: charSet)
    let pureNumbers = numbersArray.joined(separator: "")
    guard var fileSize = Double(pureNumbers) else { return nil }
    
    // Extract the size multiplier and apply it if necessary
    let sizes = ["k": 1024.0, "m": 1024.0 * 1024.0, "g": 1024.0 * 1024.0 * 1024.0]
    for (sizeString, multiplier) in sizes {
        if let _ = formatted.lowercased().range(of: sizeString, options: .backwards) {
            fileSize *= multiplier
            break
        }
    }
    return Int(fileSize)
}

// Temporary backfill for Obj-C
@objc final class Defines_ObjCDeleteMe: NSObject {
    @objc static func formatFileSizeWithBytes(_ bytes: Int) -> String {
        return formatFileSize(bytes: bytes)
    }
    @objc static func fileSizeFromFormat(_ formatted: String) -> Int {
        return fileSize(formatted: formatted) ?? 0
    }
}
