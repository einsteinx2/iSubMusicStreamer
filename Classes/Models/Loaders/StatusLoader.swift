//
//  StatusLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc final class StatusLoader: APILoader {
    @objc let urlString: String
    @objc let username: String
    @objc let password: String
    
    @objc var isNewSearchSupported = false
    @objc var isVideoSupported = false
    @objc var majorVersion = 0
    @objc var minorVersion = 0
    @objc var versionString: String?
    
    convenience init(server: Server, callback: LoaderCallback? = nil) {
        self.init(urlString: server.url.absoluteString, username: server.username, password: server.password, callback: callback)
    }
    
    convenience init(server: Server, delegate: APILoaderDelegate? = nil) {
        self.init(urlString: server.url.absoluteString, username: server.username, password: server.password, delegate: delegate)
    }
    
    @objc init(urlString: String, username: String, password: String, delegate: APILoaderDelegate?) {
        self.urlString = urlString
        self.username = username
        self.password = password
        super.init(delegate: delegate)
    }
    
    @objc init(urlString: String, username: String, password: String, callback: LoaderCallback?) {
        self.urlString = urlString
        self.username = username
        self.password = password
        super.init(callback: callback)
    }
    
    override var type: APILoaderType { .status }
    
    override func createRequest() -> URLRequest? {
        NSMutableURLRequest(susAction: "ping", urlString: urlString, username: username, password: password, parameters: nil) as URLRequest
    }
    
    override func processResponse(data: Data) {
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ServerCheckFailed)
        } else {
            if root.tag == "subsonic-response" {
                self.versionString = root.attribute("version")
                if let versionString = self.versionString {
                    let splitVersion = versionString.components(separatedBy: ".")
                    if splitVersion.count > 0 {
                        self.majorVersion = Int(splitVersion[0]) ?? 0
                        if self.majorVersion >= 2 {
                            isNewSearchSupported = true
                            isVideoSupported = true
                        }
                        
                        if splitVersion.count > 1 {
                            self.minorVersion = Int(splitVersion[1]) ?? 0
                            if self.majorVersion >= 1 {
                                if self.minorVersion >= 4 {
                                    isNewSearchSupported = true
                                }
                                if self.minorVersion >= 7 {
                                    isVideoSupported = true
                                }
                            }
                        }
                    }
                }
                
                if let error = root.child("error"), error.isValid {
                    let code = error.attribute("code").intXML
                    if code == 40 {
                        // Incorrect credentials, so fail
                        informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_IncorrectCredentials)))
                        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ServerCheckFailed)
                    } else {
                        // This is a Subsonic server, so pass
                        informDelegateLoadingFinished()
                        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ServerCheckPassed)
                    }
                } else {
                    // This is a Subsonic server, so pass
                    informDelegateLoadingFinished()
                    NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ServerCheckPassed)
                }
            } else {
                // This is not a Subsonic server, so fail
                informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotASubsonicServer)))
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ServerCheckFailed)
            }
        }
    }
}
