//
//  URLRequest+Subsonic.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

// Subsonic API versions
private let ver1_0_0 = ["ping", "getLicense", "getMusicFolders", "getNowPlaying", "getIndexes", "getMusicDirectory", "search", "getPlaylists", "getPlaylist", "download", "stream", "getCoverArt", "1.0.0"]
private let ver1_2_0 = ["createPlaylist", "deletePlaylist", "getChatMessages", "addChatMessage", "getAlbumList", "getRandomSongs", "getLyrics", "jukeboxControl", "1.2.0"]
private let ver1_3_0 = ["getUser", "deleteUser", "1.3.0"]
private let ver1_4_0 = ["search2", "1.4.0"]
private let ver1_5_0 = ["scrobble", "1.5.0"]
private let ver1_6_0 = ["getPodcasts", "getShares", "createShare", "updateShare", "deleteShare", "setRating", "1.6.0"]
private let ver1_8_0 = ["hls", "getAlbumList2", "getArtists", "getArtist", "getAlbum", "getSong", "1.8.0"]
private let versions = Set<[String]>([ver1_0_0, ver1_2_0, ver1_3_0, ver1_4_0, ver1_5_0, ver1_6_0, ver1_8_0])

extension URLRequest {
    private static func parseQueryString(parameters: [String: Any]?, version: String, username: String, password: String) -> String {
        var queryString = "v=\(version)&c=iSub&u=\(username.URLQueryEncoded)&p=\(password.URLQueryEncoded)"
        if let parameters = parameters {
            for (key, value) in parameters {
                switch value {
                case let array as [Any]:
                    // handle multiple values for key
                    for subValue in array {
                        switch subValue {
                        case let string as String: queryString += "&\(key.URLQueryEncoded)=\(string.URLQueryEncoded)"
                        case let number as NSNumber: queryString += "&\(key.URLQueryEncoded)=\(number.stringValue.URLQueryEncoded)"
                        default: break
                        }
                    }
                case let string as String: queryString += "&\(key.URLQueryEncoded)=\(string.URLQueryEncoded)"
                case let number as NSNumber: queryString += "&\(key.URLQueryEncoded)=\(number.stringValue.URLQueryEncoded)"
                default: break
                }
            }
        }
        return queryString
    }
    
    init?(subsonicAction action: String, urlString: String, username: String, password: String, parameters: [String: Any]?, byteOffset: Int) {
        var finalUrlString: String
        if action == "hls" {
            finalUrlString = "\(urlString)/rest/\(action).m3u8"
        } else {
            finalUrlString = "\(urlString)/rest/\(action).view"
        }
        var version: String?
        
        // Set the API version for this call by checking the arrays
        // NOTE: I'm always sending whatever URL version this specific API call belongs to, even though that's not really correct. You're supposed to send a single version all the time, and if the server is too old, it will return an error and tell you to upgrade. To provide the greatest compatibility, I always send the lowest possible version number, so only the unsupported API calls return that error rather than all of them.
        // TODO: Actually test this on different Subsonic versions (see what happens when different versions are sent)
        for versionArray in versions {
            if versionArray.contains(action) {
                version = versionArray.last
                break
            }
        }
        assert(version != nil, "Subsonic API call version number not set!")
        
        guard let finalVersion = version else {
            DDLogError("Subsonic API call version number not set!")
            return nil
        }

        let queryString = Self.parseQueryString(parameters: parameters, version: finalVersion, username: username, password: password)
        
        // Handle special case when loading playlists
        var loadingTimeout = 240.0
        if action == "getPlaylist" {
            // Timeout set to 60 mins to prevent timeout errors
            loadingTimeout = 3600.0
        } else if action == "ping" {
            // Short timeout for pings to detect server outages faster
            loadingTimeout = 15.0;
        }
        
        // Create the request
        // TODO: implement this
        // TODO: Either use POST for all requests (I think there was some problem with them for some requests though) or use POST at least for requests that can be very large, for example sending playlist contents or jukebox play queue contents
        finalUrlString += "?\(queryString)"
        guard let url = URL(string: finalUrlString) else {
            DDLogError("[URLRequest] Failed to convert finalUrlString to URL")
            return nil
        }
        
        self.init(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: loadingTimeout)
        
        // Set the HTTP Basic Auth header if needed
        let settings: Settings = Resolver.resolve()
        if settings.isBasicAuthEnabled {
            let authString = "\(username.URLQueryEncoded):\(password.URLQueryEncoded)"
            if let authData = authString.data(using: .utf8) {
                let authValue = "Basic \(authData.base64EncodedString())"
                setValue(authValue, forHTTPHeaderField: "Authorization")
            }
        }
        
        // Add range header if needed
        if byteOffset > 0 {
            setValue("bytes=\(byteOffset)-", forHTTPHeaderField: "Range")
        }
        
        // Turn off request caching
        setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    }
    
    init?(serverId: Int, subsonicAction action: String, parameters: [String: Any]? = nil, byteOffset: Int = 0) {
        let store: Store = Resolver.resolve()
//        let settings: Settings = Resolver.resolve()
//        guard let server = store.server(id: serverId ?? settings.currentServerId) else { return nil }
        guard let server = store.server(id: serverId) else { return nil }
        
        self.init(subsonicAction: action,
                  urlString: server.url.absoluteString,
                  username: server.username,
                  password: server.password,
                  parameters: parameters,
                  byteOffset: byteOffset)
    }
}

// Temporary extra extension for Obj-C
@objc extension NSURLRequest {
    static func request(serverId: Int, subsonicAction action: String, parameters: [String: Any]? = nil, byteOffset: Int = 0) -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: action, parameters: parameters, byteOffset: byteOffset)
    }
}
