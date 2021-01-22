//
//  LyricsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class LyricsLoader: AbstractAPILoader {
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
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
            NotificationCenter.postOnMainThread(name: Notifications.lyricsFailed)
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
                NotificationCenter.postOnMainThread(name: Notifications.lyricsFailed)
            } else if let lyricsElement = root.child("lyrics"), lyricsElement.isValid {
                let lyrics = Lyrics(tagArtistName: tagArtistName, songTitle: songTitle, element: lyricsElement)
                if lyrics.lyricsText != "" && store.add(lyrics: lyrics) {
                    self.lyrics = lyrics
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NoLyricsFound)))
                }
            } else {
                informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NoLyricsElement)))
            }
        }
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
