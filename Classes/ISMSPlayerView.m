//
//  ISMSPlayerView.m
//  iSub
//
//  Created by Justin Hill on 10/2/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

#import "ISMSPlayerView.h"

@interface ISMSPlayerView ()

// Controls
@property (strong) UIView *topToolbarView;
@property (strong) UIView *topToolbarButtonsView;

@property (strong) UIView *footerInfoContainer;
@property (readonly) BOOL controlsShouldRetract;
@property (strong) NSLayoutConstraint *controlsTopConstraint;
@property BOOL controlsShowing;

@property (readonly) CGFloat topContentOffset;
@property (strong) UIImageView *coverArtImageView;

// 

@end

@implementation ISMSPlayerView

#pragma mark - Life cycle
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithRedInt:34 greenInt:34 blueInt:34 alpha:1];
        self.topToolbarView = [[UIView alloc] init];
        self.topToolbarButtonsView = [[UIView alloc] init];
        self.footerInfoContainer = [[UIView alloc] init];
        
        self.scrubberView = [[ISMSScrubberView alloc] init];
        self.scrubberView.delegate = self;
    }
    
    return self;
}

#pragma mark - Properties
/**
 @brief Whether or not the controls should retract based on the height of the screen.
 
 @return YES if the controls should retract, otherwise NO.
 */
- (BOOL)controlsShouldRetract {
    return [[UIScreen mainScreen] bounds].size.height < 568;
}

#pragma mark - Layout
- (void)layoutSubviews {
    [self layoutControls];
    [self layoutFooterInfo];
    [self layoutCoverArt];
    
    [super layoutSubviews];
}

/**
 @brief Lays out the controls at the top of the player. These controls may or may not retract
        depending on the size of the screen.
 */
- (void)layoutControls {
    if (!self.topToolbarView.superview) {
        self.topToolbarView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.topToolbarView];
        
        [self.topToolbarView autolayoutPinEdge:NSLayoutAttributeLeft toParentEdge:NSLayoutAttributeLeft constant:0];
        [self.topToolbarView autolayoutPinEdge:NSLayoutAttributeRight toParentEdge:NSLayoutAttributeRight constant:0];
        //[self.topToolbarView autolayoutPinEdge:NSLayoutAttributeTop toEdge:NSLayoutAttributeBottom ofSibling:self.viewController.topLayoutGuide constant:0];
        [self.topToolbarView autolayoutSetAttribute:NSLayoutAttributeHeight toConstant:70];
    }
    
    [self layoutScrubber];
    [self layoutTopToolbarButtons];
}

- (void)layoutScrubber {
    if (!self.scrubberView.superview) {
        self.scrubberView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.topToolbarView addSubview:self.scrubberView];
        
        [self.scrubberView autolayoutPinEdge:NSLayoutAttributeLeft toParentEdge:NSLayoutAttributeLeft constant:0];
        [self.scrubberView autolayoutPinEdge:NSLayoutAttributeRight toParentEdge:NSLayoutAttributeRight constant:0];
        [self.scrubberView autolayoutPinEdge:NSLayoutAttributeTop toParentEdge:NSLayoutAttributeTop constant:0];
        [self.scrubberView autolayoutSetAttribute:NSLayoutAttributeHeight toConstant:25];
    }
}

- (void)layoutTopToolbarButtons {
    if (!self.topToolbarButtonsView.superview) {
        self.topToolbarButtonsView.translatesAutoresizingMaskIntoConstraints = NO;
        self.topToolbarButtonsView.backgroundColor = [UIColor redColor];
        [self.topToolbarView addSubview:self.topToolbarButtonsView];
        
        [self.topToolbarButtonsView autolayoutPinEdge:NSLayoutAttributeLeft toParentEdge:NSLayoutAttributeLeft constant:0];
        [self.topToolbarButtonsView autolayoutPinEdge:NSLayoutAttributeRight toParentEdge:NSLayoutAttributeRight constant:0];
        [self.topToolbarButtonsView autolayoutPinEdge:NSLayoutAttributeTop toEdge:NSLayoutAttributeBottom ofSibling:self.scrubberView constant:0];
        [self.topToolbarButtonsView autolayoutPinEdge:NSLayoutAttributeBottom toParentEdge:NSLayoutAttributeBottom constant:0];
    }
}

- (void)layoutCoverArt {

}
        

/**
 @brief Lays out the info bar at the bottom of the screen. This bar may or may not retract
        depending on the size of the screen.
 */
- (void)layoutFooterInfo {
    
}

@end
