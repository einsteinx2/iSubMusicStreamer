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
    // Test hook: when set, all directories resolve under this root instead of the standard system locations
    static var rootOverride: URL?

    static var documentDirectory: URL {
        guard let root = rootOverride else {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        return createdDirectory(url: root.appendingPathComponent("Documents"))
    }

    static var cachesDirectory: URL {
        guard let root = rootOverride else {
            return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        }
        return createdDirectory(url: root.appendingPathComponent("Caches"))
    }

    static var applicationSupportDirectory: URL {
        let base: URL
        if let root = rootOverride {
            base = root.appendingPathComponent("Application Support")
        } else {
            base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        }
        return createdDirectory(url: base.appendingPathComponent("iSub"))
    }

    static var databaseDirectory: URL {
        createdDirectory(url: applicationSupportDirectory.appendingPathComponent("database"))
    }

    static var downloadsDirectory: URL {
        createdDirectory(url: documentDirectory.appendingPathComponent("Downloads"))
    }

    static var tempDownloadsDirectory: URL {
        createdDirectory(url: cachesDirectory.appendingPathComponent("Temp Downloads"))
    }

    private static func createdDirectory(url: URL) -> URL {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                DDLogError("Failed to create directory at \(url.path): \(error)")
            }
        }
        return url
    }
}
