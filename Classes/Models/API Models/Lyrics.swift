//
//  Lyrics.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct Lyrics: Codable, Equatable {
    let tagArtistName: String
    let songTitle: String
    let lyricsText: String
    
    init(tagArtistName: String, songTitle: String, element: RXMLElement) {
        self.tagArtistName = tagArtistName
        self.songTitle = songTitle
        self.lyricsText = element.text
    }
}
