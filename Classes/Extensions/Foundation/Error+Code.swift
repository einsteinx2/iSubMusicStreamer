//
//  Error+Code.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

extension Error {
    var domain: String { (self as NSError).domain }
    var code: Int { (self as NSError).code }
}
