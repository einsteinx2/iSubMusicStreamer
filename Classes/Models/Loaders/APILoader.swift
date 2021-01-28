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

@objc protocol APILoaderDelegate {
    @objc(loadingFinished:)
    func loadingFinished(loader: APILoader?)
    @objc(loadingFailed:error:)
    func loadingFailed(loader: APILoader?, error: Error?)
}

@objc enum APILoaderType: Int {
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
    case dropdownFolder     = 12
    case serverShuffle      = 13
    case scrobble           = 14
    case rootArtists        = 15
    case tagArtist          = 16
    case tagAlbum           = 17
    case song               = 18
}

@objc class APILoader: NSObject, CancelableLoader {
    static private let sessionDelegate = SelfSignedCertURLSessionDelegate()
    @objc final class var sharedSession: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.networkServiceType = .responsiveData
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 240
        return URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }
    
    @objc weak var delegate: APILoaderDelegate?
    @objc var callback: LoaderCallback?
    
    @objc var type: APILoaderType { .generic }
    
    private var selfRef: APILoader?
    private var dataTask: URLSessionDataTask?
    
    init(delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.delegate = delegate
        self.callback = callback
        super.init()
    }
    
    func createRequest() -> URLRequest? {
        return nil
    }
    
    @objc func startLoad() {
        guard let request = createRequest() else { return }
        
        // Cancel any existing request
        cancelLoad()
        
        // Keep a strong reference to self to allow loading without saving a loader reference
        if selfRef == nil {
            selfRef = self
        }
        
        // Load the API endpoint
        dataTask = Self.sharedSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                DDLogError("[SUSLoader] loader type: \(self.type.rawValue) failed: \(error)")
                self.informDelegateLoadingFailed(error: error)
            } else if let data = data {
                DDLogVerbose("[SUSLoader] loader type: \(self.type.rawValue) response:\n\(String(data: data, encoding: .utf8) ?? "Failed to convert data to string.")")
                self.processResponse(data: data)
            } else {
                DDLogError("[SUSLoader] loader type: \(self.type.rawValue) did not receive any data")
                self.informDelegateLoadingFailed(error: APIError.responseNotXML)
            }
        }
        dataTask?.resume()
    }
    
    @objc func cancelLoad() {
        dataTask?.cancel()
        cleanup()
    }
    
    private func cleanup() {
        // Clean up the connection
        dataTask = nil
        
        // Remove strong reference to self so the loader can deallocate
        selfRef = nil
    }
    
    func processResponse(data: Data) {
    }
    
    func informDelegateLoadingFinished() {
        DispatchQueue.main.async {
            self.delegate?.loadingFinished(loader: self)
            self.callback?(true, nil)
            self.cleanup()
        }
    }
    
    func informDelegateLoadingFailed(error: Error?) {
        DispatchQueue.main.async {
            self.delegate?.loadingFailed(loader: self, error: error)
            self.callback?(false, error)
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
