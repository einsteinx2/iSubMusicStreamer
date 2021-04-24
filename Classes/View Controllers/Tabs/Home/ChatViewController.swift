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

final class ChatViewController: UIViewController {
    @Injected private var analytics: Analytics
    
    var serverId: Int { Settings.shared().currentServerId }
    
    private var loader: ChatLoader?
    
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
        loader?.cancelLoad()
        loader?.delegate = nil
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
        HUD.show(message: "Sending")
        let chatSendLoader = ChatSendLoader(serverId: serverId, message: message)
        chatSendLoader.callback = { [weak self] _, success, error in
            HUD.hide()
            guard let self = self else { return }
            if success {
                self.startLoad()
            } else {
                self.textInput.text = message
            }
        }
        chatSendLoader.startLoad()
    }
    
    func startLoad() {
        HUD.show(closeHandler: cancelLoad)
        cancelLoad()
        loader = ChatLoader(serverId: serverId, delegate: self)
        loader?.startLoad()
    }
    
    func cancelLoad() {
        HUD.hide()
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
    }
}

extension ChatViewController: APILoaderDelegate {
    func loadingFinished(loader: APILoader?) {
        HUD.hide()
        if let loader = loader as? ChatLoader {
            chatMessages = loader.chatMessages
        }
        self.loader?.delegate = nil
        self.loader = nil
        tableView.reloadData()
        tableView.setNeedsUpdateConstraints()
        tableView.refreshControl?.endRefreshing()
    }
    
    func loadingFailed(loader: APILoader?, error: Error?) {
        HUD.hide()
        self.loader?.delegate = nil
        self.loader = nil
        tableView.refreshControl?.endRefreshing()
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
