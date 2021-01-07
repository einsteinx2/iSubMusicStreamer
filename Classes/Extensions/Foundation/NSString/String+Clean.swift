//
//  String+Clean.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

extension Optional where Wrapped == String {
    var cleanXML: String { self?.clean() ?? "" }
}
