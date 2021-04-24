//
//  SelfSignedCertURLSessionDelegate.swift
//  iSub
//
//  Created by Benjamin Baron on 11/12/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class SelfSignedCertURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Allow self-signed SSL certificates
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url, let scheme = url.scheme, let host = url.host, let port = url.port {
            let settings: Settings = Resolver.resolve()
            let redirectedUrlString = "\(scheme)://\(host):\(port)"
            DDLogInfo("Redirecting to \(redirectedUrlString)")
            settings.currentServerRedirectUrlString = redirectedUrlString
        } else {
            DDLogError("Redirecting request, but url is nil")
        }
        
        completionHandler(request)
    }
}
