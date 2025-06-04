//
//  AsyncLyricsLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class AsyncLyricsLoader: AsyncAPILoader<Lyrics> {
    @Injected private var store: Store
    
    let serverId: Int
    let tagArtistName: String
    let songTitle: String
        
    convenience init?(song: Song) {
        guard let tagArtistName = song.tagArtistName, song.title.count > 0 else { return nil }
        self.init(serverId: song.serverId, tagArtistName: tagArtistName, songTitle: song.title)
    }
    
    init(serverId: Int, tagArtistName: String, songTitle: String) {
        self.serverId = serverId
        self.tagArtistName = tagArtistName
        self.songTitle = songTitle
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .lyrics }

    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getLyrics, parameters: ["artist": tagArtistName, "title": songTitle])
    }
    
    override func processResponse(data: Data) async throws -> Lyrics {
        try Task.checkCancellation()
        
        guard let root = try await validate(data: data), let element = try await validateChild(parent: root, childTag: "lyrics") else {
            throw APIError.responseNotXML
        }

        let lyrics = Lyrics(tagArtistName: tagArtistName, songTitle: songTitle, element: element)
        guard lyrics.lyricsText.count > 0 else {
            throw APIError.dataNotFound
        }
        guard store.add(lyrics: lyrics) else {
            throw APIError.database
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.lyricsDownloaded)
        return lyrics
    }
    
    override func handleFailure() {
        NotificationCenter.postOnMainThread(name: Notifications.lyricsFailed)
    }
}
