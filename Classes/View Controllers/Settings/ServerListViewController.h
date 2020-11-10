//
//  ServerListViewController.h
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"
#import "SUSLoaderDelegate.h"

@class SettingsTabViewController, HelpTabViewController;

@interface ServerListViewController : CustomUITableViewController <SUSLoaderDelegate>

@property (nonatomic) BOOL isEditing;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
//@property (nonatomic, copy) NSString *theNewRedirectionUrl;
@property (nonatomic, strong) SettingsTabViewController *settingsTabViewController;
@property (nonatomic, strong) HelpTabViewController *helpTabViewController;

- (void)addAction:(id)sender;
- (void)segmentAction:(id)sender;

@end
