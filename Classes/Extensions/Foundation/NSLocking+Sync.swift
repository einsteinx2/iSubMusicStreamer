//
//  NSLocking+Sync.swift
//  iSub
//
//  Created by Ben Baron on 2/25/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation

extension NSLocking {
    func sync<T>(block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}
