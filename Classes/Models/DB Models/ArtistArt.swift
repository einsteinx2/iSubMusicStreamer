//
//  ArtistArt.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct ArtistArt: Codable {
    let serverId: Int
    let id: String
    let data: Data
    
    var image: UIImage? { UIImage(data: data) }
}
