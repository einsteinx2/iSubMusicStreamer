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
    
    override var type: APILoaderType { .lyrics }
    
    let tagArtistName: String
    let songTitle: String
    var lyrics: Lyrics?
    
    @objc init(tagArtistName: String, songTitle: String, delegate: APILoaderDelegate?) {
        self.tagArtistName = tagArtistName
        self.songTitle = songTitle
        super.init(delegate: delegate)
    }
    
    override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "getLyrics", parameters: ["artist": tagArtistName, "title": songTitle]) as URLRequest
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_LyricsFailed)
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_LyricsFailed)
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
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_LyricsDownloaded)
        super.informDelegateLoadingFinished()
    }
    
    override func informDelegateLoadingFailed(error: NSError?) {
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_LyricsFailed)
        super.informDelegateLoadingFailed(error: error)
    }
}
