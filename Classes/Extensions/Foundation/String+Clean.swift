//
//  String+Clean.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

private extension String {
    // NOTE: Presumably Subsonic was sending back some characters using HTML encoding for some reason...but that doesn't seem to be the case anymore
    // NOTE: Previously was using GTMNSString library to string HTML encoding from strings, leaving this here in case it need to be re-enabled
    func clean() -> String {
        //self.gtm_stringByUnescapingFromHTML()?.removingPercentEncoding ?? self
        return self
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
        if let self {
            return Int(self.clean())
        } else {
            return nil
        }
    }
    
    var floatXML: Float {
        floatXMLOptional ?? 0
    }
    var floatXMLOptional: Float? {
        if let self {
            return Float(self.clean())
        } else {
            return nil
        }
    }
    
    var doubleXML: Double {
        doubleXMLOptional ?? 0
    }
    var doubleXMLOptional: Double? {
        if let self {
            return Double(self.clean())
        } else {
            return nil
        }
    }
    
    var boolXML: Bool {
        boolXMLOptional ?? false
    }
    var boolXMLOptional: Bool? {
        if let self {
            return Bool(self.clean())
        } else {
            return nil
        }
    }
    
    var dateXML: Date {
        dateXMLOptional ?? .distantPast
    }
    var dateXMLOptional: Date? {
        if let self {
            return SubsonicDateParsing.date(from: self)
        } else {
            return nil
        }
    }
}
