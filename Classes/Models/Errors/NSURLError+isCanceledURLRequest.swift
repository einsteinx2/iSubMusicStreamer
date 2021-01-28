//
//  NSURLError+isCanceledURLRequest.swift
//  iSub
//
//  Created by Benjamin Baron on 1/27/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

extension Error {
    var isCanceledURLRequest: Bool {
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
