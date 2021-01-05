//
//  MediaFolder.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB

@objc final class MediaFolder: NSObject, Codable {
    @objc(mediaFolderId) let id: Int
    @objc let name: String
    
    @objc init(id: Int, name: String) {
        self.id = id
        self.name = name
        super.init()
    }
}
