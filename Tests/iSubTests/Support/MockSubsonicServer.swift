//
//  MockSubsonicServer.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
@testable import iSub_Beta

// An in-process mock Subsonic server backed by a URLProtocol stub. Maps Subsonic
// actions (the /rest/<action>.view path component) to canned responses — fixture XML,
// arbitrary bytes, HTTP error codes, or connection errors — and records every request
// (including decoded query/body parameters) for assertions.
//
// Usage:
//     MockSubsonicServer.install()          // in setUp (SandboxedTestCase does not do this)
//     try MockSubsonicServer.stub(.ping, fixture: "XML/ping_success.xml")
//     ...
//     MockSubsonicServer.uninstall()        // in tearDown
enum MockSubsonicServer {
    struct StubResponse {
        var statusCode = 200
        var headers: [String: String] = ["Content-Type": "text/xml; charset=utf-8"]
        var body = Data()
        var connectionError: Error?
        // When true, the response headers and body are delivered but the request
        // never finishes — the transfer stays in-flight until cancelled. Used to
        // test cancellation of active downloads.
        var stall = false
    }

    struct ReceivedRequest {
        let action: String
        let request: URLRequest
        let parameters: [String: [String]]

        // Convenience for single-value parameters
        func parameter(_ name: String) -> String? {
            parameters[name]?.first
        }
    }

    typealias StubHandler = (ReceivedRequest) -> StubResponse

    private static let lock = NSLock()
    private static var stubs = [String: StubResponse]()
    private static var handlers = [String: StubHandler]()
    private static var requests = [ReceivedRequest]()

    static var receivedRequests: [ReceivedRequest] {
        lock.lock(); defer { lock.unlock() }
        return requests
    }

    static func receivedRequests(action: SubsonicAction) -> [ReceivedRequest] {
        receivedRequests.filter { $0.action == action.rawValue }
    }

    // MARK: Lifecycle

    static func install() {
        reset()
        APIURLSession.stubProtocolClasses = [MockSubsonicURLProtocol.self]
        APIURLSession.shared = URLSession(configuration: APIURLSession.ephemeralConfiguration())
    }

    static func uninstall() {
        APIURLSession.stubProtocolClasses = nil
        APIURLSession.shared = APIURLSession.createDefaultSession()
        reset()
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        stubs.removeAll()
        handlers.removeAll()
        requests.removeAll()
    }

    // MARK: Stubbing

    static func stub(_ action: SubsonicAction, fixture relativePath: String) throws {
        stub(action, data: try Fixtures.data(relativePath))
    }

    static func stub(_ action: SubsonicAction, data: Data, statusCode: Int = 200, contentType: String = "text/xml; charset=utf-8") {
        lock.lock(); defer { lock.unlock() }
        stubs[action.rawValue] = StubResponse(statusCode: statusCode, headers: ["Content-Type": contentType], body: data)
    }

    static func stubConnectionError(_ action: SubsonicAction, code: URLError.Code = .cannotConnectToHost) {
        lock.lock(); defer { lock.unlock() }
        stubs[action.rawValue] = StubResponse(connectionError: URLError(code))
    }

    // Delivers the body but never completes, keeping the transfer in-flight
    static func stubStalling(_ action: SubsonicAction, data: Data, contentType: String = "application/octet-stream") {
        lock.lock(); defer { lock.unlock() }
        stubs[action.rawValue] = StubResponse(headers: ["Content-Type": contentType], body: data, stall: true)
    }

    // Dynamic stub: the handler receives the decoded request and returns the response,
    // so one action can answer differently per request (e.g. per folder id in recursion)
    static func stub(_ action: SubsonicAction, handler: @escaping StubHandler) {
        lock.lock(); defer { lock.unlock() }
        handlers[action.rawValue] = handler
    }

    // Convenience builders for handler-based stubs
    static func xmlResponse(_ xml: String) -> StubResponse {
        StubResponse(body: Data(xml.utf8))
    }

    static func xmlResponse(fixture relativePath: String) throws -> StubResponse {
        StubResponse(body: try Fixtures.data(relativePath))
    }

    // MARK: URLProtocol integration

    fileprivate static func response(for received: ReceivedRequest) -> StubResponse? {
        lock.lock(); defer { lock.unlock() }
        if let handler = handlers[received.action] {
            return handler(received)
        }
        return stubs[received.action]
    }

    fileprivate static func record(_ received: ReceivedRequest) {
        lock.lock(); defer { lock.unlock() }
        requests.append(received)
    }

    // The action is the last path component minus its extension: /rest/ping.view -> ping
    fileprivate static func action(from request: URLRequest) -> String {
        (request.url?.lastPathComponent as NSString?)?.deletingPathExtension ?? ""
    }

    // Decodes parameters from the query string (GET) or the form-encoded body (POST).
    // Values are collected into arrays because Subsonic allows repeated keys (e.g. songId).
    fileprivate static func parameters(from request: URLRequest) -> [String: [String]] {
        var raw = request.url?.query ?? ""
        if let bodyData = request.bodyData, let bodyString = String(data: bodyData, encoding: .utf8), !bodyString.isEmpty {
            raw += raw.isEmpty ? bodyString : "&\(bodyString)"
        }
        var parameters = [String: [String]]()
        for pair in raw.components(separatedBy: "&") where !pair.isEmpty {
            let parts = pair.components(separatedBy: "=")
            let name = parts[0].removingPercentEncoding ?? parts[0]
            let value = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : ""
            parameters[name, default: []].append(value)
        }
        return parameters
    }
}

private extension URLRequest {
    // URLSession converts httpBody into a stream before the request reaches a URLProtocol,
    // so read the body back out of the stream
    var bodyData: Data? {
        if let httpBody = httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

final class MockSubsonicURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let action = MockSubsonicServer.action(from: request)
        let received = MockSubsonicServer.ReceivedRequest(
            action: action,
            request: request,
            parameters: MockSubsonicServer.parameters(from: request)
        )
        MockSubsonicServer.record(received)

        guard let stub = MockSubsonicServer.response(for: received) else {
            // Unstubbed action: fail fast so the offending test is obvious
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL, userInfo: [
                NSLocalizedDescriptionKey: "MockSubsonicServer: no stub registered for action '\(action)'"
            ]))
            return
        }

        if let connectionError = stub.connectionError {
            client?.urlProtocol(self, didFailWithError: connectionError)
            return
        }

        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: stub.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        if !stub.stall {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
