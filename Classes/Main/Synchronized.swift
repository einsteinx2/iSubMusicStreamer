//
//  Synchronized.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

// https://stackoverflow.com/a/34173952/299262
func synchronized<T>(_ lock: AnyObject, _ body: () throws -> T) rethrows -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return try body()
}
