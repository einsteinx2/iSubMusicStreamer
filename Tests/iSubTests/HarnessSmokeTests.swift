//
//  HarnessSmokeTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import Resolver
@testable import iSub_Beta

final class HarnessSmokeTests: SandboxedTestCase {
    // MARK: File system sandbox

    func testFileSystemDirectoriesRedirectIntoSandbox() {
        XCTAssertTrue(FileSystem.databaseDirectory.path.hasPrefix(sandbox.root.path))
        XCTAssertTrue(FileSystem.downloadsDirectory.path.hasPrefix(sandbox.root.path))
        XCTAssertTrue(FileSystem.tempDownloadsDirectory.path.hasPrefix(sandbox.root.path))
        XCTAssertTrue(FileSystem.applicationSupportDirectory.path.hasPrefix(sandbox.root.path))
    }

    func testSandboxDirectoriesAreCreatedOnAccess() {
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: FileSystem.databaseDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(FileManager.default.fileExists(atPath: FileSystem.downloadsDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testDeactivatedSandboxRestoresRealDirectories() throws {
        let sandboxedPath = FileSystem.databaseDirectory.path
        try sandbox.deactivate()
        XCTAssertFalse(FileSystem.databaseDirectory.path.hasPrefix(sandbox.root.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sandboxedPath))
        // Reactivate so tearDown cleans up normally
        try sandbox.activate()
    }

    // MARK: Fixtures

    func testFixturesFolderIsBundled() throws {
        let readme = try Fixtures.string("README.md")
        XCTAssertTrue(readme.contains("Test Fixtures"))
    }

    func testMissingFixtureThrows() {
        XCTAssertThrowsError(try Fixtures.data("Nonexistent/nope.xml"))
    }

    // MARK: Dependency injection

    func testTestContainerOverrideShadowsAppRegistration() {
        let store = Store()
        TestContainer.register { store }
        XCTAssertTrue(Resolver.resolve(Store.self) === store)
        // The override is cached, so repeated resolution returns the same instance
        XCTAssertTrue(Resolver.resolve(Store.self) === Resolver.resolve(Store.self))
    }

    func testUnregisteredServicesFallBackToAppContainer() {
        // No override registered for PlayQueue, so the app's registration resolves
        XCTAssertNotNil(Resolver.optional(PlayQueue.self))
    }

    func testDeactivateRestoresAppContainer() {
        let store = Store()
        TestContainer.register { store }
        TestContainer.deactivate()
        XCTAssertFalse(Resolver.resolve(Store.self) === store)
        // Reactivate so tearDown's deactivate is balanced
        TestContainer.activate()
    }
}
