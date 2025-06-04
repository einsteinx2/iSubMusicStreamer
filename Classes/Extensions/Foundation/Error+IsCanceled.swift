//
//  Error+IsCanceled.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

extension Error {
    var isCanceled: Bool {
        return self is CancellationError || ((self as NSError).domain == "NSURLErrorDomain" && (self as NSError).code == -999)
    }
}
