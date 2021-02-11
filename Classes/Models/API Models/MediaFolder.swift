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
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.name = element.attribute("name").stringXML
    }
    
    static func ==(lhs: MediaFolder, rhs: MediaFolder) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}
