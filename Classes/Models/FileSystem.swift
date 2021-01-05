//
//  FileSystem.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

struct FileSystem {
    static let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    
    static var applicationSupportDirectory: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("iSub")
        createDirectory(url: url)
        return url
    }()
    
    static var databaseDirectory: URL = {
        let url = applicationSupportDirectory.appendingPathComponent("database")
        createDirectory(url: url)
        return url
    }()
    
    private static func createDirectory(url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DDLogError("Failed to create application support directory at \(url.path): \(error)")
            }
        }
    }
}
