//
//  ScrobbleLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class ScrobbleLoader: APILoader {
    @objc let song: Song
    @objc let isSubmission: Bool
    
    @objc init(song: Song, isSubmission: Bool, callback: @escaping LoaderCallback) {
        self.song = song
        self.isSubmission = isSubmission
        super.init(callback: callback)
    }
    
    override var type: APILoaderType { .scrobble }
    
    override func createRequest() -> URLRequest? {
        let parameters: [AnyHashable: Any] = ["id": song.id, "submission": isSubmission]
        return NSMutableURLRequest(susAction: "scrobble", parameters: parameters) as URLRequest
    }
    
    override func processResponse(data: Data) {
        informDelegateLoadingFinished()
    }
}
