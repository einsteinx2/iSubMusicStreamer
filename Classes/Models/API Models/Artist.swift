//
//  Artist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

protocol Artist: TableCellModel {
    var serverId: Int { get }
    var id: Int { get }
    var name: String { get }
    var coverArtId: String? { get }
    var artistImageUrl: String? { get }
    var albumCount: Int { get }
}
