//
//  TestContainer.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
@testable import iSub_Beta

// Shadows the app's Resolver registrations (see DependencyInjection.swift) with a
// per-test child container so tests can register fakes without mutating the app's
// container. The app's registrations remain reachable as fallbacks, so anything
// not overridden still resolves normally.
enum TestContainer {
    // Per-activation cache so overridden "singletons" live only for one test
    private static var testScope = ResolverScopeCache()

    static func activate() {
        testScope = ResolverScopeCache()
        Resolver.root = Resolver(child: .main)
    }

    static func deactivate() {
        testScope.reset()
        Resolver.root = .main
    }

    // Registers an override that resolves to a single cached instance for this test
    @discardableResult
    static func register<Service>(factory: @escaping () -> Service) -> ResolverOptions<Service> {
        Resolver.root.register { factory() }.scope(testScope)
    }
}
