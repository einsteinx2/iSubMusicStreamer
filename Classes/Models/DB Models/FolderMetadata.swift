//
//  FolderMetadata.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

struct FolderMetadata: Codable, Equatable {
    let serverId: Int
    let parentFolderId: Int
    let folderCount: Int
    let songCount: Int
    let duration: Int
}
