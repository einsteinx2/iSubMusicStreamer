//
//  DownloadedTagArtist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import InflectorKit

struct DownloadedTagArtist: Codable, Equatable {
    let serverId: Int
    let id: Int
    let name: String
    let coverArtId: String?
    let artistImageUrl: String?
    let albumCount: Int

    static func ==(lhs: DownloadedTagArtist, rhs: DownloadedTagArtist) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension DownloadedTagArtist: TableCellModel {
    private var store: Store { Resolver.resolve() }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        if let albumCount = store.downloadedTagAlbumsCount(downloadedTagArtist: self) {
            return "\(albumCount) \("Album".pluralize(amount: albumCount))"
        }
        return nil
    }
    var durationLabelText: String? { nil }
    var isDownloaded: Bool { true }
    var isDownloadable: Bool { false }
    
    var tagArtistId: Int? { id }
    var tagAlbumId: Int? { nil }
    var parentFolderId: Int? { nil }
    
    func download() {
        // TODO: implement this
        fatalError("implement this")
    }
    func queue() {
        // TODO: implement this
        fatalError("implement this")
    }
    func queueNext() {
        // TODO: implement this
        fatalError("implement this")
    }
}
