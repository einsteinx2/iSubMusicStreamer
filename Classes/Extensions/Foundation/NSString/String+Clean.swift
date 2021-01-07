//
//  String+Clean.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

extension Optional where Wrapped == String {
    var stringXML: String {
        stringXMLOptional ?? ""
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
