//
//  ScrobbleLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class ScrobbleLoader: APILoader {
    let song: Song
    let isSubmission: Bool
    
    init(song: Song, isSubmission: Bool, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.song = song
        self.isSubmission = isSubmission
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .scrobble }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: song.serverId, subsonicAction: "scrobble", parameters: ["id": song.id, "submission": isSubmission])
    }
    
    override func processResponse(data: Data) {
        guard let _ = validate(data: data) else { return }
        informDelegateLoadingFinished()
    }
}
