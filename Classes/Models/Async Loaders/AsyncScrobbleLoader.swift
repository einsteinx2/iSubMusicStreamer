//
//  AsyncScrobbleLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/4/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation

final class AsyncScrobbleLoader: AsyncAPILoader<Void> {
    let song: Song
    let isSubmission: Bool
    
    init(song: Song, isSubmission: Bool) {
        self.song = song
        self.isSubmission = isSubmission
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .scrobble }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: song.serverId, subsonicAction: .scrobble, parameters: ["id": song.id, "submission": isSubmission])
    }
    
    override func processResponse(data: Data) async throws {
        try Task.checkCancellation()

        _ = try decodeSubsonicResponse(data: data)
    }
}
