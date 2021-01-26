//
//  URL+FileSystemAttributes.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

extension URL {
    var systemTotalSpace: Int? {
        do {
            return try resourceValues(forKeys: [.volumeTotalCapacityKey]).volumeTotalCapacity
        } catch {
            DDLogError("[URL+FileSystemAttributes] Failed to get file system size of \(self), \(error)")
        }
        return nil
    }
    
    var systemAvailableSpace: Int? {
        do {
            if let capacity = try resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage {
                return Int(capacity)
            }
        } catch {
            DDLogError("[URL+FileSystemAttributes] Failed to get file system avaiable space of \(self), \(error)")
        }
        return nil
    }
    
    var fileSize: Int? {
        do {
            if let capacity = try resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize {
                return Int(capacity)
            }
        } catch {
            DDLogError("[URL+FileSystemAttributes] Failed to get file system avaiable space of \(self), \(error)")
        }
        return nil
    }
    
    var skipBackup: Bool {
        get {
            // This URL must point to a file
            guard FileManager.default.fileExists(atPath: path) else { return false }
            
            do {
                if let isExcludedFromBackup = try resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup {
                    return isExcludedFromBackup
                }
            } catch {
                DDLogError("[URL+FileSystemAttributes] Failed to get is excluded from backup of \(self), \(error)")
            }
            return false
        }
        set {
            // This URL must point to a file
            guard FileManager.default.fileExists(atPath: path) else { return }
            
            do {
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try setResourceValues(resourceValues)
            } catch {
                DDLogError("[URL+FileSystemAttributes] Failed to set is excluded from backup of \(self) to \(newValue), \(error)")
            }
        }
    }
}
