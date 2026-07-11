//
//  SettingsRegistry.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Enumerates the @UserDefault properties of a SavedSettings instance via reflection and
// exposes the ones carrying SettingUI metadata as UI rows. Rows appear in declaration
// order, so within a section the display order is the property order in SavedSettings.
//
// Reading and writing through Item.property is safe even though Mirror hands back a
// copy of the wrapper struct: the wrapper stores nothing on the instance — both
// accessors go straight to UserDefaults, and onChange side effects fire on every
// write path. Build a fresh registry per screen from an injected SavedSettings; never
// cache one statically (tests swap SavedSettings.defaults between cases).
struct SettingsRegistry {
    struct Item: Identifiable {
        // The SavedSettings.Key raw value; unique across all settings
        let id: String
        let ui: SettingUI
        let property: AnySettingProperty
    }

    let items: [Item]
    // Every @UserDefault property (including internal-only ones), for dependsOn lookups
    private let propertiesByKey: [String: AnySettingProperty]

    init(settings: SavedSettings) {
        var items = [Item]()
        var propertiesByKey = [String: AnySettingProperty]()
        for child in Mirror(reflecting: settings).children {
            guard let property = child.value as? AnySettingProperty else { continue }
            propertiesByKey[property.settingKey.rawValue] = property
            if let ui = property.settingUI {
                items.append(Item(id: property.settingKey.rawValue, ui: ui, property: property))
            }
        }
        self.items = items
        self.propertiesByKey = propertiesByKey
    }

    func items(in section: SettingsSection) -> [Item] {
        items.filter { $0.ui.section == section }
    }

    // The current value of a Bool setting by key, respecting its default value when
    // never written (unlike UserDefaults.bool(forKey:) which returns false)
    func boolValue(for key: SavedSettings.Key) -> Bool? {
        propertiesByKey[key.rawValue]?.anyValue() as? Bool
    }
}
