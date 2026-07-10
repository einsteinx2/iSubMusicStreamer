//
//  AsyncServerPlaylistDeleteLoader.swift
//  iSub
//
//  Created by Ben Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

final class AsyncServerPlaylistDeleteLoader: AsyncAPILoader<Void> {
    let serverId: Int
    let serverPlaylistId: Int

    init(serverId: Int, serverPlaylistId: Int) {
        self.serverId = serverId
        self.serverPlaylistId = serverPlaylistId
        super.init()
    }

    convenience init(serverPlaylist: ServerPlaylist) {
        self.init(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id)
    }

    // MARK: APILoader Overrides

    override var type: APILoaderType { .serverPlaylistDelete }

    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .deletePlaylist, parameters: ["id": "\(serverPlaylistId)"])
    }

    override func processResponse(data: Data) async throws {
        guard let _ = try await validate(data: data) else {
            throw APIError.responseNotXML
        }
    }
}
