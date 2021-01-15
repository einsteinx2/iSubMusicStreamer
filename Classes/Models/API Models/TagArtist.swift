//
//  TagArtist.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import InflectorKit

@objc(ISMSTagArtist) final class TagArtist: NSObject, NSCopying, Codable {
    @objc let serverId: Int
    @objc(artistId) let id: Int
    @objc let name: String
    @objc let coverArtId: String?
    @objc let artistImageUrl: String?
    @objc let albumCount: Int
    
    @objc init(serverId: Int, id: Int, name: String, coverArtId: String?, artistImageUrl: String?, albumCount: Int) {
        self.serverId = serverId
        self.id = id
        self.name = name
        self.coverArtId = coverArtId
        self.artistImageUrl = artistImageUrl
        self.albumCount = albumCount
        super.init()
    }
    
    @objc init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.name = element.attribute("name").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.artistImageUrl = element.attribute("artistImageUrl").stringXMLOptional
        self.albumCount = element.attribute("albumCount").intXML
        super.init()
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        TagArtist(serverId: serverId, id: id, name: name, coverArtId: coverArtId, artistImageUrl: artistImageUrl, albumCount: albumCount)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? TagArtist {
            return self === object || (serverId == object.serverId && id == object.id)
        }
        return false
    }
    
    @objc override var description: String {
        "\(super.description): serverId: \(serverId), id: \(id), name: \(name), coverArtId: \(coverArtId ?? "nil"), artistImageUrl: \(artistImageUrl ?? "nil"), albumCount: \(albumCount)"
    }
}

@objc extension TagArtist: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { "\(albumCount) \("Album".pluralize(amount: albumCount))" }
    var durationLabelText: String? { nil }
    var isCached: Bool { false }
    func download() { SongLoader.downloadAll(tagArtistId: id) }
    func queue() { SongLoader.queueAll(tagArtistId: id) }
}
