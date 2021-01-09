//
//  FolderMetadata.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

struct FolderMetadata: Codable {
    let serverId: Int
    let parentFolderId: Int
    let folderCount: Int
    let songCount: Int
    let duration: Int
    
    init(serverId: Int, parentFolderId: Int, folderCount: Int, songCount: Int, duration: Int) {
        self.serverId = serverId
        self.parentFolderId = parentFolderId
        self.folderCount = folderCount
        self.songCount = songCount
        self.duration = duration
    }
}
