//
//  TableIndex.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class TableSection: NSObject, Codable {
    @objc let serverId: Int
    @objc let mediaFolderId: Int
    @objc let name: String
    @objc let position: Int
    @objc let itemCount: Int
    
    @objc init(serverId: Int, mediaFolderId: Int, name: String, position: Int, itemCount: Int) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        self.name = name
        self.position = position
        self.itemCount = itemCount
    }
    
    override var description: String {
        return "\(super.description): serverId: \(serverId), mediaFolderId: \(mediaFolderId), name: \(name), position: \(position), itemCount: \(itemCount)"
    }
}
