//
//  LyricsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class LyricsLoader: SUSLoader {
    @Injected private var store: Store
    
    override var type: SUSLoaderType { SUSLoaderType_Lyrics }
    
    let tagArtistName: String
    let songTitle: String
    var lyrics: Lyrics?
    
    @objc init(delegate: SUSLoaderDelegate?, tagArtistName: String, songTitle: String) {
        self.tagArtistName = tagArtistName
        self.songTitle = songTitle
        super.init(delegate: delegate)
    }
    
    override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "getLyrics", parameters: ["artist": tagArtistName, "title": songTitle]) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_LyricsFailed)
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_LyricsFailed)
            } else if let lyricsElement = root.child("lyrics"), lyricsElement.isValid {
                let lyrics = Lyrics(tagArtistName: tagArtistName, songTitle: songTitle, element: lyricsElement)
                if lyrics.lyricsText != "" && store.add(lyrics: lyrics) {
                    self.lyrics = lyrics
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NoLyricsFound)))
                }
            } else {
                informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NoLyricsElement)))
            }
        }
    }
    
    override func informDelegateLoadingFinished() {
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_LyricsDownloaded)
        super.informDelegateLoadingFinished()
    }
    
    override func informDelegateLoadingFailed(_ error: Error?) {
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_LyricsFailed)
        super.informDelegateLoadingFailed(error)
    }
}
