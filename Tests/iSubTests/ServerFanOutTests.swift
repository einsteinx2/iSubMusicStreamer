//
//  ServerFanOutTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

private struct TestFailure: Error, Equatable {
    let serverId: Int
}

final class ServerFanOutTests: XCTestCase {
    private let servers = [TestData.server(id: 1, urlString: "https://one.example.com"),
                           TestData.server(id: 2, urlString: "https://two.example.com"),
                           TestData.server(id: 3, urlString: "https://three.example.com")]

    func testSuccessesPreserveServerOrderRegardlessOfCompletionOrder() async {
        let result = await ServerFanOut.run(servers: servers) { server in
            // Later servers finish first
            try await Task.sleep(nanoseconds: UInt64((4 - server.id) * 20_000_000))
            return ["item-\(server.id)"]
        }

        XCTAssertEqual(result.successes.map(\.server.id), [1, 2, 3], "results must come back in input order")
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertFalse(result.isTotalFailure)
    }

    func testPartialFailureKeepsTheOtherServersResults() async {
        let result = await ServerFanOut.run(servers: servers) { server in
            if server.id == 2 {
                throw TestFailure(serverId: server.id)
            }
            return ["item-\(server.id)"]
        }

        XCTAssertEqual(result.successes.map(\.server.id), [1, 3])
        XCTAssertEqual(result.failures.map(\.server.id), [2])
        XCTAssertFalse(result.isTotalFailure)
        XCTAssertEqual(result.concatenated(), ["item-1", "item-3"])
    }

    func testTotalFailure() async {
        let result: ServerFanOutResult<[String]> = await ServerFanOut.run(servers: servers) { server in
            throw TestFailure(serverId: server.id)
        }

        XCTAssertTrue(result.isTotalFailure)
        XCTAssertEqual(result.failures.count, 3)
    }

    func testNoServersIsNotATotalFailure() async {
        let result: ServerFanOutResult<[String]> = await ServerFanOut.run(servers: []) { _ in [] }
        XCTAssertFalse(result.isTotalFailure, "an empty fan-out has nothing to fail")
        XCTAssertTrue(result.successes.isEmpty)
    }

    func testInterleavedMergeRoundRobinsUnevenLists() {
        let result = ServerFanOutResult<[String]>(
            successes: [.init(server: servers[0], value: ["a1", "a2", "a3"]),
                        .init(server: servers[1], value: ["b1"]),
                        .init(server: servers[2], value: ["c1", "c2"])],
            failures: [])

        XCTAssertEqual(result.interleaved(), ["a1", "b1", "c1", "a2", "c2", "a3"])
    }

    func testSortedMergeUsesTheComparator() {
        let result = ServerFanOutResult<[Int]>(
            successes: [.init(server: servers[0], value: [3, 1]),
                        .init(server: servers[1], value: [2])],
            failures: [])

        XCTAssertEqual(result.sorted(by: <), [1, 2, 3])
    }

    func testCancellationPropagatesToEveryServerLoad() async {
        let task = Task {
            await ServerFanOut.run(servers: servers) { server -> [String] in
                try await Task.sleep(nanoseconds: 10_000_000_000)
                return ["never-\(server.id)"]
            }
        }
        task.cancel()

        let result = await task.value
        XCTAssertTrue(result.successes.isEmpty, "cancelled loads must not produce values")
        XCTAssertEqual(result.failures.count, 3, "every per-server load observes the cancellation")
    }
}

@MainActor
final class PerServerPagerTests: XCTestCase {
    private let servers = [TestData.server(id: 1, urlString: "https://one.example.com"),
                           TestData.server(id: 2, urlString: "https://two.example.com")]

    // Server 1 has 5 items, server 2 has 2; pure function of (server, offset)
    private static func page(counts: [Int: Int], pageSize: Int) -> @Sendable (Server, Int) async throws -> [String] {
        { server, offset in
            let total = counts[server.id] ?? 0
            guard offset < total else { return [] }
            let end = min(offset + pageSize, total)
            return (offset..<end).map { "s\(server.id)-\($0)" }
        }
    }

    func testRoundRobinPagesWithPerServerOffsetsAndExhaustion() async {
        let pager = PerServerPager(servers: servers, pageSize: 2,
                                   fetchPage: Self.page(counts: [1: 5, 2: 3], pageSize: 2))

        let first = await pager.nextPage()
        XCTAssertEqual(first.items, ["s1-0", "s2-0", "s1-1", "s2-1"])
        XCTAssertTrue(pager.hasMore)

        let second = await pager.nextPage()
        XCTAssertEqual(second.items, ["s1-2", "s2-2", "s1-3"], "server 2's short page exhausts it")
        XCTAssertTrue(pager.hasMore, "server 1 still has a row left")

        let third = await pager.nextPage()
        XCTAssertEqual(third.items, ["s1-4"], "only server 1 is asked once server 2 is exhausted")
        XCTAssertFalse(pager.hasMore)

        let empty = await pager.nextPage()
        XCTAssertTrue(empty.items.isEmpty)
    }

    func testThrowingServerIsDroppedWithoutWedgingHasMore() async {
        let pager = PerServerPager(servers: servers, pageSize: 2) { server, offset -> [String] in
            if server.id == 2 {
                throw TestFailure(serverId: 2)
            }
            return offset == 0 ? ["s1-0", "s1-1"] : ["s1-2"]
        }

        let first = await pager.nextPage()
        XCTAssertEqual(first.items, ["s1-0", "s1-1"])
        XCTAssertEqual(first.failures.map(\.server.id), [2], "the dead server is reported once")
        XCTAssertTrue(pager.hasMore)

        let second = await pager.nextPage()
        XCTAssertEqual(second.items, ["s1-2"])
        XCTAssertTrue(second.failures.isEmpty, "the dead server is not asked again")
        XCTAssertFalse(pager.hasMore)
    }

    func testSingleServerPagerBehavesLikePlainPaging() async {
        let pager = PerServerPager(servers: [servers[0]], pageSize: 2,
                                   fetchPage: Self.page(counts: [1: 3], pageSize: 2))

        let first = await pager.nextPage()
        XCTAssertEqual(first.items, ["s1-0", "s1-1"])
        XCTAssertTrue(pager.hasMore)

        let second = await pager.nextPage()
        XCTAssertEqual(second.items, ["s1-2"])
        XCTAssertFalse(pager.hasMore)
    }

    func testExactMultipleEndsWithAnEmptyFinalPage() async {
        let pager = PerServerPager(servers: [servers[0]], pageSize: 2,
                                   fetchPage: Self.page(counts: [1: 4], pageSize: 2))

        _ = await pager.nextPage()
        _ = await pager.nextPage()
        XCTAssertTrue(pager.hasMore, "a full final page can't prove exhaustion yet")

        let final = await pager.nextPage()
        XCTAssertTrue(final.items.isEmpty)
        XCTAssertFalse(pager.hasMore)
    }
}
