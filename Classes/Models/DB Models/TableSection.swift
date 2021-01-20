//
//  TableIndex.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct TableSection: Codable {
    let serverId: Int
    let mediaFolderId: Int
    let name: String
    let position: Int
    let itemCount: Int
}
