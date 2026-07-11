//
//  SettingsSectionViewModel.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI
import Resolver

// Backs every registry-driven settings screen. Values live in UserDefaults (via the
// @UserDefault wrappers), so instead of mirroring them into published properties this
// exposes Bindings whose getters read changeToken — any write (local or external)
// bumps the token and @Observable re-renders exactly the rows that read it.
@Observable final class SettingsSectionViewModel {
    let section: SettingsSection

    @ObservationIgnored @Injected private var settings: SavedSettings
    @ObservationIgnored private lazy var registry = SettingsRegistry(settings: settings)

    // Bumped on every binding write and on external UserDefaults changes (e.g.
    // isForceOfflineMode flipped by NetworkMonitor while this screen is visible)
    private var changeToken = 0
    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?

    var items: [SettingsRegistry.Item] {
        _ = changeToken
        return registry.items(in: section)
    }

    init(section: SettingsSection) {
        self.section = section
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                  object: nil,
                                                                  queue: .main) { [weak self] _ in
            self?.changeToken += 1
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    // A SwiftUI binding to a setting's value. Writes go through the type-erased
    // wrapper so onChange side effects fire; no side-effect logic lives in the UI.
    func binding<V>(_ item: SettingsRegistry.Item, default defaultValue: V) -> Binding<V> {
        Binding(
            get: { [weak self] in
                if let self { _ = self.changeToken }
                return item.property.anyValue() as? V ?? defaultValue
            },
            set: { [weak self] newValue in
                item.property.setAnyValue(newValue)
                self?.changeToken += 1
            }
        )
    }

    func intValue(_ item: SettingsRegistry.Item) -> Int {
        _ = changeToken
        return item.property.anyValue() as? Int ?? 0
    }

    // dependsOn support: a row is disabled while the Bool setting it depends on is false
    func isEnabled(_ item: SettingsRegistry.Item) -> Bool {
        guard let key = item.ui.dependsOn else { return true }
        _ = changeToken
        return registry.boolValue(for: key) ?? true
    }
}
