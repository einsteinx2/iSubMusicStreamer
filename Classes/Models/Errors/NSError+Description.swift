//
//  NSError+Description.swift
//  iSub
//
//  Created by Benjamin Baron on 1/27/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

extension NSError {
    override public var description: String {
        "\(domain)(\(code)) - \(localizedDescription)"
    }
}
