//
//  String+Clean.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

// This is the format that my server seems to reply with
private let iso8601FormatterWithMilliseconds: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .iso8601)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return dateFormatter
}()

// This is the format shown in the documentation
private let iso8601FormatterWithoutTimezone: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .iso8601)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return dateFormatter
}()

private func formatDate(dateString: String) -> Date? {
    iso8601FormatterWithMilliseconds.date(from: dateString) ?? iso8601FormatterWithoutTimezone.date(from: dateString)
}

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
            return formatDate(dateString: self)
        } else {
            return nil
        }
    }
}
