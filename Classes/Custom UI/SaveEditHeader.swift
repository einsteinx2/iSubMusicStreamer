//
//  SaveEditHeader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

protocol SaveEditHeaderDelegate {
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader)
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader)
}

final class SaveEditHeader: UIView {
    private let saveLabel = UILabel()
    private let countLabel = UILabel()
    private let deleteLabel = UILabel()
    private let saveDeleteButton = UIButton(type: .custom)
    private let editLabel = UILabel()
    private let editButton = UIButton(type: .custom)
    
    private var saveType: String = ""
    private var countType: String = ""
    private var pluralizeClearType: Bool = true
    private var isLargeCount: Bool = false

    var delegate: SaveEditHeaderDelegate?
    private(set) var isEditing = false
    
    var count = 0 {
        didSet {
            countLabel.text = "\(count) \(countType.pluralize(amount: count))"
        }
    }
    
    var selectedCount = 0 {
        didSet {
            if selectedCount == 0 {
                deleteLabel.text = "Clear \((pluralizeClearType ? saveType.pluralized : saveType).capitalized)"
            } else {
                deleteLabel.text = "Remove \(selectedCount) \(countType.pluralize(amount: selectedCount))"
            }
        }
    }
        
    init(saveType: String = "", countType: String = "", pluralizeClearType: Bool = true, isLargeCount: Bool = false, delegate: SaveEditHeaderDelegate? = nil) {
//        self.saveType = saveType
//        self.countType = countType
//        self.pluralizeClearType = pluralizeClearType
//        self.isLargeCount = isLargeCount
        self.delegate = delegate
        super.init(frame: .zero)
        
        set(saveType: saveType, countType: countType, pluralizeClearType: pluralizeClearType, isLargeCount: isLargeCount)

//        if isLargeCount {
//            countLabel.textColor = .label
//            countLabel.textAlignment = .center
//            countLabel.font = .boldSystemFont(ofSize: 22)
//            addSubview(countLabel)
//            countLabel.snp.makeConstraints { make in
//                make.width.equalToSuperview().multipliedBy(0.75)
//                make.height.equalToSuperview()
//                make.leading.equalToSuperview()
//                make.bottom.equalToSuperview()
//            }
//        } else {
//            saveLabel.textColor = .label
//            saveLabel.textAlignment = .center
//            saveLabel.font = .boldSystemFont(ofSize: 22)
//            saveLabel.text = "Save \(saveType.capitalized)"
//            addSubview(saveLabel)
//            saveLabel.snp.makeConstraints { make in
//                make.width.equalToSuperview().multipliedBy(0.75)
//                make.height.equalToSuperview().multipliedBy(0.666)
//                make.leading.top.equalToSuperview()
//            }
//
//            countLabel.textColor = .label
//            countLabel.textAlignment = .center
//            countLabel.font = .boldSystemFont(ofSize: 12)
//            addSubview(countLabel)
//            countLabel.snp.makeConstraints { make in
//                make.width.equalToSuperview().multipliedBy(0.75)
//                make.height.equalToSuperview().multipliedBy(0.333)
//                make.leading.equalToSuperview()
//                make.bottom.equalToSuperview().offset(-4)
//            }
//        }

        deleteLabel.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        deleteLabel.textColor = .label
        deleteLabel.textAlignment = .center
        deleteLabel.font = .boldSystemFont(ofSize: 22)
        deleteLabel.adjustsFontSizeToFitWidth = true
        deleteLabel.minimumScaleFactor = 0.5
        deleteLabel.isHidden = true
        addSubview(deleteLabel)
        deleteLabel.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.75)
            make.leading.top.bottom.equalToSuperview()
        }

        saveDeleteButton.addTarget(self, action: #selector(saveDeleteAction(button:)), for: .touchUpInside)
        addSubview(saveDeleteButton)
        saveDeleteButton.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.75)
            make.leading.top.bottom.equalToSuperview()
        }

        editLabel.textColor = .systemBlue
        editLabel.textAlignment = .center
        editLabel.font = .boldSystemFont(ofSize: 22)
        editLabel.text = "Edit"
        addSubview(editLabel)
        editLabel.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.25)
            make.trailing.top.bottom.equalToSuperview()
        }

        editButton.addTarget(self, action: #selector(editAction(button:)), for: .touchUpInside)
        addSubview(editButton)
        editButton.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.25)
            make.trailing.top.bottom.equalToSuperview()
        }
    }
    
    func set(saveType: String = "", countType: String = "", pluralizeClearType: Bool = true, isLargeCount: Bool = false) {
        self.saveType = saveType
        self.countType = countType
        self.pluralizeClearType = pluralizeClearType
        self.isLargeCount = isLargeCount
        if !isLargeCount {
            saveLabel.text = "Save \(saveType.capitalized)"
        }
        
        saveLabel.removeFromSuperview()
        countLabel.removeFromSuperview()
        if isLargeCount {
            countLabel.textColor = .label
            countLabel.textAlignment = .center
            countLabel.font = .boldSystemFont(ofSize: 22)
            addSubview(countLabel)
            countLabel.snp.makeConstraints { make in
                make.width.equalToSuperview().multipliedBy(0.75)
                make.height.equalToSuperview()
                make.leading.equalToSuperview()
                make.bottom.equalToSuperview()
            }
        } else {
            saveLabel.textColor = .label
            saveLabel.textAlignment = .center
            saveLabel.font = .boldSystemFont(ofSize: 22)
            saveLabel.text = "Save \(saveType.capitalized)"
            addSubview(saveLabel)
            saveLabel.snp.makeConstraints { make in
                make.width.equalToSuperview().multipliedBy(0.75)
                make.height.equalToSuperview().multipliedBy(0.666)
                make.leading.top.equalToSuperview()
            }

            countLabel.textColor = .label
            countLabel.textAlignment = .center
            countLabel.font = .boldSystemFont(ofSize: 12)
            addSubview(countLabel)
            countLabel.snp.makeConstraints { make in
                make.width.equalToSuperview().multipliedBy(0.75)
                make.height.equalToSuperview().multipliedBy(0.333)
                make.leading.equalToSuperview()
                make.bottom.equalToSuperview().offset(-4)
            }
        }
        
//        if isLargeCount {
//            saveLabel.removeFromSuperview()
//            countLabel.font = .boldSystemFont(ofSize: 22)
//            countLabel.snp.remakeConstraints { make in
//                make.width.equalToSuperview().multipliedBy(0.75)
//                make.height.equalToSuperview()
//                make.leading.equalToSuperview()
//                make.bottom.equalToSuperview()
//            }
//        } else {
//            if saveLabel.superview == nil {
//                saveLabel.textColor = .label
//                saveLabel.textAlignment = .center
//                saveLabel.font = .boldSystemFont(ofSize: 22)
//                addSubview(saveLabel)
//            }
//            saveLabel.text = "Save \(saveType.capitalized)"
//            saveLabel.snp.remakeConstraints { make in
//                make.width.equalToSuperview().multipliedBy(0.75)
//                make.height.equalToSuperview().multipliedBy(0.666)
//                make.leading.top.equalToSuperview()
//            }
//
//            countLabel.textColor = .label
//            countLabel.textAlignment = .center
//            countLabel.font = .boldSystemFont(ofSize: 12)
//            addSubview(countLabel)
//            countLabel.snp.remakeConstraints { make in
//                make.width.equalToSuperview().multipliedBy(0.75)
//                make.height.equalToSuperview().multipliedBy(0.333)
//                make.leading.equalToSuperview()
//                make.bottom.equalToSuperview().offset(-4)
//            }
//        }
    }

    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }

    @objc private func saveDeleteAction(button: UIButton) {
        delegate?.saveEditHeaderSaveDeleteAction(self)
    }

    @objc private func editAction(button: UIButton) {
        delegate?.saveEditHeaderEditAction(self)
    }
    
    func setEditing(_ editing: Bool, animated: Bool) {
        guard isEditing != editing else { return }
        
        isEditing = editing
        if editing {
            editLabel.backgroundColor = UIColor(red: 0.008, green: 0.46, blue: 0.933, alpha: 1)
            editLabel.textColor = .label
            editLabel.text = "Done"
            selectedCount = 0
        } else {
            editLabel.backgroundColor = .clear
            editLabel.textColor = .systemBlue
            editLabel.text = "Edit"
        }
        
        saveLabel.isHidden = editing
        countLabel.isHidden = editing
        deleteLabel.isHidden = !editing
    }
}
