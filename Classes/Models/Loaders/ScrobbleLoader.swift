//
//  ScrobbleLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class ScrobbleLoader: APILoader {
    @objc var serverId = Settings.shared().currentServerId
    @objc let song: Song
    @objc let isSubmission: Bool
    
    @objc init(song: Song, isSubmission: Bool, callback: @escaping LoaderCallback) {
        self.song = song
        self.isSubmission = isSubmission
        super.init(callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .scrobble }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "scrobble", parameters: ["id": song.id, "submission": isSubmission])
    }
    
    override func processResponse(data: Data) {
        informDelegateLoadingFinished()
    }
}
