//
//  StatusLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class StatusLoader: APILoader {
    let urlString: String
    let username: String
    let password: String
    
    private(set) var isVideoSupported = false
    private(set) var isNewSearchSupported = false
    private(set) var isTagSerachSupported = false
    private(set) var majorAPIVersion = 0
    private(set) var minorAPIVersion = 0
    private(set) var versionString: String?
    
    convenience init(server: Server, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.init(urlString: server.url.absoluteString, username: server.username, password: server.password, delegate: delegate, callback: callback)
    }
    
    init(urlString: String, username: String, password: String, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.urlString = urlString
        self.username = username
        self.password = password
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .status }
    
    override func createRequest() -> URLRequest? {
        URLRequest(subsonicAction: "ping", urlString: urlString, username: username, password: password, parameters: nil, byteOffset: 0)
    }
    
    override func processResponse(data: Data) {
        isVideoSupported = false
        isNewSearchSupported = false
        isTagSerachSupported = false
        majorAPIVersion = 0
        minorAPIVersion = 0
        versionString = nil
        guard let root = validate(data: data) else { return }
        guard let version = validateAttribute(element: root, attribute: "version") else { return }
        self.versionString = version
        
        // Split the major and minor version from the version string
        let splitVersion = version.components(separatedBy: ".")
        if splitVersion.count > 0 {
            // Check major version
            majorAPIVersion = Int(splitVersion[0]) ?? 0
            if majorAPIVersion >= 2 {
                isVideoSupported = true
                isNewSearchSupported = true
            }
            
            // Check minor version
            if splitVersion.count > 1 {
                minorAPIVersion = Int(splitVersion[1]) ?? 0
                if majorAPIVersion >= 1 {
                    if minorAPIVersion >= 4 {
                        isNewSearchSupported = true
                    }
                    if minorAPIVersion >= 7 {
                        isVideoSupported = true
                        isTagSerachSupported = true
                    }
                }
            }
        }
        
        informDelegateLoadingFinished()
    }
    
    override func informDelegateLoadingFinished() {
        NotificationCenter.postOnMainThread(name: Notifications.serverCheckPassed)
        super.informDelegateLoadingFinished()
    }
    
    override func informDelegateLoadingFailed(error: Error?) {
        NotificationCenter.postOnMainThread(name: Notifications.serverCheckFailed)
        super.informDelegateLoadingFailed(error: error)
    }
}
