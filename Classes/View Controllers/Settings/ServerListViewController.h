//
//  ServerListViewController.h
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class SettingsTabViewController, Server;

@interface ServerListViewController : UIViewController <SUSLoaderDelegate>

@property (nonatomic, strong) NSArray<Server*> *servers;
@property (nonatomic, strong) Server *serverToEdit;

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) UIView *segmentControlContainer;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) SettingsTabViewController *settingsTabViewController;

- (void)addAction:(id)sender;
- (void)segmentAction:(id)sender;

@end
