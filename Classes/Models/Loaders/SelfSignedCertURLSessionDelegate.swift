//
//  SelfSignedCertURLSessionDelegate.swift
//  iSub
//
//  Created by Benjamin Baron on 11/12/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

final class SelfSignedCertURLSessionDelegate: NSObject, URLSessionDelegate {
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
}
