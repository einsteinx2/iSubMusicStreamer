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
    // OpenSubsonic self-identification attributes from the ping response root (all
    // absent on legacy Subsonic/Airsonic servers)
    let serverTypeName: String?
    let serverVersion: String?
    let isOpenSubsonic: Bool
    // The ping always probes with f=json; a server that answered in JSON supports it
    let isJsonSupported: Bool

    var serverType: ServerType {
        ServerTypeDetection.serverType(typeAttribute: serverTypeName, isOpenSubsonic: isOpenSubsonic)
    }
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
        // Always probe with f=json: a capable server answers JSON, anything else
        // ignores the unknown parameter and answers XML, and the response decoder
        // sniffs the format either way
        URLRequest(subsonicAction: .ping, urlString: urlString, username: username, password: password, parameters: nil, byteOffset: 0, format: .json)
    }
    
    override func processResponse(data: Data) async throws -> StatusAPIResponseData {
        try Task.checkCancellation()
        
        let response = try decodeSubsonicResponse(data: data)
        guard let version = response.version else {
            throw APIError.responseMissingAttribute(tag: "subsonic-response", attribute: "version")
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
        return StatusAPIResponseData(isVideoSupported: isVideoSupported,
                                     isNewSearchSupported: isNewSearchSupported,
                                     isTagSerachSupported: isTagSerachSupported,
                                     majorAPIVersion: majorAPIVersion,
                                     minorAPIVersion: minorAPIVersion,
                                     versionString: version,
                                     serverTypeName: response.type,
                                     serverVersion: response.serverVersion,
                                     isOpenSubsonic: response.openSubsonic ?? false,
                                     isJsonSupported: SubsonicEnvelope.sniffsAsJSON(data))
    }
    
    override func handleFailure() {
        NotificationCenter.postOnMainThread(name: Notifications.serverCheckFailed)
    }
}
