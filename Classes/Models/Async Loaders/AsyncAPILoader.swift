//
//  AsyncAPILoader.swift
//  iSub
//
//  Created by Ben Baron on 5/27/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//
//

import Foundation
import CocoaLumberjackSwift

protocol AsyncAPILoadable {
    associatedtype LoadedType
    func load() async throws -> LoadedType
}

enum AsyncAPILoaderType: String {
    case generic
    case rootFolders
    case subFolders
    case chat
    case chatSend
    case lyrics
    case coverArt
    case serverPlaylists
    case serverPlaylist
    case nowPlaying
    case status
    case quickAlbums
    case mediaFolders
    case serverShuffle
    case scrobble
    case rootArtists
    case tagArtist
    case tagAlbum
    case song
    case search
}

fileprivate let defaultSessionDelegate = SelfSignedCertURLSessionDelegate()
fileprivate let defaultSharedSession: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.waitsForConnectivity = true
    configuration.networkServiceType = .responsiveData
    configuration.timeoutIntervalForResource = 60
    configuration.timeoutIntervalForRequest = 240
    return URLSession(configuration: configuration, delegate: defaultSessionDelegate, delegateQueue: nil)
}()

class AsyncAPILoader<T>: AsyncAPILoadable {
    typealias LoadedType = T
    
    var type: APILoaderType { .generic }
    
    var sharedSession: URLSession { defaultSharedSession }
    
    func load() async throws -> LoadedType {
        try Task.checkCancellation()
        guard let request = createRequest() else {
            DDLogError("[AsyncAPILoader] Failed to create URLRequest")
            throw APIError.requestCreation
        }
        
        // Optional debug logging
        if Debug.apiRequests {
            let urlString = request.url?.absoluteString ?? ""
            let httpBodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "(failed to convert request body data to string)"
            DDLogInfo("[APILoader \(type)] request url: \(urlString)  body: \(httpBodyString)")
        }
        
        try Task.checkCancellation()
        let (data, _) = try await sharedSession.data(for: request)
        if Debug.apiResponses {
            let dataString = String(data: data, encoding: .utf8) ?? "(failed to convert response data to string)"
            DDLogInfo("[APILoader \(self.type)] response: \(dataString)")
        }
        
        try Task.checkCancellation()
        return try await processResponse(data: data)
    }
    
    func createRequest() -> URLRequest? {
        fatalError("[APILoader \(type)] createRequest function MUST be overridden")
    }
    
    func processResponse(data: Data) async throws -> T {
        fatalError("[APILoader \(type)] processResponse function MUST be overridden")
    }
}

// Subsonic API validation
extension AsyncAPILoader {
    // Returns a valid root XML element if it exists
    func validateRoot(data: Data) async throws -> RXMLElement? {
        let root = RXMLElement(xmlData: data)
        guard root.isValid else {
            throw APIError.responseNotXML
        }
        guard root.tag == "subsonic-response" else {
            throw APIError.serverUnsupported
        }
        return root
    }
    
    // Returns a valid error XML element if it exists
    func validateSubsonicError(root: RXMLElement) async throws -> RXMLElement? {
        guard let error = root.child("error"), error.isValid else {
            return nil
        }
        throw SubsonicError(element: error)
    }
    
    // Convenience function to return a valid root XML element or the Subsonic error if it exists since this is required in every loader
    func validate(data: Data) async throws -> RXMLElement? {
        guard let root = try await validateRoot(data: data) else {
            return nil
        }
        guard try await validateSubsonicError(root: root) == nil else {
            return nil
        }
        return root
    }
    
    // Returns a valid child XML element if it exists
    func validateChild(parent: RXMLElement, childTag: String) async throws -> RXMLElement? {
        guard let child = parent.child(childTag), child.isValid else {
            throw APIError.responseMissingElement(parent: parent.tag ?? "nil", tag: childTag)
        }
        return child
    }
    
    // Returns a valid child XML element if it exists
    func validateAttribute(element: RXMLElement, attribute: String) async throws -> String? {
        guard let value = element.attribute(attribute) else {
            throw APIError.responseMissingAttribute(tag: element.tag ?? "nil", attribute: attribute)
        }
        return value
    }
}
