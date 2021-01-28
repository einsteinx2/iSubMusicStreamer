//
//  LyricsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class LyricsLoader: APILoader {
    @Injected private var store: Store
    
    let serverId: Int
    let tagArtistName: String
    let songTitle: String
    
    private(set) var lyrics: Lyrics?
    
    convenience init?(song: Song, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        guard let tagArtistName = song.tagArtistName, song.title.count > 0 else { return nil }
        self.init(serverId: song.serverId, tagArtistName: tagArtistName, songTitle: song.title, delegate: delegate, callback: callback)
    }
    
    @objc init(serverId: Int, tagArtistName: String, songTitle: String, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.serverId = serverId
        self.tagArtistName = tagArtistName
        self.songTitle = songTitle
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .lyrics }

    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getLyrics", parameters: ["artist": tagArtistName, "title": songTitle])
    }
    
    override func processResponse(data: Data) {
        self.lyrics = nil
        guard let root = validate(data: data) else { return }
        guard let lyricsElement = validateChild(parent: root, childTag: "lyrics") else { return }
        
        let lyrics = Lyrics(tagArtistName: tagArtistName, songTitle: songTitle, element: lyricsElement)
        guard lyrics.lyricsText.count > 0 else {
            informDelegateLoadingFailed(error: APIError.dataNotFound)
            return
        }
        guard store.add(lyrics: lyrics) else {
            informDelegateLoadingFailed(error: APIError.database)
            return
        }
        
        self.lyrics = lyrics
        informDelegateLoadingFinished()
    }
    
    override func informDelegateLoadingFinished() {
        NotificationCenter.postOnMainThread(name: Notifications.lyricsDownloaded)
        super.informDelegateLoadingFinished()
    }
    
    override func informDelegateLoadingFailed(error: Error?) {
        NotificationCenter.postOnMainThread(name: Notifications.lyricsFailed)
        super.informDelegateLoadingFailed(error: error)
    }
}
