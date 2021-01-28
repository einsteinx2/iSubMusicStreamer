//
//  String+Clean.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

private extension String {
    // TODO: Investigate what problem I was solving using this process. I know I did it for some reason many years ago, but now I have no idea ¯\_(ツ)_/¯
    // NOTE: Presumably Subsonic was sending back some characters using HTML encoding for some reason...need to confirm that.
    func clean() -> String {
        self.gtm_stringByUnescapingFromHTML()?.removingPercentEncoding ?? self
    }
}

extension Optional where Wrapped == String {
    var stringXML: String {
        stringXMLOptional ?? "nil"
    }
    var stringXMLOptional: String? {
        self?.clean()
    }
    
    var intXML: Int {
        intXMLOptional ?? 0
    }
    var intXMLOptional: Int? {
        if let self = self {
            return Int(self.clean())
        } else {
            return nil
        }
    }
    
    var floatXML: Float {
        floatXMLOptional ?? 0
    }
    var floatXMLOptional: Float? {
        if let self = self {
            return Float(self.clean())
        } else {
            return nil
        }
    }
    
    var boolXML: Bool {
        boolXMLOptional ?? false
    }
    var boolXMLOptional: Bool? {
        if let self = self {
            return Bool(self.clean())
        } else {
            return nil
        }
    }
    
    
}
