//
//  PerServerPager.swift
//  iSub
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// One paging cursor per server for merged, load-more lists (Browse album lists,
// search results). Every nextPage() round fetches one page from each non-exhausted
// server concurrently and returns the round's items interleaved round-robin. A
// server that returns a short page is exhausted normally; one that throws is dropped
// for the session (reported in that round's failures) so a dead server can't wedge
// hasMore forever. Single-server screens use a one-server pager, keeping the paging
// logic identical in both modes.
@MainActor
final class PerServerPager<Item> {
    private struct Cursor {
        let server: Server
        var offset = 0
        var isExhausted = false
    }

    private let pageSize: Int
    private let fetchPage: @Sendable (Server, _ offset: Int) async throws -> [Item]
    private var cursors: [Cursor]

    init(servers: [Server], pageSize: Int, fetchPage: @escaping @Sendable (Server, _ offset: Int) async throws -> [Item]) {
        self.pageSize = pageSize
        self.fetchPage = fetchPage
        self.cursors = servers.map { Cursor(server: $0) }
    }

    var hasMore: Bool {
        cursors.contains { !$0.isExhausted }
    }

    func nextPage() async -> (items: [Item], failures: [ServerFanOutResult<[Item]>.Failure]) {
        let activeCursors = cursors.filter { !$0.isExhausted }
        guard !activeCursors.isEmpty else { return ([], []) }

        let offsetsByServerId = Dictionary(uniqueKeysWithValues: activeCursors.map { ($0.server.id, $0.offset) })
        let fetchPage = fetchPage
        let result = await ServerFanOut.run(servers: activeCursors.map(\.server)) { server in
            try await fetchPage(server, offsetsByServerId[server.id] ?? 0)
        }

        for success in result.successes {
            guard let index = cursors.firstIndex(where: { $0.server.id == success.server.id }) else { continue }
            cursors[index].offset += success.value.count
            if success.value.count < pageSize {
                cursors[index].isExhausted = true
            }
        }
        for failure in result.failures {
            guard let index = cursors.firstIndex(where: { $0.server.id == failure.server.id }) else { continue }
            cursors[index].isExhausted = true
        }

        return (result.interleaved(), result.failures)
    }
}
