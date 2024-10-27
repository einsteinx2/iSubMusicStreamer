//
//  ObjC.swift
//  iSub
//
//  Created by Benjamin Baron on 11/25/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

// Example based on answers in: https://stackoverflow.com/questions/35119531/catch-objective-c-exception-in-swift

import Foundation

public struct NSExceptionError: Error, CustomStringConvertible, @unchecked Sendable {
    public let exception: NSException

    public init(exception: NSException) {
       self.exception = exception
    }
    
    public var description: String {
        return "ObjC exception: \(exception.name): \(exception.reason ?? "")"
    }
}

public struct ObjC {
    public static func perform(workItem: () -> Void) throws {
        if let exception = objcTryBlock(workItem) {
           throw NSExceptionError(exception: exception)
        }
   }
}
