//
//  DropdownFolderLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/5/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class DropdownFolderLoader: APILoader {
    @objc var serverId = Settings.shared().currentServerId
    @objc private(set) var mediaFolders = [MediaFolder]()
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .dropdownFolder }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getMusicFolders")
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                var mediaFolders = [MediaFolder(serverId: serverId, id: MediaFolder.allFoldersId, name: "All Media Folders")]
                root.iterate("musicFolders.musicFolder") { e in
                    mediaFolders.append(MediaFolder(serverId: self.serverId, element: e))
                }
                self.mediaFolders = mediaFolders
                informDelegateLoadingFinished()
            }
        }
    }
}
