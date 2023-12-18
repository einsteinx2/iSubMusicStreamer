//
//  ServerEditViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import CocoaLumberjackSwift

@objc final class ServerEditViewController: UIViewController {    
    let backgroundImageView = UIImageView(image: UIImage(named: "settings-page"))
    let urlField = InsetTextField(inset: 5)
    let usernameField = InsetTextField(inset: 5)
    let passwordField = InsetTextField(inset: 5)
    let closeButton = UIButton(type: .close)
    let saveButton = UIButton(type: .system)
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.backgroundImageView.alpha = UIApplication.orientation().isPortrait ? 1.0 : 0.3
        }, completion: nil)
    }
    
    override func viewDidLoad() {
        view.backgroundColor = .black
        view.overrideUserInterfaceStyle = .dark
        
        view.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.width.equalTo(320)
            make.height.equalTo(460)
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        closeButton.addClosure(for: .touchUpInside) { [unowned self] in
            ViewObjects.shared().serverToEdit = nil
            
            self.dismiss(animated: true, completion: nil)
            
            if UserDefaults.standard.object(forKey: "servers") != nil {
                // Pop the view back
                let currentTabBarController = AppDelegate.shared().currentTabBarController
                if currentTabBarController.selectedIndex == 4 && currentTabBarController.moreNavigationController.viewControllers.count >= 2 {
                    currentTabBarController.moreNavigationController.popToViewController(currentTabBarController.moreNavigationController.viewControllers[1], animated: true)
                } else if let navController = currentTabBarController.selectedViewController as? UINavigationController {
                    navController.popToRootViewController(animated: true)
                }
            }
        }
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(10)
        }
                
        let urlLabel = UILabel()
        urlLabel.font = .systemFont(ofSize: 17)
        urlLabel.textColor = .lightGray
        urlLabel.text = "http://myserver.subsonic.org"
        
        urlField.delegate = self
        urlField.backgroundColor = .white
        urlField.textColor = .black
        urlField.keyboardType = .URL
        urlField.textContentType = .URL
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.layer.cornerRadius = 8
        urlField.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        
        let usernameLabel = UILabel()
        usernameLabel.font = .systemFont(ofSize: 17)
        usernameLabel.textColor = .lightGray
        usernameLabel.text = "username"
        
        usernameField.delegate = self
        usernameField.backgroundColor = .white
        usernameField.textColor = .black
        usernameField.keyboardType = .default
        usernameField.textContentType = .username
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        usernameField.layer.cornerRadius = 8
        usernameField.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        
        let passwordLabel = UILabel()
        passwordLabel.font = .systemFont(ofSize: 17)
        passwordLabel.textColor = .lightGray
        passwordLabel.text = "password"
        
        passwordField.delegate = self
        passwordField.backgroundColor = .white
        passwordField.textColor = .black
        passwordField.keyboardType = .default
        passwordField.textContentType = .password
        passwordField.isSecureTextEntry = true
        passwordField.autocapitalizationType = .none
        passwordField.autocorrectionType = .no
        passwordField.layer.cornerRadius = 8
        passwordField.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        
        let stackView = UIStackView()
        stackView.backgroundColor = .clear
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.spacing = 5
        stackView.addArrangedSubviews([urlLabel, urlField, usernameLabel, usernameField, passwordLabel, passwordField])
        view.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(50)
            make.trailing.equalToSuperview().offset(-50)
            make.height.equalTo(240)
        }
        
        let saveButton = UIButton(type: .system)
        saveButton.addTarget(self, action: #selector(saveButtonAction), for: .touchUpInside)
        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp.bottom).offset(20)
            make.trailing.equalTo(stackView)
        }
        
        if let serverToEdit = ViewObjects.shared().serverToEdit {
            urlField.text = serverToEdit.url
            usernameField.text = serverToEdit.username
            passwordField.text = serverToEdit.password
        } else {
            urlField.becomeFirstResponder()
        }
    }
    
    private func checkURL() -> Bool {
        guard let url = urlField.text, url.count > 0 else { return false }
        
        // Add http:// if needed
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
           urlField.text = "http://\(url)"
        }
        
        // Remove trailing / if needed
        if url.last == "/" {
            urlField.text = String(url.prefix(url.count - 1))
        }
        
        return true
    }
    
    private func checkUsername() -> Bool {
        return usernameField.text?.count ?? 0 > 0
    }
    
    private func checkPassword() -> Bool {
        return passwordField.text?.count ?? 0 > 0
    }
    
    @objc private func saveButtonAction() {
        if !checkURL() {
            let message = "The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional"
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel) { _ in
                self.urlField.becomeFirstResponder()
            })
            present(alert, animated: true, completion: nil)
        } else if !checkUsername() {
            let message = "Please enter a username"
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel) { _ in
                self.usernameField.becomeFirstResponder()
            })
            present(alert, animated: true, completion: nil)
        } else if !checkPassword() {
            let message = "Please enter a password"
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel) { _ in
                self.passwordField.becomeFirstResponder()
            })
            present(alert, animated: true, completion: nil)
        } else {
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: "Checking Server")
            let loader = SUSStatusLoader(delegate: self)
            loader.urlString = urlField.text
            loader.username = usernameField.text
            loader.password = passwordField.text
            loader.startLoad()
        }
    }
}

extension ServerEditViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        urlField.resignFirstResponder()
        usernameField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        if textField == urlField {
            usernameField.becomeFirstResponder()
        } else if textField == usernameField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            if !checkURL() {
                urlField.becomeFirstResponder()
            } else if !checkUsername() {
                usernameField.becomeFirstResponder()
            } else if !checkPassword() {
                passwordField.becomeFirstResponder()
            } else {
                saveButtonAction()
            }
        }
        return true
    }
    
    // This dismisses the keyboard when any area outside the keyboard is touched
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        urlField.resignFirstResponder()
        usernameField.resignFirstResponder()
        passwordField.resignFirstResponder()
        super.touchesBegan(touches, with: event)
    }
}

extension ServerEditViewController: SUSLoaderDelegate {
    func loadingFailed(_ loader: SUSLoader!, withError error: Error!) {
        ViewObjects.shared().hideLoadingScreen()
        
        var message = "Unknown error occured, please try again."
        if error != nil {
            let nsError = error as NSError
            if nsError.code != ISMSErrorCode_IncorrectCredentials {
                message = "Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\nError code \(nsError.code):\n\(nsError.localizedDescription)"
            } else {
                message = "Either your username or password is incorrect, please try again"
            }
        }
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func loadingFinished(_ loader: SUSLoader!) {
        ViewObjects.shared().hideLoadingScreen()
        
        let server = Server()
        server.url = urlField.text
        server.username = usernameField.text
        server.password = passwordField.text
        server.type = SUBSONIC
        
        if Settings.shared().serverList == nil {
            Settings.shared().serverList = NSMutableArray()
        }
        
        if let serverToEdit = ViewObjects.shared().serverToEdit, let serverList = Settings.shared().serverList {
            // Replace the entry in the server list
            if let index = Settings.shared().serverList?.index(of: serverToEdit) {
                Settings.shared().serverList?.replaceObject(at: index, with: server)
            }
            
            // Update the serverToEdit to the new details
            ViewObjects.shared().serverToEdit = server
            
            // Save the plist values
            UserDefaults.standard.set(server.url, forKey: "url")
            UserDefaults.standard.set(server.username, forKey: "username")
            UserDefaults.standard.set(server.password, forKey: "password")
            do {
                let archivedServerList = try NSKeyedArchiver.archivedData(withRootObject: serverList, requiringSecureCoding: true)
                UserDefaults.standard.set(archivedServerList, forKey: "servers")
            } catch {
                DDLogError("Error archiving the server list: \(error)")
            }
            UserDefaults.standard.synchronize()
            
            NotificationCenter.postNotificationToMainThread(name: "reloadServerList")
            NotificationCenter.postNotificationToMainThread(name: "showSaveButton")
            
            self.dismiss(animated: true, completion: nil)
            
            var userInfo = [AnyHashable: Any]()
            if let statusLoader = loader as? SUSStatusLoader {
                userInfo["isVideoSupported"] = statusLoader.isVideoSupported
                userInfo["isNewSearchAPI"] = statusLoader.isNewSearchAPI
            }
            NotificationCenter.postNotificationToMainThread(name: "switchServer", userInfo: userInfo)
        } else if let serverList = Settings.shared().serverList {
            // Create the entry in serverList
            ViewObjects.shared().serverToEdit = server
            Settings.shared().serverList?.add(server)
            
            if let statusLoader = loader as? SUSStatusLoader {
                Settings.shared().isVideoSupported = statusLoader.isVideoSupported
                Settings.shared().isNewSearchAPI = statusLoader.isNewSearchAPI
            }
            
            // Save the plist values
            UserDefaults.standard.set(server.url, forKey: "url")
            UserDefaults.standard.set(server.username, forKey: "username")
            UserDefaults.standard.set(server.password, forKey: "password")
            do {
                let archivedServerList = try NSKeyedArchiver.archivedData(withRootObject: serverList, requiringSecureCoding: true)
                UserDefaults.standard.set(archivedServerList, forKey: "servers")
            } catch {
                DDLogError("Error archiving the server list: \(error)")
            }
            UserDefaults.standard.synchronize()
            
            NotificationCenter.postNotificationToMainThread(name: "reloadServerList")
            NotificationCenter.postNotificationToMainThread(name: "showSaveButton")
            
            self.dismiss(animated: true, completion: nil)
            
            if UIDevice.isPad() {
                AppDelegate.shared().padRootViewController.menuViewController.showHome()
            }
            
            var userInfo = [AnyHashable: Any]()
            if let statusLoader = loader as? SUSStatusLoader {
                userInfo["isVideoSupported"] = statusLoader.isVideoSupported
                userInfo["isNewSearchAPI"] = statusLoader.isNewSearchAPI
            }
            NotificationCenter.postNotificationToMainThread(name: "switchServer", userInfo: userInfo)
        }
    }
}
