//
//  AsyncServerPlaylistCreateLoader.swift
//  iSub
//
//  Created by Ben Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Saves a playlist to the server. Subsonic's createPlaylist creates a new playlist
// every time when given a name (even a duplicate name), so overwriting an existing
// playlist must send its playlistId instead of the name.
final class AsyncServerPlaylistCreateLoader: AsyncAPILoader<Void> {
    let serverId: Int
    let name: String
    let overwriteServerPlaylistId: Int?
    let songIds: [String]

    init(serverId: Int, name: String, overwriteServerPlaylistId: Int? = nil, songIds: [String]) {
        self.serverId = serverId
        self.name = name
        self.overwriteServerPlaylistId = overwriteServerPlaylistId
        self.songIds = songIds
        super.init()
    }

    // MARK: APILoader Overrides

    override var type: APILoaderType { .serverPlaylistCreate }

    override func createRequest() -> URLRequest? {
        var parameters: [String: Any] = ["songId": songIds]
        if let overwriteServerPlaylistId {
            parameters["playlistId"] = "\(overwriteServerPlaylistId)"
        } else {
            parameters["name"] = name
        }
        return URLRequest(serverId: serverId, subsonicAction: .createPlaylist, parameters: parameters)
    }

    override func processResponse(data: Data) async throws {
        guard let _ = try await validate(data: data) else {
            throw APIError.responseNotXML
        }
    }
}
