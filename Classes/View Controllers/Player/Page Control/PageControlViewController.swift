//
//  PageControlViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/16/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

final class PageControlViewController: UIViewController {
    private enum PageType: Int, CaseIterable {
        case coverArt = 0, lyrics, songInfo, cacheStatus
    }
    
    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private var pageControlUsed = false
    private var isRotating = false
    
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
        isRotating = true
        coordinator.animate { _ in
            self.changePage()
        } completion: { _ in
            self.isRotating = false
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
        
        pageControl.pageIndicatorTintColor = .secondaryLabel
        pageControl.currentPageIndicatorTintColor = .label
        pageControl.numberOfPages = PageType.count
        pageControl.currentPage = 0
        pageControl.addTarget(self, action: #selector(changePage), for: .valueChanged)
        view.addSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.height.equalTo(20)
            make.top.equalTo(scrollView.snp.bottom)
            make.centerX.equalToSuperview()
        }
        
        var prevController: UIViewController? = nil
        for page in PageType.allCases {
            var controller: UIViewController? = nil
            switch page {
            case .coverArt:
                coverArtViewController = CoverArtViewController()
                controller = coverArtViewController
            case .lyrics:
                controller = LyricsViewController()
            case .songInfo:
                controller = SongInfoViewController()
            case .cacheStatus:
                controller = CacheStatusViewController()
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
                    if page.rawValue == PageType.count - 1 {
                        make.trailing.equalToSuperview()
                    }
                }
                prevController = controller
            }
        }
    }
    
    @objc private func changePage() {
        let page = pageControl.currentPage
        
        // update the scroll view to the appropriate page
        scrollView.setContentOffset(CGPoint(x: scrollView.bounds.width * CGFloat(page), y: 0), animated: true)
        
        // Set the boolean used when scrolls originate from the UIPageControl. See scrollViewDidScroll.
        pageControlUsed = true
    }
    
    func showCoverArt(animated: Bool) {
        guard pageControl.currentPage != PageType.coverArt.rawValue else { return }
        pageControlUsed = false
        pageControl.currentPage = PageType.coverArt.rawValue
        scrollView.setContentOffset(CGPoint(x: scrollView.bounds.width * CGFloat(pageControl.currentPage), y: 0), animated: animated)
    }
}

extension PageControlViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // We don't want a "feedback loop" between the UIPageControl and the scroll delegate in
        // which a scroll event generated from the user hitting the page control triggers updates from
        // the delegate method. We use a boolean to disable the delegate logic when the page control is used.
        if pageControlUsed || isRotating {
            // do nothing - the scroll was initiated from the page control, not the user dragging
            return;
        }
        
        // Switch the indicator when more than 50% of the previous/next page is visible
        let pageWidth = scrollView.bounds.size.width;
        if pageWidth > 0 {
            let page = Int(floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1)
            self.pageControl.currentPage = page
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        pageControlUsed = false
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControlUsed = false
    }
}
