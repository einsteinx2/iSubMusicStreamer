//
//  DownloadedIndicatorView.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

final class DownloadedIndicatorView: UIView {
    private let size: CGFloat
    
    override var intrinsicContentSize: CGSize { CGSize(width: size, height: size) }
    
    convenience init() {
        self.init(size: 20)
    }
    
    init(size: CGFloat) {
        self.size = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        
        let maskPath = UIBezierPath()
        maskPath.move(to: .zero)
        maskPath.addLine(to: CGPoint(x: size, y: 0))
        maskPath.addLine(to: CGPoint(x: 0, y: size))
        maskPath.close()
        
        let triangleMaskLayer = CAShapeLayer()
        triangleMaskLayer.path = maskPath.cgPath
        
        backgroundColor = Colors.currentCellColor
        layer.mask = triangleMaskLayer
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
}
