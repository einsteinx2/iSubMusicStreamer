//
//  QuickAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class QuickAlbumsLoader: APILoader {
    @objc var serverId = Settings.shared().currentServerId
    
    @objc var folderAlbums = [FolderAlbum]()
    // TODO: Make this an enum once only swift code is using this class
    @objc var modifier = ""
    @objc var offset = 0
    
    override var type: APILoaderType { .quickAlbums }
    
    override func createRequest() -> URLRequest? {
        let parameters: [AnyHashable: Any] = ["size": 20, "type": modifier, "offset": offset]
        return NSMutableURLRequest(susAction: "getAlbumList", parameters: parameters) as URLRequest
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
