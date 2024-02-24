//
//  APILoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

protocol CancelableLoader {
    func cancelLoad()
}

// APILoader callback block, make sure to always check success bool, not error, as error can be nil when success is NO
typealias APILoaderCallback = (_ loader: APILoader?, _ success: Bool, _ error: Error?) -> Void

protocol APILoaderDelegate: AnyObject {
    func loadingFinished(loader: APILoader?)
    func loadingFailed(loader: APILoader?, error: Error?)
}

enum APILoaderType: Int {
    case generic            =  0
    case rootFolders        =  1
    case subFolders         =  2
    case chat               =  3
    case chatSend           =  4
    case lyrics             =  5
    case coverArt           =  6
    case serverPlaylists    =  7
    case serverPlaylist     =  8
    case nowPlaying         =  9
    case status             = 10
    case quickAlbums        = 11
    case mediaFolders       = 12
    case serverShuffle      = 13
    case scrobble           = 14
    case rootArtists        = 15
    case tagArtist          = 16
    case tagAlbum           = 17
    case song               = 18
    case search             = 19
}

class APILoader: CancelableLoader {
    static private let sessionDelegate = SelfSignedCertURLSessionDelegate()
    final class var sharedSession: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.networkServiceType = .responsiveData
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 240
        return URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }
    
    var type: APILoaderType { .generic }
    
    weak var delegate: APILoaderDelegate?
    var callback: APILoaderCallback?
    private var dataTask: URLSessionDataTask?
    
    init(delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.delegate = delegate
        self.callback = callback
    }
    
    func createRequest() -> URLRequest? {
        fatalError("[APILoader \(type)] createRequest function MUST be overridden")
    }
    
    func startLoad() {
        guard let request = createRequest() else { return }
        
        // Optional debug logging
        if Debug.apiRequests {
            let urlString = request.url?.absoluteString ?? ""
            let httpBodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "(failed to convert request body data to string)"
            DDLogInfo("[APILoader \(type)] request url: \(urlString)  body: \(httpBodyString)")
        }
        
        // Cancel any existing request
        cancelLoad()
                
        // Load the API endpoint
        dataTask = Self.sharedSession.dataTask(with: request) { data, response, error in
            if let error = error {
                DDLogError("[APILoader \(self.type)] failed: \(error)")
                self.informDelegateLoadingFailed(error: error)
            } else if let data = data {
                // Optional debug logging
                if Debug.apiResponses {
                    let dataString = String(data: data, encoding: .utf8) ?? "(failed to convert response data to string)"
                    DDLogInfo("[APILoader \(self.type)] response: \(dataString)")
                }
                self.processResponse(data: data)
            } else {
                DDLogError("[APILoader \(self.type)] did not receive any data")
                self.informDelegateLoadingFailed(error: APIError.responseNotXML)
            }
        }
        dataTask?.resume()
    }
    
    func cancelLoad() {
        dataTask?.cancel()
        cleanup()
    }
    
    private func cleanup() {
        // Clean up the connection
        dataTask?.cancel()
        dataTask = nil
    }
    
    func processResponse(data: Data) {
        fatalError("[APILoader \(type)] processResponse function MUST be overridden")
    }
    
    func informDelegateLoadingFinished() {
        DispatchQueue.main.async {
            self.delegate?.loadingFinished(loader: self)
            self.callback?(self, true, nil)
            self.cleanup()
        }
    }
    
    func informDelegateLoadingFailed(error: Error?) {
        DispatchQueue.main.async {
            self.delegate?.loadingFailed(loader: self, error: error)
            self.callback?(self, false, error)
            self.cleanup()
        }
    }
}

// Subsonic API validation
extension APILoader {
    // Returns a valid root XML element if it exists
    func validateRoot(data: Data, informDelegate: Bool = true) -> RXMLElement? {
        let root = RXMLElement(fromXMLData: data)
        guard root.isValid else {
            if informDelegate { informDelegateLoadingFailed(error: APIError.responseNotXML) }
            return nil
        }
        guard root.tag == "subsonic-response" else {
            if informDelegate { informDelegateLoadingFailed(error: APIError.serverUnsupported) }
            return nil
        }
        return root
    }
    
    // Returns a valid error XML element if it exists
    func validateSubsonicError(root: RXMLElement, informDelegate: Bool = true) -> RXMLElement? {
        guard let error = root.child("error"), error.isValid else { return nil }
        if informDelegate {
            informDelegateLoadingFailed(error: SubsonicError(element: error))
        }
        return nil
    }
    
    // Convenience function to return a valid root XML element or the Subsonic error if it exists since this is required in every loader
    func validate(data: Data, informDelegate: Bool = true) -> RXMLElement? {
        guard let root = validateRoot(data: data, informDelegate: informDelegate) else { return nil }
        guard validateSubsonicError(root: root, informDelegate: informDelegate) == nil else { return nil }
        return root
    }
    
    // Returns a valid child XML element if it exists
    func validateChild(parent: RXMLElement, childTag: String, informDelegate: Bool = true) -> RXMLElement? {
        guard let child = parent.child(childTag), child.isValid else {
            if informDelegate {
                informDelegateLoadingFailed(error: APIError.responseMissingElement(parent: parent.tag ?? "nil", tag: childTag))
            }
            return nil
        }
        return child
    }
    
    // Returns a valid child XML element if it exists
    func validateAttribute(element: RXMLElement, attribute: String, informDelegate: Bool = true) -> String? {
        guard let value = element.attribute(attribute) else {
            if informDelegate {
                informDelegateLoadingFailed(error: APIError.responseMissingAttribute(tag: element.tag ?? "nil", attribute: attribute))
            }
            return nil
        }
        return value
    }
}
