//
//  Debug.swift
//  iSub
//
//  Created by Ben Baron on 2/24/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation

#if SILENT
struct Debug {
    static var apiRequests = false
    static var apiResponses = false
    static var audioEngine = false
    static var audioEngineStreamQueue = false
    static var streamManager = false
}
#elseif DEBUG
struct Debug {
    static var apiRequests = true
    static var apiResponses = true
    static var audioEngine = false
    static var audioEngineStreamQueue = false
    static var streamManager = false
}
#else
struct Debug {
    static var apiRequests = false
    static var apiResponses = false
    static var audioEngine = false
    static var audioEngineStreamQueue = false
    static var streamManager = false
}
#endif
