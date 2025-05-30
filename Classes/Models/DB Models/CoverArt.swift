//
//  CoverArt.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

struct CoverArt: Codable, Equatable {
    let serverId: Int
    let id: String
    let isLarge: Bool
    let data: Data
    
    var image: UIImage? { UIImage(data: data) }
    
    static func ==(lhs: CoverArt, rhs: CoverArt) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id && lhs.isLarge == rhs.isLarge
    }
}
