//
//  RootFolder.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSFolderArtist) final class FolderArtist: NSObject, NSCopying {
    @objc(folderId) let id: String
    @objc let name: String
    
    @objc init(id: String, name: String) {
        self.id = id
        self.name = name
        super.init()
    }
    
    @objc init(element: RXMLElement) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.name = element.attribute("name")?.clean() ?? ""
        super.init()
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
