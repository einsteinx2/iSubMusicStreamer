//
//  DownloadedTagAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct DownloadedTagAlbum: Codable, Equatable {
    let serverId: Int
    let id: Int
    let name: String
    let coverArtId: String?
    let tagArtistId: String?
    let tagArtistName: String?
    let songCount: Int
    let duration: Int
    let playCount: Int
    let year: Int
    let genre: String?
    
    static func ==(lhs: DownloadedTagAlbum, rhs: DownloadedTagAlbum) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension DownloadedTagAlbum: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        // TODO: implement this using number of songs downloaded not number of songs in the album model
        return nil
//        var textParts = [String]()
//        if year > 0 { textParts.append(String(year)) }
//        textParts.append("\(songCount) \("Song".pluralize(amount: songCount))")
//        textParts.append(NSString.formatTime(Double(duration)))
//
//        var text = textParts[0]
//        for i in 1..<textParts.count {
//            text += " • " + textParts[i]
//        }
//        return text
    }
    var durationLabelText: String? { nil }
    var isCached: Bool { true }
    func download() {
        // TODO: implement this
        fatalError("implement this")
    }
    func queue() {
        // TODO: implement this
        fatalError("implement this")
    }
}
