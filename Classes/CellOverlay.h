//
//  CellOverlay.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface CellOverlay : UIView 

@property (strong) UIButton *inputBlocker;
@property (strong) UIButton *downloadButton;
@property (strong) UIButton *queueButton;

+ (CellOverlay*)cellOverlayWithTableCell:(UITableViewCell*)cell;
- (id)initWithTableCell:(UITableViewCell*)cell;

- (void)enableButtons;

@end
