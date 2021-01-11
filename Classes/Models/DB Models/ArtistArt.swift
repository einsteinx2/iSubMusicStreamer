//
//  ArtistArt.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class ArtistArt: NSObject, Codable {
    @objc let serverId: Int
    @objc(coverArtId) let id: String
    @objc let data: Data
    
    @objc var image: UIImage? { UIImage(data: data) }
    
    @objc init(serverId: Int, id: String, data: Data) {
        self.serverId = serverId
        self.id = id
        self.data = data
        super.init()
    }
    
    override var description: String {
        "\(super.description): serverId: \(serverId), id: \(id), data.count: \(data.count)"
    }
}
