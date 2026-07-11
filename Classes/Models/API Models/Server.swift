//
//  Server.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

enum ServerType: Int, Codable {
    case none = 0
    case subsonic = 1
    case navidrome = 2
    case airsonic = 3
    case gonic = 4
    case lms = 5
    case ampache = 6
    // A server that self-identifies through the OpenSubsonic type attribute but isn't
    // one of the known types above
    case openSubsonic = 99

    var displayName: String {
        switch self {
        case .none: return "Unknown"
        case .subsonic: return "Subsonic"
        case .navidrome: return "Navidrome"
        case .airsonic: return "Airsonic"
        case .gonic: return "gonic"
        case .lms: return "LMS"
        case .ampache: return "Ampache"
        case .openSubsonic: return "OpenSubsonic"
        }
    }
}

// Maps the ping response's OpenSubsonic attributes to a ServerType. Legacy servers
// (original Subsonic and original Airsonic) don't identify themselves — their ping
// responses are indistinguishable — so anything without a type attribute gets the
// generic .subsonic badge.
enum ServerTypeDetection {
    static func serverType(typeAttribute: String?, isOpenSubsonic: Bool) -> ServerType {
        guard let type = typeAttribute?.lowercased(), !type.isEmpty else { return .subsonic }
        // e.g. "Airsonic-Advanced" and "AirsonicAdvanced"
        if type.contains("airsonic") { return .airsonic }
        switch type {
        case "navidrome": return .navidrome
        case "gonic": return .gonic
        case "lms": return .lms
        case "ampache": return .ampache
        case "subsonic": return .subsonic
        default: return isOpenSubsonic ? .openSubsonic : .subsonic
        }
    }
}

final class Server: NSObject, Codable, Identifiable {
    @objc(serverId) var id: Int
    // Updated when a ping response identifies the server type (see ServerTypeDetection)
    var type: ServerType
    let url: URL
    let username: String
    let password: String
    
    // Server URL in the format "scheme_host_port_path"
    // I.e. https://plex:4041 is "https_plex_4041",
    //      http://test.subsonic.org is "http_test.subsonic.org_80",
    //      http://test.com:8080/subsonic is "http_test.com_8080_subsonic"
    //      https://myserver.net:4041/subsonic/server1 is "https_myserver.net_4041_subsonic_server1"
    // This gives a unique filesystem path that can be used when storing downloaded songs
    let path: String
    
    var isVideoSupported: Bool = true
    var isNewSearchSupported: Bool = true
    var isTagSearchSupported: Bool = true
    
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
    
    init(id: Int, type: ServerType, url: URL, username: String, password: String, path: String, isVideoSupported: Bool, isNewSearchSupported: Bool, isTagSearchSupported: Bool) {
        self.id = id
        self.type = type
        self.url = url
        self.username = username
        self.password = password
        self.path = path
        self.isVideoSupported = isVideoSupported
        self.isNewSearchSupported = isNewSearchSupported
        self.isTagSearchSupported = isTagSearchSupported
        super.init()
    }
    
    init(id: Int, type: ServerType, url: URL, username: String, password: String) {
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
    
    override var description: String {
        "\(super.description): id: \(id), type: \(type), url: \(url)"
    }
}
