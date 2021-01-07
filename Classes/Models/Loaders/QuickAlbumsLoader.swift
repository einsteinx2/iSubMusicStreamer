//
//  QuickAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class QuickAlbumsLoader: SUSLoader {
    @objc var folderAlbums = [FolderAlbum]()
    // TODO: Make this an enum once only swift code is using this class
    @objc var modifier = ""
    @objc var offset = 0
    
    override var type: SUSLoaderType { SUSLoaderType_QuickAlbums }
    
    override func createRequest() -> URLRequest {
        let parameters: [AnyHashable: Any] = ["size": 20, "type": modifier, "offset": offset]
        return NSMutableURLRequest(susAction: "getAlbumList", parameters: parameters) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
            } else {
                folderAlbums.removeAll()
                root.iterate("albumList.album") { e in
                    let folderAlbum = FolderAlbum(element: e)
                    if folderAlbum.name != ".AppleDouble" {
                        self.folderAlbums.append(folderAlbum)
                    }
                }
                informDelegateLoadingFinished()
            }
        }
    }
}
