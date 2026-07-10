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
    // Resolver reads its static `root` under its internal (private) lock, but the
    // assignments in activate/deactivate cannot take that lock. Keeping the last few
    // retired containers alive ensures a background thread mid-resolve never has the
    // container deallocated out from under it by the swap.
    private static var retiredRoots = [Resolver]()

    static func activate() {
        retire(Resolver.root)
        Resolver.root = Resolver(child: .main)
    }

    static func deactivate() {
        retire(Resolver.root)
        Resolver.root = .main
    }

    private static func retire(_ root: Resolver) {
        guard root !== Resolver.main else { return }
        retiredRoots.append(root)
        if retiredRoots.count > 2 {
            retiredRoots.removeFirst()
        }
    }

    // Registers an override that resolves to a single cached instance for this test.
    // Each registration gets its own scope cache: re-registering a type replaces the
    // whole registration (and its cache) under Resolver's lock, so it takes effect
    // even if the type was already resolved. A shared cache would instead need a
    // reset() here, and ResolverScopeCache.reset() mutates its dictionary WITHOUT
    // taking Resolver's lock — racing any in-flight background resolve (crashes the
    // test host with a bad access in ResolverScopeCache.resolve).
    @discardableResult
    static func register<Service>(factory: @escaping () -> Service) -> ResolverOptions<Service> {
        return Resolver.root.register { factory() }.scope(ResolverScopeCache())
    }
}
