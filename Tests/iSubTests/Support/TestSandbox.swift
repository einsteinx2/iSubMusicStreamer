//
//  TestSandbox.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import XCTest
@testable import iSub_Beta

// Redirects all FileSystem directories (database, downloads, temp downloads, etc)
// into a unique temporary directory for the duration of a test, then deletes it
final class TestSandbox {
    let root: URL

    init(name: String = UUID().uuidString) {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("iSubTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    func activate() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        FileSystem.rootOverride = root
    }

    func deactivate() throws {
        if FileSystem.rootOverride == root {
            FileSystem.rootOverride = nil
        }
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }
}

// Base class for unit/integration tests that need an isolated file system
// and a fresh dependency injection container per test
class SandboxedTestCase: XCTestCase {
    private(set) var sandbox: TestSandbox!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sandbox = TestSandbox()
        try sandbox.activate()
        TestContainer.activate()
    }

    override func tearDownWithError() throws {
        TestContainer.deactivate()
        try sandbox.deactivate()
        sandbox = nil
        try super.tearDownWithError()
    }
}
