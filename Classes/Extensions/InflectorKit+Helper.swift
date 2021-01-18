//
//  InflectorKit+Helper.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import InflectorKit

import Foundation

@objc extension NSString {
    func pluralize(amount: Int) -> NSString {
        return amount == 1 ? self : pluralized as NSString
    }
}


