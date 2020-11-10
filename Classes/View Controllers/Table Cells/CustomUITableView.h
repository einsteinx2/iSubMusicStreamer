//
//  CustomUITableView.h
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface CustomUITableView : UITableView 

@property CGPoint startTouchPosition;
@property BOOL hasSwiped;
@property (strong) UITableViewCell *cellShowingOverlay;
@property (strong) UITableViewCell *tapAndHoldCell;
@property (strong) NSDate *lastDeleteToggle;

- (BOOL)isTouchHorizontal:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;

- (void)disableCellsTemporarily;
- (void)enableCells;

@end
