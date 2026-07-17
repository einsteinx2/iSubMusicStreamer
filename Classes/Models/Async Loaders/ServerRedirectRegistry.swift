//
//  ServerRedirectRegistry.swift
//  iSub
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// Per-server redirect URLs negotiated at request time (e.g. the subsonic.org
// redirector). The old design kept ONE redirect string on the session and applied it
// to every server's requests, so a redirect negotiated for server A hijacked server
// B's requests as soon as more than one server was in play (multi-server local
// playlists, Combined Library). Entries survive server switches; they are cleared
// when a server is deleted or its URL is edited.
final class ServerRedirectRegistry {
    private let lock = NSLock()
    private var redirectsByServerId: [Int: String] = [:]

    func redirectUrlString(serverId: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return redirectsByServerId[serverId]
    }

    func clearRedirect(serverId: Int) {
        lock.lock()
        defer { lock.unlock() }
        redirectsByServerId[serverId] = nil
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        redirectsByServerId.removeAll()
    }

    // Called from the shared URLSession delegates (on their delegate queues). The
    // redirecting task is matched to a server by deriving the pre-redirect base URL
    // from its original request — every Subsonic request is "<base>/rest/<action>" —
    // and comparing it to each server's configured URL or its currently recorded
    // redirect (so a chain A→B→C re-matches through B). An unmatched base is dropped
    // rather than guessed: recording it against the wrong server would poison that
    // server's requests.
    func recordRedirect(originalRequestUrl: URL?, redirectedRequestUrl: URL?, knownServers: [Server]) {
        guard let originalBase = Self.baseUrlString(requestUrl: originalRequestUrl) else {
            DDLogError("[ServerRedirectRegistry] Redirecting request, but the original URL is missing or not a Subsonic API URL")
            return
        }
        guard let redirectedBase = Self.baseUrlString(requestUrl: redirectedRequestUrl) else {
            DDLogError("[ServerRedirectRegistry] Redirecting request for \(originalBase), but the redirect URL is unusable")
            return
        }

        lock.lock()
        defer { lock.unlock() }
        let serverId = knownServers.first {
            $0.url.absoluteString == originalBase || redirectsByServerId[$0.id] == originalBase
        }?.id
        guard let serverId else {
            DDLogError("[ServerRedirectRegistry] No server matches redirecting base \(originalBase); ignoring redirect to \(redirectedBase)")
            return
        }
        DDLogInfo("[ServerRedirectRegistry] Recording redirect for server \(serverId) to \(redirectedBase)")
        redirectsByServerId[serverId] = redirectedBase
    }

    // "<base>/rest/<action>" → "<base>" (preserves any path prefix); falls back to
    // scheme://host[:port] for redirect targets that don't keep the /rest/ path
    static func baseUrlString(requestUrl: URL?) -> String? {
        guard let url = requestUrl else { return nil }
        let absolute = url.absoluteString
        if let range = absolute.range(of: "/rest/") {
            return String(absolute[..<range.lowerBound])
        }
        guard let scheme = url.scheme, let host = url.host else { return nil }
        if let port = url.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }
}
