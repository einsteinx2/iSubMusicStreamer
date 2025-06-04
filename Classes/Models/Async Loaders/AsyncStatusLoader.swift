//
//  AsyncStatusLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation

// TODO: See if it makes sense to include the valid SSL cert bool here somehow
struct StatusAPIResponseData {
    let isVideoSupported: Bool
    let isNewSearchSupported: Bool
    let isTagSerachSupported: Bool
    let majorAPIVersion: Int
    let minorAPIVersion: Int
    let versionString: String?
}

final class AsyncStatusLoader: AsyncAPILoader<StatusAPIResponseData> {
    let urlString: String
    let username: String
    let password: String
    
    convenience init(server: Server) {
        self.init(urlString: server.url.absoluteString, username: server.username, password: server.password)
    }
    
    init(urlString: String, username: String, password: String) {
        self.urlString = urlString
        self.username = username
        self.password = password
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .status }
    
    override func createRequest() -> URLRequest? {
        URLRequest(subsonicAction: .ping, urlString: urlString, username: username, password: password, parameters: nil, byteOffset: 0)
    }
    
    override func processResponse(data: Data) async throws -> StatusAPIResponseData {
        try Task.checkCancellation()
        
        guard let root = try await validate(data: data), let version = try await validateAttribute(element: root, attribute: "version") else {
            throw APIError.responseNotXML
        }
        
        var isVideoSupported = false
        var isNewSearchSupported = false
        var isTagSerachSupported = false
        var majorAPIVersion = 0
        var minorAPIVersion = 0
        
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
        
        try Task.checkCancellation()
        
        NotificationCenter.postOnMainThread(name: Notifications.serverCheckPassed)
        return StatusAPIResponseData(isVideoSupported: isVideoSupported, isNewSearchSupported: isNewSearchSupported, isTagSerachSupported: isTagSerachSupported, majorAPIVersion: majorAPIVersion, minorAPIVersion: minorAPIVersion, versionString: version)
    }
    
    override func handleFailure() {
        NotificationCenter.postOnMainThread(name: Notifications.serverCheckFailed)
    }
}
