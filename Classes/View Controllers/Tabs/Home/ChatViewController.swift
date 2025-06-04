//
//  ChatViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver
import CocoaLumberjackSwift

final class ChatViewController: UIViewController {
    @Injected private var settings: SavedSettings
    @Injected private var analytics: Analytics
    
    var serverId: Int { (Resolver.resolve() as SavedSettings).currentServerId }
    
    private var loaderTask: Task<Void, Never>?
    
    private var chatMessages = [ChatMessage]()
    
    private let textInput = UITextView()
    private let tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Chat"
        
        setupDefaultTableView(tableView)
        tableView.register(ChatTableViewCell.self, forCellReuseIdentifier: ChatTableViewCell.reuseId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = Defines.tallRowHeight
        tableView.refreshControl = RefreshControl { [unowned self] in
            startLoad()
        }
        
        addHeader()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startLoad()
        analytics.log(event: .chatTab)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textInput.becomeFirstResponder()
    }
    
    deinit {
        loaderTask?.cancel()
        loaderTask = nil
    }
    
    private func addHeader() {
        // Create the container view and constrain it to the table
        let headerView = UIView()
        headerView.backgroundColor = .lightGray
        tableView.tableHeaderView = headerView
        headerView.snp.makeConstraints { make in
            make.height.equalTo(82)
            make.centerX.width.top.bottom.equalToSuperview()
        }
        
        let sendButton = UIButton(type: .custom)
        sendButton.addTarget(self, action: #selector(sendAction), for: .touchUpInside)
        sendButton.setImage(UIImage(named: "comment-write"), for: .normal)
        sendButton.setImage(UIImage(named: "comment-write-pressed"), for: .highlighted)
        headerView.addSubview(sendButton)
        sendButton.snp.makeConstraints { make in
            make.width.height.equalTo(60)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-10)
        }
        
        textInput.layer.borderWidth = 3
        textInput.layer.borderColor = UIColor.black.cgColor
        textInput.font = .systemFont(ofSize: 16)
        headerView.addSubview(textInput)
        textInput.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(5)
            make.trailing.equalTo(sendButton.snp.leading).offset(-10)
            make.top.equalToSuperview().offset(5)
            make.bottom.equalToSuperview().offset(-5)
        }
        
        // Force re-layout using the constraints
        tableView.tableHeaderView?.layoutIfNeeded()
        tableView.tableHeaderView = tableView.tableHeaderView
    }
    
    @objc private func sendAction() {
        guard let text = textInput.text, text.count > 0 else { return }
        textInput.resignFirstResponder()
        textInput.text = ""
        send(message: text)
    }
    
    private func send(message: String) {
        Task {
            do {
                HUD.show(message: "Sending")
                defer {
                    HUD.hide()
                }
                
                try await AsyncChatSendLoader(serverId: serverId, message: message).load()
                startLoad()
            } catch {
                textInput.text = message
            }
        }
    }
    
    func startLoad() {
        loaderTask?.cancel()
        loaderTask = Task {
            do {
                HUD.show(closeHandler: cancelLoad)
                defer {
                    HUD.hide()
                    tableView.refreshControl?.endRefreshing()
                }
                
                chatMessages = try await AsyncChatLoader(serverId: serverId).load()
                tableView.reloadData()
                tableView.setNeedsUpdateConstraints()
            } catch {
                if !error.isCanceled {
                    DDLogError("[ChatViewController] Failed to load new chat messages: \(error)")
                }
            }
        }
    }
    
    func cancelLoad() {
        HUD.hide()
        loaderTask?.cancel()
        loaderTask = nil
    }
}

extension ChatViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatTableViewCell.reuseId) as! ChatTableViewCell
        cell.chatMessage = chatMessages[indexPath.row]
        return cell
    }
}
