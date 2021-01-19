//
//  URL+QueryParameters.swift
//  iSub Release
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

// https://stackoverflow.com/a/45122058/299262
extension URL {
    subscript(queryParam: String) -> String? {
        guard let url = URLComponents(string: absoluteString) else { return nil }
        
        let queryItem = url.queryItems?.first { $0.name == queryParam }
        return queryItem?.value
    }
}
