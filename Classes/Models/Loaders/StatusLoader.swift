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
    
    private(set) var isNewSearchSupported = false
    private(set) var isVideoSupported = false
    private(set) var majorVersion = 0
    private(set) var minorVersion = 0
    private(set) var versionString: String?
    
    convenience init(server: Server, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.init(urlString: server.url.absoluteString, username: server.username, password: server.password, delegate: delegate, callback: callback)
    }
    
    init(urlString: String, username: String, password: String, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
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
        isNewSearchSupported = false
        isVideoSupported = false
        majorVersion = 0
        minorVersion = 0
        versionString = nil
        guard let root = validate(data: data) else { return }
        guard let version = validateAttribute(element: root, attribute: "version") else { return }
        self.versionString = version
        
        // Split the major and minor version from the version string
        let splitVersion = version.components(separatedBy: ".")
        if splitVersion.count > 0 {
            // Check major version
            majorVersion = Int(splitVersion[0]) ?? 0
            if majorVersion >= 2 {
                isNewSearchSupported = true
                isVideoSupported = true
            }
            
            // Check minor version
            if splitVersion.count > 1 {
                minorVersion = Int(splitVersion[1]) ?? 0
                if majorVersion >= 1 {
                    if minorVersion >= 4 {
                        isNewSearchSupported = true
                    }
                    if minorVersion >= 7 {
                        isVideoSupported = true
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
