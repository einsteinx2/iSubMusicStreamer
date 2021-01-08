//
//  ArtistArt.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class ArtistArt: NSObject, Codable {
    @objc(coverArtId) let id: String
    @objc let data: Data
    
    @objc var image: UIImage? { UIImage(data: data) }
    
    @objc init(id: String, data: Data) {
        self.id = id
        self.data = data
        super.init()
    }
}
