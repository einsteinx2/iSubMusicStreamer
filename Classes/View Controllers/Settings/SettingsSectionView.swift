//
//  SettingsSectionView.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI
import Resolver

// A registry-driven settings screen: renders the section's rows in declaration order,
// splitting into visual groups after each row that declares a footer. The Downloads
// section additionally splices in the hand-built cache-space row after the cache limit
// type picker.
struct SettingsSectionView: View {
    @State var viewModel: SettingsSectionViewModel

    private var groupedItems: [[SettingsRegistry.Item]] {
        var groups = [[SettingsRegistry.Item]]()
        var current = [SettingsRegistry.Item]()
        for item in viewModel.items {
            current.append(item)
            if item.ui.footer != nil {
                groups.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }
        return groups
    }

    var body: some View {
        let groups = groupedItems
        List {
            ForEach(groups.indices, id: \.self) { index in
                Section {
                    ForEach(groups[index]) { item in
                        SettingRow(item: item, viewModel: viewModel)
                        if item.id == SavedSettings.Key.cachingTypeSetting.rawValue {
                            CacheSpaceRow(cachingType: viewModel.intValue(item))
                                .disabled(!viewModel.isEnabled(item))
                        }
                    }
                } footer: {
                    if let footer = groups[index].last?.ui.footer {
                        Text(footer)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// The min-free-space / max-cache-size editor: a slider over the device's total space
// with an editable size field, plus a free/total space readout. Not registry-driven —
// its bounds come from the file system and it writes one of two settings depending on
// the cache limit type.
struct CacheSpaceRow: View {
    let cachingType: Int

    private let settings: SavedSettings = Resolver.resolve()
    private let downloadsManager: DownloadsManager = Resolver.resolve()

    @State private var sliderValue: Float = 0
    @State private var sizeText = ""
    @State private var totalSpace = 1
    @State private var freeSpace = 0
    @FocusState private var sizeFieldFocused: Bool

    private var isMinFreeSpace: Bool { cachingType == CachingType.minSpace.rawValue }
    private var currentSetting: Int { isMinFreeSpace ? settings.minFreeSpace : settings.maxCacheSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isMinFreeSpace ? "Minimum Free Space" : "Maximum Cache Size")
                Spacer()
                TextField("Size", text: $sizeText)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .foregroundStyle(.secondary)
                    .focused($sizeFieldFocused)
                    .onSubmit { commitText() }
                    .accessibilityIdentifier("options.cacheSpaceField")
            }

            Slider(value: $sliderValue, in: 0...1) { editing in
                if editing {
                    sizeFieldFocused = false
                } else {
                    commitSlider()
                }
            }
            .accessibilityIdentifier("options.cacheSpaceSlider")
            .onChange(of: sliderValue) {
                // Live label update while dragging; the setting commits on release
                sizeText = formatFileSize(bytes: Int(sliderValue * Float(totalSpace)))
            }

            HStack {
                Text("Free: \(formatFileSize(bytes: freeSpace))")
                Spacer()
                Text("Total: \(formatFileSize(bytes: totalSpace))")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .onAppear {
            totalSpace = max(downloadsManager.totalSpace, 1)
            freeSpace = downloadsManager.freeSpace
            reload()
        }
        .onChange(of: cachingType) {
            reload()
        }
    }

    private func reload() {
        sliderValue = Float(currentSetting) / Float(totalSpace)
        sizeText = formatFileSize(bytes: currentSetting)
    }

    private func commitText() {
        guard let size = fileSize(formatted: sizeText) else {
            reload()
            return
        }
        sliderValue = Float(size) / Float(totalSpace)
        commitSlider()
    }

    private func commitSlider() {
        let result = CacheSpaceSliderMath.spaceSetting(sliderValue: sliderValue, totalSpace: totalSpace, freeSpace: freeSpace)
        if isMinFreeSpace {
            settings.minFreeSpace = result.bytes
        } else {
            settings.maxCacheSize = result.bytes
        }
        if let clampedSliderValue = result.clampedSliderValue {
            sliderValue = clampedSliderValue
        }
        sizeText = formatFileSize(bytes: result.bytes)
    }
}
