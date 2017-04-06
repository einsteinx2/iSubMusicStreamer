//
//  CustomUITableViewController.m
//  iSub
//
//  Created by Benjamin Baron on 10/9/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"

@implementation CustomUITableViewController

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxToggled) name:ISMSNotification_JukeboxEnabled object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxToggled) name:ISMSNotification_JukeboxDisabled object:nil];
    
    if (SYSTEM_VERSION_LESS_THAN(@"7"))
    {
        self.navigationController.navigationBar.translucent = NO;
        self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateBackgroundColor];
}

- (void)updateBackgroundColor
{
    self.view.backgroundColor = settingsS.isJukeboxEnabled ? viewObjectsS.jukeboxColor : viewObjectsS.windowColor;
}

- (void)jukeboxToggled
{
    [self updateBackgroundColor];
}

@end
