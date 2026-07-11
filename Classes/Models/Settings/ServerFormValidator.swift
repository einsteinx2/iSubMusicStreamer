//
//  ServerFormValidator.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Pure validation for the server add/edit form (unit tested). Replaces the old
// ServerEditViewController.checkURL/checkUsername/checkPassword, fixing the case
// where a URL needed both the scheme prepended and the trailing slash stripped
// (the old code applied only one of the two).
enum ServerFormValidator {
    // Returns the normalized URL string — prepends http:// when no scheme is given
    // and strips a single trailing slash — or nil when empty
    static func normalizeURL(_ raw: String) -> String? {
        guard !raw.isEmpty else { return nil }

        var url = raw
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://\(url)"
        }
        if url.last == "/" {
            url = String(url.prefix(url.count - 1))
        }
        return url
    }

    static func isValidUsername(_ username: String) -> Bool {
        !username.isEmpty
    }

    static func isValidPassword(_ password: String) -> Bool {
        !password.isEmpty
    }
}
