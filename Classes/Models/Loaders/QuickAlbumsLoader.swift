//
//  QuickAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class QuickAlbumsLoader: APILoader {
    var serverId = Settings.shared().currentServerId
    var folderAlbums = [FolderAlbum]()
    // TODO: Make this an enum once only swift code is using this class
    var modifier = ""
    var offset = 0
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .quickAlbums }
    
    override func createRequest() -> URLRequest? {
        let parameters: [String: Any] = ["size": 20, "type": modifier, "offset": offset]
        return URLRequest(serverId: serverId, subsonicAction: "getAlbumList", parameters: parameters)
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                folderAlbums.removeAll()
                root.iterate("albumList.album") { e in
                    let folderAlbum = FolderAlbum(serverId: self.serverId, element: e)
                    if folderAlbum.name != ".AppleDouble" {
                        self.folderAlbums.append(folderAlbum)
                    }
                }
                informDelegateLoadingFinished()
            }
        }
    }
}
