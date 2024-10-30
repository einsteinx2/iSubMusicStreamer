//
//  EqualizerViewController.swift
//  iSub
//
//  Created by Ben Baron on 2/24/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class EqualizerViewController: UIViewController {
    
    @Injected private var settings: SavedSettings
    @Injected private var analytics: Analytics
    
    let closeButton = UIButton(type: .close)
    var overlay: UIView?
    let dismissButton = UIButton(type: .custom)
    @IBOutlet var controlsContainer: UIView!
    var isPresetPickerShowing = false
    let presetPicker = UIPickerView()
    let presetPickerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    @IBOutlet var presetLabel: UILabel!
    @IBOutlet var toggleButton: UIButton!
    @IBOutlet var equalizerSeparatorLine: UIView!
    @IBOutlet var equalizerPath: EqualizerPathView!
    @IBOutlet var equalizerView: EqualizerView?
    var equalizerPointViews = [EqualizerPointView]()
    @IBOutlet var gainSlider: SnappySlider!
    @IBOutlet var gainBoostAmountLabel: UILabel!
    @IBOutlet var gainBoostLabel: UILabel!
    var lastGainValue: Float = 0
    var effectDAO = BassEffectDAO(type: .parametricEQ)
    var selectedView: EqualizerPointView?
    let deletePresetButton = UIButton(type: .roundedRect)
    let savePresetButton = UIButton(type: .roundedRect)
    var isSavePresetButtonShowing = false
    var isDeletePresetButtonShowing = false
    var saveDialog: DDSocialDialog?
    var wasVisualizerOffBeforeRotation = false
    let swipeDetectorLeft: UISwipeGestureRecognizer = { UISwipeGestureRecognizer(target: EqualizerViewController.self, action: #selector(swipeLeft)) }()
    let swipeDetectorRight: UISwipeGestureRecognizer = { UISwipeGestureRecognizer(target: EqualizerViewController.self, action: #selector(swipeRight)) }()
    @IBOutlet var landscapeButtonsHolder: UIView!
    


    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {        
        coordinator.animate { context in
            if UIApplication.orientation.isPortrait {
                self.navigationController?.isNavigationBarHidden = false
                
                self.equalizerSeparatorLine.alpha = 1.0
                self.equalizerPath.alpha = 1.0
                self.equalizerView?.frame = self.equalizerPath.frame
                for eqPointview in self.equalizerPointViews {
                    eqPointview.alpha = 1.0
                }
                
                let device = UIDevice.current
                if device.batteryState != .charging && device.batteryState != .full {
                    if self.settings.isScreenSleepEnabled {
                        UIApplication.shared.isIdleTimerDisabled = false
                    }
                }
                
                if !UIDevice.isPad {
                    self.controlsContainer.alpha = 1.0
                    self.controlsContainer.isUserInteractionEnabled = true
                    
                    if self.wasVisualizerOffBeforeRotation {
                        self.equalizerView?.changeType(.none)
                    }
                }
            } else {
                self.navigationController?.isNavigationBarHidden = true
                
                self.equalizerSeparatorLine.alpha = 0.0
                self.equalizerPath.alpha = 0.0
                self.equalizerView?.frame = self.view.bounds
                for eqPointview in self.equalizerPointViews {
                    eqPointview.alpha = 0.0
                }
                
                UIApplication.shared.isIdleTimerDisabled = true
                
                if !UIDevice.isPad {
                    self.dismissPicker()
                    
                    self.controlsContainer.alpha = 0.0
                    self.controlsContainer.isUserInteractionEnabled = false
                    
                    self.wasVisualizerOffBeforeRotation = (self.equalizerView?.visualizerType == VisualizerType.none)
                    if self.wasVisualizerOffBeforeRotation {
                        self.equalizerView?.nextType()
                    }
                }
            }
        }
        
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overrideUserInterfaceStyle = .dark
        
        toggleButton.layer.masksToBounds = true
        toggleButton.layer.cornerRadius = 2
        
        presetLabel.superview?.layer.cornerRadius = 4
        presetLabel.superview?.layer.masksToBounds = true
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(showPresetPicker))
        presetLabel.superview?.addGestureRecognizer(recognizer)
        
        isSavePresetButtonShowing = false
        let f = self.presetLabel.superview?.frame ?? .zero
        savePresetButton.frame = CGRectMake(f.origin.x + f.size.width - 65, f.origin.y, 60, 30)
        savePresetButton.setTitle("Save", for: .normal)
        savePresetButton.addTarget(self, action: #selector(promptToSaveCustomPreset), for: .touchUpInside)
        savePresetButton.alpha = 0
        savePresetButton.isEnabled = false
        savePresetButton.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin]
        controlsContainer.addSubview(savePresetButton)

        deletePresetButton.frame = CGRectMake(f.origin.x + f.size.width - 65, f.origin.y, 60, 30)
        deletePresetButton.setTitle("Delete", for: .normal)
        deletePresetButton.addTarget(self, action: #selector(promptToDeleteCustomPreset), for: .touchUpInside)
        deletePresetButton.alpha = 0
        deletePresetButton.isEnabled = false
        deletePresetButton.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin]
        controlsContainer.addSubview(deletePresetButton)

        if BassPlayer.shared.equalizer.equalizerValues.count == 0 {
            effectDAO.selectCurrentPreset()
        }

        updatePresetPicker()
        updateToggleButton()
        equalizerView?.startEqDisplay()

        let detents: [Float] = [1.0, 2.0, 3.0]
        gainSlider.snapDistance = 0.13
        gainSlider.detents = detents
        gainSlider.value = settings.gainMultiplier
        lastGainValue = gainSlider.value
        gainBoostAmountLabel.text = String(format: "%.1fx", gainSlider.value)

        if UIDevice.isPad {
            gainSlider.frame.origin.y += 7
            gainBoostLabel.frame.origin.y += 7
            gainBoostAmountLabel.frame.origin.y += 7
            savePresetButton.frame.origin.y -= 10
            deletePresetButton.frame.origin.y -= 10
        }
        
        controlsContainer.bringSubviewToFront(savePresetButton)
        controlsContainer.bringSubviewToFront(deletePresetButton)
        
        savePresetButton.frame.origin.x -= 5
        deletePresetButton.frame.origin.x -= 5
        
        if UIApplication.orientation.isLandscape && !UIDevice.isPad {
            controlsContainer.alpha = 0.0
            controlsContainer.isUserInteractionEnabled = false
            
            wasVisualizerOffBeforeRotation = (equalizerView?.visualizerType == VisualizerType.none)
            if wasVisualizerOffBeforeRotation {
                equalizerView?.nextType()
            }
        }
                
        swipeDetectorLeft.direction = .left
        equalizerView?.addGestureRecognizer(swipeDetectorLeft)

        swipeDetectorRight.direction = .right
        equalizerView?.addGestureRecognizer(swipeDetectorRight)
        
        if isBeingPresented {
            closeButton.frame.origin = CGPoint(x: 20, y: 20)
            closeButton.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
            closeButton.addTarget(self, action: #selector(dismiss(_:)), for: .touchUpInside)
            view.addSubview(closeButton)
        }
        
        analytics.log(event: .equalizer)
    }
    
    @objc func swipeLeft() {
        if UIApplication.orientation.isLandscape {
            equalizerView?.nextType()
        }
    }
    
    @objc func swipeRight() {
        if UIApplication.orientation.isLandscape {
            equalizerView?.prevType()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        createEqViews()
        
        if !UIDevice.isPad && UIApplication.orientation.isLandscape {
            equalizerPath.alpha = 0
            
            for eqPointView in equalizerPointViews {
                eqPointView.alpha = 0
            }
        }
        
        navigationController?.navigationBar.isHidden = UIApplication.orientation.isLandscape
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(createEqViews), name: Notifications.bassEffectPresetLoaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(dismissPicker), name: NSNotification.Name(rawValue: "hidePresetPicker"))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if settings.isShouldShowEQViewInstructions {
            let message = "Double tap to create a new EQ point and double tap any existing EQ points to remove them."
            let alert = UIAlertController(title: "Instructions", message: message, preferredStyle: .alert)
            alert.addAction(title: "Don't Show Again", style: .destructive) { _ in
                self.settings.isShouldShowEQViewInstructions = false
            }
            alert.addCancelAction()
            present(alert, animated: true)
        }
    }
    
    func createAndDrawEqualizerPath() {
        equalizerPath.points = equalizerPointViews.map { $0.center }
    }
    
    @objc func createEqViews() {
        removeEqViews()
            
        equalizerPointViews = BassPlayer.shared.equalizer.equalizerValues.map { eqValue in
            let eqView = EqualizerPointView(eqValue: eqValue, parentSize: equalizerView?.frame.size ?? .zero)
            view.insertSubview(eqView, aboveSubview: equalizerPath)
            return eqView
        }
        
        createAndDrawEqualizerPath()
    }
    
    func removeEqViews() {
        equalizerPointViews.forEach { $0.removeFromSuperview() }
        equalizerPointViews.removeAll()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.bassEffectPresetLoaded)
        NotificationCenter.removeObserverOnMainThread(self, name: Notification.Name(rawValue: "hidePresetPicker"))
        removeEqViews()
        equalizerView?.stopEqDisplay()
        equalizerView?.removeFromSuperview()
        equalizerView = nil
        BassPlayer.shared.visualizer.type = .none
        navigationController?.navigationBar.isHidden = false
    }
    
    func hideSavePresetButton(animated: Bool) {
        isSavePresetButtonShowing = false
        if animated {
            UIView.animate(withDuration: 0.5) {
                self.presetLabel.superview?.frame.size.width = 300
                self.savePresetButton.alpha = 0
            }
        } else {
            presetLabel.superview?.frame.size.width = 300
            savePresetButton.alpha = 0
        }
        savePresetButton.isEnabled = false
    }
    
    func showSavePresetButton(animated: Bool) {
        hideDeletePresetButton(animated: false)
        isSavePresetButtonShowing = true
        savePresetButton.isEnabled = true
        
        if animated {
            UIView.animate(withDuration: 0.5) {
                self.presetLabel.superview?.frame.size.width = 300 - 70
                self.savePresetButton.alpha = 1
            }
        } else {
            presetLabel.superview?.frame.size.width = 300 - 70
            savePresetButton.alpha = 1
        }
    }
    
    func hideDeletePresetButton(animated: Bool) {
        isDeletePresetButtonShowing = false
        if animated {
            UIView.animate(withDuration: 0.5) {
                self.presetLabel.superview?.frame.size.width = 300
                self.deletePresetButton.alpha = 0
            }
        } else {
            presetLabel.superview?.frame.size.width = 300
            deletePresetButton.alpha = 0
        }
        deletePresetButton.isEnabled = false
    }
    
    func showDeletePresetButton(animated: Bool) {
        hideSavePresetButton(animated: false)
        isDeletePresetButtonShowing = true
        deletePresetButton.isEnabled = true
        if animated {
            UIView.animate(withDuration: 0.5) {
                self.presetLabel.superview?.frame.size.width = 300 - 70
                self.deletePresetButton.alpha = 1
            }
        } else {
            presetLabel.superview?.frame.size.width = 300 - 70
            deletePresetButton.alpha = 1
        }
    }
    
    func eqPoints() -> [CGPoint] {
        return equalizerPointViews.map { $0.position }
    }
    
    func saveTempCustomPreset() {
        effectDAO.saveTempCustomPreset(points: eqPoints())
        updatePresetPicker()
    }
    
    @objc func promptToDeleteCustomPreset() {
        // TODO: Better default name
        let presetName = effectDAO.selectedPreset?.name ?? ""
        let title = "\"\(presetName)\""
        let message = "Are you sure you want to delete this preset?"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(title: "Delete", style: .destructive) { _ in
            self.effectDAO.deleteCustomPreset(id: self.effectDAO.selectedPresetId)
            self.updatePresetPicker()
            self.presetPicker.selectRow(0, inComponent: 0, animated: false)
            self.pickerView(self.presetPicker, didSelectRow: 0, inComponent: 0)
        }
        alert.addCancelAction()
        present(alert, animated: true)
    }

    @objc func promptToSaveCustomPreset() {
        if effectDAO.userPresetsMinusCustom.count > 0 {
            if let saveDialog = DDSocialDialog(frame: CGRect(x: 0, y: 0, width: 300, height: 300), theme: DDSocialDialogThemeISub) {
                saveDialog.titleLabel.text = "Choose Preset To Save"
                let saveTable = UITableView(frame: saveDialog.contentView.frame, style: .plain)
                saveTable.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                saveTable.dataSource = self
                saveTable.delegate = self
                saveDialog.contentView.addSubview(saveTable)
                self.saveDialog = saveDialog
                saveDialog.show()
            }
        } else {
            promptForSavePresetName()
        }
    }
    
    func promptForSavePresetName() {
        let alert = UIAlertController(title: "Create Preset", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Preset name"
        }
        alert.addAction(title: "Save", style: .default) { _ in
            // TODO: Better default name
            let name = alert.textFields?.first?.text ?? ""
            self.effectDAO.saveCustomPreset(name: name, points: self.eqPoints())
            self.effectDAO.deleteTempCustomPreset()
            self.updatePresetPicker()
        }
        alert.addCancelAction()
        present(alert, animated: true)
    }
    
    @IBAction func movedGainSlider(_ sender: Any?) {
        let gainValue = gainSlider.value
        let minValue = gainSlider.minimumValue
        let maxValue = gainSlider.maximumValue
        
        settings.gainMultiplier = gainValue
        BassPlayer.shared.equalizer.gain = gainValue
        
        let difference = abs(gainValue - lastGainValue)
        if difference >= 0.1 || gainValue == minValue || gainValue == maxValue {
            gainBoostAmountLabel.text = String(format: "%.1fx", gainValue)
            lastGainValue = gainValue
        }
    }
    
    // MARK:  Touch gestures interception
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Detect touch anywhere
        guard let touch = touches.first, let touchedView = view.hitTest(touch.location(in: view), with: nil) else { return }

        if let pointView = touchedView as? EqualizerPointView {
            selectedView = pointView;
            
            if touch.tapCount == 2 {
                // Remove the point
                BassPlayer.shared.equalizer.removeEqualizerValue(value: pointView.eqValue)
                equalizerPointViews.removeAll { $0 == pointView }
                pointView.removeFromSuperview()
                selectedView = nil
                
                createAndDrawEqualizerPath()
            }
        } else if let eqView = touchedView as? EqualizerView, touch.tapCount == 2 {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(type(_:)), object: nil)
            
            // Only create EQ points in portrait mode when EQ is visible
            if UIDevice.isPad || UIApplication.orientation.isPortrait {
                // Add a point
                
                // Find the tap point
                let point = touch.location(in: eqView)
                
                // Create the eq view
                let pointView = EqualizerPointView(point: point, parentSize: eqView.bounds.size)
                let eqValue = BassPlayer.shared.equalizer.addEqualizerValue(value: pointView.eqValue.parameters)
                pointView.eqValue = eqValue

                // Add the view
                equalizerPointViews.append(pointView)
                view.addSubview(pointView)

                createAndDrawEqualizerPath()
                
                saveTempCustomPreset()
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let selectedView = selectedView, let equalizerView = equalizerView, let touch = touches.first else { return }
        
        let location = touch.location(in: equalizerView)
        if CGRectContainsPoint(equalizerView.frame, location) {
            selectedView.center = touch.location(in: view)
            BassPlayer.shared.equalizer.updateEqParameter(value: selectedView.eqValue)
            createAndDrawEqualizerPath()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let selectedView = selectedView else { return }
        
        BassPlayer.shared.equalizer.updateEqParameter(value: selectedView.eqValue)
        self.selectedView = nil
        saveTempCustomPreset()
    }
    
    @IBAction func dismiss(_ sender: Any?) {
        if let navigationController = navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    @IBAction func toggle(_ sender: Any?) {
        if BassPlayer.shared.equalizer.toggleEqualizer() {
            removeEqViews()
            createEqViews()
        }
        updateToggleButton()
        equalizerPath.setNeedsDisplay()
    }
    
    func updateToggleButton() {
        if settings.isEqualizerOn {
            toggleButton.setTitle("EQ is ON", for: .normal)
            toggleButton.backgroundColor = UIColor(white: 1, alpha: 0.25)
        } else {
            toggleButton.setTitle("EQ is OFF", for: .normal)
            toggleButton.backgroundColor = .clear
        }
    }
    
    @IBAction func type(_ sender: Any?) {
        equalizerView?.nextType()
    }
}

// MARK: Preset Picker

extension EqualizerViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func updatePresetPicker() {
        let selectedPreset = effectDAO.selectedPreset
        presetPicker.reloadAllComponents()
        presetPicker.selectRow(effectDAO.selectedPresetIndex, inComponent: 0, animated: true)
        presetLabel.text = selectedPreset?.name as? String
    }
    
    @objc func showPresetPicker() {
        guard let controlsContainer = controlsContainer, let equalizerView = equalizerView, !isPresetPickerShowing else { return }
        
        isPresetPickerShowing = true
        
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.80)
        overlay.alpha = 0.0
        view.insertSubview(overlay, belowSubview: controlsContainer)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.overlay = overlay
        
        dismissButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dismissButton.addTarget(self, action: #selector(dismissPicker), for: .touchUpInside)
        dismissButton.frame = equalizerView.frame
        dismissButton.isEnabled = false
        overlay.addSubview(dismissButton)
        
        presetPicker.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height - equalizerView.frame.height)
        presetPicker.dataSource = self
        presetPicker.delegate = self

        presetPickerBlurView.frame = CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: view.frame.height - equalizerView.frame.height)
        presetPickerBlurView.contentView.addSubview(presetPicker)
        view.addSubview(presetPickerBlurView)
        view.bringSubviewToFront(overlay)
        view.bringSubviewToFront(presetPickerBlurView)
        updatePresetPicker()

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            overlay.alpha = 1
            self.dismissButton.isEnabled = true
            self.presetPickerBlurView.frame.origin.y = equalizerView.frame.height
        }
    }
    
    @objc func dismissPicker() {
        guard isPresetPickerShowing else { return }
        
        presetPicker.resignFirstResponder()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.overlay?.alpha = 0
            self.dismissButton.isEnabled = false
            self.presetPickerBlurView.frame.origin.y = self.view.frame.height
        } completion: { _ in
            self.presetPicker.removeFromSuperview()
            self.presetPickerBlurView.removeFromSuperview()
            self.dismissButton.removeFromSuperview()
            self.overlay?.removeFromSuperview()
            self.overlay = nil
            self.isPresetPickerShowing = false
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        effectDAO.selectPreset(index: row)
        
        let isDefault = effectDAO.selectedPreset?.isDefault ?? false
        if effectDAO.selectedPresetId == BassEffectDAO.bassEffectTempCustomPresetId && !isSavePresetButtonShowing {
            showSavePresetButton(animated: true)
        } else if effectDAO.selectedPresetId != BassEffectDAO.bassEffectTempCustomPresetId && isSavePresetButtonShowing {
            hideSavePresetButton(animated: true)
        }
    
        if effectDAO.selectedPresetId != BassEffectDAO.bassEffectTempCustomPresetId && !isDeletePresetButtonShowing && !isDefault {
            showDeletePresetButton(animated: true)
        } else if (effectDAO.selectedPresetId == BassEffectDAO.bassEffectTempCustomPresetId || isDefault) && isDeletePresetButtonShowing {
            hideDeletePresetButton(animated: true)
        }
        
        updatePresetPicker()
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return effectDAO.presets[row].name
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return effectDAO.presets.count
    }
}

// MARK: TableView delegate for save dialog

extension EqualizerViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return effectDAO.userPresetsMinusCustom.count
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "NoReuse")
        switch indexPath.section {
        case 0: 
            cell.textLabel?.text = "New Preset"
        case 1:
            let preset = effectDAO.userPresetsMinusCustom[indexPath.row]
            cell.tag = preset.presetId
            cell.textLabel?.text = preset.name
        default:
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch (section) {
        case 1: return "Saved Presets"
        default: return ""
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            // Save a new preset
            promptForSavePresetName()
        } else {
            // Save over an existing preset
            let currentTableCell = self.tableView(tableView, cellForRowAt: indexPath)
            // TODO: Better default name
            effectDAO.saveCustomPreset(id: currentTableCell.tag, name: currentTableCell.textLabel?.text ?? "", points: eqPoints())
            effectDAO.deleteTempCustomPreset()
            updatePresetPicker()
        }
        saveDialog?.dismiss(true)
    }
}
