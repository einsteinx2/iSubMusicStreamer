//
//  FolderMetadata.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSFolderMetadata) final class FolderMetadata: NSObject, NSCopying {
    @objc let folderId: String
    @objc let subfolderCount: Int
    @objc let songCount: Int
    @objc let duration: Int
    
    @objc init(folderId: String, subfolderCount: Int, songCount: Int, duration: Int) {
        self.folderId = folderId
        self.subfolderCount = subfolderCount
        self.songCount = songCount
        self.duration = duration
        super.init()
    }
    
    @objc init(result: FMResultSet) {
        self.folderId = result.string(forColumn: "folderId") ?? ""
        self.subfolderCount = result.long(forColumn: "subfolderCount")
        self.songCount = result.long(forColumn: "songCount")
        self.duration = result.long(forColumn: "duration")
        super.init()
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        return FolderMetadata(folderId: folderId, subfolderCount: subfolderCount, songCount: songCount, duration: duration)
    }
    
    override var description: String {
        return "\(super.description): folderId: \(folderId), subfolderCount: \(subfolderCount), songCount: \(songCount), duration: \(duration)"
    }
}
