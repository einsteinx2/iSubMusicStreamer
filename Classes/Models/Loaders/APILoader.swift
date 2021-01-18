//
//  APILoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

@objc protocol APILoaderDelegate {
    @objc(loadingFinished:)
    func loadingFinished(loader: APILoader?)
    @objc(loadingFailed:error:)
    func loadingFailed(loader: APILoader?, error: NSError?)
}

@objc protocol APILoaderManager {
    func startLoad()
    func cancelLoad()
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
}

@objc class APILoader: NSObject {
    static private let sessionDelegate = SelfSignedCertURLSessionDelegate()
    @objc final class var sharedSession: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 240
        return URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }
    
    @objc weak var delegate: APILoaderDelegate?
    @objc var callback: LoaderCallback?
    
    @objc var type: APILoaderType { .generic }
    
    private var selfRef: APILoader?
    private var dataTask: URLSessionDataTask?
    
    @objc override init() {
        super.init()
    }
    
    @objc init(delegate: APILoaderDelegate?) {
        self.delegate = delegate
        super.init()
    }
    
    @objc init(callback: LoaderCallback?) {
        self.callback = callback
        super.init()
    }
    
    @objc func createRequest() -> URLRequest? {
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
                self.informDelegateLoadingFailed(error: error as NSError)
            } else if let data = data {
                DDLogVerbose("[SUSLoader] loader type: \(self.type.rawValue) response:\n\(String(data: data, encoding: .utf8) ?? "Failed to convert data to string.")")
                self.processResponse(data: data)
            } else {
                DDLogError("[SUSLoader] loader type: \(self.type.rawValue) did not receive any data")
                self.informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
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
    
    @objc func processResponse(data: Data) {
        
    }
    
    @objc func informDelegateLoadingFinished() {
        EX2Dispatch.runInMainThreadAsync {
            self.delegate?.loadingFinished(loader: self)
            self.callback?(true, nil)
            self.cleanup()
        }
    }
    
    @objc func informDelegateLoadingFailed(error: NSError?) {
        EX2Dispatch.runInMainThreadAsync {
            self.delegate?.loadingFailed(loader: self, error: error)
            self.callback?(false, error)
            self.cleanup()
        }
    }
}
