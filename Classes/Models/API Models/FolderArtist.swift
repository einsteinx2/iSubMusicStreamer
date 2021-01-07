//
//  RootFolder.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSFolderArtist) final class FolderArtist: NSObject, NSCopying {
    @objc(folderId) let id: Int
    @objc let name: String
    
    @objc init(id: Int, name: String) {
        self.id = id
        self.name = name
        super.init()
    }
    
    @objc init(element: RXMLElement) {
        self.id =  element.attribute("id").intXML
        self.name = element.attribute("name").stringXML
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
    func download() { SongLoader.downloadAll(folderId: id) }
    func queue() { SongLoader.queueAll(folderId: id) }
}
