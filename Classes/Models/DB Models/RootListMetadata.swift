//
//  RootListMetadata.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct RootListMetadata: Codable {
    let serverId: Int
    let mediaFolderId: Int
    let itemCount: Int
    let reloadDate: Date
}
