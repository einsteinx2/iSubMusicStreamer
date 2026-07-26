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

enum APILoaderType: String {
    case generic
    case rootFolders
    case subFolders
    case chat
    case chatSend
    case lyrics
    case coverArt
    case serverPlaylists
    case serverPlaylist
    case serverPlaylistCreate
    case serverPlaylistDelete
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

// Central provider of the URLSession used by all API loaders. Tests can replace `shared`
// with a session whose configuration registers a URLProtocol stub (see MockSubsonicServer
// in iSubTests). Code that builds its own session (StreamHandler, Jukebox) creates its
// configuration via ephemeralConfiguration() so the same stubs apply there too.
enum APIURLSession {
    // Test hook: URLProtocol classes inserted into every configuration from ephemeralConfiguration()
    static var stubProtocolClasses: [AnyClass]?

    static func ephemeralConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        if let stubProtocolClasses = stubProtocolClasses {
            configuration.protocolClasses = stubProtocolClasses + (configuration.protocolClasses ?? [])
        }
        return configuration
    }

    static var shared: URLSession = createDefaultSession()

    static func createDefaultSession() -> URLSession {
        let configuration = ephemeralConfiguration()
        configuration.waitsForConnectivity = true
        configuration.networkServiceType = .responsiveData
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 240
        return URLSession(configuration: configuration, delegate: defaultSessionDelegate, delegateQueue: nil)
    }
}

class AsyncAPILoader<T>: AsyncAPILoadable {
    typealias LoadedType = T

    var type: APILoaderType { .generic }

    var sharedSession: URLSession { APIURLSession.shared }
    
    func load() async throws -> LoadedType {
        do {
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
                if type != .coverArt {
                    let dataString = String(data: data, encoding: .utf8) ?? "(failed to convert response data to string)"
                    DDLogInfo("[APILoader \(self.type)] response: \(dataString)")
                }
            }
            
            try Task.checkCancellation()
            return try await processResponse(data: data)
        } catch {
            handleFailure()
            throw error
        }
    }
    
    func createRequest() -> URLRequest? {
        fatalError("[APILoader \(type)] createRequest function MUST be overridden")
    }
    
    func processResponse(data: Data) async throws -> T {
        fatalError("[APILoader \(type)] processResponse function MUST be overridden")
    }
    
    // Optional method to override to do something extra on failure
    func handleFailure() {
        // Default implementation is empty
    }
}

// Format-neutral Subsonic response decoding into the Codable DTO layer. The wire
// format is detected by sniffing, so a server that answers XML despite f=json (or
// vice versa) parses fine with no special-casing.
extension AsyncAPILoader {
    func decodeSubsonicResponse(data: Data) throws -> SubsonicResponse {
        let envelope: SubsonicEnvelope
        do {
            envelope = try SubsonicEnvelope.decode(from: data)
        } catch let error as DecodingError {
            DDLogError("[APILoader \(type)] Failed to decode Subsonic response: \(error)")
            // A parseable document whose top level isn't subsonic-response means we
            // reached something that isn't a Subsonic server
            if case .keyNotFound(let key, let context) = error, key.stringValue == "subsonic-response", context.codingPath.isEmpty {
                throw APIError.serverUnsupported
            }
            throw APIError.responseNotSubsonic
        }
        if let error = envelope.response.error {
            throw SubsonicError(code: error.code, message: error.message ?? "nil")
        }
        return envelope.response
    }

    // Unwraps the endpoint's payload from the response (replaces validateChild)
    func require<P>(_ payload: P?, _ name: String) throws -> P {
        guard let payload else {
            throw APIError.responseMissingElement(parent: "subsonic-response", tag: name)
        }
        return payload
    }
}

