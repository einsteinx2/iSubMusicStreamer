//
//  OptionsViewController.swift
//  iSub
//
//  Created by Ben Baron on 2/26/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

final class OptionsViewController: UIViewController {
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var store: Store
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var scrollViewContents: UIView!
    
    @IBOutlet var versionLabel: UILabel!
    @IBOutlet var manualOfflineModeSwitch: UISwitch!
    @IBOutlet var autoReloadArtistSwitch: UISwitch!
    @IBOutlet var disablePopupsSwitch: UISwitch!
    @IBOutlet var disableRotationSwitch: UISwitch!
    @IBOutlet var disableScreenSleepSwitch: UISwitch!
    @IBOutlet var enableBasicAuthSwitch: UISwitch!
    @IBOutlet var disableCellUsageSwitch: UISwitch!
    @IBOutlet var recoverSegmentedControl: UISegmentedControl!
    @IBOutlet var maxBitrateWifiSegmentedControl: UISegmentedControl!
    @IBOutlet var maxBitrate3GSegmentedControl: UISegmentedControl!
    @IBOutlet var enableManualCachingOnWWANLabel: UILabel!
    @IBOutlet var enableManualCachingOnWWANSwitch: UISwitch!
    @IBOutlet var enableSongCachingLabel: UILabel!
    @IBOutlet var enableSongCachingSwitch: UISwitch!
    @IBOutlet var enableNextSongCacheLabel: UILabel!
    @IBOutlet var enableNextSongCacheSwitch: UISwitch!
    @IBOutlet var enableBackupCacheLabel: UILabel!
    @IBOutlet var enableBackupCacheSwitch: UISwitch!
    @IBOutlet var cachingTypeSegmentedControl: UISegmentedControl!
    var totalSpace: Int = 0
    var freeSpace: Int = 0
    @IBOutlet var cacheSpaceLabel1: UILabel!
    @IBOutlet var cacheSpaceLabel2: UITextField!
    @IBOutlet var freeSpaceLabel: UILabel!
    @IBOutlet var totalSpaceLabel: UILabel!
    @IBOutlet var totalSpaceBackground: UIView!
    @IBOutlet var freeSpaceBackground: UIView!
    @IBOutlet var cacheSpaceSlider: UISlider!
    @IBOutlet var autoDeleteCacheSwitch: UISwitch!
    @IBOutlet var autoDeleteCacheTypeSegmentedControl: UISegmentedControl!
    @IBOutlet var cacheSongCellColorSegmentedControl: UISegmentedControl!
    @IBOutlet var enableScrobblingSwitch: UISwitch!
    @IBOutlet var scrobblePercentLabel: UILabel!
    @IBOutlet var scrobblePercentSlider: UISlider!
    @IBOutlet var quickSkipSegmentControl: UISegmentedControl!
    @IBOutlet var enableLockScreenArt: UISwitch!
    @IBOutlet var enableLockArtLabel: UILabel!
    @IBOutlet var maxVideoBitrateWifiSegmentedControl: UISegmentedControl!
    @IBOutlet var maxVideoBitrate3GSegmentedControl: UISegmentedControl!
    var loadedTime: Date = Date()
    @IBOutlet var resetAlbumArtCacheButton: UIButton!
    @IBOutlet var shareLogsButton: UIButton!
    @IBOutlet var openSourceLicensesButton: UIButton!
    @IBOutlet var switches: [UISwitch]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollViewContents.frame.size.width = view.frame.width
        
        scrollView.isScrollEnabled = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentSize = scrollViewContents.frame.size
        scrollView.addSubview(scrollViewContents)
        
        // Set version label
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "???"
        let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] ?? "???"
        versionLabel.text = "iSub \(version) build \(build)"
        
        // Main Settings
        enableScrobblingSwitch.isOn = settings.isScrobbleEnabled
        scrobblePercentSlider.value = settings.scrobblePercent
        updateScrobblePercentLabel()
        manualOfflineModeSwitch.isOn = settings.isForceOfflineMode
        autoReloadArtistSwitch.isOn = settings.isAutoReloadArtistsEnabled
        disablePopupsSwitch.isOn = !settings.isPopupsEnabled
        disableRotationSwitch.isOn = settings.isRotationLockEnabled
        disableScreenSleepSwitch.isOn = !settings.isScreenSleepEnabled
        enableBasicAuthSwitch.isOn = settings.isBasicAuthEnabled
        disableCellUsageSwitch.isOn = settings.isDisableUsageOver3G
        recoverSegmentedControl.selectedSegmentIndex = settings.recoverSetting
        maxBitrateWifiSegmentedControl.selectedSegmentIndex = settings.maxBitrateWifi
        maxBitrate3GSegmentedControl.selectedSegmentIndex = settings.maxBitrate3G
        enableLockScreenArt.isOn = settings.isLockScreenArtEnabled
        
        // Cache Settings
        enableManualCachingOnWWANSwitch.isOn = settings.isManualCachingOnWWANEnabled
        enableSongCachingSwitch.isOn = settings.isSongCachingEnabled
        enableNextSongCacheSwitch.isOn = settings.isNextSongCacheEnabled
        enableBackupCacheSwitch.isOn = settings.isBackupCacheEnabled
        cacheSpaceSlider.setThumbImage(UIImage(named: "controller-slider-thumb"), for: .normal)
        
        totalSpace = downloadsManager.totalSpace
        freeSpace = downloadsManager.freeSpace
        freeSpaceLabel.text = "Free space: \(formatFileSize(bytes: freeSpace))"
        totalSpaceLabel.text = "Total space: \(formatFileSize(bytes: totalSpace))"
        let percentFree = CGFloat(freeSpace) / CGFloat(totalSpace)
        freeSpaceBackground.frame.size.width *= percentFree
        cachingTypeSegmentedControl.selectedSegmentIndex = settings.cachingType
        toggleCacheControlsVisibility()
        cachingTypeToggle()
        
        autoDeleteCacheSwitch.isOn = settings.isAutoDeleteCacheEnabled
        autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex = settings.autoDeleteCacheType
        cacheSongCellColorSegmentedControl.selectedSegmentIndex = settings.downloadedSongCellColorType
        
        switch settings.quickSkipNumberOfSeconds {
        case 5: quickSkipSegmentControl.selectedSegmentIndex = 0
        case 15: quickSkipSegmentControl.selectedSegmentIndex = 1
        case 30: quickSkipSegmentControl.selectedSegmentIndex = 2
        case 45: quickSkipSegmentControl.selectedSegmentIndex = 3
        case 60: quickSkipSegmentControl.selectedSegmentIndex = 4
        case 120: quickSkipSegmentControl.selectedSegmentIndex = 5
        case 300: quickSkipSegmentControl.selectedSegmentIndex = 6
        case 600: quickSkipSegmentControl.selectedSegmentIndex = 7
        case 1200: quickSkipSegmentControl.selectedSegmentIndex = 8
        default: break
        }
        
        // Fix cut off text on small devices
        if UIDevice.isSmall {
            quickSkipSegmentControl.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11)], for: .normal)
        }
        
        cacheSpaceLabel2.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        
        maxVideoBitrate3GSegmentedControl.selectedSegmentIndex = settings.maxVideoBitrate3G
        maxVideoBitrateWifiSegmentedControl.selectedSegmentIndex = settings.maxVideoBitrateWifi
        
        resetAlbumArtCacheButton.backgroundColor = .white
        resetAlbumArtCacheButton.layer.cornerRadius = 8
        
        shareLogsButton.backgroundColor = .white
        shareLogsButton.layer.cornerRadius = 8
        
        openSourceLicensesButton.backgroundColor = .white
        openSourceLicensesButton.layer.cornerRadius = 8
    }
    
    func cachingTypeToggle() {
        switch cachingTypeSegmentedControl.selectedSegmentIndex {
        case 0:
            cacheSpaceLabel1.text = "Minimum free space:"
            cacheSpaceLabel2.text = formatFileSize(bytes: settings.minFreeSpace)
            cacheSpaceSlider.value = Float(settings.minFreeSpace) / Float(totalSpace)
        case 1:
            cacheSpaceLabel1.text = "Maximum cache size:"
            cacheSpaceLabel2.text = formatFileSize(bytes: settings.maxCacheSize)
            cacheSpaceSlider.value = Float(settings.maxCacheSize) / Float(totalSpace)
        default:
            break
        }
    }
    
    @IBAction func segmentAction(_ sender: UISegmentedControl) {
        // TODO: See if this workaround is still necessary
        guard Date().timeIntervalSince(loadedTime) > 0.5 else { return }
        
        switch sender {
        case recoverSegmentedControl:
            settings.recoverSetting = recoverSegmentedControl.selectedSegmentIndex
        case maxBitrateWifiSegmentedControl:
            settings.maxBitrateWifi = maxBitrateWifiSegmentedControl.selectedSegmentIndex
        case maxBitrate3GSegmentedControl:
            settings.maxBitrate3G = maxBitrate3GSegmentedControl.selectedSegmentIndex
        case cachingTypeSegmentedControl:
            settings.cachingType = cachingTypeSegmentedControl.selectedSegmentIndex
            cachingTypeToggle()
        case autoDeleteCacheTypeSegmentedControl:
            settings.autoDeleteCacheType = autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex
        case cacheSongCellColorSegmentedControl:
            settings.downloadedSongCellColorType = cacheSongCellColorSegmentedControl.selectedSegmentIndex
        case quickSkipSegmentControl:
            switch quickSkipSegmentControl.selectedSegmentIndex {
            case 0: settings.quickSkipNumberOfSeconds = 5
            case 1: settings.quickSkipNumberOfSeconds = 15
            case 2: settings.quickSkipNumberOfSeconds = 30
            case 3: settings.quickSkipNumberOfSeconds = 45
            case 4: settings.quickSkipNumberOfSeconds = 60
            case 5: settings.quickSkipNumberOfSeconds = 120
            case 6: settings.quickSkipNumberOfSeconds = 300
            case 7: settings.quickSkipNumberOfSeconds = 600
            case 8: settings.quickSkipNumberOfSeconds = 1200
            default: break
            }
            
            if UIDevice.isPad {
                // Update the quick skip buttons in the player with the new values on iPad since player is always visible
                NotificationCenter.postOnMainThread(name: Notifications.quickSkipSecondsSettingChanged)
            }
        case maxVideoBitrate3GSegmentedControl:
            settings.maxVideoBitrate3G = maxVideoBitrate3GSegmentedControl.selectedSegmentIndex
        case maxVideoBitrateWifiSegmentedControl:
            settings.maxVideoBitrateWifi = maxVideoBitrateWifiSegmentedControl.selectedSegmentIndex
        default:
            break
        }
    }
    
    func toggleCacheControlsVisibility() {
        if enableSongCachingSwitch.isOn {
            enableNextSongCacheLabel.alpha = 1
            enableNextSongCacheSwitch.isEnabled = true
            enableNextSongCacheSwitch.alpha = 1
            cachingTypeSegmentedControl.isEnabled = true
            cachingTypeSegmentedControl.alpha = 1
            cacheSpaceLabel1.alpha = 1
            cacheSpaceLabel2.alpha = 1
            freeSpaceLabel.alpha = 1
            totalSpaceLabel.alpha = 1
            totalSpaceBackground.alpha = 0.7
            freeSpaceBackground.alpha = 0.7
            cacheSpaceSlider.isEnabled = true
            cacheSpaceSlider.alpha = 1
        } else {
            enableNextSongCacheLabel.alpha = 0.5
            enableNextSongCacheSwitch.isEnabled = false
            enableNextSongCacheSwitch.alpha = 0.5
            cachingTypeSegmentedControl.isEnabled = false
            cachingTypeSegmentedControl.alpha = 0.5
            cacheSpaceLabel1.alpha = 0.5
            cacheSpaceLabel2.alpha = 0.5
            freeSpaceLabel.alpha = 0.5
            totalSpaceLabel.alpha = 0.5
            totalSpaceBackground.alpha = 0.3
            freeSpaceBackground.alpha = 0.3
            cacheSpaceSlider.isEnabled = false
            cacheSpaceSlider.alpha = 0.5
        }
    }
    
    @IBAction func switchAction(_ sender: UISwitch) {
        // TODO: See if this workaround is still necessary
        guard Date().timeIntervalSince(loadedTime) > 0.5 else { return }
        
        switch sender {
        case manualOfflineModeSwitch:
            settings.isForceOfflineMode = manualOfflineModeSwitch.isOn
            let name = manualOfflineModeSwitch.isOn ? Notifications.goOffline : Notifications.goOnline
            NotificationCenter.postOnMainThread(name: name)
        case enableScrobblingSwitch:
            settings.isScrobbleEnabled = enableScrobblingSwitch.isOn
        case enableManualCachingOnWWANSwitch:
            if enableManualCachingOnWWANSwitch.isOn {
                // Prompt the warning
                let message = "This feature can use a large amount of data. Please be sure to monitor your data plan usage to avoid overage charges from your wireless provider."
                let alert = UIAlertController(title: "Warning", message: message, preferredStyle: .alert)
                alert.addOKAction(style: .destructive) { _ in
                    self.settings.isManualCachingOnWWANEnabled = true
                }
                alert.addCancelAction() { _ in
                    // They canceled, turn off the switch
                    self.enableManualCachingOnWWANSwitch.setOn(false, animated: true)
                }
                present(alert, animated: true)
            } else {
                settings.isManualCachingOnWWANEnabled = false
            }
        case enableSongCachingSwitch:
            settings.isSongCachingEnabled = enableSongCachingSwitch.isOn
            toggleCacheControlsVisibility()
        case enableNextSongCacheSwitch:
            settings.isNextSongCacheEnabled = enableNextSongCacheSwitch.isOn
            toggleCacheControlsVisibility()
        case enableBackupCacheSwitch:
            if enableBackupCacheSwitch.isOn {
                // Prompt the warning
                let message = "This setting can take up a large amount of space on your computer or iCloud storage. Are you sure you want to backup your cached songs?"
                let alert = UIAlertController(title: "Warning", message: message, preferredStyle: .alert)
                alert.addOKAction(style: .destructive) { _ in
                    self.settings.isBackupCacheEnabled = true
                }
                alert.addCancelAction() { _ in
                    // They canceled, turn off the switch
                    self.enableBackupCacheSwitch.setOn(false, animated: true)
                }
                present(alert, animated: true)
            } else {
                settings.isBackupCacheEnabled = false
            }
        case autoDeleteCacheSwitch:
            settings.isAutoDeleteCacheEnabled = autoDeleteCacheSwitch.isOn
        case autoReloadArtistSwitch:
            settings.isAutoReloadArtistsEnabled = autoReloadArtistSwitch.isOn
        case disablePopupsSwitch:
            settings.isPopupsEnabled = !disablePopupsSwitch.isOn
        case disableRotationSwitch:
            settings.isRotationLockEnabled = disableRotationSwitch.isOn
        case disableScreenSleepSwitch:
            settings.isScreenSleepEnabled = !disableScreenSleepSwitch.isOn
            UIApplication.shared.isIdleTimerDisabled = disableScreenSleepSwitch.isOn
        case enableBasicAuthSwitch:
            settings.isBasicAuthEnabled = enableBasicAuthSwitch.isOn
        case enableLockScreenArt:
            settings.isLockScreenArtEnabled = enableLockScreenArt.isOn
        case disableCellUsageSwitch:
            settings.isDisableUsageOver3G = disableCellUsageSwitch.isOn
            if !settings.isOfflineMode && settings.isDisableUsageOver3G && !SceneDelegate.shared.isWifi {
                // We're on 3G and we just disabled use on 3G, so go offline
                NotificationCenter.postOnMainThread(name: Notifications.goOffline)
            } else if settings.isOfflineMode && !settings.isDisableUsageOver3G && !SceneDelegate.shared.isWifi {
                // We're on 3G and we just enabled use on 3G, so go online if we're offline
                NotificationCenter.postOnMainThread(name: Notifications.goOnline)
            }
        default:
            break
        }
    }
    
    @IBAction func resetAlbumArtCacheAction() {
        let message = "Are you sure you want to do this? This will clear all saved album art."
        let alert = UIAlertController(title: "Reset Album Art Cache", message: message, preferredStyle: .alert)
        alert.addOKAction(style: .destructive) { _ in
            self.perform(#selector(self.resetAlbumArtCache), with: nil, afterDelay: 0.05)
        }
        alert.addCancelAction()
        present(alert, animated: true)
    }
    
    @objc func resetFolderCache() {
        let serverId = settings.currentServerId
        store.resetFolderAlbumCache(serverId: serverId)
        store.deleteTagAlbums(serverId: serverId)
        SceneDelegate.shared.popLibraryTab()
    }
    
    @objc func resetAlbumArtCache() {
        let serverId = settings.currentServerId
        store.resetCoverArtCache(serverId: serverId)
        store.resetArtistArtCache(serverId: serverId)
        SceneDelegate.shared.popLibraryTab()
    }
    
    @IBAction func shareAppLogsAction() {
        guard let path = settings.zipAllLogFiles(), let pathUrl = URL(string: path) else {
            DDLogError("[OptionsViewController] Failed to share logs due to a problem with the path")
            return
        }
        
        let shareSheet = UIActivityViewController(activityItems: [pathUrl], applicationActivities: nil)
        if let popoverPresentationController = shareSheet.popoverPresentationController {
            // Fix exception on iPad
            // TODO: See if this is still necessary
            popoverPresentationController.sourceView = shareLogsButton;
            popoverPresentationController.sourceRect = shareLogsButton.bounds
        }
        
        shareSheet.completionWithItemsHandler = { (_, _, _, _) in
            // Delete the zip file since we're done with it
            do {
                try FileManager.default.removeItem(at: pathUrl)
            } catch {
                DDLogError("[OptionsViewController] Failed to remove log file at path \(path) with error: \(error)")
            }
        }
        present(shareSheet, animated: true)
    }
    
    @IBAction func viewOpenSourceLicensesAction() {
        present(UINavigationController(rootViewController: LicensesViewController()), animated: true)
    }
    
    func updateCacheSpaceSlider() {
        guard let formatted = cacheSpaceLabel2.text, let size = fileSize(formatted: formatted) else {
            DDLogError("[OptionsViewController] Failed to update cache space slider because failed to format file size")
            return
        }
        cacheSpaceSlider.value = Float(size) / Float(totalSpace)
    }
    
    @IBAction func updateMinFreeSpaceLabel() {
        let bytes = Int(cacheSpaceSlider.value * Float(self.totalSpace))
        cacheSpaceLabel2.text = formatFileSize(bytes: bytes)
    }
    
    @IBAction func updateMinFreeSpaceSetting() {
        switch cachingTypeSegmentedControl.selectedSegmentIndex {
        case 0:
            // Check if the user is trying to assing a higher min free space than is available space - 50MB
            if cacheSpaceSlider.value * Float(totalSpace) > Float(freeSpace) - 52428800 {
                settings.minFreeSpace = freeSpace - 52428800
                cacheSpaceSlider.value = Float(settings.minFreeSpace) / Float(totalSpace) // Leave 50MB space
            } else if cacheSpaceSlider.value * Float(totalSpace) < 52428800 {
                settings.minFreeSpace = 52428800
                cacheSpaceSlider.value = Float(settings.minFreeSpace) / Float(totalSpace) // Leave 50MB space
            } else {
                settings.minFreeSpace = Int(cacheSpaceSlider.value * Float(totalSpace))
            }
        case 1:
            // Check if the user is trying to assign a larger max cache size than there is available space - 50MB
            if cacheSpaceSlider.value * Float(totalSpace) > Float(freeSpace) - 52428800 {
                settings.maxCacheSize = freeSpace - 52428800
                cacheSpaceSlider.value = Float(settings.maxCacheSize) / Float(totalSpace) // Leave 50MB space
            } else if cacheSpaceSlider.value * Float(totalSpace) < 52428800 {
                settings.maxCacheSize = 52428800
                self.cacheSpaceSlider.value = Float(settings.maxCacheSize) / Float(totalSpace) // Leave 50MB space
            } else {
                settings.maxCacheSize = Int(cacheSpaceSlider.value * Float(totalSpace))
            }
        default:
            break
        }
        updateMinFreeSpaceLabel()
    }
    
    @IBAction func updateScrobblePercentLabel() {
        let percentInt = Int(scrobblePercentSlider.value * 100)
        scrobblePercentLabel.text = "\(percentInt)"
    }
    
    @IBAction func updateScrobblePercentSetting() {
        settings.scrobblePercent = scrobblePercentSlider.value
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
}

extension OptionsViewController: UITextFieldDelegate {
    
    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        guard let tableView = view.superview as? UITableView else { return }
        
        var rect = CGRect(x: 0, y: 500, width: 320, height: 5)
        tableView.scrollRectToVisible(rect, animated: false)
        rect = UIApplication.orientation.isPortrait ? CGRect(x: 0, y: 1600, width: 320, height: 5) : CGRect(x: 0, y: 1455, width: 320, height: 5)
        tableView.scrollRectToVisible(rect, animated: false)
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        updateMinFreeSpaceSetting()
        textField.resignFirstResponder()
        return true
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        updateCacheSpaceSlider()
    }
}
