//
//  ISMSPlayerViewController.m
//  iSub
//
//  Created by Justin Hill on 10/2/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

#import "ISMSPlayerViewController.h"

@interface ISMSPlayerViewController ()

@end

@implementation ISMSPlayerViewController

- (void)loadView {
    self.view = [[ISMSPlayerView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    self.playerView = (ISMSPlayerView *)self.view;
    self.playerView.delegate = self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

@end
