//
//  TableIndex.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class TableSection: NSObject, Codable {
    @objc let mediaFolderId: Int
    @objc let name: String
    @objc let position: Int
    @objc let itemCount: Int
    
    @objc init(mediaFolderId: Int, name: String, position: Int, itemCount: Int) {
        self.mediaFolderId = mediaFolderId
        self.name = name
        self.position = position
        self.itemCount = itemCount
    }
}
