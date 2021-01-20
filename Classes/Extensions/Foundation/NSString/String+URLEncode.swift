//
//  String+URLEncode.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc extension NSString {
    var URLQueryEncoded: String {
        return addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self as String
    }
}
