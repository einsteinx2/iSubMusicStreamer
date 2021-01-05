//
//  DropdownFolderLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class DropdownFolderLoader: SUSLoader {
    @objc private(set) var mediaFolders = [MediaFolder]()
    
    override var type: SUSLoaderType { SUSLoaderType_DropdownFolder }
    
    override func createRequest() -> URLRequest {
        return NSMutableURLRequest(susAction: "getMusicFolders", parameters: nil) as URLRequest
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
                var mediaFolders = [MediaFolder(id: MediaFolder.allFoldersId, name: "All Media Folders")]
                root.iterate("musicFolders.musicFolder") { e in
                    if let id = Int(e.attribute("id") ?? ""), let name = e.attribute("name") {
                        mediaFolders.append(MediaFolder(id: id, name: name))
                    }
                }
                self.mediaFolders = mediaFolders
                informDelegateLoadingFinished()
            }
        }
    }
}
