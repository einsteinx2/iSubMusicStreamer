//
//  NowPlayingLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class NowPlayingLoader: APILoader {
    @Injected private var store: Store
    
    @objc var serverId = Settings.shared().currentServerId
    
    @objc var nowPlayingSongs = [NowPlayingSong]()
    
    override var type: APILoaderType { .nowPlaying }
    
    override func createRequest() -> URLRequest? {
        NSMutableURLRequest(susAction: "getNowPlaying", parameters: nil) as URLRequest
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                nowPlayingSongs.removeAll()
                root.iterate("nowPlaying.entry") { e in
                    let song = Song(serverId: self.serverId, element: e)
                    if self.store.add(song: song) {
                        self.nowPlayingSongs.append(NowPlayingSong(serverId: self.serverId, element: e))
                    }
                }
                informDelegateLoadingFinished()
            }
        }
    }
}
