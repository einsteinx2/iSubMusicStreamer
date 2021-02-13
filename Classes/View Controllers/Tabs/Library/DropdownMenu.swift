//
//  DropdownMenu.swift
//  iSub
//
//  Created by Benjamin Baron on 2/10/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

protocol DropdownMenuDelegate {
    func dropdownMenuNumberOfItems(_ dropdownMenu: DropdownMenu) -> Int
    func dropdownMenu(_ dropdownMenu: DropdownMenu, titleForIndex index: Int) -> String
    func dropdownMenu(_ dropdownMenu: DropdownMenu, selectedItemAt index: Int)
    func dropdownMenu(_ dropdownMenu: DropdownMenu, willToggleWithHeightChange heightChange: CGFloat, animated: Bool, animationDuration: Double)
}

final class DropdownMenu: UIView {
    static let defaultHeight: CGFloat = UIDevice.isSmall ? 40 : 44
    
    private let animationDuration = 0.15
    private let borderColor = UIColor.systemGray
    private let labelFont = UIFont.boldSystemFont(ofSize: 20)
    private let labelTextColor = UIColor.label
    private let labelBackgroundColor = Colors.background
    
    var delegate: DropdownMenuDelegate? { didSet { updateItems() }}
    let loadingTitle: String
    let height: CGFloat
    
    private(set) var isOpen = false
    var selectedIndex = -1 {
        didSet {
            let name = delegate?.dropdownMenu(self, titleForIndex: selectedIndex) ?? ""
            selectedItemButton.setTitle(name, for: .normal)
        }
    }

    private let arrowView = UIImageView(image: UIImage(named: "folder-dropdown-arrow"))
    private let selectedItemButton = UIButton(type: .custom)
    private let itemStackView = UIStackView()
    private var itemButtons = [UIButton]()
    private var itemHighlightView = UIView()
    
    // Re-draw colors
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = borderColor.cgColor
    }
    
    init(closedHeight: CGFloat = defaultHeight, loadingTitle: String = "Loading...", delegate: DropdownMenuDelegate? = nil) {
        self.height = closedHeight
        self.loadingTitle = loadingTitle
        self.delegate = delegate
        super.init(frame: .zero)
        setupViews()
        updateItems()
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    private func setupViews() {
        isUserInteractionEnabled = true
        backgroundColor = .systemGray5
        
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = 2
        layer.cornerRadius = 8
        layer.masksToBounds = true
        
        selectedItemButton.addTarget(self, action: #selector(toggleAction), for: .touchUpInside)
        selectedItemButton.setTitle(loadingTitle, for: .normal)
        selectedItemButton.setTitleColor(labelTextColor, for: .normal)
        selectedItemButton.titleLabel?.textAlignment = .center
        selectedItemButton.titleLabel?.font = labelFont
        selectedItemButton.backgroundColor = .clear
        addSubview(selectedItemButton)
        selectedItemButton.snp.makeConstraints { make in
            make.height.equalTo(height)
            make.leading.equalToSuperview().offset(5)
            make.trailing.equalToSuperview().offset(-5)
            make.top.equalToSuperview()
        }
        
        arrowView.contentMode = .scaleAspectFit
        addSubview(arrowView)
        arrowView.snp.makeConstraints { make in
            make.height.width.equalTo(18)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(selectedItemButton)
        }
        
        itemStackView.axis = .vertical
        itemStackView.spacing = 0
        addSubview(itemStackView)
        itemStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(selectedItemButton.snp.bottom)
        }
    }
    
    func updateItems() {
        // Clean up old data
        close(animated: false)
        itemButtons.forEach { $0.removeFromSuperview() }
        itemButtons.removeAll()
        
        // Create new labels
        guard let delegate = delegate else { return }
        let numberOfItems = delegate.dropdownMenuNumberOfItems(self)
        for i in 0..<numberOfItems {
            let title = delegate.dropdownMenu(self, titleForIndex: i)
            let button = UIButton(type: .custom)
            button.addTarget(self, action: #selector(itemButtonAction(button:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(itemButtonTouchDownAction(button:)), for: .touchDown)
            button.addTarget(self, action: #selector(itemButtonTouchUpAction(button:)), for: [.touchUpInside, .touchUpOutside])
            button.backgroundColor = labelBackgroundColor
            button.setTitle(title, for: .normal)
            button.setTitleColor(labelTextColor, for: .normal)
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.font = labelFont
            button.tag = i
            button.isAccessibilityElement = false
            itemButtons.append(button)
            itemStackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.height.equalTo(height)
            }
        }
        
        itemHighlightView.backgroundColor = labelTextColor.withAlphaComponent(0.3)
        itemHighlightView.alpha = 0
        itemHighlightView.removeFromSuperview()
        if let firstButton = itemButtons.first {
            itemStackView.addSubview(itemHighlightView)
            itemHighlightView.snp.makeConstraints { make in
                make.height.leading.trailing.equalTo(firstButton)
                make.top.equalTo(0)
            }
        }
            
//        dropdownButton.accessibilityLabel = selectedItemLabel.text
    }
    
    @objc private func toggleAction() {
        toggle(animated: true)
    }
    
    @objc private func itemButtonTouchDownAction(button: UIButton) {
        itemHighlightView.alpha = 1
        itemHighlightView.snp.updateConstraints { make in
            make.top.equalTo(CGFloat(button.tag) * height)
        }
    }
    
    @objc private func itemButtonTouchUpAction(button: UIButton) {
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseOut) {
            self.itemHighlightView.alpha = 0
        }
    }
    
    @objc private func itemButtonAction(button: UIButton) {
        close()
        selectedIndex = button.tag
        
        // Wait for the menu to close before informing the delegate
        DispatchQueue.main.async(after: animationDuration) {
            self.delegate?.dropdownMenu(self, selectedItemAt: self.selectedIndex)
        }
    }
    
    func toggle(animated: Bool = true) {
        isOpen = !isOpen
        
        // Rotate the arrow
        func rotateArrow() {
            let rotationModifier: CGFloat = isOpen ? 60 : 0
            arrowView.transform = CGAffineTransform(rotationAngle: (CGFloat.pi / 180) * rotationModifier)
        }
        if animated {
            UIView.animate(withDuration: animationDuration) {
                rotateArrow()
            }
        } else {
            rotateArrow()
        }
        
        // Inform delegate to resize height
        // TODO: Make this more universal so it's capable of resizing itself when not in a table header
        DispatchQueue.main.async(after: animationDuration) {
            // Wait for the highlight view to fade before calling the delegate to close the menu
            let stackHeight = self.itemStackView.frame.height - self.height
            self.delegate?.dropdownMenu(self, willToggleWithHeightChange: self.isOpen ? stackHeight : -stackHeight, animated: animated, animationDuration: self.animationDuration)
        }
        
    }
    
    func open(animated: Bool = true) {
        guard !isOpen else { return }
        toggle(animated: animated)
    }
    
    func close(animated: Bool = true) {
        guard isOpen else { return }
        toggle(animated: animated)
    }
}
