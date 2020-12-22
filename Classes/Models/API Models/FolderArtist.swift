//
//  RootFolder.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSFolderArtist) final class FolderArtist: NSObject, NSSecureCoding, NSCopying {
    static var supportsSecureCoding = true
    
    @objc(folderId) let id: String
    @objc let name: String
    
    @objc init(id: String, name: String) {
        self.id = id
        self.name = name
        super.init()
    }
    
    @objc init(attributeDict: [String: String]) {
        self.id = attributeDict["id"] ?? ""
        self.name = attributeDict["name"] ?? ""
        super.init()
    }
    
    @objc init(element: RXMLElement) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.name = element.attribute("name")?.clean() ?? ""
        super.init()
    }
    
    @objc init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String ?? ""
        self.name = coder.decodeObject(forKey: "name") as? String ?? ""
        super.init()
    }
    
    @objc func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        return FolderArtist(id: id, name: name)
    }
    
    @objc override var description: String {
        return "\(super.description): id: \(id), name: \(name)"
    }
}

@objc extension FolderArtist: TableCellModel {
    var primaryLabelText: String? { return name }
    var secondaryLabelText: String? { return nil }
    var durationLabelText: String? { return nil }
    var coverArtId: String? { return nil }
    var isCached: Bool { return false }
    func download() { Database.shared().downloadAllSongs(id, folderArtist: self) }
    func queue() { Database.shared().queueAllSongs(id, folderArtist: self) }
}
