//
//  ChatTableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

final class ChatTableViewCell: UITableViewCell {
    static let reuseId = "ChatTableViewCell"
    
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter
    }()
    
    private static func formatDate(chatMessage: ChatMessage) -> String {
        let date = Date(timeIntervalSince1970: chatMessage.timestamp)
        return dateFormatter.string(from: date)
    }
    
    var chatMessage: ChatMessage? = nil {
        didSet {
            if let chatMessage = chatMessage {
                usernameLabel.text = "\(chatMessage.username) @ \(Self.formatDate(chatMessage: chatMessage))"
                messageLabel.text = chatMessage.message
            }
        }
    }
    
    private var usernameLabel = UILabel()
    private var messageLabel = UILabel()
    
    private var messageHeightConstraint: Constraint?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
                
        selectionStyle = .none
        
        usernameLabel.textAlignment = .center
        usernameLabel.backgroundColor = .systemGray
        usernameLabel.textColor = .label
        usernameLabel.font = .boldSystemFont(ofSize: 10)
        addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints { make in
            make.height.equalTo(20)
            make.leading.trailing.top.equalToSuperview()
        }
        
        messageLabel.textAlignment = .left
        messageLabel.backgroundColor = .systemBackground
        messageLabel.textColor = .label
        messageLabel.font = .systemFont(ofSize: 20)
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 0
        addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            messageHeightConstraint = make.height.equalTo(0).priority(.low).constraint
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.top.equalTo(usernameLabel.snp.bottom).offset(5)
            make.bottom.equalToSuperview().offset(-5)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        
        // Automatically set the height based on the height of the message text
        let maxSize = CGSize(width: frame.size.width, height: CGFloat.greatestFiniteMagnitude)
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20)]
        let message = messageLabel.text ?? ""
        let height = message.boundingRect(with: maxSize,
                                          options: .usesLineFragmentOrigin,
                                          attributes: attributes,
                                          context: nil).size.height
        messageHeightConstraint?.update(offset: height < 40 ? 40 : height)
    }
}
