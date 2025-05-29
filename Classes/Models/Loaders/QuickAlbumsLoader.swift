//
//  QuickAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class QuickAlbumsLoader: APILoader {
    let serverId: Int
    // TODO: Make this an enum once only swift code is using this class
    let modifier: String
    let offset: Int
    
    private(set) var folderAlbums = [FolderAlbum]()
    
    init(serverId: Int, modifier: String, offset: Int = 0, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        self.modifier = modifier
        self.offset = offset
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .quickAlbums }
    
    override func createRequest() -> URLRequest? {
        let parameters: [String: Any] = ["size": 20, "type": modifier, "offset": offset]
        return URLRequest(serverId: serverId, subsonicAction: .getAlbumList, parameters: parameters)
    }
    
    override func processResponse(data: Data) {
        folderAlbums.removeAll()
        guard let root = validate(data: data) else { return }
        guard let albumList = validateChild(parent: root, childTag: "albumList") else { return }
         
        albumList.iterate("album") { e, _ in
            let folderAlbum = FolderAlbum(serverId: self.serverId, element: e)
            if folderAlbum.name != ".AppleDouble" { self.folderAlbums.append(folderAlbum) }
        }
        
        informDelegateLoadingFinished()
    }
}
