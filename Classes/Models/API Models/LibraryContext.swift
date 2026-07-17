//
//  LibraryContext.swift
//  iSub
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Which library the app is operating in: a single server, or the Combined Library
// that merges every saved server. Each context owns its own play queue snapshot,
// local playlists, and bookmarks, keyed by contextId — a server's id (>= 1), or 0
// for the Combined Library. -1 means "no context" (fresh install before any server
// exists) and is also the contextId stamped on the reserved queue playlist rows.
enum LibraryContext: Equatable {
    case server(Server)
    case combined

    static let combinedContextId = 0
    static let noContextId = -1

    var contextId: Int {
        switch self {
        case .server(let server): return server.id
        case .combined: return Self.combinedContextId
        }
    }

    var server: Server? {
        if case .server(let server) = self { return server }
        return nil
    }
}
