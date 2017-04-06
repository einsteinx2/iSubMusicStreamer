//
//  CustomUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 12/22/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CellOverlay;
@interface CustomUITableViewCell : UITableViewCell

@property (nonatomic) BOOL isIndexShowing;
@property (nonatomic) BOOL isOverlayShowing;
@property (strong) CellOverlay *overlayView;
@property (strong) NSIndexPath *indexPath;
@property (nonatomic) BOOL isSearching;
@property (strong) UIImageView *deleteToggleImage;
@property BOOL isDelete;
- (UIImage *)nowPlayingImageBlack;
- (UIImage *)nowPlayingImageWhite;

- (void)showOverlay;
- (void)hideOverlay;

- (void)downloadAction;
- (void)queueAction;
- (void)blockerAction;

- (void)scrollLabels;

- (void)toggleDelete;

@end
