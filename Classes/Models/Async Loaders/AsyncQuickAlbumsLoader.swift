//
//  AsyncQuickAlbumsLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation

enum QuickAlbumsModifier: String {
    case recent
    case frequent
    case newest
    case random
}

final class AsyncQuickAlbumsLoader: AsyncAPILoader<[FolderAlbum]> {
    let serverId: Int
    let modifier: QuickAlbumsModifier
    let offset: Int
    
    private(set) var folderAlbums = [FolderAlbum]()
    
    init(serverId: Int, modifier: QuickAlbumsModifier, offset: Int = 0) {
        self.serverId = serverId
        self.modifier = modifier
        self.offset = offset
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .quickAlbums }
    
    override func createRequest() -> URLRequest? {
        let parameters: [String: Any] = ["size": 20, "type": modifier.rawValue, "offset": offset]
        return URLRequest(serverId: serverId, subsonicAction: .getAlbumList, parameters: parameters)
    }
    
    override func processResponse(data: Data) async throws -> [FolderAlbum] {
        try Task.checkCancellation()
        
        guard let root = try await validate(data: data), let albumList = try await validateChild(parent: root, childTag: "albumList") else {
            throw APIError.responseNotXML
        }
        
        try Task.checkCancellation()
        
        var folderAlbums = [FolderAlbum]()
        for try await element in albumList.iterate("album") {
            let folderAlbum = FolderAlbum(serverId: serverId, element: element)
            if folderAlbum.name != ".AppleDouble" {
                folderAlbums.append(folderAlbum)
            }
        }
        
        try Task.checkCancellation()
        
        return folderAlbums
    }
}
