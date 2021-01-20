//
//  CustomStringConvertable+Default.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

// Modified from https://gist.github.com/khramtsoff/ad84ba1b8a2e927c7b19aed5c36d5750
extension CustomStringConvertible {
    var description: String {
        var description: String = "\(type(of: self))("
        
        let selfMirror = Mirror(reflecting: self)
        
        for child in selfMirror.children {
            if let propertyName = child.label {
                description += "\(propertyName): \(child.value), "
            }
        }
        
        if let superclassMirror = selfMirror.superclassMirror {
            for child in superclassMirror.children {
                if let propertyName = child.label {
                    description += "\(propertyName): \(child.value), "
                }
            }
        }
        
        description += "<\(Unmanaged.passUnretained(self as AnyObject).toOpaque())>)"
        
        return description
    }
}
