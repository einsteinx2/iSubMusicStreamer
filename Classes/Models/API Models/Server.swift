//
//  Server.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc enum ServerType: Int, Codable {
    case none = 0
    case subsonic = 1
}

@objc final class Server: NSObject, Codable {
    @objc(serverId) var id: Int
    @objc let type: ServerType
    @objc let url: URL
    @objc let username: String
    @objc let password: String
    
    // Server URL in the format "scheme_host_port_path"
    // I.e. https://plex:4041 is "https_plex_4041",
    //      http://test.subsonic.org is "http_test.subsonic.org_80",
    //      http://test.com:8080/subsonic is "http_test.com_8080_subsonic"
    //      https://myserver.net:4041/subsonic/server1 is "https_myserver.net_4041_subsonic_server1"
    // This gives a unique filesystem path that can be used when storing downloaded songs
    @objc let path: String
    
    @objc var isVideoSupported: Bool = true
    @objc var isNewSearchSupported: Bool = true
    
    static func generatePathFromURL(url: URL) -> String {
        let scheme = url.scheme ?? "scheme"
        let host = url.host ?? "host"
        let port: String
        if let urlPort = url.port {
            port = "\(urlPort)"
        } else {
            port = "port"
        }
        
        var path = "\(scheme)_\(host)_\(port)"
        for component in url.pathComponents {
            if component != "/" {
                path += "_\(component)"
            }
        }
        return path
    }
    
    @objc init(id: Int, type: ServerType, url: URL, username: String, password: String, path: String, isVideoSupported: Bool, isNewSearchSupported: Bool) {
        self.id = id
        self.type = type
        self.url = url
        self.username = username
        self.password = password
        self.path = path
        self.isVideoSupported = isVideoSupported
        self.isNewSearchSupported = isNewSearchSupported
        super.init()
    }
    
    @objc init(id: Int, type: ServerType, url: URL, username: String, password: String) {
        self.id = id
        self.type = type
        self.url = url
        self.username = username
        self.password = password
        self.path = Self.generatePathFromURL(url: url)
        super.init()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? Server {
            return self === object || id == object.id
        }
        return false
    }
}
