//
//  CoverArt.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class CoverArt: NSObject, Codable {
    @objc(coverArtId) let id: String
    @objc let isLarge: Bool
    @objc let data: Data
    
    @objc var image: UIImage? { UIImage(data: data) }
    
    @objc init(id: String, isLarge: Bool, data: Data) {
        self.id = id
        self.isLarge = isLarge
        self.data = data
        super.init()
    }
}
