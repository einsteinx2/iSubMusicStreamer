//
//  String+Hex.swift
//  iSub
//
//  Created by Benjamin Baron on 2/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

extension String {
    var hexValue: String? {
        data(using: .utf8)?.map({ String(format: "%X", $0) }).joined()
    }
}
