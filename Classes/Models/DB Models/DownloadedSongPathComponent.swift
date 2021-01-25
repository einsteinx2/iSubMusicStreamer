//
//  DownloadedSongPathComponent.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct DownloadedSongPathComponent: Codable, Equatable {
    let level: Int
    let maxLevel: Int
    let pathComponent: String
    let parentPathComponent: String?
    let serverId: Int
    let songId: Int
}
