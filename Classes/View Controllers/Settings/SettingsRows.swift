//
//  SettingsRows.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI

extension SettingsRegistry.Item {
    var accessibilityIdentifier: String {
        ui.accessibilityId ?? "options.\(id)"
    }
}

// Renders one registry-driven settings row, dispatching on its metadata kind
struct SettingRow: View {
    let item: SettingsRegistry.Item
    let viewModel: SettingsSectionViewModel

    var body: some View {
        Group {
            switch item.ui.kind {
            case .toggle:
                SettingToggleRow(item: item, viewModel: viewModel)
            case .picker(let labels):
                SettingPickerRow(item: item, viewModel: viewModel, labels: labels, values: Array(labels.indices))
            case .pickerMapped(let labels, let values):
                SettingPickerRow(item: item, viewModel: viewModel, labels: labels, values: values)
            case .percentSlider:
                SettingSliderRow(item: item, viewModel: viewModel)
            }
        }
        .disabled(!viewModel.isEnabled(item))
    }
}

struct SettingToggleRow: View {
    let item: SettingsRegistry.Item
    let viewModel: SettingsSectionViewModel

    @State private var confirmationPresented = false

    var body: some View {
        let value = viewModel.binding(item, default: false)
        if let confirmation = item.ui.confirmation {
            // Turning ON prompts first; canceling leaves the setting off. Turning off
            // never prompts. (Matches the old OptionsViewController warning alerts.)
            Toggle(item.ui.title, isOn: Binding(
                get: { value.wrappedValue },
                set: { newValue in
                    if newValue && !value.wrappedValue {
                        confirmationPresented = true
                    } else {
                        value.wrappedValue = newValue
                    }
                }
            ))
            .accessibilityIdentifier(item.accessibilityIdentifier)
            .alert(confirmation.title, isPresented: $confirmationPresented) {
                Button("OK", role: .destructive) { value.wrappedValue = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(confirmation.message)
            }
        } else {
            Toggle(item.ui.title, isOn: value)
                .accessibilityIdentifier(item.accessibilityIdentifier)
        }
    }
}

struct SettingPickerRow: View {
    let item: SettingsRegistry.Item
    let viewModel: SettingsSectionViewModel
    let labels: [String]
    let values: [Int]

    var body: some View {
        let value = viewModel.binding(item, default: 0)
        Picker(item.ui.title, selection: value) {
            ForEach(values.indices, id: \.self) { index in
                Text(labels[index]).tag(values[index])
            }
            // Tolerate a stored value outside the option list (the old segmented
            // control just showed no selection)
            if !values.contains(value.wrappedValue) {
                Text("\(value.wrappedValue)").tag(value.wrappedValue)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier(item.accessibilityIdentifier)
    }
}

struct SettingSliderRow: View {
    let item: SettingsRegistry.Item
    let viewModel: SettingsSectionViewModel

    var body: some View {
        let value = viewModel.binding(item, default: Float(0))
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.ui.title)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...1)
                .accessibilityIdentifier(item.accessibilityIdentifier)
        }
    }
}
