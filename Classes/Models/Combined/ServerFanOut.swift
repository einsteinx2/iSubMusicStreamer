//
//  ServerFanOut.swift
//  iSub
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Task-group fan-out over a set of servers with per-server error tolerance: one slow
// or dead server must not block or fail the others. Successes preserve the input
// server order regardless of completion order; failures carry their server so screens
// can show a "couldn't reach" note with the right labels.
struct ServerFanOutResult<Value> {
    struct Success {
        let server: Server
        let value: Value
    }
    struct Failure {
        let server: Server
        let error: Error
    }

    let successes: [Success]
    let failures: [Failure]

    // At least one server was asked and none answered — the only case that warrants
    // a modal error instead of partial results
    var isTotalFailure: Bool { successes.isEmpty && !failures.isEmpty }
}

enum ServerFanOut {
    // Child tasks inherit the surrounding task, so cancelling the caller's Task (the
    // view controllers' loaderTask pattern) cancels every per-server load
    static func run<Value>(servers: [Server],
                           operation: @escaping @Sendable (Server) async throws -> Value) async -> ServerFanOutResult<Value> {
        await withTaskGroup(of: (Int, Result<Value, Error>).self) { group in
            for (index, server) in servers.enumerated() {
                group.addTask {
                    do {
                        return (index, .success(try await operation(server)))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            var indexedResults = [(Int, Result<Value, Error>)]()
            for await result in group {
                indexedResults.append(result)
            }
            indexedResults.sort { $0.0 < $1.0 }

            var successes = [ServerFanOutResult<Value>.Success]()
            var failures = [ServerFanOutResult<Value>.Failure]()
            for (index, result) in indexedResults {
                switch result {
                case .success(let value):
                    successes.append(.init(server: servers[index], value: value))
                case .failure(let error):
                    failures.append(.init(server: servers[index], error: error))
                }
            }
            return ServerFanOutResult(successes: successes, failures: failures)
        }
    }
}

// Merge strategies for list results. Concatenated keeps whole-server blocks in server
// order (for lists that get re-sorted anyway); interleaved round-robins so every
// server stays visible near the top of relevance- or recency-ordered lists.
extension ServerFanOutResult {
    func concatenated<Element>() -> [Element] where Value == [Element] {
        successes.flatMap(\.value)
    }

    func interleaved<Element>() -> [Element] where Value == [Element] {
        var iterators = successes.map { $0.value.makeIterator() }
        var merged = [Element]()
        var didAppend = true
        while didAppend {
            didAppend = false
            for index in iterators.indices {
                if let element = iterators[index].next() {
                    merged.append(element)
                    didAppend = true
                }
            }
        }
        return merged
    }

    func sorted<Element>(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] where Value == [Element] {
        concatenated().sorted(by: areInIncreasingOrder)
    }
}
