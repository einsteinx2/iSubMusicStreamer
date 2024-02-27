//
//  ServerEditViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import CocoaLumberjackSwift
import Resolver

// TODO: implement this - for some reason, after an incorrect password on first server addition, it still adds the entry so you end up with 2 entries
// Not sure why that's able to happen as it only saves the server on the success callback...
final class ServerEditViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    
    let backgroundImageView = UIImageView(image: UIImage(named: "settings-page"))
    let urlField = InsetTextField(inset: 5)
    let usernameField = InsetTextField(inset: 5)
    let passwordField = InsetTextField(inset: 5)
    let closeButton = UIButton(type: .close)
    let saveButton = UIButton(type: .system)
    var serverToEdit: Server?
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.backgroundImageView.alpha = UIApplication.orientation.isPortrait ? 1.0 : 0.3
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
            self.serverToEdit = nil
            
            self.dismiss(animated: true, completion: nil)
            
            if UserDefaults.standard.object(forKey: "servers") != nil {
                // Pop the view back
                if let tabBarController = SceneDelegate.shared.tabBarController {
                    if tabBarController.selectedIndex == 4 && tabBarController.moreNavigationController.viewControllers.count >= 2 {
                        tabBarController.moreNavigationController.popToViewController(tabBarController.moreNavigationController.viewControllers[1], animated: true)
                    } else if let navController = tabBarController.selectedViewController as? UINavigationController {
                        navController.popToRootViewController(animated: true)
                    }
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
        urlField.keyboardType = .default
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
        
        if let serverToEdit = serverToEdit {
            urlField.text = serverToEdit.url.absoluteString
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
            alert.addOKAction() { _ in
                self.urlField.becomeFirstResponder()
            }
            present(alert, animated: true, completion: nil)
        } else if !checkUsername() {
            let message = "Please enter a username"
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addOKAction() { _ in
                self.usernameField.becomeFirstResponder()
            }
            present(alert, animated: true, completion: nil)
        } else if !checkPassword() {
            let message = "Please enter a password"
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addOKAction() { _ in
                self.passwordField.becomeFirstResponder()
            }
            present(alert, animated: true, completion: nil)
        } else {
            let loader = StatusLoader(urlString: urlField.text ?? "", username: usernameField.text ?? "", password: passwordField.text ?? "", delegate: self)
            HUD.show(message: "Checking Server") {
                HUD.hide()
                loader.cancelLoad()
            }
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

extension ServerEditViewController: APILoaderDelegate {
    func loadingFinished(loader: APILoader?) {
        HUD.hide()
        guard let statusLoader = loader as? StatusLoader else { return }
        
        if let serverToEdit = serverToEdit {
            serverToEdit.isVideoSupported = statusLoader.isVideoSupported
            serverToEdit.isNewSearchSupported = statusLoader.isNewSearchSupported
            if store.add(server: serverToEdit) {
                settings.currentServer = serverToEdit
            }
        } else if let url = URL(string: urlField.text ?? ""), let username = usernameField.text, let password = passwordField.text {
            let server = Server(id: store.nextServerId(), type: .subsonic, url: url, username: username, password: password)
            server.isVideoSupported = statusLoader.isVideoSupported
            server.isNewSearchSupported = statusLoader.isNewSearchSupported
            if store.add(server: server) {
                settings.currentServer = server
            }
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.reloadServerList)
        NotificationCenter.postOnMainThread(name: Notifications.showBackButton)
        
        self.dismiss(animated: true, completion: nil)
        
        if UIDevice.isPad {
            SceneDelegate.shared.padRootViewController?.menuViewController.showHome()
        }
        
        NotificationCenter.postOnMainThread(name: Notifications.switchServer)
    }
    
    func loadingFailed(loader: APILoader?, error: Error?) {
        HUD.hide()
        if let error = error, error.isCanceledURLRequest {
            return
        }
        
        var message = "Unknown error occured, please try again."
        if let error = error as? SubsonicError, case .badCredentials = error {
            message = "Either your username or password is incorrect, please try again"
        } else {
            message = "Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet."
            if let error = error {
                message += "\n\nError: \(error)"
            }
        }
        
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addOKAction()
        present(alert, animated: true)
    }
}
