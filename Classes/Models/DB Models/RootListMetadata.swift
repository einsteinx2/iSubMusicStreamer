//
//  RootListMetadata.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class RootListMetadata: NSObject, Codable {
    @objc let serverId: Int
    @objc let mediaFolderId: Int
    @objc let itemCount: Int
    @objc let reloadDate: Date
    
    @objc init(serverId: Int, mediaFolderId: Int, itemCount: Int, reloadDate: Date) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        self.itemCount = itemCount
        self.reloadDate = reloadDate
        super.init()
    }
    
    override var description: String {
        return "\(super.description): serverId: \(serverId), mediaFolderId: \(mediaFolderId), itemCount: \(itemCount), reloadDate: \(reloadDate)"
    }
}
