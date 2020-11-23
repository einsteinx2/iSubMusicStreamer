//
//  PageControlViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/16/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

class PageControlViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private var pageControlUsed = false
    
    private let numberOfPages = 4
    private var viewControllers = [UIViewController]()
    
    private var coverArtViewController: CoverArtViewController?
    var coverArtId: String? {
        get { return coverArtViewController?.coverArtId }
        set { coverArtViewController?.coverArtId = newValue }
    }
    var coverArtImage: UIImage? {
        get { return coverArtViewController?.image }
        set { coverArtViewController?.image = newValue }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Fix the scroll offset if the scrollview is resized during rotation
        coordinator.animate { _ in
            self.changePage()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // a page is the width of the scroll view
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.scrollsToTop = false;
        scrollView.bounces = false
        scrollView.isMultipleTouchEnabled = true
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.isUserInteractionEnabled = true
        scrollView.delegate = self;
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.height.equalTo(view.snp.width)
            make.leading.trailing.top.equalToSuperview()
        }
        
        pageControl.numberOfPages = numberOfPages
        pageControl.currentPage = 0
        pageControl.addTarget(self, action: #selector(changePage), for: .valueChanged)
        view.addSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.height.equalTo(20)
            make.top.equalTo(scrollView.snp.bottom)
            make.centerX.equalToSuperview()
        }
        
        var prevController: UIViewController? = nil
        for index in 0..<numberOfPages {
            var controller: UIViewController? = nil
            switch index {
            case 0:
                coverArtViewController = CoverArtViewController()
                controller = coverArtViewController
            case 1:
                controller = SongInfoViewController()
            case 2:
                controller = LyricsViewController(nibName: nil, bundle: nil)
            case 3:
                controller = DebugViewController(nibName: "DebugViewController", bundle: nil)
            default: break
            }
            
            if let controller = controller {
                viewControllers.append(controller)
    
                addChild(controller)
                scrollView.addSubview(controller.view)
                controller.view.snp.makeConstraints { make in
                    make.width.height.equalTo(view.snp.width)
                    if let prevController = prevController {
                        make.leading.equalTo(prevController.view.snp.trailing)
                    } else {
                        make.leading.equalToSuperview()
                    }
                    if index == numberOfPages - 1 {
                        make.trailing.equalToSuperview()
                    }
                }
                prevController = controller
            }
        }
    }
    
    @objc private func changePage() {
        let page = pageControl.currentPage;
        print("currentPage: \(pageControl.currentPage)")
        
        // update the scroll view to the appropriate page
        scrollView.setContentOffset(CGPoint(x: scrollView.bounds.width * CGFloat(page), y: 0), animated: true)
        
        // Set the boolean used when scrolls originate from the UIPageControl. See scrollViewDidScroll.
        pageControlUsed = true
    }
}

extension PageControlViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // We don't want a "feedback loop" between the UIPageControl and the scroll delegate in
        // which a scroll event generated from the user hitting the page control triggers updates from
        // the delegate method. We use a boolean to disable the delegate logic when the page control is used.
        if pageControlUsed  {
            // Send a notification so the playlist view hides the edit controls
            NotificationCenter.postNotificationToMainThread(name: "hideEditControls")
            
            // do nothing - the scroll was initiated from the page control, not the user dragging
            return;
        }
        
        // Switch the indicator when more than 50% of the previous/next page is visible
        let pageWidth = scrollView.bounds.size.width;
        let page = Int(floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1);
        self.pageControl.currentPage = page;
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        pageControlUsed = false
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControlUsed = false
    }
}
