//
//  FolderMetadata.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

struct FolderMetadata {
    let folderId: String
    let subfolderCount: Int
    let songCount: Int
    let duration: Int
    
    init(folderId: String, subfolderCount: Int, songCount: Int, duration: Int) {
        self.folderId = folderId
        self.subfolderCount = subfolderCount
        self.songCount = songCount
        self.duration = duration
    }
    
    init(result: FMResultSet) {
        self.folderId = result.string(forColumn: "folderId") ?? ""
        self.subfolderCount = result.long(forColumn: "subfolderCount")
        self.songCount = result.long(forColumn: "songCount")
        self.duration = result.long(forColumn: "duration")
    }
}
