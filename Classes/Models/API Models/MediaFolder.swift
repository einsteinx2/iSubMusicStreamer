//
//  MediaFolder.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB

struct MediaFolder: Codable, Equatable {
    static let allFoldersId = -1
    
    let serverId: Int
    let id: Int
    let name: String
    
    init(serverId: Int, id: Int, name: String) {
        self.serverId = serverId
        self.id = id
        self.name = name
    }
    
    // Reproduces the legacy XML init's defaults exactly (incl. the "nil" sentinel)
    init(serverId: Int, dto: MusicFolderDTO) {
        self.serverId = serverId
        self.id = Int(dto.id.value) ?? 0
        self.name = dto.name ?? "nil"
    }
    
    static func ==(lhs: MediaFolder, rhs: MediaFolder) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}
