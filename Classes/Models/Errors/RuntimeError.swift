//
//  RuntimeError.swift
//  iSub
//
//  Created by Benjamin Baron on 1/26/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct RuntimeError: Error {
    let message: String

    var localizedDescription: String {
        return message
    }
}

extension RuntimeError: CustomStringConvertible {
    var description: String {
        "RuntimeError - \(localizedDescription)"
    }
}
