//
//  AsyncMediaFoldersLoader.swift
//  iSub
//
//  Created by Ben Baron on 5/28/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

final class AsyncMediaFoldersLoader: AsyncAPILoader<[MediaFolder]> {
    let serverId: Int
        
    init(serverId: Int) {
        self.serverId = serverId
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .mediaFolders }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: .getMusicFolders)
    }
    
    override func processResponse(data: Data) async throws -> [MediaFolder] {
        try Task.checkCancellation()
        
        let allFoldersMediaFolder = MediaFolder(serverId: serverId, id: MediaFolder.allFoldersId, name: "All Media Folders")
        
        let musicFolders = try require(decodeSubsonicResponse(data: data).musicFolders, "musicFolders")

        try Task.checkCancellation()

        return [allFoldersMediaFolder] + (musicFolders.musicFolder?.values ?? []).map { MediaFolder(serverId: serverId, dto: $0) }
    }
}
