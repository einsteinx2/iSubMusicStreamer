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
    @objc static let allFoldersId = -1
    
    @objc let serverId: Int
    @objc(mediaFolderId) let id: Int
    @objc let name: String
    
    init(serverId: Int, id: Int, name: String) {
        self.serverId = serverId
        self.id = id
        self.name = name
        super.init()
    }
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.name = element.attribute("name").stringXML
        super.init()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? MediaFolder {
            return self === object || (serverId == object.serverId && id == object.id)
        }
        return false
    }
    
    override var description: String {
        return "\(super.description): serverId: \(serverId), id: \(id), name: \(name)"
    }
}
