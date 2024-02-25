//
//  BassEffectDAO.swift
//  iSub
//
//  Created by Ben Baron on 2/24/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

@objc enum BassEffectType: Int {
    case parametricEQ = 1
}

// TODO: Finish testing this implementation and remove all unneeded ObjC interop from the various related classes
final class BassEffectDAO {

    @LazyInjected private var player: BassPlayer
    @LazyInjected private var settings: SavedSettings
    
    static let bassEffectTempCustomPresetId = 1000000
    static let bassEffectUserPresetStartId = 1000
    
    private static let bassEffectSelectedPresetIdKey = "BassEffectSelectedPresetId"
    private static let bassEffectUserPresetsKey = "BassEffectUserPresets"
    
    let type: BassEffectType
    
    private(set) var presets: [BassEffectPreset]
    
    var userPresets: [BassEffectPreset] {
        return presets.filter { $0.presetId >= Self.bassEffectUserPresetStartId }
    }
    
    var userPresetsMinusCustom: [BassEffectPreset] {
        return presets.filter { $0.presetId >= Self.bassEffectUserPresetStartId && $0.presetId != Self.bassEffectTempCustomPresetId }
    }
    
    var selectedPreset: BassEffectPreset? {
        return presets.first { $0.presetId == selectedPresetId }
    }
    
    var selectedPresetId: Int {
        get {
            guard let dict = UserDefaults.standard.object(forKey: Self.bassEffectSelectedPresetIdKey) as? [String: Any],
                  let selectedPresetId = dict["\(type.rawValue)"] as? Int else {
                return -1
            }
            return selectedPresetId
        }
        set {
            guard selectedPresetId != newValue else { return }
            
            var dict = UserDefaults.standard.object(forKey: Self.bassEffectSelectedPresetIdKey) as? [String: Any] ?? [:]
            dict["\(type.rawValue)"] = newValue
            UserDefaults.standard.setValue(dict, forKey: Self.bassEffectSelectedPresetIdKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    var selectedPresetIndex: Int {
        return presets.firstIndex { $0.presetId == selectedPresetId } ?? 0
    }
    
    init(type: BassEffectType) {
        self.type = type
        presets = Self.readAllPresets(type: type)
    }
        
    private static func readDefaultPresets(type: BassEffectType) -> [BassEffectPreset] {
        guard let url = Bundle.main.url(forResource: "BassEffectDefaultPresets", withExtension: "plist") else {
            DDLogError("[BassEffectDAO] Failed to read default presets, the plist file doesn't exist in the main bundle")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try PropertyListDecoder().decode([Int: [Int: BassEffectPreset]].self, from: data)
            if let presets = decoded[type.rawValue] {
                return presets.keys.sorted().map { presets[$0]! }
            }
        } catch {
            DDLogError("[BassEffectDAO] Failed to parse default presets: \(error)")
        }
        
        return []
    }
    
    private static func readUserPresets(type: BassEffectType) -> [BassEffectPreset] {
        guard let dict = UserDefaults.standard.object(forKey: bassEffectUserPresetsKey) as? [String: Any] else { return [] }
        
        do {
            let json = try JSONSerialization.data(withJSONObject: dict)
            let decoded = try JSONDecoder().decode([Int: [Int: BassEffectPreset]].self, from: json)
            if let presets = decoded[type.rawValue] {
                return presets.keys.sorted().map { presets[$0]! }
            }
        } catch {
            DDLogError("[BassEffectDAO] Failed to parse user presets: \(error)")
        }
        
        return []
    }
    
    private static func readAllPresets(type: BassEffectType) -> [BassEffectPreset] {
        return Self.readDefaultPresets(type: type) + Self.readUserPresets(type: type)
    }
    
    func selectCurrentPreset() {
        selectPreset(id: selectedPresetId)
    }
    
    func selectPreset(id: Int) {
        guard let index = presets.firstIndex(where: { $0.presetId == id }) else {
            DDLogError("[BassEffectDAO] Failed to select preset with id \(id) because it doesn't exist")
            return
        }
        
        selectPreset(index: index)
    }
    
    func selectPreset(index: Int) {
        guard index >= 0 && index < presets.count else {
            DDLogError("[BassEffectDAO] Failed to select preset at index \(index) because it doesn't exist")
            return
        }

        let preset = presets[index]
        selectedPresetId = preset.presetId
        
        if type == .parametricEQ {
            player.equalizer.removeAllEqualizerValues()
            
            preset.values.forEach { point in
                let value = BASS_DX8_PARAMEQ(fCenter: exp2f((Float(point.x) * Float(RANGE_OF_EXPONENTS)) + 5),
                                             fBandwidth: Float(DEFAULT_BANDWIDTH),
                                             fGain: Float(0.5 - point.y) * Float(MAX_GAIN * 2))
                player.equalizer.addEqualizerValue(value: value)
            }
            
            if settings.isEqualizerOn {
                player.equalizer.toggleEqualizer()
            }
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.bassEffectPresetLoaded)
    }
    
    func deleteCustomPreset(id: Int) {
        let typeKey = "\(type.rawValue)"
        let idKey = "\(id)"
        
        guard var dict = UserDefaults.standard.object(forKey: Self.bassEffectUserPresetsKey) as? [String: Any],
                var typeDict = dict[typeKey] as? [String: Any], let _ = typeDict.removeValue(forKey: idKey) else {
            DDLogError("[BassEffectDAO] Failed to delete custom preset with id \(id) because it doesn't exist")
            return
        }
        
        if id == selectedPresetId {
            selectedPresetId = 0
        }
        
        dict[typeKey] = typeDict
        UserDefaults.standard.setValue(dict, forKey: Self.bassEffectUserPresetsKey)
        UserDefaults.standard.synchronize()
        
        presets = Self.readAllPresets(type: type)
    }
    
    func deleteCustomPreset(index: Int) {
        guard index >= 0 && index < presets.count else {
            DDLogError("[BassEffectDAO] Failed to delete custom preset at index \(index) because it doesn't exist")
            return
        }
        
        deleteCustomPreset(id: presets[index].presetId)
    }
    
    func deleteTempCustomPreset() {
        deleteCustomPreset(id: Self.bassEffectTempCustomPresetId)
    }
    
    func saveCustomPreset(id: Int, name: String, points: [CGPoint]) {
        selectedPresetId = id
        
        let typeKey = "\(type.rawValue)"
        let idKey = "\(id)"
        
        var dict = UserDefaults.standard.object(forKey: Self.bassEffectUserPresetsKey) as? [String: Any] ?? [:]
        var typeDict = dict[typeKey] as? [String: Any] ?? [:]
        
        let preset: [String: Any] = ["presetId": id,
                                     "name": name,
                                     "values": points.map({ NSCoder.string(for: $0) }),
                                     "isDefault": false]
        typeDict[idKey] = preset
        dict[typeKey] = typeDict
        
        UserDefaults.standard.setValue(dict, forKey: Self.bassEffectUserPresetsKey)
        UserDefaults.standard.synchronize()
        
        presets = Self.readAllPresets(type: type)
    }
    
    func saveCustomPreset(name: String, points: [CGPoint]) {
        var id = Self.bassEffectUserPresetStartId
        if let highestUserPresetId = userPresetsMinusCustom.last?.presetId {
            id = highestUserPresetId + 1
        }
        
        saveCustomPreset(id: id, name: name, points: points)
    }
    
    func saveTempCustomPreset(points: [CGPoint]) {
        saveCustomPreset(id: Self.bassEffectTempCustomPresetId, name: "Custom", points: points)
    }
}

struct BassEffectPreset: Codable {
    let presetId: Int
    let name: String
    let isDefault: Bool
    let values: [CGPoint]
    
    enum CodingKeys: String, CodingKey {
        case presetId
        case name
        case isDefault
        case values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.presetId = try container.decode(Int.self, forKey: .presetId)
        self.name = try container.decode(String.self, forKey: .name)
        self.isDefault = try container.decode(Bool.self, forKey: .isDefault)
        
        let valueStrings = try container.decode([String].self, forKey: .values)
        self.values = valueStrings.map { NSCoder.cgPoint(for: $0) }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.presetId, forKey: .presetId)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.isDefault, forKey: .isDefault)
        
        let valueStrings = self.values.map { NSCoder.string(for: $0) }
        try container.encode(valueStrings, forKey: .values)
    }
}
